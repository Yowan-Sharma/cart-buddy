from decimal import Decimal

from rest_framework import serializers

from .models import HandoverOtp, Order, OrderItem, OrderParticipant, OrderStatus, OrderStatusHistory


class OrderSerializer(serializers.ModelSerializer):
	creator_username = serializers.CharField(source="creator.username", read_only=True)
	participants_count = serializers.IntegerField(read_only=True, default=0)
	items_count = serializers.IntegerField(read_only=True, default=0)

	class Meta:
		model = Order
		fields = [
			"id",
			"organisation",
			"campus",
			"creator",
			"creator_username",
			"title",
			"restaurant_name",
			"external_platform",
			"external_reference",
			"meeting_point",
			"meeting_notes",
			"status",
			"max_participants",
			"currency",
			"subtotal_amount",
			"platform_fee",
			"delivery_fee",
			"other_fee",
			"total_amount",
			"is_settled",
			"cutoff_at",
			"expected_delivery_at",
			"delivered_at",
			"completed_at",
			"cancelled_at",
			"cancel_reason",
			"participants_count",
			"items_count",
			"created_at",
			"updated_at",
		]
		read_only_fields = [
			"id",
			"creator",
			"creator_username",
			"subtotal_amount",
			"total_amount",
			"is_settled",
			"participants_count",
			"items_count",
			"created_at",
			"updated_at",
		]

	def validate_currency(self, value):
		if len(value) != 3:
			raise serializers.ValidationError("currency must be a 3-letter ISO code.")
		return value.upper()


class OrderParticipantSerializer(serializers.ModelSerializer):
	user_username = serializers.CharField(source="user.username", read_only=True)

	class Meta:
		model = OrderParticipant
		fields = [
			"id",
			"order",
			"user",
			"user_username",
			"role",
			"status",
			"amount_due",
			"amount_paid",
			"joined_at",
			"left_at",
		]
		read_only_fields = ["id", "joined_at", "left_at", "user_username"]

	def validate(self, attrs):
		amount_due = attrs.get("amount_due", Decimal("0.00"))
		amount_paid = attrs.get("amount_paid", Decimal("0.00"))
		if amount_paid > amount_due and amount_due > Decimal("0.00"):
			raise serializers.ValidationError("amount_paid cannot exceed amount_due.")
		return attrs


class OrderItemSerializer(serializers.ModelSerializer):
	added_by_username = serializers.CharField(source="added_by.username", read_only=True)

	class Meta:
		model = OrderItem
		fields = [
			"id",
			"order",
			"added_by",
			"added_by_username",
			"name",
			"quantity",
			"unit_price",
			"line_total",
			"special_instructions",
			"external_item_reference",
			"is_active",
			"created_at",
			"updated_at",
		]
		read_only_fields = ["id", "added_by", "added_by_username", "created_at", "updated_at"]

	def validate(self, attrs):
		quantity = attrs.get("quantity", getattr(self.instance, "quantity", 1))
		unit_price = attrs.get("unit_price", getattr(self.instance, "unit_price", Decimal("0.00")))
		line_total = attrs.get("line_total", getattr(self.instance, "line_total", Decimal("0.00")))
		expected = unit_price * quantity
		if line_total != expected:
			raise serializers.ValidationError({"line_total": "line_total must equal unit_price * quantity."})
		return attrs


class OrderStatusHistorySerializer(serializers.ModelSerializer):
	changed_by_username = serializers.CharField(source="changed_by.username", read_only=True)

	class Meta:
		model = OrderStatusHistory
		fields = [
			"id",
			"order",
			"from_status",
			"to_status",
			"changed_by",
			"changed_by_username",
			"reason",
			"metadata",
			"created_at",
		]
		read_only_fields = fields


class HandoverOtpSerializer(serializers.ModelSerializer):
	participant_user_id = serializers.IntegerField(source="participant.user_id", read_only=True)

	class Meta:
		model = HandoverOtp
		fields = [
			"id",
			"order",
			"participant",
			"participant_user_id",
			"code_last4",
			"status",
			"expires_at",
			"verified_at",
			"failed_attempts",
			"max_attempts",
			"verified_by",
			"created_at",
			"updated_at",
		]
		read_only_fields = fields


class OrderStatusUpdateSerializer(serializers.Serializer):
	status = serializers.ChoiceField(choices=OrderStatus.choices)
	reason = serializers.CharField(required=False, allow_blank=True, max_length=255)
	metadata = serializers.JSONField(required=False)


class HandoverOtpGenerateSerializer(serializers.Serializer):
	expires_in_minutes = serializers.IntegerField(required=False, min_value=3, max_value=60, default=15)


class HandoverOtpVerifySerializer(serializers.Serializer):
	participant_id = serializers.IntegerField()
	otp = serializers.CharField(min_length=4, max_length=8)