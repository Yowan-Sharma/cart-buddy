from django.utils import timezone
from django.db import transaction
from decimal import Decimal
from datetime import timedelta
import logging

from .models import (
    Dispute, DisputeMessage, DisputeHistory, DisputeResolution,
    DisputeStatus, ResolutionType, MessageType
)
from orders.models import Order, OrderParticipant
from payments.models import PaymentTransaction

logger = logging.getLogger(__name__)


class DisputeService:
    """Service layer for dispute operations"""
    
    @staticmethod
    def create_dispute(order, raised_by, category, priority, title, description, amount_claimed, evidence):
        """Create a new dispute"""
        dispute = Dispute.objects.create(
            order=order,
            raised_by=raised_by,
            category=category,
            priority=priority,
            title=title,
            description=description,
            amount_claimed=amount_claimed or Decimal("0.00"),
            evidence=evidence or {},
        )
        
        # Add system message
        DisputeMessage.objects.create(
            dispute=dispute,
            sender=raised_by,
            message=f"Dispute raised: {title}",
            message_type=MessageType.SYSTEM,
        )
        
        order_info = f"for order {order.id}" if order else "without specific order"
        logger.info(f"Dispute {dispute.ticket_id} created {order_info}")
        return dispute
    
    @staticmethod
    def add_message(dispute, sender, message, message_type=MessageType.USER):
        """Add message to dispute"""
        msg = DisputeMessage.objects.create(
            dispute=dispute,
            sender=sender,
            message=message,
            message_type=message_type,
        )
        return msg
    
    @staticmethod
    def change_status(dispute, new_status, changed_by, reason):
        """Change dispute status with history tracking"""
        old_status = dispute.status
        
        # Create history record
        DisputeHistory.objects.create(
            dispute=dispute,
            changed_by=changed_by,
            old_status=old_status,
            new_status=new_status,
            change_reason=reason,
        )
        
        # Update dispute
        dispute.status = new_status
        if new_status == DisputeStatus.RESOLVED:
            dispute.resolved_at = timezone.now()
        dispute.save()
        
        # Add system message
        DisputeMessage.objects.create(
            dispute=dispute,
            sender=changed_by,
            message=f"Status changed from {old_status} to {new_status}: {reason}",
            message_type=MessageType.SYSTEM,
        )
        
        logger.info(f"Dispute {dispute.ticket_id} status: {old_status} -> {new_status}")
    
    @staticmethod
    def resolve_dispute(dispute, resolution_type, amount_approved, resolution_notes, resolved_by):
        """Resolve dispute with decision"""
        with transaction.atomic():
            # Update dispute
            dispute.resolution_type = resolution_type
            dispute.amount_approved = amount_approved
            dispute.resolution_notes = resolution_notes
            dispute.status = DisputeStatus.RESOLVED
            dispute.resolved_at = timezone.now()
            dispute.save()
            
            # Create or update resolution
            resolution, created = DisputeResolution.objects.get_or_create(
                dispute=dispute,
                defaults={
                    "resolved_by": resolved_by,
                    "refund_amount": amount_approved,
                }
            )
            
            if not created:
                resolution.resolved_by = resolved_by
                resolution.refund_amount = amount_approved
                resolution.save()
            
            # Create history
            DisputeHistory.objects.create(
                dispute=dispute,
                changed_by=resolved_by,
                old_status=DisputeStatus.IN_REVIEW,
                new_status=DisputeStatus.RESOLVED,
                change_reason=f"Resolved: {resolution_type} - {resolution_notes}",
            )
            
            # Add system message
            DisputeMessage.objects.create(
                dispute=dispute,
                sender=resolved_by,
                message=f"Dispute resolved: {resolution_type}. Amount approved: ₹{amount_approved}",
                message_type=MessageType.ADMIN,
            )
            
            logger.info(f"Dispute {dispute.ticket_id} resolved with {resolution_type}")
            
            return resolution
    
    @staticmethod
    def escalate_dispute(dispute, escalation_reason, escalated_by):
        """Escalate dispute for higher priority handling"""
        dispute.is_escalated = True
        dispute.escalation_reason = escalation_reason
        if dispute.status == DisputeStatus.OPEN:
            dispute.priority = "CRITICAL"  # Escalated disputes get critical priority
        dispute.save()
        
        # Add history
        DisputeHistory.objects.create(
            dispute=dispute,
            changed_by=escalated_by,
            old_status=dispute.status,
            new_status=dispute.status,
            change_reason=f"ESCALATED: {escalation_reason}",
        )
        
        # Add message
        DisputeMessage.objects.create(
            dispute=dispute,
            sender=escalated_by,
            message=f"Dispute escalated: {escalation_reason}",
            message_type=MessageType.SYSTEM,
        )
        
        logger.info(f"Dispute {dispute.ticket_id} escalated")
    
    @staticmethod
    def assign_dispute(dispute, assigned_to, assigned_by):
        """Assign dispute to admin"""
        dispute.assigned_to = assigned_to
        if dispute.status == DisputeStatus.OPEN:
            dispute.status = DisputeStatus.IN_REVIEW
        dispute.save()
        
        DisputeHistory.objects.create(
            dispute=dispute,
            changed_by=assigned_by,
            old_status=DisputeStatus.OPEN,
            new_status=DisputeStatus.IN_REVIEW,
            change_reason=f"Assigned to {assigned_to.username}",
        )
        
        logger.info(f"Dispute {dispute.ticket_id} assigned to {assigned_to.username}")
    
    @staticmethod
    def get_dispute_stats():
        """Get dashboard statistics"""
        from django.db.models import Count, Sum, Q, F, Value
        from django.db.models.functions import Coalesce
        
        disputes = Dispute.objects.all()
        
        stats = {
            "total_open": disputes.filter(status=DisputeStatus.OPEN).count(),
            "total_in_review": disputes.filter(status=DisputeStatus.IN_REVIEW).count(),
            "total_under_negotiation": disputes.filter(status=DisputeStatus.UNDER_NEGOTIATION).count(),
            "total_resolved": disputes.filter(status=DisputeStatus.RESOLVED).count(),
            "total_rejected": disputes.filter(status=DisputeStatus.REJECTED).count(),
            "total_closed": disputes.filter(status=DisputeStatus.CLOSED).count(),
            "total_amount_in_dispute": disputes.aggregate(Sum("amount_claimed"))["amount_claimed__sum"] or Decimal("0"),
            "total_amount_approved": disputes.aggregate(Sum("amount_approved"))["amount_approved__sum"] or Decimal("0"),
        }
        
        # Calculate average resolution time
        resolved = disputes.filter(resolved_at__isnull=False)
        if resolved.exists():
            total_hours = 0
            for d in resolved:
                hours = (d.resolved_at - d.created_at).total_seconds() / 3600
                total_hours += hours
            stats["average_resolution_time_hours"] = total_hours / resolved.count()
        else:
            stats["average_resolution_time_hours"] = 0
        
        # By category
        stats["by_category"] = dict(
            disputes.values("category").annotate(count=Count("id")).values_list("category", "count")
        )
        
        # By priority
        stats["by_priority"] = dict(
            disputes.values("priority").annotate(count=Count("id")).values_list("priority", "count")
        )
        
        return stats
