from django.urls import path

from .views import (
	ApproveOrderItemView,
	MyHandoverOtpView,
	OrderDetailView,
	OrderItemDetailView,
	OrderItemListCreateView,
	OrderListCreateView,
	OrderParticipantDetailView,
	OrderParticipantListCreateView,
	OrderStatusHistoryListView,
	OrderStatusUpdateView,
	RejectOrderItemView,
	SubmitCartView,
	VerifyHandoverOtpView,
)


urlpatterns = [
	path("", OrderListCreateView.as_view(), name="order_list_create"),
	path("<int:pk>/", OrderDetailView.as_view(), name="order_detail"),
	path("<int:order_id>/participants/", OrderParticipantListCreateView.as_view(), name="order_participant_list_create"),
	path("participants/<int:pk>/", OrderParticipantDetailView.as_view(), name="order_participant_detail"),
	path("<int:order_id>/items/", OrderItemListCreateView.as_view(), name="order_item_list_create"),
	path("<int:order_id>/cart/submit/", SubmitCartView.as_view(), name="order_cart_submit"),
	path("items/<int:pk>/", OrderItemDetailView.as_view(), name="order_item_detail"),
	path("items/<int:pk>/approve/", ApproveOrderItemView.as_view(), name="order_item_approve"),
	path("items/<int:pk>/reject/", RejectOrderItemView.as_view(), name="order_item_reject"),
	path("<int:order_id>/status/", OrderStatusUpdateView.as_view(), name="order_status_update"),
	path("<int:order_id>/status-history/", OrderStatusHistoryListView.as_view(), name="order_status_history"),
	path("<int:order_id>/handover-otp/me/", MyHandoverOtpView.as_view(), name="order_handover_otp_me"),
	path("<int:order_id>/handover-otp/verify/", VerifyHandoverOtpView.as_view(), name="order_handover_otp_verify"),
]
