from django.db import models


class PaymentProvider(models.TextChoices):
	RAZORPAY = "RAZORPAY", "Razorpay"


class PaymentStatus(models.TextChoices):
	CREATED = "CREATED", "Created"
	AUTHORIZED = "AUTHORIZED", "Authorized"
	CAPTURED = "CAPTURED", "Captured"
	FAILED = "FAILED", "Failed"
	REFUNDED = "REFUNDED", "Refunded"


class PaymentTransaction(models.Model):
	order = models.ForeignKey("orders.Order", on_delete=models.PROTECT, related_name="payment_transactions")
	participant = models.ForeignKey(
		"orders.OrderParticipant",
		on_delete=models.PROTECT,
		related_name="payment_transactions",
	)
	user = models.ForeignKey("users.User", on_delete=models.PROTECT, related_name="payment_transactions")

	provider = models.CharField(max_length=20, choices=PaymentProvider.choices, default=PaymentProvider.RAZORPAY)
	status = models.CharField(max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.CREATED)

	amount = models.DecimalField(max_digits=10, decimal_places=2)
	currency = models.CharField(max_length=3, default="INR")

	receipt_id = models.CharField(max_length=100, unique=True)
	idempotency_key = models.CharField(max_length=64, unique=True)

	razorpay_order_id = models.CharField(max_length=100, unique=True)
	razorpay_payment_id = models.CharField(max_length=100, blank=True, null=True, unique=True)
	razorpay_signature = models.CharField(max_length=255, blank=True)

	is_amount_applied = models.BooleanField(default=False)
	captured_at = models.DateTimeField(blank=True, null=True)
	failed_reason = models.CharField(max_length=255, blank=True)

	gateway_payload = models.JSONField(default=dict, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		ordering = ["-created_at"]
		indexes = [
			models.Index(fields=["order", "created_at"]),
			models.Index(fields=["participant", "status"]),
			models.Index(fields=["status"]),
		]
		constraints = [
			models.CheckConstraint(
				condition=models.Q(amount__gt=0),
				name="payments_transaction_amount_gt_zero",
			),
		]

	def __str__(self):
		return f"{self.provider} {self.status} - {self.amount} {self.currency} (Order #{self.order_id})"
