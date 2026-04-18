import secrets
from datetime import timedelta

from django.contrib.auth.hashers import check_password, make_password
from django.db import transaction
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from core.filters import OrganisationFilterBackend

from organisations.models import MembershipRole, MembershipStatus, OrganisationMembership

from .models import HandoverOtp, HandoverOtpStatus, Order, OrderItem, OrderParticipant, OrderStatus, OrderStatusHistory, ParticipantRole, ParticipantStatus
from .serializers import (
	HandoverOtpGenerateSerializer,
	HandoverOtpSerializer,
	HandoverOtpVerifySerializer,
	OrderItemSerializer,
	OrderParticipantSerializer,
	OrderSerializer,
	OrderStatusHistorySerializer,
	OrderStatusUpdateSerializer,
)


ALLOWED_MANAGER_ROLES = [MembershipRole.OWNER, MembershipRole.ADMIN, MembershipRole.STAFF]


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


class OrderListCreateView(generics.ListCreateAPIView):
	serializer_class = OrderSerializer
	permission_classes = [IsAuthenticated]
	filter_backends = [OrganisationFilterBackend]

	def get_queryset(self):
		queryset = (
			Order.objects.select_related("creator", "organisation", "campus")
			.annotate(participants_count=Count("participants", distinct=True), items_count=Count("items", distinct=True))
		)
		return queryset

	@transaction.atomic
	def perform_create(self, serializer):
		organisation = serializer.validated_data.get("organisation")
		if organisation and not _is_org_admin(self.request.user, organisation.id):
			raise PermissionDenied("You do not have permission to create orders in this organisation.")

		order = serializer.save(creator=self.request.user)
		OrderParticipant.objects.create(
			order=order,
			user=self.request.user,
			role=ParticipantRole.CREATOR,
			status=ParticipantStatus.JOINED,
		)

		order.recalculate_totals()
		order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])

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
		return queryset

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
		serializer.save()
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
		serializer.save(added_by=request.user)

		order.recalculate_totals()
		order.save(update_fields=["subtotal_amount", "total_amount", "updated_at"])

		return Response(serializer.data, status=status.HTTP_201_CREATED)


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
		return item.added_by_id == request.user.id

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

		otp = HandoverOtp.objects.filter(order=order, participant=participant).first()
		if not otp:
			return Response({"exists": False}, status=status.HTTP_200_OK)
		return Response({"exists": True, "otp": HandoverOtpSerializer(otp).data}, status=status.HTTP_200_OK)

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
		expires_in_minutes = payload.validated_data["expires_in_minutes"]

		plain_otp = f"{secrets.randbelow(10**6):06d}"
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

		participant.status = ParticipantStatus.HANDED_OVER
		participant.save(update_fields=["status"])

		return Response({"message": "OTP verified successfully."}, status=status.HTTP_200_OK)
