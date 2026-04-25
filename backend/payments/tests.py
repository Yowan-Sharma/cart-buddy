from decimal import Decimal
from unittest.mock import patch

from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from orders.models import Order, OrderParticipant, ParticipantRole, ParticipantStatus
from organisations.models import MembershipRole, MembershipStatus, Organisation, OrganisationMembership, Campus
from payments.models import PaymentStatus, PaymentTransaction
from payments.services import calculate_cart_commission_share
from users.models import User


@override_settings(
	RAZORPAY_KEY_ID="rzp_test_key",
	RAZORPAY_KEY_SECRET="rzp_test_secret",
	RAZORPAY_WEBHOOK_SECRET="rzp_test_webhook_secret",
)
class PaymentsApiFlowTests(APITestCase):
	def setUp(self):
		self.creator = User.objects.create_user(
			username="creator_test",
			password="Pass@1234",
			email="creator@test.com",
			phone=9876543210,
			hostel="A",
			gender="Male",
		)
		self.joiner = User.objects.create_user(
			username="joiner_test",
			password="Pass@1234",
			email="joiner@test.com",
			phone=9876543211,
			hostel="B",
			gender="Female",
		)

		self.organisation = Organisation.objects.create(
			name="CartBuddy Test University",
			short_code="CBTU",
			domain="test.edu",
		)
		self.campus = Campus.objects.create(
			organisation=self.organisation,
			name="Main Campus",
			city="Delhi",
			state="Delhi",
		)

		OrganisationMembership.objects.create(
			organisation=self.organisation,
			user=self.creator,
			role=MembershipRole.OWNER,
			status=MembershipStatus.ACTIVE,
		)
		OrganisationMembership.objects.create(
			organisation=self.organisation,
			user=self.joiner,
			role=MembershipRole.MEMBER,
			status=MembershipStatus.ACTIVE,
		)

		self.order = Order.objects.create(
			organisation=self.organisation,
			campus=self.campus,
			creator=self.creator,
			title="Pizza Night",
			restaurant_name="Dominos",
			external_platform="SWIGGY",
			external_reference="ref_123",
			meeting_point="Hostel Gate",
			max_participants=5,
			currency="INR",
			platform_fee="10.00",
			delivery_fee="20.00",
			other_fee="0.00",
			cutoff_at="2099-01-01T10:00:00Z",
		)

		self.creator_participant = OrderParticipant.objects.create(
			order=self.order,
			user=self.creator,
			role=ParticipantRole.CREATOR,
			status=ParticipantStatus.JOINED,
			amount_due="0.00",
			amount_paid="0.00",
		)
		self.joiner_participant = OrderParticipant.objects.create(
			order=self.order,
			user=self.joiner,
			role=ParticipantRole.JOINER,
			status=ParticipantStatus.JOINED,
			amount_due="150.00",
			amount_paid="0.00",
		)

	@patch("payments.views.create_order")
	def test_create_razorpay_order_success(self, mock_create_order):
		mock_create_order.return_value = {
			"id": "order_test_123",
			"amount": 15300,
			"currency": "INR",
			"receipt": "receipt_test_123",
			"status": "created",
		}

		self.client.force_authenticate(user=self.joiner)
		response = self.client.post(
			"/payments/orders/create/",
			{
				"order_id": self.order.id,
				"participant_id": self.joiner_participant.id,
			},
			format="json",
		)

		self.assertEqual(response.status_code, status.HTTP_201_CREATED)
		self.assertEqual(response.data["razorpay"]["order_id"], "order_test_123")
		self.assertEqual(response.data["razorpay"]["key_id"], "rzp_test_key")
		self.assertEqual(mock_create_order.call_args.kwargs["amount"], Decimal("153.00"))

		payment_txn = PaymentTransaction.objects.get(
			participant=self.joiner_participant,
			razorpay_order_id="order_test_123",
		)
		self.assertEqual(payment_txn.status, PaymentStatus.CREATED)
		self.assertEqual(str(payment_txn.amount), "153.00")

	def test_calculate_cart_commission_share_splits_equally(self):
		self.assertEqual(calculate_cart_commission_share(Decimal("150.00"), 2), Decimal("3.00"))

	@patch("payments.views.capture_payment")
	@patch("payments.views.fetch_payment")
	@patch("payments.views.verify_payment_signature")
	def test_verify_razorpay_payment_captured_updates_participant(
		self,
		mock_verify_signature,
		mock_fetch_payment,
		mock_capture_payment,
	):
		payment_txn = PaymentTransaction.objects.create(
			order=self.order,
			participant=self.joiner_participant,
			user=self.joiner,
			amount="150.00",
			currency="INR",
			receipt_id="receipt_verify_123",
			idempotency_key="idem_verify_123",
			razorpay_order_id="order_verify_123",
		)

		mock_verify_signature.return_value = None
		mock_fetch_payment.return_value = {
			"id": "pay_verify_123",
			"order_id": "order_verify_123",
			"status": "captured",
		}
		mock_capture_payment.return_value = {
			"id": "pay_verify_123",
			"order_id": "order_verify_123",
			"status": "captured",
		}

		self.client.force_authenticate(user=self.joiner)
		response = self.client.post(
			"/payments/orders/verify/",
			{
				"payment_transaction_id": payment_txn.id,
				"razorpay_payment_id": "pay_verify_123",
				"razorpay_signature": "sig_verify_123",
			},
			format="json",
		)

		self.assertEqual(response.status_code, status.HTTP_200_OK)
		self.assertEqual(mock_capture_payment.call_args.kwargs["amount"], Decimal("153.00"))
		payment_txn.refresh_from_db()
		self.joiner_participant.refresh_from_db()

		self.assertEqual(payment_txn.status, PaymentStatus.CAPTURED)
		self.assertTrue(payment_txn.is_amount_applied)
		self.assertEqual(str(self.joiner_participant.amount_paid), "150.00")
		self.assertEqual(self.joiner_participant.status, ParticipantStatus.PAID)

	@patch("payments.views.safe_json_loads")
	@patch("payments.views.verify_webhook_signature")
	def test_webhook_payment_captured_updates_transaction_and_participant(
		self,
		mock_verify_webhook_signature,
		mock_safe_json_loads,
	):
		payment_txn = PaymentTransaction.objects.create(
			order=self.order,
			participant=self.joiner_participant,
			user=self.joiner,
			amount="150.00",
			currency="INR",
			receipt_id="receipt_webhook_123",
			idempotency_key="idem_webhook_123",
			razorpay_order_id="order_webhook_123",
		)

		mock_verify_webhook_signature.return_value = None
		mock_safe_json_loads.return_value = {
			"event": "payment.captured",
			"payload": {
				"payment": {
					"entity": {
						"id": "pay_webhook_123",
						"order_id": "order_webhook_123",
						"status": "captured",
					}
				}
			},
		}

		response = self.client.post(
			"/payments/webhooks/razorpay/",
			data=b"{}",
			content_type="application/json",
			HTTP_X_RAZORPAY_SIGNATURE="sig_webhook_123",
		)

		self.assertEqual(response.status_code, status.HTTP_200_OK)
		payment_txn.refresh_from_db()
		self.joiner_participant.refresh_from_db()

		self.assertEqual(payment_txn.status, PaymentStatus.CAPTURED)
		self.assertTrue(payment_txn.is_amount_applied)
		self.assertEqual(str(self.joiner_participant.amount_paid), "150.00")
		self.assertEqual(self.joiner_participant.status, ParticipantStatus.PAID)
