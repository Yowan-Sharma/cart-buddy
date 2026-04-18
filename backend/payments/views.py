import uuid

from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from orders.models import Order, OrderParticipant, ParticipantStatus
from organisations.models import MembershipStatus, OrganisationMembership

from .models import PaymentStatus, PaymentTransaction
from .serializers import (
	CreateRazorpayOrderSerializer,
	PaymentTransactionSerializer,
	RazorpayWebhookSerializer,
	VerifyRazorpayPaymentSerializer,
	paise_to_decimal,
)
from .services import (
	RazorpayConfigError,
	capture_payment,
	create_order,
	fetch_payment,
	safe_json_loads,
	verify_payment_signature,
	verify_webhook_signature,
)


def _order_visible_to_user(order, user):
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


def _resolve_participant(order, request_user, participant_id=None):
	if participant_id:
		participant = get_object_or_404(OrderParticipant, id=participant_id, order=order)
	else:
		participant = get_object_or_404(OrderParticipant, order=order, user=request_user)

	if participant.user_id != request_user.id and not request_user.is_superuser:
		raise PermissionError("You can only create payment for your own participant record.")

	return participant


@transaction.atomic
def _apply_successful_payment(payment_txn, payment_payload):
	if payment_txn.is_amount_applied:
		return

	participant = payment_txn.participant
	participant.amount_paid = participant.amount_paid + payment_txn.amount
	if participant.amount_paid >= participant.amount_due:
		participant.status = ParticipantStatus.PAID
	participant.save(update_fields=["amount_paid", "status"])

	payment_txn.is_amount_applied = True
	payment_txn.save(update_fields=["is_amount_applied", "updated_at"])


class CreateRazorpayOrderView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request):
		serializer = CreateRazorpayOrderSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		order = get_object_or_404(Order, id=serializer.validated_data["order_id"])
		if not _order_visible_to_user(order, request.user):
			return Response({"error": "You do not have access to this order."}, status=status.HTTP_403_FORBIDDEN)

		try:
			participant = _resolve_participant(
				order,
				request.user,
				serializer.validated_data.get("participant_id"),
			)
		except PermissionError as exc:
			return Response({"error": str(exc)}, status=status.HTTP_403_FORBIDDEN)

		payable_amount = participant.amount_due - participant.amount_paid
		if payable_amount <= 0:
			return Response({"error": "No pending amount for this participant."}, status=status.HTTP_400_BAD_REQUEST)

		receipt = f"cb_ord{order.id}_part{participant.id}_{uuid.uuid4().hex[:10]}"
		idem_key = uuid.uuid4().hex

		try:
			gateway_order = create_order(
				amount=payable_amount,
				currency=order.currency,
				receipt=receipt,
				notes={
					"order_id": str(order.id),
					"participant_id": str(participant.id),
					"user_id": str(request.user.id),
				},
			)
		except RazorpayConfigError as exc:
			return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
		except Exception as exc:
			return Response({"error": f"Failed to create Razorpay order: {exc}"}, status=status.HTTP_502_BAD_GATEWAY)

		payment_txn = PaymentTransaction.objects.create(
			order=order,
			participant=participant,
			user=request.user,
			amount=payable_amount,
			currency=order.currency,
			receipt_id=receipt,
			idempotency_key=idem_key,
			razorpay_order_id=gateway_order["id"],
			gateway_payload=gateway_order,
		)

		return Response(
			{
				"payment_transaction": PaymentTransactionSerializer(payment_txn).data,
				"razorpay": {
					"key_id": settings.RAZORPAY_KEY_ID,
					"order_id": gateway_order["id"],
					"amount": gateway_order.get("amount"),
					"currency": gateway_order.get("currency"),
					"receipt": gateway_order.get("receipt"),
					"status": gateway_order.get("status"),
				},
			},
			status=status.HTTP_201_CREATED,
		)


class VerifyRazorpayPaymentView(APIView):
	permission_classes = [IsAuthenticated]

	@transaction.atomic
	def post(self, request):
		serializer = VerifyRazorpayPaymentSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		payment_transaction_id = serializer.validated_data.get("payment_transaction_id")
		razorpay_order_id = serializer.validated_data.get("razorpay_order_id")

		queryset = PaymentTransaction.objects.select_related("participant", "order", "user")
		if payment_transaction_id:
			payment_txn = get_object_or_404(queryset, id=payment_transaction_id)
		else:
			payment_txn = get_object_or_404(queryset, razorpay_order_id=razorpay_order_id)

		if payment_txn.user_id != request.user.id and not request.user.is_superuser:
			return Response({"error": "You cannot verify this transaction."}, status=status.HTTP_403_FORBIDDEN)

		try:
			verify_payment_signature(
				razorpay_order_id=payment_txn.razorpay_order_id,
				razorpay_payment_id=serializer.validated_data["razorpay_payment_id"],
				razorpay_signature=serializer.validated_data["razorpay_signature"],
			)
		except Exception:
			payment_txn.status = PaymentStatus.FAILED
			payment_txn.failed_reason = "Invalid signature"
			payment_txn.razorpay_payment_id = serializer.validated_data["razorpay_payment_id"]
			payment_txn.razorpay_signature = serializer.validated_data["razorpay_signature"]
			payment_txn.save(
				update_fields=[
					"status",
					"failed_reason",
					"razorpay_payment_id",
					"razorpay_signature",
					"updated_at",
				]
			)
			return Response({"error": "Invalid Razorpay signature."}, status=status.HTTP_400_BAD_REQUEST)

		payment_payload = fetch_payment(serializer.validated_data["razorpay_payment_id"])
		payment_status = payment_payload.get("status", "").lower()

		payment_txn.razorpay_payment_id = serializer.validated_data["razorpay_payment_id"]
		payment_txn.razorpay_signature = serializer.validated_data["razorpay_signature"]
		payment_txn.gateway_payload = payment_payload

		if payment_status == "authorized":
			payment_payload = capture_payment(
				razorpay_payment_id=serializer.validated_data["razorpay_payment_id"],
				amount=payment_txn.amount,
				currency=payment_txn.currency,
			)
			payment_status = payment_payload.get("status", "").lower()
			payment_txn.gateway_payload = payment_payload

		if payment_status == "captured":
			payment_txn.status = PaymentStatus.CAPTURED
			payment_txn.captured_at = timezone.now()
			payment_txn.failed_reason = ""
			payment_txn.save(
				update_fields=[
					"razorpay_payment_id",
					"razorpay_signature",
					"gateway_payload",
					"status",
					"captured_at",
					"failed_reason",
					"updated_at",
				]
			)
			_apply_successful_payment(payment_txn, payment_payload)
		elif payment_status == "authorized":
			payment_txn.status = PaymentStatus.AUTHORIZED
			payment_txn.save(update_fields=["status", "razorpay_payment_id", "razorpay_signature", "gateway_payload", "updated_at"])
		else:
			payment_txn.status = PaymentStatus.FAILED
			payment_txn.failed_reason = payment_payload.get("error_description", "Payment not captured")
			payment_txn.save(
				update_fields=[
					"status",
					"failed_reason",
					"razorpay_payment_id",
					"razorpay_signature",
					"gateway_payload",
					"updated_at",
				]
			)

		return Response(PaymentTransactionSerializer(payment_txn).data, status=status.HTTP_200_OK)


class MyPaymentTransactionsView(generics.ListAPIView):
	serializer_class = PaymentTransactionSerializer
	permission_classes = [IsAuthenticated]

	def get_queryset(self):
		queryset = PaymentTransaction.objects.select_related("order", "participant", "user").all()
		if not self.request.user.is_superuser:
			queryset = queryset.filter(user=self.request.user)

		order_id = self.request.query_params.get("order")
		status_filter = self.request.query_params.get("status")
		if order_id:
			queryset = queryset.filter(order_id=order_id)
		if status_filter:
			queryset = queryset.filter(status=status_filter)
		return queryset


class RazorpayWebhookView(APIView):
	permission_classes = [AllowAny]

	@transaction.atomic
	def post(self, request):
		signature = request.headers.get("X-Razorpay-Signature", "")
		raw_body = request.body

		try:
			verify_webhook_signature(raw_body, signature)
		except RazorpayConfigError as exc:
			return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
		except Exception:
			return Response({"error": "Invalid webhook signature."}, status=status.HTTP_400_BAD_REQUEST)

		payload = safe_json_loads(raw_body)
		serializer = RazorpayWebhookSerializer(data=payload)
		serializer.is_valid(raise_exception=True)

		event = serializer.validated_data["event"]
		payment_entity = (
			serializer.validated_data.get("payload", {})
			.get("payment", {})
			.get("entity", {})
		)

		if not payment_entity:
			return Response({"message": "No payment entity in webhook."}, status=status.HTTP_200_OK)

		razorpay_order_id = payment_entity.get("order_id")
		razorpay_payment_id = payment_entity.get("id")
		payment_status = payment_entity.get("status", "").lower()

		if not razorpay_order_id:
			return Response({"message": "No razorpay order id in webhook."}, status=status.HTTP_200_OK)

		payment_txn = PaymentTransaction.objects.filter(razorpay_order_id=razorpay_order_id).first()
		if not payment_txn:
			return Response({"message": "No matching transaction."}, status=status.HTTP_200_OK)

		payment_txn.razorpay_payment_id = razorpay_payment_id
		payment_txn.gateway_payload = payload

		if event == "payment.captured" or payment_status == "captured":
			payment_txn.status = PaymentStatus.CAPTURED
			payment_txn.captured_at = timezone.now()
			payment_txn.failed_reason = ""
			payment_txn.save(
				update_fields=[
					"razorpay_payment_id",
					"gateway_payload",
					"status",
					"captured_at",
					"failed_reason",
					"updated_at",
				]
			)
			_apply_successful_payment(payment_txn, payload)
		elif event == "payment.failed" or payment_status == "failed":
			payment_txn.status = PaymentStatus.FAILED
			payment_txn.failed_reason = (
				payment_entity.get("error_description")
				or payment_entity.get("description")
				or "Payment failed"
			)
			payment_txn.save(
				update_fields=[
					"razorpay_payment_id",
					"gateway_payload",
					"status",
					"failed_reason",
					"updated_at",
				]
			)
		else:
			payment_txn.status = PaymentStatus.AUTHORIZED if payment_status == "authorized" else payment_txn.status
			payment_txn.save(update_fields=["razorpay_payment_id", "gateway_payload", "status", "updated_at"])

		return Response({"message": "Webhook processed."}, status=status.HTTP_200_OK)
