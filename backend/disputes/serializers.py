from rest_framework import serializers
from django.utils import timezone
from .models import (
    Dispute, DisputeMessage, DisputeHistory, DisputeResolution,
    DisputeCategory, DisputePriority, DisputeStatus, ResolutionType, MessageType
)
from users.models import User
from orders.models import Order


class UserBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email"]


class DisputeMessageSerializer(serializers.ModelSerializer):
    sender = UserBriefSerializer(read_only=True)
    message_type_display = serializers.CharField(source="get_message_type_display", read_only=True)
    
    class Meta:
        model = DisputeMessage
        fields = ["id", "sender", "message", "message_type", "message_type_display", "created_at"]
        read_only_fields = ["created_at", "sender"]


class SendDisputeMessageSerializer(serializers.Serializer):
    message = serializers.CharField(min_length=1, max_length=5000, required=True)
    
    def validate_message(self, value):
        if not value.strip():
            raise serializers.ValidationError("Message cannot be empty or whitespace only")
        return value.strip()


class DisputeHistorySerializer(serializers.ModelSerializer):
    changed_by = UserBriefSerializer(read_only=True)
    old_status_display = serializers.CharField(source="get_old_status_display", read_only=True)
    new_status_display = serializers.CharField(source="get_new_status_display", read_only=True)
    
    class Meta:
        model = DisputeHistory
        fields = [
            "id", "changed_by", "old_status", "old_status_display",
            "new_status", "new_status_display", "change_reason", "created_at"
        ]
        read_only_fields = ["changed_by", "created_at"]


class DisputeResolutionSerializer(serializers.ModelSerializer):
    resolved_by = UserBriefSerializer(read_only=True)
    
    class Meta:
        model = DisputeResolution
        fields = [
            "id", "resolution_status", "refund_transaction_id", "refund_amount",
            "replacement_order", "resolved_by", "resolved_at", "executed_at"
        ]
        read_only_fields = ["resolved_by", "resolved_at"]


class CreateDisputeSerializer(serializers.Serializer):
    order_id = serializers.IntegerField(required=False, allow_null=True)
    category = serializers.ChoiceField(choices=DisputeCategory.choices)
    priority = serializers.ChoiceField(
        choices=DisputePriority.choices,
        default=DisputePriority.MEDIUM,
        required=False
    )
    title = serializers.CharField(max_length=255, min_length=5)
    description = serializers.CharField(max_length=5000, min_length=20)
    amount_claimed = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=0, required=False, default=0.0)
    evidence = serializers.JSONField(required=False, default=dict)
    
    def validate_order_id(self, value):
        if value is None:
            return None
        try:
            Order.objects.get(pk=value)
        except Order.DoesNotExist:
            raise serializers.ValidationError("Order not found")
        return value
    
    def validate_amount_claimed(self, value):
        if value <= 0:
            raise serializers.ValidationError("Amount must be greater than 0")
        return value


class DisputeListSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    priority_display = serializers.CharField(source="get_priority_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    raised_by = UserBriefSerializer(read_only=True)
    assigned_to = UserBriefSerializer(read_only=True)
    
    class Meta:
        model = Dispute
        fields = [
            "id", "ticket_id", "order", "raised_by", "assigned_to",
            "category", "category_display", "priority", "priority_display",
            "status", "status_display", "title", "amount_claimed",
            "amount_approved", "is_escalated", "created_at", "resolved_at"
        ]
        read_only_fields = fields


class DisputeDetailSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    priority_display = serializers.CharField(source="get_priority_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    resolution_type_display = serializers.CharField(source="get_resolution_type_display", read_only=True)
    raised_by = UserBriefSerializer(read_only=True)
    assigned_to = UserBriefSerializer(read_only=True)
    messages = DisputeMessageSerializer(many=True, read_only=True)
    history = DisputeHistorySerializer(many=True, read_only=True)
    resolution = DisputeResolutionSerializer(read_only=True)
    
    class Meta:
        model = Dispute
        fields = [
            "id", "ticket_id", "order", "raised_by", "assigned_to",
            "category", "category_display", "priority", "priority_display",
            "status", "status_display", "title", "description", "evidence",
            "amount_claimed", "amount_approved", "resolution_type",
            "resolution_type_display", "resolution_notes", "is_escalated",
            "escalation_reason", "messages", "history", "resolution",
            "created_at", "updated_at", "resolved_at"
        ]
        read_only_fields = fields


class ResolveDisputeSerializer(serializers.Serializer):
    resolution_type = serializers.ChoiceField(choices=ResolutionType.choices)
    amount_approved = serializers.DecimalField(
        max_digits=12, decimal_places=2, required=False, allow_null=True
    )
    resolution_notes = serializers.CharField(max_length=2000, required=True)
    
    def validate_amount_approved(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("Amount cannot be negative")
        return value


class EscalateDisputeSerializer(serializers.Serializer):
    escalation_reason = serializers.CharField(max_length=1000, min_length=10, required=True)


class AdminAssignDisputeSerializer(serializers.Serializer):
    assigned_to_id = serializers.IntegerField(required=True)
    
    def validate_assigned_to_id(self, value):
        try:
            User.objects.get(pk=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found")
        return value


class DisputeStatsSerializer(serializers.Serializer):
    """Dashboard statistics for disputes"""
    total_open = serializers.IntegerField()
    total_in_review = serializers.IntegerField()
    total_under_negotiation = serializers.IntegerField()
    total_resolved = serializers.IntegerField()
    total_rejected = serializers.IntegerField()
    total_closed = serializers.IntegerField()
    average_resolution_time_hours = serializers.FloatField()
    total_amount_in_dispute = serializers.DecimalField(max_digits=15, decimal_places=2)
    total_amount_approved = serializers.DecimalField(max_digits=15, decimal_places=2)
    by_category = serializers.DictField()
    by_priority = serializers.DictField()
