from django.db.models import Q
from rest_framework import filters


class OrganisationFilterBackend(filters.BaseFilterBackend):
    """
    Filter queryset to orders (and similar) visible to the current user.

    - Superusers: no filter.
    - Users with an organisation: rows where organisation matches, or organisation is null
      (open / campus-wide orders that are not tied to a single tenant).
    - Users without an organisation: empty queryset (client should complete onboarding).
    """
    def filter_queryset(self, request, queryset, view):
        if request.user.is_superuser:
            return queryset

        user_org = getattr(request.user, "organisation", None)
        if user_org:
            if hasattr(queryset.model, "organisation"):
                return queryset.filter(
                    Q(organisation=user_org) | Q(organisation__isnull=True)
                )
            return queryset

        return queryset.none()
