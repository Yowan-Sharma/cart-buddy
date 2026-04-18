from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone


class OrderStatus(models.TextChoices):
	OPEN = "OPEN", "Open"
	LOCKED = "LOCKED", "Locked"
	IN_PROGRESS = "IN_PROGRESS", "In Progress"
	DELIVERED = "DELIVERED", "Delivered"
	COMPLETED = "COMPLETED", "Completed"
	CANCELLED = "CANCELLED", "Cancelled"


class ParticipantRole(models.TextChoices):
	CREATOR = "CREATOR", "Creator"
	JOINER = "JOINER", "Joiner"


class ParticipantStatus(models.TextChoices):
	INVITED = "INVITED", "Invited"
	JOINED = "JOINED", "Joined"
	PAID = "PAID", "Paid"
	LEFT = "LEFT", "Left"
	REFUNDED = "REFUNDED", "Refunded"
	HANDED_OVER = "HANDED_OVER", "Handed Over"


class HandoverOtpStatus(models.TextChoices):
	ACTIVE = "ACTIVE", "Active"
	VERIFIED = "VERIFIED", "Verified"
	EXPIRED = "EXPIRED", "Expired"
	REVOKED = "REVOKED", "Revoked"


class Order(models.Model):
	organisation = models.ForeignKey(
		"organisations.Organisation",
		on_delete=models.PROTECT,
		related_name="orders",
		null=True,
		blank=True,
	)
	campus = models.ForeignKey(
		"organisations.Campus",
		on_delete=models.PROTECT,
		related_name="orders",
		null=True,
		blank=True,
	)
	creator = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.PROTECT,
		related_name="created_orders",
	)
	title = models.CharField(max_length=120)
	restaurant_name = models.CharField(max_length=120)
	external_platform = models.CharField(max_length=50, blank=True)
	external_reference = models.CharField(max_length=100, blank=True)
	meeting_point = models.CharField(max_length=120)
	meeting_notes = models.CharField(max_length=255, blank=True)

	status = models.CharField(
		max_length=20,
		choices=OrderStatus.choices,
		default=OrderStatus.OPEN,
	)
	max_participants = models.PositiveSmallIntegerField(default=6)

	currency = models.CharField(max_length=3, default="INR")
	subtotal_amount = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)
	platform_fee = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)
	delivery_fee = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)
	other_fee = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)
	total_amount = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)

	is_settled = models.BooleanField(default=False)
	cutoff_at = models.DateTimeField()
	expected_delivery_at = models.DateTimeField(null=True, blank=True)
	delivered_at = models.DateTimeField(null=True, blank=True)
	completed_at = models.DateTimeField(null=True, blank=True)
	cancelled_at = models.DateTimeField(null=True, blank=True)
	cancel_reason = models.CharField(max_length=255, blank=True)

	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		ordering = ["-created_at"]
		indexes = [
			models.Index(fields=["organisation", "campus"]),
			models.Index(fields=["status"]),
			models.Index(fields=["meeting_point"]),
			models.Index(fields=["cutoff_at"]),
			models.Index(fields=["created_at"]),
		]
		constraints = [
			models.CheckConstraint(
				condition=models.Q(max_participants__gt=0),
				name="orders_order_max_participants_gt_zero",
			),
			models.CheckConstraint(
				condition=models.Q(subtotal_amount__gte=0),
				name="orders_order_subtotal_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(platform_fee__gte=0),
				name="orders_order_platform_fee_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(delivery_fee__gte=0),
				name="orders_order_delivery_fee_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(other_fee__gte=0),
				name="orders_order_other_fee_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(total_amount__gte=0),
				name="orders_order_total_non_negative",
			),
		]

	def __str__(self) -> str:
		return f"Order #{self.pk} - {self.restaurant_name} ({self.status})"

	def clean(self):
		if self.campus_id and self.organisation_id and self.campus.organisation_id != self.organisation_id:
			raise ValidationError("campus must belong to the same organisation.")
		if self.completed_at and self.status != OrderStatus.COMPLETED:
			raise ValidationError("completed_at can only be set when order is COMPLETED.")
		if self.cancelled_at and self.status != OrderStatus.CANCELLED:
			raise ValidationError("cancelled_at can only be set when order is CANCELLED.")
		if self.cutoff_at and self.cutoff_at <= timezone.now() and self.status == OrderStatus.OPEN:
			raise ValidationError("Open orders must have cutoff_at in the future.")

	def recalculate_totals(self):
		item_total = (
			self.items.filter(is_active=True).aggregate(total=models.Sum("line_total")).get("total")
			or Decimal("0.00")
		)
		self.subtotal_amount = item_total
		self.total_amount = item_total + self.platform_fee + self.delivery_fee + self.other_fee


class OrderParticipant(models.Model):
	order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="participants")
	user = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.CASCADE,
		related_name="order_memberships",
	)
	role = models.CharField(
		max_length=10,
		choices=ParticipantRole.choices,
		default=ParticipantRole.JOINER,
	)
	status = models.CharField(
		max_length=20,
		choices=ParticipantStatus.choices,
		default=ParticipantStatus.JOINED,
	)

	amount_due = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)
	amount_paid = models.DecimalField(
		max_digits=10,
		decimal_places=2,
		default=Decimal("0.00"),
	)

	joined_at = models.DateTimeField(auto_now_add=True)
	left_at = models.DateTimeField(null=True, blank=True)

	class Meta:
		ordering = ["joined_at"]
		constraints = [
			models.UniqueConstraint(
				fields=["order", "user"],
				name="orders_orderparticipant_unique_member",
			),
			models.CheckConstraint(
				condition=models.Q(amount_due__gte=0),
				name="orders_participant_due_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(amount_paid__gte=0),
				name="orders_participant_paid_non_negative",
			),
		]
		indexes = [
			models.Index(fields=["status"]),
			models.Index(fields=["role"]),
		]

	def __str__(self) -> str:
		return f"Order #{self.order_id} - User #{self.user_id} ({self.role})"


class OrderItem(models.Model):
	order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
	added_by = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
		related_name="added_order_items",
	)
	name = models.CharField(max_length=120)
	quantity = models.PositiveIntegerField(default=1)
	unit_price = models.DecimalField(max_digits=10, decimal_places=2)
	line_total = models.DecimalField(max_digits=10, decimal_places=2)
	special_instructions = models.CharField(max_length=255, blank=True)
	external_item_reference = models.CharField(max_length=100, blank=True)
	is_active = models.BooleanField(default=True)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		ordering = ["created_at"]
		constraints = [
			models.CheckConstraint(
				condition=models.Q(quantity__gt=0),
				name="orders_item_quantity_gt_zero",
			),
			models.CheckConstraint(
				condition=models.Q(unit_price__gte=0),
				name="orders_item_unit_price_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(line_total__gte=0),
				name="orders_item_line_total_non_negative",
			),
		]

	def __str__(self) -> str:
		return f"{self.name} x{self.quantity} (Order #{self.order_id})"

	def clean(self):
		expected_total = (self.unit_price or Decimal("0.00")) * self.quantity
		if self.line_total != expected_total:
			raise ValidationError({"line_total": "line_total must equal unit_price * quantity."})


class OrderStatusHistory(models.Model):
	order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="status_history")
	from_status = models.CharField(max_length=20, choices=OrderStatus.choices)
	to_status = models.CharField(max_length=20, choices=OrderStatus.choices)
	changed_by = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
		related_name="order_state_changes",
	)
	reason = models.CharField(max_length=255, blank=True)
	metadata = models.JSONField(default=dict, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)

	class Meta:
		ordering = ["-created_at"]
		indexes = [
			models.Index(fields=["order", "created_at"]),
		]

	def __str__(self) -> str:
		return f"Order #{self.order_id}: {self.from_status} -> {self.to_status}"


class HandoverOtp(models.Model):
	order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="handover_otps")
	participant = models.OneToOneField(
		OrderParticipant,
		on_delete=models.CASCADE,
		related_name="handover_otp",
	)

	otp_hash = models.CharField(max_length=128)
	code_last4 = models.CharField(max_length=4)
	status = models.CharField(
		max_length=12,
		choices=HandoverOtpStatus.choices,
		default=HandoverOtpStatus.ACTIVE,
	)
	expires_at = models.DateTimeField()
	verified_at = models.DateTimeField(null=True, blank=True)
	failed_attempts = models.PositiveSmallIntegerField(default=0)
	max_attempts = models.PositiveSmallIntegerField(default=5)
	verified_by = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
		related_name="verified_handover_otps",
	)

	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		indexes = [
			models.Index(fields=["status"]),
			models.Index(fields=["expires_at"]),
		]
		constraints = [
			models.CheckConstraint(
				condition=models.Q(failed_attempts__gte=0),
				name="orders_handoverotp_failed_attempts_non_negative",
			),
			models.CheckConstraint(
				condition=models.Q(max_attempts__gt=0),
				name="orders_handoverotp_max_attempts_gt_zero",
			),
		]

	def __str__(self) -> str:
		return f"Handover OTP for participant #{self.participant_id} ({self.status})"

	def clean(self):
		if self.participant_id and self.order_id and self.participant.order_id != self.order_id:
			raise ValidationError("participant must belong to the same order.")

	@property
	def is_expired(self) -> bool:
		return timezone.now() >= self.expires_at
