from rest_framework.permissions import BasePermission
from .models import Dispute
from orders.models import OrderParticipant, Order
from organisations.models import OrganisationMembership, MembershipRole


def can_view_dispute(dispute, user):
    """Check if user can view this dispute"""
    if user.is_staff:
        return True
    
    # Dispute raiser can view
    if dispute.raised_by == user:
        return True
    
    # Order participants can view disputes on their order
    if OrderParticipant.objects.filter(order=dispute.order, user=user).exists():
        return True
    
    # Organization members (ADMIN/OWNER) can view
    org = dispute.order.organisation
    if OrganisationMembership.objects.filter(
        organisation=org,
        user=user,
        role__in=[MembershipRole.ADMIN, MembershipRole.OWNER]
    ).exists():
        return True
    
    return False


def can_edit_dispute(dispute, user):
    """Check if user can edit dispute (limited fields)"""
    if user.is_staff:
        return True
    
    # Only raiser can edit open disputes
    if dispute.raised_by == user and dispute.status == "OPEN":
        return True
    
    return False


def can_escalate_dispute(dispute, user):
    """Check if user can escalate"""
    if user.is_staff:
        return True
    
    if dispute.raised_by == user and dispute.status in ["IN_REVIEW", "UNDER_NEGOTIATION"]:
        return True
    
    return False


def can_add_message(dispute, user):
    """Check if user can add message to dispute"""
    return can_view_dispute(dispute, user)


def can_resolve_dispute(user):
    """Check if user can resolve disputes (admin only)"""
    return user.is_staff


class IsDisputeRaiser(BasePermission):
    """Only dispute raiser can access"""
    
    def has_object_permission(self, request, view, obj):
        return obj.raised_by == request.user


class IsDisputeParticipant(BasePermission):
    """Dispute raiser or order participants"""
    
    def has_object_permission(self, request, view, obj):
        return can_view_dispute(obj, request.user)


class IsDisputeAdmin(BasePermission):
    """Staff only"""
    
    def has_permission(self, request, view):
        return request.user.is_staff


class CanAddDisputeMessage(BasePermission):
    """Can add message to dispute"""
    
    def has_object_permission(self, request, view, obj):
        return can_add_message(obj, request.user)


class CanResolveDispute(BasePermission):
    """Only admins can resolve"""
    
    def has_permission(self, request, view):
        return request.user.is_staff
