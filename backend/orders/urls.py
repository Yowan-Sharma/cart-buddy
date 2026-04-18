from django.urls import path

from .views import (
	MyHandoverOtpView,
	OrderDetailView,
	OrderItemDetailView,
	OrderItemListCreateView,
	OrderListCreateView,
	OrderParticipantDetailView,
	OrderParticipantListCreateView,
	OrderStatusHistoryListView,
	OrderStatusUpdateView,
	VerifyHandoverOtpView,
)


urlpatterns = [
	path("", OrderListCreateView.as_view(), name="order_list_create"),
	path("<int:pk>/", OrderDetailView.as_view(), name="order_detail"),
	path("<int:order_id>/participants/", OrderParticipantListCreateView.as_view(), name="order_participant_list_create"),
	path("participants/<int:pk>/", OrderParticipantDetailView.as_view(), name="order_participant_detail"),
	path("<int:order_id>/items/", OrderItemListCreateView.as_view(), name="order_item_list_create"),
	path("items/<int:pk>/", OrderItemDetailView.as_view(), name="order_item_detail"),
	path("<int:order_id>/status/", OrderStatusUpdateView.as_view(), name="order_status_update"),
	path("<int:order_id>/status-history/", OrderStatusHistoryListView.as_view(), name="order_status_history"),
	path("<int:order_id>/handover-otp/me/", MyHandoverOtpView.as_view(), name="order_handover_otp_me"),
	path("<int:order_id>/handover-otp/verify/", VerifyHandoverOtpView.as_view(), name="order_handover_otp_verify"),
]