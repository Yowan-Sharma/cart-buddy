from django.urls import path
from .views import NewUser, Login, Logout, UserProfile, RefreshTokenView, GoogleLoginView


urlpatterns = [
    path("register/", NewUser.as_view(), name="create_user"),
    path("login/", Login.as_view(), name="login"),
    path("logout/", Logout.as_view(), name="logout"),
    path("refresh/", RefreshTokenView.as_view(), name="refresh_token"),
    path("me/", UserProfile.as_view(), name="user_profile"),
    path("google/", GoogleLoginView.as_view(), name="google_login"),
]