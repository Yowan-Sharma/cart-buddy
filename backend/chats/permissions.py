from orders.models import Order
from organisations.models import MembershipStatus, OrganisationMembership


def can_access_order_chat(*, order: Order, user) -> bool:
    if user.is_superuser or order.creator_id == user.id:
        return True

    if order.participants.filter(user=user).exists():
        return True

    if order.organisation_id:
        return OrganisationMembership.objects.filter(
            organisation_id=order.organisation_id,
            user=user,
            status=MembershipStatus.ACTIVE,
        ).exists()

    return False
