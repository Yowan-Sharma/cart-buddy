import secrets
from datetime import timedelta
from decimal import Decimal

from django.contrib.auth.hashers import check_password, make_password
from django.conf import settings
from django.db import transaction
from django.db.models import Count, Q, Sum
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from core.filters import OrganisationFilterBackend

from organisations.models import MembershipRole, MembershipStatus, OrganisationMembership

from chats.models import ChatMessageType, OrderChatMessage
from payments.models import (
	PaymentStatus,
	PaymentTransaction,
	Wallet,
	WalletTransaction,
	WalletTransactionType,
)
from payments.services import calculate_cart_commission_share

from .models import (
	HandoverOtp,
	HandoverOtpStatus,
	Order,
	OrderItem,
	OrderItemStatus,
	OrderParticipant,
	ParticipantRole,
	OrderStatus,
	OrderStatusHistory,
	ParticipantStatus,
)
from .serializers import (
	CartSubmitSerializer,
	HandoverOtpGenerateSerializer,
	HandoverOtpSerializer,
	HandoverOtpVerifySerializer,
	OrderItemSerializer,
	OrderItemReviewSerializer,
	OrderParticipantSerializer,
	OrderSerializer,
	OrderStatusHistorySerializer,
	OrderStatusUpdateSerializer,
)


ALLOWED_MANAGER_ROLES = [MembershipRole.OWNER, MembershipRole.ADMIN, MembershipRole.STAFF]


def _is_org_member(user, organisation_id):
	if user.is_superuser:
		return True
	return OrganisationMembership.objects.filter(
		organisation_id=organisation_id,
		user=user,
		status=MembershipStatus.ACTIVE,
	).exists()


def _is_org_admin(user, organisation_id):
	if user.is_superuser:
		return True
	return OrganisationMembership.objects.filter(
		organisation_id=organisation_id,
		user=user,
		status=MembershipStatus.ACTIVE,
		role__in=ALLOWED_MANAGER_ROLES,
	).exists()


def _is_order_manager(user, order):
	if user.is_superuser or order.creator_id == user.id:
		return True
	if order.organisation_id:
		return _is_org_admin(user, order.organisation_id)
	return False


def _is_order_member(user, order):
	if user.is_superuser or order.creator_id == user.id:
		return True
	if order.participants.filter(user=user).exists():
		return True
	if order.organisation_id:
		return OrganisationMembership.objects.filter(
			organisation_id=order.organisation_id,
			user=user,
			status=MembershipStatus.ACTIVE,
		).exists()
	return False


def _get_order_participant(order, user):
	return OrderParticipant.objects.filter(order=order, user=user).first()


def _post_system_message(order, message, metadata=None):
	creator = order.creator
	if not creator:
		return
	OrderChatMessage.objects.create(
		order=order,
		sender=creator,
		message_type=ChatMessageType.SYSTEM,
		message=message,
		metadata=metadata or {},
	)


def _recalculate_participant_due(participant):
	approved_total = (
		participant.items.filter(
			is_active=True,
			status=OrderItemStatus.APPROVED,
		).aggregate(total=Sum("line_total")).get("total")
		or Decimal("0.00")
	)
	participant.amount_due = approved_total
	if participant.role == ParticipantRole.CREATOR:
		participant.amount_paid = approved_total
		participant.status = ParticipantStatus.PAID
	elif participant.amount_paid <= Decimal("0.00"):
		participant.status = ParticipantStatus.JOINED
	elif participant.amount_paid >= participant.amount_due and participant.amount_due > Decimal("0.00"):
		participant.status = ParticipantStatus.PAID
	elif participant.amount_due <= Decimal("0.00"):
		participant.status = ParticipantStatus.REFUNDED if participant.amount_paid <= Decimal("0.00") else ParticipantStatus.JOINED
	else:
		participant.status = ParticipantStatus.JOINED
	participant.save(update_fields=["amount_due", "amount_paid", "status"])
	return approved_total


def _refund_excess_if_needed(participant, reason):
	from payments.models import PaymentRefund, PaymentStatus, RefundStatus
	from payments.services import RazorpayConfigError, create_refund

	refundable_amount = participant.amount_paid - participant.amount_due
	if refundable_amount <= Decimal("0.00"):
		return None

	remaining = refundable_amount
	processed = []
	captured_transactions = participant.payment_transactions.filter(
		status=PaymentStatus.CAPTURED,
	).order_by("-created_at")

	for payment_txn in captured_transactions:
		if remaining <= Decimal("0.00"):
			break

		already_refunded = (
			payment_txn.refunds.filter(status=RefundStatus.PROCESSED)
			.aggregate(total=Sum("amount"))
			.get("total")
			or Decimal("0.00")
		)
		available = payment_txn.amount - already_refunded
		if available <= Decimal("0.00"):
			continue

		refund_amount = min(available, remaining)
		refund_record = PaymentRefund.objects.create(
			payment_transaction=payment_txn,
			order=participant.order,
			participant=participant,
			user=participant.user,
			amount=refund_amount,
			currency=payment_txn.currency,
			reason=reason,
		)

		try:
			payload = create_refund(
				razorpay_payment_id=payment_txn.razorpay_payment_id,
				amount=refund_amount,
				notes={
					"order_id": str(participant.order_id),
					"participant_id": str(participant.id),
					"reason": reason,
				},
			)
			refund_record.status = RefundStatus.PROCESSED
			refund_record.provider_refund_id = payload.get("id")
			refund_record.gateway_payload = payload
			refund_record.failed_reason = ""
			refund_record.save(
				update_fields=[
					"status",
					"provider_refund_id",
					"gateway_payload",
					"failed_reason",
					"updated_at",
				]
			)
			remaining -= refund_amount
			processed.append(refund_record)
		except RazorpayConfigError as exc:
			refund_record.status = RefundStatus.FAILED
			refund_record.failed_reason = str(exc)
			refund_record.save(update_fields=["status", "failed_reason", "updated_at"])
			break
		except Exception as exc:
			refund_record.status = RefundStatus.FAILED
			refund_record.failed_reason = str(exc)
			refund_record.save(update_fields=["status", "failed_reason", "updated_at"])
			break

	if processed:
		total_refunded = sum((refund.amount for refund in processed), Decimal("0.00"))
		participant.amount_paid = max(Decimal("0.00"), participant.amount_paid - total_refunded)
		if participant.amount_due <= Decimal("0.00") and participant.amount_paid <= Decimal("0.00"):
			participant.status = ParticipantStatus.REFUNDED
		elif participant.amount_paid >= participant.amount_due and participant.amount_due > Decimal("0.00"):
			participant.status = ParticipantStatus.PAID
		else:
			participant.status = ParticipantStatus.JOINED
		participant.save(update_fields=["amount_paid", "status"])

	return processed


class OrderListCreateView(generics.ListCreateAPIView):
	serializer_class = OrderSerializer
	permission_classes = [IsAuthenticated]
	filter_backends = [OrganisationFilterBackend]

	def get_queryset(self):
		queryset = (
			Order.objects.select_related("creator", "organisation", "campus")
			.annotate(participants_count=Count("participants", distinct=True), items_count=Count("items", distinct=True))
		)
		status_param = self.request.query_params.get("status")
		if status_param:
			statuses = status_param.split(",")
			queryset = queryset.filter(status__in=statuses)

		mine_param = self.request.query_params.get("mine")
		if mine_param == "true":
			queryset = queryset.filter(participants__user=self.request.user)

		campus_param = self.request.query_params.get("campus")
		if campus_param:
			queryset = queryset.filter(campus_id=campus_param)

		search_param = self.request.query_params.get("search")
		if search_param:
			queryset = queryset.filter(
				Q(title__icontains=search_param) |
				Q(store_name__icontains=search_param)
			)

		return queryset.order_by("-created_at").distinct()

	@transaction.atomic
	def perform_create(self, serializer):
		organisation = serializer.validated_data.get("organisation")
		if organisation and not _is_org_member(self.request.user, organisation.id):
			raise PermissionDenied("You must be an active member of this organisation to create an order.")
		if organisation and not organisation.pickup_points.filter(is_active=True).exists():
			raise PermissionDenied("This organisation has no active pickup points configured yet.")

		base_amount = serializer.validated_data.get("base_amount", Decimal("0.00"))
		order = serializer.save(
			creator=self.request.user,
			cutoff_at=timezone.now() + timedelta(hours=settings.ORDER_DEFAULT_CUTOFF_HOURS),
		)
		participant = OrderParticipant.objects.create(
			order=order,
			user=self.request.user,
			role=ParticipantRole.CREATOR,
			status=ParticipantStatus.JOINED,
		)

		if base_amount > 0:
			OrderItem.objects.create(
				order=order,
				participant=participant,
				added_by=self.request.user,
				name="Base Order (Host)",
				quantity=1,
				unit_price=base_amount,
				line_total=base_amount,
				status=OrderItemStatus.APPROVED,
				reviewed_by=self.request.user,
				reviewed_at=timezone.now(),
			)

		order.recalculate_totals()
		order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])
		_recalculate_participant_due(participant)
		_post_system_message(
			order,
			f"{self.request.user.username} created the order room.",
			{"event": "order_created"},
		)

	def create(self, request, *args, **kwargs):
		serializer = self.get_serializer(data=request.data)
		serializer.is_valid(raise_exception=True)
		try:
			self.perform_create(serializer)
		except PermissionDenied as exc:
			return Response({"error": str(exc)}, status=status.HTTP_403_FORBIDDEN)
		headers = self.get_success_headers(serializer.data)
		return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)


class OrderDetailView(generics.RetrieveUpdateDestroyAPIView):
	serializer_class = OrderSerializer
	permission_classes = [IsAuthenticated]
	filter_backends = [OrganisationFilterBackend]

	def get_queryset(self):
		queryset = (
			Order.objects.select_related("creator", "organisation", "campus")
			.annotate(participants_count=Count("participants", distinct=True), items_count=Count("items", distinct=True))
		)
		status_param = self.request.query_params.get("status")
		if status_param:
			statuses = status_param.split(",")
			queryset = queryset.filter(status__in=statuses)
		return queryset.order_by("-created_at")

	def update(self, request, *args, **kwargs):
		order = self.get_object()
		if not _is_order_manager(request.user, order):
			return Response({"error": "Only creator or organisation manager can update this order."}, status=status.HTTP_403_FORBIDDEN)
		return super().update(request, *args, **kwargs)

	def destroy(self, request, *args, **kwargs):
		order = self.get_object()
		if not _is_order_manager(request.user, order):
			return Response({"error": "Only creator or organisation manager can delete this order."}, status=status.HTTP_403_FORBIDDEN)
		return super().destroy(request, *args, **kwargs)


class OrderParticipantListCreateView(generics.ListCreateAPIView):
	serializer_class = OrderParticipantSerializer
	permission_classes = [IsAuthenticated]

	def get_order(self):
		return get_object_or_404(Order, pk=self.kwargs["order_id"])

	def get_queryset(self):
		order = self.get_order()
		if not _is_order_member(self.request.user, order):
			return OrderParticipant.objects.none()
		return OrderParticipant.objects.select_related("user", "order").filter(order=order)

	@transaction.atomic
	def create(self, request, *args, **kwargs):
		order = self.get_order()
		if not _is_order_member(request.user, order):
			return Response({"error": "You do not have access to this order."}, status=status.HTTP_403_FORBIDDEN)
		if order.status != OrderStatus.OPEN:
			return Response({"error": "Participants can only be added while order is OPEN."}, status=status.HTTP_400_BAD_REQUEST)
		if timezone.now() >= order.cutoff_at:
			return Response({"error": "Cannot join after cutoff."}, status=status.HTTP_400_BAD_REQUEST)

		payload = request.data.copy()
		target_user_id = payload.get("user") or request.user.id
		if str(target_user_id) != str(request.user.id) and not _is_order_manager(request.user, order):
			return Response({"error": "Only managers can add other users."}, status=status.HTTP_403_FORBIDDEN)

		active_participants = order.participants.exclude(status__in=[ParticipantStatus.LEFT, ParticipantStatus.REFUNDED]).count()
		if active_participants >= order.max_participants:
			return Response({"error": "Order has reached max participants."}, status=status.HTTP_400_BAD_REQUEST)

		if order.participants.filter(user_id=target_user_id).exists():
			return Response({"error": "User is already part of this order."}, status=status.HTTP_400_BAD_REQUEST)

		payload["user"] = target_user_id
		payload["order"] = order.id
		payload.setdefault("status", ParticipantStatus.JOINED)
		payload.setdefault("role", ParticipantRole.JOINER)

		serializer = self.get_serializer(data=payload)
		serializer.is_valid(raise_exception=True)
		participant = serializer.save()
		_post_system_message(
			order,
			f"{participant.user.username} joined the order.",
			{
				"event": "participant_joined",
				"participant_id": participant.id,
				"user_id": participant.user_id,
			},
		)
		# --- APPLY PENDING PENALTY ---
		if participant.user.pending_penalty > 0:
			penalty_amount = participant.user.pending_penalty
			OrderItem.objects.create(
				order=order,
				participant=participant,
				added_by=request.user,
				name="Late Fee (Previous Order)",
				quantity=1,
				unit_price=penalty_amount,
				line_total=penalty_amount,
				status=OrderItemStatus.APPROVED,
				reviewed_by=order.creator,
				reviewed_at=timezone.now(),
			)
			# Reset penalty on user
			target_user = participant.user
			target_user.pending_penalty = Decimal("0.00")
			target_user.save(update_fields=["pending_penalty"])
			
			# Recalculate order totals
			order.recalculate_totals()
			order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])
			
			# Refresh participant to update amount_due if needed
			_recalculate_participant_due(participant)
		# -----------------------------

		return Response(serializer.data, status=status.HTTP_201_CREATED)


class OrderParticipantDetailView(generics.RetrieveUpdateDestroyAPIView):
	serializer_class = OrderParticipantSerializer
	permission_classes = [IsAuthenticated]

	def get_queryset(self):
		queryset = OrderParticipant.objects.select_related("order", "user")
		if self.request.user.is_superuser:
			return queryset
		return queryset.filter(
			Q(order__creator=self.request.user)
			| Q(order__participants__user=self.request.user)
			| Q(order__organisation__memberships__user=self.request.user, order__organisation__memberships__status=MembershipStatus.ACTIVE)
		).distinct()

	def partial_update(self, request, *args, **kwargs):
		participant = self.get_object()
		if participant.user_id != request.user.id and not _is_order_manager(request.user, participant.order):
			return Response({"error": "Only managers can modify other participants."}, status=status.HTTP_403_FORBIDDEN)
		return super().partial_update(request, *args, **kwargs)


class OrderItemListCreateView(generics.ListCreateAPIView):
	serializer_class = OrderItemSerializer
	permission_classes = [IsAuthenticated]

	def get_order(self):
		return get_object_or_404(Order, pk=self.kwargs["order_id"])

	def get_queryset(self):
		order = self.get_order()
		if not _is_order_member(self.request.user, order):
			return OrderItem.objects.none()
		return OrderItem.objects.select_related("order", "added_by").filter(order=order)

	@transaction.atomic
	def create(self, request, *args, **kwargs):
		order = self.get_order()
		if not _is_order_member(request.user, order):
			return Response({"error": "You do not have access to this order."}, status=status.HTTP_403_FORBIDDEN)
		if order.status not in [OrderStatus.OPEN, OrderStatus.LOCKED]:
			return Response({"error": "Items can only be managed while order is OPEN or LOCKED."}, status=status.HTTP_400_BAD_REQUEST)

		payload = request.data.copy()
		payload["order"] = order.id
		serializer = self.get_serializer(data=payload)
		serializer.is_valid(raise_exception=True)
		participant = _get_order_participant(order, request.user)
		if not participant:
			return Response({"error": "You must join the order before adding items."}, status=status.HTTP_400_BAD_REQUEST)
		item = serializer.save(
			added_by=request.user,
			participant=participant,
			status=OrderItemStatus.DRAFT,
		)

		order.recalculate_totals()
		order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])

		return Response(OrderItemSerializer(item).data, status=status.HTTP_201_CREATED)


class OrderItemDetailView(generics.RetrieveUpdateDestroyAPIView):
	serializer_class = OrderItemSerializer
	permission_classes = [IsAuthenticated]

	def get_queryset(self):
		queryset = OrderItem.objects.select_related("order", "added_by")
		if self.request.user.is_superuser:
			return queryset
		return queryset.filter(
			Q(order__creator=self.request.user)
			| Q(order__participants__user=self.request.user)
			| Q(order__organisation__memberships__user=self.request.user, order__organisation__memberships__status=MembershipStatus.ACTIVE)
		).distinct()

	def _can_edit_item(self, request, item):
		if request.user.is_superuser:
			return True
		if _is_order_manager(request.user, item.order):
			return True
		return item.added_by_id == request.user.id and item.status == OrderItemStatus.DRAFT

	@transaction.atomic
	def partial_update(self, request, *args, **kwargs):
		item = self.get_object()
		if not self._can_edit_item(request, item):
			return Response({"error": "You cannot edit this item."}, status=status.HTTP_403_FORBIDDEN)
		response = super().partial_update(request, *args, **kwargs)
		item.order.recalculate_totals()
		item.order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])
		return response

	@transaction.atomic
	def destroy(self, request, *args, **kwargs):
		item = self.get_object()
		if not self._can_edit_item(request, item):
			return Response({"error": "You cannot remove this item."}, status=status.HTTP_403_FORBIDDEN)
		order = item.order
		response = super().destroy(request, *args, **kwargs)
		order.recalculate_totals()
		order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])
		return response


class SubmitCartView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request, order_id):
		order = get_object_or_404(Order, pk=order_id)
		if not _is_order_member(request.user, order):
			return Response({"error": "You do not have access to this order."}, status=status.HTTP_403_FORBIDDEN)

		serializer = CartSubmitSerializer(data=request.data or {})
		serializer.is_valid(raise_exception=True)
		participant = _get_order_participant(order, request.user)
		if not participant:
			return Response({"error": "You must join the order before submitting a cart."}, status=status.HTTP_400_BAD_REQUEST)

		draft_items = OrderItem.objects.filter(
			order=order,
			participant=participant,
			status=OrderItemStatus.DRAFT,
			is_active=True,
		)
		if not draft_items.exists():
			return Response({"error": "No draft items to submit."}, status=status.HTTP_400_BAD_REQUEST)

		now = timezone.now()
		draft_items.update(
			status=OrderItemStatus.SUBMITTED,
			review_reason="",
			reviewed_by=None,
			reviewed_at=None,
			updated_at=now,
		)

		_post_system_message(
			order,
			f"{request.user.username} submitted a cart for review.",
			{
				"event": "cart_submitted",
				"participant_id": participant.id,
			},
		)

		items = OrderItem.objects.filter(order=order, participant=participant).select_related("participant", "added_by", "reviewed_by")
		return Response(OrderItemSerializer(items, many=True).data, status=status.HTTP_200_OK)


class ApproveOrderItemView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request, pk):
		item = get_object_or_404(
			OrderItem.objects.select_related("order", "participant", "participant__user"),
			pk=pk,
		)
		if not _is_order_manager(request.user, item.order):
			return Response({"error": "Only the order manager can approve items."}, status=status.HTTP_403_FORBIDDEN)
		if item.status not in [OrderItemStatus.SUBMITTED, OrderItemStatus.DRAFT]:
			return Response({"error": "Only draft or submitted items can be approved."}, status=status.HTTP_400_BAD_REQUEST)

		review = OrderItemReviewSerializer(data=request.data or {})
		review.is_valid(raise_exception=True)

		item.status = OrderItemStatus.APPROVED
		item.review_reason = review.validated_data.get("reason", "")
		item.reviewed_by = request.user
		item.reviewed_at = timezone.now()
		item.save(update_fields=["status", "review_reason", "reviewed_by", "reviewed_at", "updated_at"])

		_recalculate_participant_due(item.participant)
		item.order.recalculate_totals()
		item.order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])

		_post_system_message(
			item.order,
			f"{request.user.username} approved {item.participant.user.username}'s item: {item.name}.",
			{
				"event": "item_approved",
				"item_id": item.id,
				"participant_id": item.participant_id,
			},
		)

		return Response(OrderItemSerializer(item).data, status=status.HTTP_200_OK)


class RejectOrderItemView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request, pk):
		item = get_object_or_404(
			OrderItem.objects.select_related("order", "participant", "participant__user"),
			pk=pk,
		)
		if not _is_order_manager(request.user, item.order):
			return Response({"error": "Only the order manager can reject items."}, status=status.HTTP_403_FORBIDDEN)
		if item.status == OrderItemStatus.REJECTED:
			return Response({"error": "Item is already rejected."}, status=status.HTTP_400_BAD_REQUEST)

		review = OrderItemReviewSerializer(data=request.data or {})
		review.is_valid(raise_exception=True)
		reason = review.validated_data.get("reason") or "Item went out of stock."

		item.status = OrderItemStatus.REJECTED
		item.review_reason = reason
		item.reviewed_by = request.user
		item.reviewed_at = timezone.now()
		item.is_active = False
		item.save(
			update_fields=[
				"status",
				"review_reason",
				"reviewed_by",
				"reviewed_at",
				"is_active",
				"updated_at",
			]
		)

		_recalculate_participant_due(item.participant)
		refunds = _refund_excess_if_needed(item.participant, reason)
		item.order.recalculate_totals()
		item.order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])

		_post_system_message(
			item.order,
			f"{request.user.username} rejected {item.participant.user.username}'s item '{item.name}' as out of stock.",
			{
				"event": "item_rejected",
				"item_id": item.id,
				"participant_id": item.participant_id,
				"refund_count": len(refunds or []),
			},
		)

		return Response(OrderItemSerializer(item).data, status=status.HTTP_200_OK)


class OrderStatusHistoryListView(generics.ListAPIView):
	serializer_class = OrderStatusHistorySerializer
	permission_classes = [IsAuthenticated]

	def get_queryset(self):
		order = get_object_or_404(Order, pk=self.kwargs["order_id"])
		if not _is_order_member(self.request.user, order):
			return OrderStatusHistory.objects.none()
		return OrderStatusHistory.objects.filter(order=order).select_related("changed_by")


class OrderStatusUpdateView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request, order_id):
		order = get_object_or_404(Order, pk=order_id)
		if not _is_order_manager(request.user, order):
			return Response({"error": "Only managers can change order status."}, status=status.HTTP_403_FORBIDDEN)

		serializer = OrderStatusUpdateSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)
		new_status = serializer.validated_data["status"]
		reason = serializer.validated_data.get("reason", "")
		metadata = serializer.validated_data.get("metadata", {})

		old_status = order.status
		if old_status == new_status:
			return Response({"error": "Order is already in the requested status."}, status=status.HTTP_400_BAD_REQUEST)

		order.status = new_status
		now = timezone.now()
		if new_status == OrderStatus.ARRIVED:
			order.prepared_at = now
		if new_status == OrderStatus.DELIVERED:
			order.delivered_at = now
		if new_status == OrderStatus.COMPLETED:
			order.completed_at = now
		if new_status == OrderStatus.CANCELLED:
			order.cancelled_at = now
			order.cancel_reason = reason

		order.save()

		OrderStatusHistory.objects.create(
			order=order,
			from_status=old_status,
			to_status=new_status,
			changed_by=request.user,
			reason=reason,
			metadata=metadata,
		)

		return Response(OrderSerializer(order, context={"request": request}).data, status=status.HTTP_200_OK)


class MyHandoverOtpView(APIView):
	permission_classes = [IsAuthenticated]

	def get_participant(self, user, order):
		return OrderParticipant.objects.filter(order=order, user=user).first()

	def get(self, request, order_id):
		order = get_object_or_404(Order, pk=order_id)
		participant = self.get_participant(request.user, order)
		if not participant:
			return Response({"error": "You are not a participant in this order."}, status=status.HTTP_403_FORBIDDEN)

		if participant.role == ParticipantRole.CREATOR:
			return Response({"error": "Creator does not require handover OTP."}, status=status.HTTP_400_BAD_REQUEST)

		otp_obj = HandoverOtp.objects.filter(order=order, participant=participant).first()
		
		# Auto-generate if it doesn't exist and order is ARRIVED
		if not otp_obj and order.status == OrderStatus.ARRIVED:
			plain_otp = f"{secrets.randbelow(10**4):04d}"
			expires_at = timezone.now() + timedelta(hours=24)
			otp_obj = HandoverOtp.objects.create(
				order=order,
				participant=participant,
				otp_hash=make_password(plain_otp),
				code_last4=plain_otp,
				status=HandoverOtpStatus.ACTIVE,
				expires_at=expires_at,
			)
			return Response({
				"otp": plain_otp,
				"status": otp_obj.status,
				"expires_at": otp_obj.expires_at
			}, status=status.HTTP_200_OK)

		if not otp_obj:
			return Response({"error": "No OTP found and order not yet arrived."}, status=status.HTTP_404_NOT_FOUND)

		return Response({
			"otp": otp_obj.code_last4,
			"status": otp_obj.status,
			"expires_at": otp_obj.expires_at
		}, status=status.HTTP_200_OK)

	@transaction.atomic
	def post(self, request, order_id):
		order = get_object_or_404(Order, pk=order_id)
		participant = self.get_participant(request.user, order)
		if not participant:
			return Response({"error": "You are not a participant in this order."}, status=status.HTTP_403_FORBIDDEN)
		if participant.role == ParticipantRole.CREATOR:
			return Response({"error": "Creator does not require handover OTP."}, status=status.HTTP_400_BAD_REQUEST)

		payload = HandoverOtpGenerateSerializer(data=request.data or {})
		payload.is_valid(raise_exception=True)
		expires_in_minutes = payload.validated_data.get("expires_in_minutes", 1440)

		plain_otp = f"{secrets.randbelow(10**4):04d}"
		expires_at = timezone.now() + timedelta(minutes=expires_in_minutes)

		otp_obj, _ = HandoverOtp.objects.update_or_create(
			order=order,
			participant=participant,
			defaults={
				"otp_hash": make_password(plain_otp),
				"code_last4": plain_otp[-4:],
				"status": HandoverOtpStatus.ACTIVE,
				"expires_at": expires_at,
				"verified_at": None,
				"failed_attempts": 0,
				"verified_by": None,
			},
		)

		return Response(
			{
				"otp": plain_otp,
				"expires_at": otp_obj.expires_at,
				"status": otp_obj.status,
				"code_last4": otp_obj.code_last4,
			},
			status=status.HTTP_201_CREATED,
		)


class VerifyHandoverOtpView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request, order_id):
		order = get_object_or_404(Order, pk=order_id)
		if not _is_order_manager(request.user, order):
			return Response({"error": "Only creator or manager can verify OTPs."}, status=status.HTTP_403_FORBIDDEN)

		serializer = HandoverOtpVerifySerializer(data=request.data)
		serializer.is_valid(raise_exception=True)
		participant_id = serializer.validated_data["participant_id"]
		otp_input = serializer.validated_data["otp"]

		participant = OrderParticipant.objects.filter(id=participant_id, order=order).first()
		if not participant:
			return Response({"error": "Participant not found for this order."}, status=status.HTTP_404_NOT_FOUND)

		otp_obj = HandoverOtp.objects.filter(order=order, participant=participant).first()
		if not otp_obj:
			return Response({"error": "No OTP found for participant."}, status=status.HTTP_404_NOT_FOUND)

		if otp_obj.status != HandoverOtpStatus.ACTIVE:
			return Response({"error": f"OTP is {otp_obj.status} and cannot be verified."}, status=status.HTTP_400_BAD_REQUEST)

		if otp_obj.is_expired:
			otp_obj.status = HandoverOtpStatus.EXPIRED
			otp_obj.save(update_fields=["status", "updated_at"])
			return Response({"error": "OTP has expired."}, status=status.HTTP_400_BAD_REQUEST)

		if not check_password(otp_input, otp_obj.otp_hash):
			otp_obj.failed_attempts += 1
			if otp_obj.failed_attempts >= otp_obj.max_attempts:
				otp_obj.status = HandoverOtpStatus.REVOKED
			otp_obj.save(update_fields=["failed_attempts", "status", "updated_at"])
			return Response({"error": "Invalid OTP."}, status=status.HTTP_400_BAD_REQUEST)

		now = timezone.now()
		otp_obj.status = HandoverOtpStatus.VERIFIED
		otp_obj.verified_at = now
		otp_obj.verified_by = request.user
		otp_obj.save(update_fields=["status", "verified_at", "verified_by", "updated_at"])

		# --- LATE PICKUP PENALTY LOGIC ---
		if order.prepared_at:
			diff = now - order.prepared_at
			if diff > timedelta(minutes=15):
				penalty_amount = Decimal("20.00")
				user = participant.user
				user.pending_penalty += penalty_amount
				user.save(update_fields=["pending_penalty"])
				
				minutes_late = int(diff.total_seconds() // 60)
				_post_system_message(
					order,
					f"SYSTEM: {user.username} was {minutes_late} minutes late for pickup. A penalty of ₹{penalty_amount} will be added to their next order.",
					{"event": "late_penalty", "user_id": user.id, "minutes_late": minutes_late}
				)
		# ---------------------------------

		participant.status = ParticipantStatus.HANDED_OVER
		participant.save(update_fields=["status"])

		# Release funds to host wallet
		payment = PaymentTransaction.objects.filter(
			order=order,
			participant=participant,
			status=PaymentStatus.CAPTURED
		).first()

		if payment:
			active_participants = order.participants.exclude(status__in=[ParticipantStatus.LEFT, ParticipantStatus.REFUNDED])
			cart_total = active_participants.aggregate(total=Sum("amount_due")).get("total") or Decimal("0.00")
			commission_share = calculate_cart_commission_share(cart_total, active_participants.count())
			net_payout = max(Decimal("0.00"), payment.amount - commission_share)
			host = order.creator
			host_wallet, _ = Wallet.objects.get_or_create(user=host)
			host_wallet.balance += net_payout
			host_wallet.save()

			WalletTransaction.objects.create(
				wallet=host_wallet,
				amount=net_payout,
				transaction_type=WalletTransactionType.INFLOW,
				description=f"Handoff from {participant.user.username} for Order #{order.id}",
				order=order,
				reference_payment=payment
			)

		# Check if all participants are handed over to mark order as complete
		other_participants = order.participants.exclude(role=ParticipantRole.CREATOR)
		all_done = not other_participants.exclude(status=ParticipantStatus.HANDED_OVER).exists()

		if all_done:
			active_participants = order.participants.exclude(status__in=[ParticipantStatus.LEFT, ParticipantStatus.REFUNDED])
			cart_total = active_participants.aggregate(total=Sum("amount_due")).get("total") or Decimal("0.00")
			commission_share = calculate_cart_commission_share(cart_total, active_participants.count())
			if commission_share > Decimal("0.00"):
				host_wallet, _ = Wallet.objects.get_or_create(user=order.creator)
				host_wallet.balance = max(Decimal("0.00"), host_wallet.balance - commission_share)
				host_wallet.save(update_fields=["balance", "updated_at"])
				WalletTransaction.objects.create(
					wallet=host_wallet,
					amount=commission_share,
					transaction_type=WalletTransactionType.OUTFLOW,
					description=f"Commission for Order #{order.id}",
					order=order,
				)
			order.status = OrderStatus.COMPLETED
			order.save(update_fields=["status", "updated_at"])

		return Response({
			"message": "OTP verified successfully. Funds released to host.",
			"order_status": order.status
		}, status=status.HTTP_200_OK)
