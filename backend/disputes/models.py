from django.db import models
from django.contrib.auth import get_user_model
from orders.models import Order
from decimal import Decimal

User = get_user_model()


class DisputeCategory(models.TextChoices):
    PAYMENT_ISSUE = "PAYMENT_ISSUE", "Payment Issue"
    ITEM_MISMATCH = "ITEM_MISMATCH", "Item Mismatch"
    CANCELLATION = "CANCELLATION", "Cancellation Dispute"
    DELIVERY = "DELIVERY", "Delivery Issue"
    QUALITY = "QUALITY", "Quality Complaint"
    OTHER = "OTHER", "Other"


class DisputePriority(models.TextChoices):
    LOW = "LOW", "Low"
    MEDIUM = "MEDIUM", "Medium"
    HIGH = "HIGH", "High"
    CRITICAL = "CRITICAL", "Critical"


class DisputeStatus(models.TextChoices):
    OPEN = "OPEN", "Open"
    IN_REVIEW = "IN_REVIEW", "In Review"
    UNDER_NEGOTIATION = "UNDER_NEGOTIATION", "Under Negotiation"
    RESOLVED = "RESOLVED", "Resolved"
    CLOSED = "CLOSED", "Closed"
    REJECTED = "REJECTED", "Rejected"


class ResolutionType(models.TextChoices):
    AUTO_REFUND = "AUTO_REFUND", "Auto Refund"
    PARTIAL_REFUND = "PARTIAL_REFUND", "Partial Refund"
    FULL_REFUND = "FULL_REFUND", "Full Refund"
    REPLACEMENT = "REPLACEMENT", "Replacement Order"
    NO_ACTION = "NO_ACTION", "No Action Needed"


class MessageType(models.TextChoices):
    USER = "USER", "User Message"
    ADMIN = "ADMIN", "Admin Response"
    SYSTEM = "SYSTEM", "System Notification"


class Dispute(models.Model):
    # Core identifiers
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="disputes", null=True, blank=True)
    ticket_id = models.CharField(max_length=50, unique=True, editable=False)
    raised_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name="raised_disputes")
    assigned_to = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_disputes")
    
    # Classification
    category = models.CharField(max_length=50, choices=DisputeCategory.choices)
    priority = models.CharField(max_length=20, choices=DisputePriority.choices, default=DisputePriority.MEDIUM)
    status = models.CharField(max_length=30, choices=DisputeStatus.choices, default=DisputeStatus.OPEN)
    
    # Description
    title = models.CharField(max_length=255)
    description = models.TextField()
    evidence = models.JSONField(default=dict, blank=True, help_text="URLs or file references for evidence")
    
    # Financial tracking
    amount_claimed = models.DecimalField(max_digits=12, decimal_places=2)
    amount_approved = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, default=None)
    
    # Resolution
    resolution_type = models.CharField(max_length=50, choices=ResolutionType.choices, null=True, blank=True)
    resolution_notes = models.TextField(blank=True, help_text="Admin's decision and explanation")
    
    # Metadata
    is_escalated = models.BooleanField(default=False)
    escalation_reason = models.TextField(blank=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["ticket_id"]),
            models.Index(fields=["order", "status"]),
            models.Index(fields=["raised_by", "status"]),
            models.Index(fields=["assigned_to", "status"]),
        ]
    
    def __str__(self):
        return f"Dispute {self.ticket_id} - {self.title}"
    
    def save(self, *args, **kwargs):
        if not self.ticket_id:
            # Generate ticket ID: DISP-ORD{order_id}-{timestamp} or DISP-GEN-{timestamp}
            import time
            prefix = f"ORD{self.order_id}" if self.order_id else "GEN"
            self.ticket_id = f"DISP-{prefix}-{int(time.time())}"
        super().save(*args, **kwargs)


class DisputeMessage(models.Model):
    dispute = models.ForeignKey(Dispute, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name="dispute_messages")
    message = models.TextField()
    message_type = models.CharField(max_length=20, choices=MessageType.choices, default=MessageType.USER)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["dispute", "created_at"]),
        ]
    
    def __str__(self):
        return f"Message on {self.dispute.ticket_id} by {self.sender}"


class DisputeHistory(models.Model):
    dispute = models.ForeignKey(Dispute, on_delete=models.CASCADE, related_name="history")
    changed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name="dispute_changes")
    old_status = models.CharField(max_length=30, choices=DisputeStatus.choices)
    new_status = models.CharField(max_length=30, choices=DisputeStatus.choices)
    change_reason = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["dispute", "created_at"]),
        ]
    
    def __str__(self):
        return f"History: {self.dispute.ticket_id} {self.old_status} → {self.new_status}"


class DisputeResolution(models.Model):
    """Outcome tracking for resolved disputes"""
    RESOLUTION_STATUS = [
        ("PENDING", "Pending"),
        ("APPROVED", "Approved"),
        ("REJECTED", "Rejected"),
        ("EXECUTED", "Executed"),
    ]
    
    dispute = models.OneToOneField(Dispute, on_delete=models.CASCADE, related_name="resolution")
    resolution_status = models.CharField(max_length=20, choices=RESOLUTION_STATUS, default="PENDING")
    
    # Refund tracking
    refund_transaction_id = models.CharField(max_length=100, blank=True, help_text="Razorpay refund ID")
    refund_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    
    # Replacement tracking
    replacement_order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name="dispute_replacements")
    
    # Resolution metadata
    resolved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name="resolved_disputes")
    resolved_at = models.DateTimeField(auto_now_add=True)
    executed_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ["-resolved_at"]
    
    def __str__(self):
        return f"Resolution for {self.dispute.ticket_id}: {self.resolution_status}"
