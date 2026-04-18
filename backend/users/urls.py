from django.urls import path
from .views import NewUser,Login


urlpatterns = [
    path("register/", NewUser.as_view(), name="create_user"),
    path("login/", Login.as_view(), name="login"),
]