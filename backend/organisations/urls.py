from django.urls import path

from .views import (
	CampusDetailView,
	CampusListCreateView,
	MembershipDetailView,
	MembershipListCreateView,
	MyOrganisationMembershipsView,
	OrganisationDetailView,
	OrganisationListCreateView,
	PickupPointDetailView,
	PickupPointListCreateView,
)


urlpatterns = [
	path("", OrganisationListCreateView.as_view(), name="organisation_list_create"),
	path("<int:pk>/", OrganisationDetailView.as_view(), name="organisation_detail"),
	path("campuses/", CampusListCreateView.as_view(), name="campus_list_create"),
	path("campuses/<int:pk>/", CampusDetailView.as_view(), name="campus_detail"),
	path("pickup-points/", PickupPointListCreateView.as_view(), name="pickup_point_list_create"),
	path("pickup-points/<int:pk>/", PickupPointDetailView.as_view(), name="pickup_point_detail"),
	path("memberships/", MembershipListCreateView.as_view(), name="membership_list_create"),
	path("memberships/<int:pk>/", MembershipDetailView.as_view(), name="membership_detail"),
	path("me/memberships/", MyOrganisationMembershipsView.as_view(), name="my_memberships"),
]
