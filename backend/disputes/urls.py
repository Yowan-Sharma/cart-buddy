from django.urls import path


def get_urlpatterns():
    from .views import (
        CreateDisputeView, DisputeListView, DisputeDetailView,
        AddDisputeMessageView, DisputeMessagesListView,
        EscalateDisputeView, AdminResolveDisputeView, AdminAssignDisputeView,
        AdminListDisputesView, AdminStatsView
    )
    
    return [
        # User endpoints
        path("", CreateDisputeView.as_view(), name="create_dispute"),
        path("my/", DisputeListView.as_view(), name="list_my_disputes"),
        path("<str:ticket_id>/", DisputeDetailView.as_view(), name="dispute_detail"),
        path("<str:ticket_id>/messages/", DisputeMessagesListView.as_view(), name="dispute_messages_list"),
        path("<str:ticket_id>/messages/create/", AddDisputeMessageView.as_view(), name="add_dispute_message"),
        path("<str:ticket_id>/escalate/", EscalateDisputeView.as_view(), name="escalate_dispute"),
        
        # Admin endpoints
        path("admin/all/", AdminListDisputesView.as_view(), name="admin_list_disputes"),
        path("admin/stats/", AdminStatsView.as_view(), name="admin_stats"),
        path("<str:ticket_id>/assign/", AdminAssignDisputeView.as_view(), name="assign_dispute"),
        path("<str:ticket_id>/resolve/", AdminResolveDisputeView.as_view(), name="resolve_dispute"),
    ]


urlpatterns = get_urlpatterns()
