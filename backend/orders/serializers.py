from decimal import Decimal

from rest_framework import serializers

from organisations.models import MembershipRole, MembershipStatus, OrganisationMembership

from .models import (
	HandoverOtp,
	Order,
	OrderItem,
	OrderItemStatus,
	OrderParticipant,
	OrderStatus,
	OrderStatusHistory,
)


class OrderSerializer(serializers.ModelSerializer):
	creator_username = serializers.CharField(source="creator.username", read_only=True)
	participants_count = serializers.IntegerField(read_only=True, default=0)
	items_count = serializers.IntegerField(read_only=True, default=0)
	can_manage = serializers.SerializerMethodField()

	class Meta:
		model = Order
		fields = [
			"id",
			"organisation",
			"campus",
			"pickup_point",
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
			"min_threshold_amount",
			"base_amount",
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
			"can_manage",
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
			"can_manage",
			"created_at",
			"updated_at",
		]
		extra_kwargs = {
			"cutoff_at": {"required": False},
			"meeting_point": {"required": False},
		}

	def validate_currency(self, value):
		if len(value) != 3:
			raise serializers.ValidationError("currency must be a 3-letter ISO code.")
		return value.upper()

	def get_can_manage(self, obj):
		request = self.context.get("request")
		user = getattr(request, "user", None)
		if not user or not user.is_authenticated:
			return False
		if user.is_superuser or obj.creator_id == user.id:
			return True
		if not obj.organisation_id:
			return False
		return OrganisationMembership.objects.filter(
			organisation_id=obj.organisation_id,
			user=user,
			status=MembershipStatus.ACTIVE,
			role__in=[MembershipRole.OWNER, MembershipRole.ADMIN, MembershipRole.STAFF],
		).exists()

	def validate(self, attrs):
		instance = self.instance
		organisation = attrs.get("organisation", getattr(instance, "organisation", None))
		campus = attrs.get("campus", getattr(instance, "campus", None))
		pickup_point = attrs.get("pickup_point", getattr(instance, "pickup_point", None))
		meeting_point = attrs.get("meeting_point", getattr(instance, "meeting_point", ""))

		if organisation and not pickup_point:
			raise serializers.ValidationError(
				{"pickup_point": "Select an approved pickup point for this organisation."}
			)

		if organisation and pickup_point:
			if pickup_point.organisation_id != organisation.id:
				raise serializers.ValidationError(
					{"pickup_point": "Pickup point must belong to the selected organisation."}
				)
			if not pickup_point.is_active:
				raise serializers.ValidationError(
					{"pickup_point": "Pickup point is inactive and cannot be used."}
				)
			if campus and pickup_point.campus_id and pickup_point.campus_id != campus.id:
				raise serializers.ValidationError(
					{"pickup_point": "Pickup point must belong to the selected campus."}
				)
			attrs["meeting_point"] = pickup_point.name
		elif meeting_point:
			attrs["meeting_point"] = meeting_point.strip()

		return attrs


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
	participant = serializers.IntegerField(source="participant_id", read_only=True)
	participant_user_id = serializers.IntegerField(source="participant.user_id", read_only=True)
	reviewed_by_username = serializers.CharField(source="reviewed_by.username", read_only=True)

	class Meta:
		model = OrderItem
		fields = [
			"id",
			"order",
			"participant",
			"participant_user_id",
			"added_by",
			"added_by_username",
			"name",
			"quantity",
			"unit_price",
			"line_total",
			"special_instructions",
			"external_item_reference",
			"status",
			"review_reason",
			"reviewed_by",
			"reviewed_by_username",
			"reviewed_at",
			"is_active",
			"created_at",
			"updated_at",
		]
		read_only_fields = [
			"id",
			"participant",
			"participant_user_id",
			"added_by",
			"added_by_username",
			"status",
			"review_reason",
			"reviewed_by",
			"reviewed_by_username",
			"reviewed_at",
			"created_at",
			"updated_at",
		]

	def validate(self, attrs):
		quantity = attrs.get("quantity", getattr(self.instance, "quantity", 1))
		unit_price = attrs.get("unit_price", getattr(self.instance, "unit_price", Decimal("0.00")))
		line_total = attrs.get("line_total", getattr(self.instance, "line_total", Decimal("0.00")))
		expected = unit_price * quantity
		if line_total != expected:
			raise serializers.ValidationError({"line_total": "line_total must equal unit_price * quantity."})
		return attrs


class CartSubmitSerializer(serializers.Serializer):
	participant_id = serializers.IntegerField(required=False)


class OrderItemReviewSerializer(serializers.Serializer):
	reason = serializers.CharField(required=False, allow_blank=True, max_length=255)

	def validate_reason(self, value):
		return value.strip()


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
