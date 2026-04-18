from django.urls import include, path

urlpatterns = [
    path("users/", include("users.urls")),
    path("organisations/", include("organisations.urls")),
    path("orders/", include("orders.urls")),
    path("payments/", include("payments.urls")),
]
