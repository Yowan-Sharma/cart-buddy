from decimal import Decimal

from rest_framework import serializers

from .models import PaymentTransaction


class PaymentTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentTransaction
        fields = [
            "id",
            "order",
            "participant",
            "user",
            "provider",
            "status",
            "amount",
            "currency",
            "receipt_id",
            "idempotency_key",
            "razorpay_order_id",
            "razorpay_payment_id",
            "razorpay_signature",
            "is_amount_applied",
            "captured_at",
            "failed_reason",
            "gateway_payload",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class CreateRazorpayOrderSerializer(serializers.Serializer):
    order_id = serializers.IntegerField()
    participant_id = serializers.IntegerField(required=False)


class VerifyRazorpayPaymentSerializer(serializers.Serializer):
    payment_transaction_id = serializers.IntegerField(required=False)
    razorpay_order_id = serializers.CharField(required=False)
    razorpay_payment_id = serializers.CharField()
    razorpay_signature = serializers.CharField()

    def validate(self, attrs):
        if not attrs.get("payment_transaction_id") and not attrs.get("razorpay_order_id"):
            raise serializers.ValidationError(
                "Either payment_transaction_id or razorpay_order_id must be provided."
            )
        return attrs


class RazorpayWebhookSerializer(serializers.Serializer):
    event = serializers.CharField()
    payload = serializers.JSONField()


def paise_to_decimal(value: int) -> Decimal:
    return (Decimal(value) / Decimal("100")).quantize(Decimal("0.01"))


def decimal_to_paise(value: Decimal) -> int:
    return int((value * Decimal("100")).quantize(Decimal("1")))
