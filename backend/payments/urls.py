from django.urls import path

from .views import (
    CreateRazorpayOrderView,
    MyPaymentTransactionsView,
    RazorpayWebhookView,
    VerifyRazorpayPaymentView,
    MyWalletView,
    RequestWithdrawalView,
)


urlpatterns = [
    path("orders/create/", CreateRazorpayOrderView.as_view(), name="payments_create_razorpay_order"),
    path("orders/verify/", VerifyRazorpayPaymentView.as_view(), name="payments_verify_razorpay_payment"),
    path("transactions/", MyPaymentTransactionsView.as_view(), name="payments_my_transactions"),
    path("webhooks/razorpay/", RazorpayWebhookView.as_view(), name="payments_razorpay_webhook"),
    path("wallet/me/", MyWalletView.as_view(), name="payments_my_wallet"),
    path("wallet/withdraw/", RequestWithdrawalView.as_view(), name="payments_withdraw_funds"),
]
