from rest_framework.views import Response, status, APIView
from .serializers import UserSerializer
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken as JWTRefreshToken
from rest_framework.permissions import AllowAny, IsAuthenticated


class NewUser(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        data = request.data

        user = UserSerializer(data=data)
        if user.is_valid():
            new_user = user.save()
            refresh = JWTRefreshToken.for_user(new_user)
            response = Response({
                "message": "User Created successfully.",
                "user": user.data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            }, status=status.HTTP_201_CREATED)
            response.set_cookie(
                key="refresh_token",
                value=str(refresh),
                httponly=True,
                secure=True,
                samesite="None"
            )
            return response
        
        return Response(
            {
                "errors": user.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
class Login(APIView):
    permission_classes = [AllowAny]

    def post(self,request):
        username_or_email = request.data.get('username')
        password = request.data.get('password')

        # Check if login is email or username
        if username_or_email and "@" in username_or_email:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            try:
                username = User.objects.get(email=username_or_email).username
            except User.DoesNotExist:
                username = username_or_email
        else:
            username = username_or_email

        user = authenticate(username=username, password=password)

        if user is not None:
            refresh = JWTRefreshToken.for_user(user)
            response = Response(
                {
                    "message": "Login successful",
                    "access": str(refresh.access_token),
                    "refresh": str(refresh),
                },
                status=status.HTTP_200_OK
            )
            response.set_cookie(
                key="refresh_token",
                value=str(refresh),
                httponly=True,
                secure=True,
                samesite="None"
            )

            return response

        return Response(
            {"error": "Invalid credentials"},
            status=status.HTTP_401_UNAUTHORIZED
        )


class Logout(APIView):
    def post(self, request):
        response = Response(
            {"message": "Logout successful"},
            status=status.HTTP_200_OK
        )
        response.delete_cookie("refresh_token")
        return response


class RefreshTokenView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        # Web clients: HttpOnly cookie. Mobile / Flutter: JSON body {"refresh": "..."}.
        refresh_token = request.COOKIES.get("refresh_token")
        if not refresh_token and getattr(request, "data", None) is not None:
            refresh_token = request.data.get("refresh")

        if not refresh_token:
            return Response(
                {"error": "Refresh token not provided"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            refresh = JWTRefreshToken(refresh_token)
            new_access_token = str(refresh.access_token)
            new_refresh = str(refresh)
            response = Response(
                {"access": new_access_token, "refresh": new_refresh},
                status=status.HTTP_200_OK,
            )
            response.set_cookie(
                key="refresh_token",
                value=new_refresh,
                httponly=True,
                secure=True,
                samesite="None",
            )
            return response
        except Exception:
            return Response(
                {"error": "Invalid refresh token", "code": "token_not_valid"},
                status=status.HTTP_401_UNAUTHORIZED,
            )
    


class UserProfile(APIView):
    permission_classes = [IsAuthenticated]
    def get(self, request):
        user = request.user
        serializer = UserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    def patch(self, request):
        user = request.user
        serializer = UserSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)