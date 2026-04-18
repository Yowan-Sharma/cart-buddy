from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from django.db.models import Q

from .models import Dispute, DisputeMessage, DisputeStatus
from .serializers import (
    CreateDisputeSerializer, DisputeListSerializer, DisputeDetailSerializer,
    SendDisputeMessageSerializer, ResolveDisputeSerializer, EscalateDisputeSerializer,
    AdminAssignDisputeSerializer, DisputeStatsSerializer, DisputeMessageSerializer
)
from .permissions import (
    can_view_dispute, can_add_message, can_escalate_dispute, can_resolve_dispute,
    IsDisputeParticipant, CanAddDisputeMessage, CanResolveDispute, IsDisputeAdmin
)
from .services import DisputeService
from orders.models import Order, OrderParticipant


class CreateDisputeView(generics.CreateAPIView):
    """POST /disputes/ - Create a new dispute"""
    permission_classes = [IsAuthenticated]
    serializer_class = CreateDisputeSerializer
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        order = Order.objects.get(pk=serializer.validated_data["order_id"])
        
        # Verify user is related to this order
        if not (order.creator == request.user or OrderParticipant.objects.filter(order=order, user=request.user).exists()):
            return Response(
                {"error": "You must be creator or participant of this order to raise dispute"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        dispute = DisputeService.create_dispute(
            order=order,
            raised_by=request.user,
            category=serializer.validated_data["category"],
            priority=serializer.validated_data.get("priority", "MEDIUM"),
            title=serializer.validated_data["title"],
            description=serializer.validated_data["description"],
            amount_claimed=serializer.validated_data["amount_claimed"],
            evidence=serializer.validated_data.get("evidence"),
        )
        
        return Response(
            DisputeDetailSerializer(dispute).data,
            status=status.HTTP_201_CREATED
        )


class DisputeListView(generics.ListAPIView):
    """GET /disputes/ - List my disputes"""
    permission_classes = [IsAuthenticated]
    serializer_class = DisputeListSerializer
    
    def get_queryset(self):
        if self.request.user.is_staff:
            return Dispute.objects.all()
        
        return Dispute.objects.filter(
            Q(raised_by=self.request.user) |
            Q(order__creator=self.request.user) |
            Q(order__participants__user=self.request.user)
        ).distinct()


class DisputeDetailView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /disputes/<id>/ - View and update dispute"""
    permission_classes = [IsAuthenticated, IsDisputeParticipant]
    serializer_class = DisputeDetailSerializer
    queryset = Dispute.objects.all()
    lookup_field = "ticket_id"
    
    def get_object(self):
        obj = super().get_object()
        self.check_object_permissions(self.request, obj)
        return obj
    
    def patch(self, request, *args, **kwargs):
        dispute = self.get_object()
        
        # Only raiser can update open disputes
        if dispute.raised_by != request.user or dispute.status != DisputeStatus.OPEN:
            return Response(
                {"error": "Cannot update dispute at this stage"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Allow only title and description updates
        if "title" in request.data:
            dispute.title = request.data["title"]
        if "description" in request.data:
            dispute.description = request.data["description"]
        if "evidence" in request.data:
            dispute.evidence = request.data["evidence"]
        
        dispute.save()
        return Response(DisputeDetailSerializer(dispute).data)


class AddDisputeMessageView(generics.CreateAPIView):
    """POST /disputes/<ticket_id>/messages/ - Add message to dispute"""
    permission_classes = [IsAuthenticated, CanAddDisputeMessage]
    serializer_class = SendDisputeMessageSerializer
    
    def create(self, request, ticket_id=None, *args, **kwargs):
        dispute = get_object_or_404(Dispute, ticket_id=ticket_id)
        
        if not can_add_message(dispute, request.user):
            return Response(
                {"error": "You cannot add message to this dispute"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        message = DisputeService.add_message(
            dispute=dispute,
            sender=request.user,
            message=serializer.validated_data["message"]
        )
        
        return Response(
            DisputeMessageSerializer(message).data,
            status=status.HTTP_201_CREATED
        )


class DisputeMessagesListView(generics.ListAPIView):
    """GET /disputes/<ticket_id>/messages/ - Get dispute messages"""
    permission_classes = [IsAuthenticated, IsDisputeParticipant]
    serializer_class = DisputeMessageSerializer
    
    def get_queryset(self):
        ticket_id = self.kwargs.get("ticket_id")
        dispute = get_object_or_404(Dispute, ticket_id=ticket_id)
        
        if not can_view_dispute(dispute, self.request.user):
            return DisputeMessage.objects.none()
        
        return dispute.messages.all()


class EscalateDisputeView(generics.GenericAPIView):
    """POST /disputes/<ticket_id>/escalate/ - Escalate dispute"""
    permission_classes = [IsAuthenticated]
    serializer_class = EscalateDisputeSerializer
    
    def post(self, request, ticket_id=None):
        dispute = get_object_or_404(Dispute, ticket_id=ticket_id)
        
        if not can_escalate_dispute(dispute, request.user):
            return Response(
                {"error": "You cannot escalate this dispute"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        DisputeService.escalate_dispute(
            dispute=dispute,
            escalation_reason=serializer.validated_data["escalation_reason"],
            escalated_by=request.user
        )
        
        return Response(
            DisputeDetailSerializer(dispute).data,
            status=status.HTTP_200_OK
        )


class AdminResolveDisputeView(generics.GenericAPIView):
    """POST /disputes/<ticket_id>/resolve/ - Resolve dispute (admin only)"""
    permission_classes = [IsAuthenticated, CanResolveDispute]
    serializer_class = ResolveDisputeSerializer
    
    def post(self, request, ticket_id=None):
        dispute = get_object_or_404(Dispute, ticket_id=ticket_id)
        
        if not can_resolve_dispute(request.user):
            return Response(
                {"error": "Permission denied"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        resolution = DisputeService.resolve_dispute(
            dispute=dispute,
            resolution_type=serializer.validated_data["resolution_type"],
            amount_approved=serializer.validated_data.get("amount_approved", dispute.amount_claimed),
            resolution_notes=serializer.validated_data["resolution_notes"],
            resolved_by=request.user
        )
        
        return Response(
            DisputeDetailSerializer(dispute).data,
            status=status.HTTP_200_OK
        )


class AdminAssignDisputeView(generics.GenericAPIView):
    """POST /disputes/<ticket_id>/assign/ - Assign to admin"""
    permission_classes = [IsAuthenticated, IsDisputeAdmin]
    serializer_class = AdminAssignDisputeSerializer
    
    def post(self, request, ticket_id=None):
        dispute = get_object_or_404(Dispute, ticket_id=ticket_id)
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        from users.models import User
        assigned_to = User.objects.get(pk=serializer.validated_data["assigned_to_id"])
        
        DisputeService.assign_dispute(
            dispute=dispute,
            assigned_to=assigned_to,
            assigned_by=request.user
        )
        
        return Response(
            DisputeDetailSerializer(dispute).data,
            status=status.HTTP_200_OK
        )


class AdminListDisputesView(generics.ListAPIView):
    """GET /disputes/admin/all/ - List all disputes (admin only)"""
    permission_classes = [IsAuthenticated, IsDisputeAdmin]
    serializer_class = DisputeListSerializer
    queryset = Dispute.objects.all()
    
    def get_queryset(self):
        queryset = Dispute.objects.all()
        
        status_filter = self.request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        category_filter = self.request.query_params.get("category")
        if category_filter:
            queryset = queryset.filter(category=category_filter)
        
        priority_filter = self.request.query_params.get("priority")
        if priority_filter:
            queryset = queryset.filter(priority=priority_filter)
        
        if self.request.query_params.get("assigned_to_me") == "true":
            queryset = queryset.filter(assigned_to=self.request.user)
        
        if self.request.query_params.get("unassigned") == "true":
            queryset = queryset.filter(assigned_to__isnull=True)
        
        return queryset.order_by("-created_at")


class AdminStatsView(generics.GenericAPIView):
    """GET /disputes/admin/stats/ - Dashboard statistics"""
    permission_classes = [IsAuthenticated, IsDisputeAdmin]
    serializer_class = DisputeStatsSerializer
    
    def get(self, request):
        stats = DisputeService.get_dispute_stats()
        serializer = self.get_serializer(stats)
        return Response(serializer.data)
