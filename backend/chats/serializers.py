from rest_framework import serializers

from .models import OrderChatMessage


class OrderChatMessageSerializer(serializers.ModelSerializer):
    sender_username = serializers.CharField(source="sender.username", read_only=True)

    class Meta:
        model = OrderChatMessage
        fields = [
            "id",
            "order",
            "sender",
            "sender_username",
            "message_type",
            "message",
            "metadata",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "sender",
            "sender_username",
            "message_type",
            "created_at",
        ]


class SendChatMessageSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=4000)
    metadata = serializers.JSONField(required=False)

    def validate_message(self, value: str):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("message cannot be empty.")
        return value
