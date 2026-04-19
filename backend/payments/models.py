from django.db import models


class PaymentProvider(models.TextChoices):
	RAZORPAY = "RAZORPAY", "Razorpay"


class PaymentStatus(models.TextChoices):
	CREATED = "CREATED", "Created"
	AUTHORIZED = "AUTHORIZED", "Authorized"
	CAPTURED = "CAPTURED", "Captured"
	FAILED = "FAILED", "Failed"
	REFUNDED = "REFUNDED", "Refunded"


class RefundStatus(models.TextChoices):
	CREATED = "CREATED", "Created"
	PROCESSED = "PROCESSED", "Processed"
	FAILED = "FAILED", "Failed"


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


class PaymentRefund(models.Model):
	payment_transaction = models.ForeignKey(
		PaymentTransaction,
		on_delete=models.PROTECT,
		related_name="refunds",
	)
	order = models.ForeignKey("orders.Order", on_delete=models.PROTECT, related_name="payment_refunds")
	participant = models.ForeignKey(
		"orders.OrderParticipant",
		on_delete=models.PROTECT,
		related_name="payment_refunds",
	)
	user = models.ForeignKey("users.User", on_delete=models.PROTECT, related_name="payment_refunds")

	status = models.CharField(max_length=20, choices=RefundStatus.choices, default=RefundStatus.CREATED)
	amount = models.DecimalField(max_digits=10, decimal_places=2)
	currency = models.CharField(max_length=3, default="INR")
	reason = models.CharField(max_length=255, blank=True)

	provider_refund_id = models.CharField(max_length=100, blank=True, unique=True, null=True)
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
				name="payments_refund_amount_gt_zero",
			),
		]

	def __str__(self):
		return f"Refund {self.status} - {self.amount} {self.currency} (Order #{self.order_id})"

class Wallet(models.Model):
	user = models.OneToOneField("users.User", on_delete=models.CASCADE, related_name="wallet")
	balance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	def __str__(self):
		return f"{self.user.username}'s Wallet - {self.balance}"


class WalletTransactionType(models.TextChoices):
	DEPOSIT = "DEPOSIT", "Deposit"
	WITHDRAWAL = "WITHDRAWAL", "Withdrawal"
	INFLOW = "INFLOW", "Inflow (From Order)"
	OUTFLOW = "OUTFLOW", "Outflow (To Host)"


class WalletTransaction(models.Model):
	wallet = models.ForeignKey(Wallet, on_delete=models.CASCADE, related_name="transactions")
	amount = models.DecimalField(max_digits=12, decimal_places=2)
	transaction_type = models.CharField(max_length=20, choices=WalletTransactionType.choices)
	description = models.CharField(max_length=255, blank=True)
	order = models.ForeignKey("orders.Order", on_delete=models.SET_NULL, null=True, blank=True)
	reference_payment = models.ForeignKey(PaymentTransaction, on_delete=models.SET_NULL, null=True, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)

	def __str__(self):
		return f"{self.transaction_type} - {self.amount} ({self.wallet.user.username})"
class WithdrawalStatus(models.TextChoices):
	PENDING = "PENDING", "Pending"
	COMPLETED = "COMPLETED", "Completed"
	FAILED = "FAILED", "Failed"

class WithdrawalRequest(models.Model):
	user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="withdrawals")
	amount = models.DecimalField(max_digits=12, decimal_places=2)
	bank_account_number = models.CharField(max_length=20)
	ifsc_code = models.CharField(max_length=11)
	status = models.CharField(max_length=20, choices=WithdrawalStatus.choices, default=WithdrawalStatus.PENDING)
	processed_at = models.DateTimeField(null=True, blank=True)
	failure_reason = models.CharField(max_length=255, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	def __str__(self):
		return f"Withdrawal {self.amount} - {self.user.username} ({self.status})"
