import json
from decimal import Decimal

import razorpay
from django.conf import settings

from .serializers import decimal_to_paise


class RazorpayConfigError(Exception):
    pass


def get_razorpay_client() -> razorpay.Client:
    key_id = settings.RAZORPAY_KEY_ID
    key_secret = settings.RAZORPAY_KEY_SECRET

    if not key_id or not key_secret:
        raise RazorpayConfigError("RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET are not configured.")

    return razorpay.Client(auth=(key_id, key_secret))


def create_order(*, amount: Decimal, currency: str, receipt: str, notes: dict | None = None) -> dict:
    client = get_razorpay_client()
    payload = {
        "amount": decimal_to_paise(amount),
        "currency": currency,
        "receipt": receipt,
    }
    if notes:
        payload["notes"] = notes
    return client.order.create(data=payload)


def verify_payment_signature(*, razorpay_order_id: str, razorpay_payment_id: str, razorpay_signature: str) -> None:
    client = get_razorpay_client()
    client.utility.verify_payment_signature(
        {
            "razorpay_order_id": razorpay_order_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_signature": razorpay_signature,
        }
    )


def fetch_payment(razorpay_payment_id: str) -> dict:
    client = get_razorpay_client()
    return client.payment.fetch(razorpay_payment_id)


def capture_payment(*, razorpay_payment_id: str, amount: Decimal, currency: str = "INR") -> dict:
    client = get_razorpay_client()
    return client.payment.capture(
        razorpay_payment_id,
        decimal_to_paise(amount),
        {"currency": currency},
    )


def verify_webhook_signature(payload_bytes: bytes, signature: str) -> None:
    secret = settings.RAZORPAY_WEBHOOK_SECRET
    if not secret:
        raise RazorpayConfigError("RAZORPAY_WEBHOOK_SECRET is not configured.")

    client = get_razorpay_client()
    body = payload_bytes.decode("utf-8") if isinstance(payload_bytes, bytes) else str(payload_bytes)
    client.utility.verify_webhook_signature(body, signature, secret)


def safe_json_loads(payload_bytes: bytes) -> dict:
    body = payload_bytes.decode("utf-8") if isinstance(payload_bytes, bytes) else str(payload_bytes)
    return json.loads(body)
