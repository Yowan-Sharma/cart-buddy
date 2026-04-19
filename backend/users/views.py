from rest_framework.views import Response, status, APIView
from .serializers import UserSerializer
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken as JWTRefreshToken
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.conf import settings
import requests


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

        return Response({"errors": user.errors}, status=status.HTTP_400_BAD_REQUEST)


class Login(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username_or_email = request.data.get('username')
        password = request.data.get('password')

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

        return Response({"error": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)


class Logout(APIView):
    def post(self, request):
        response = Response({"message": "Logout successful"}, status=status.HTTP_200_OK)
        response.delete_cookie("refresh_token")
        return response


class RefreshTokenView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
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
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class GoogleLoginView(APIView):
    """
    POST /users/google/
    Body: { "id_token": "<Google ID token from Flutter>" }
    Returns: { access, refresh, is_new_user }
    """
    permission_classes = [AllowAny]

    def post(self, request):
        id_token = request.data.get('id_token')
        if not id_token:
            return Response({'error': 'id_token is required'}, status=status.HTTP_400_BAD_REQUEST)

        # Verify token with Google's tokeninfo endpoint
        google_response = requests.get(
            'https://oauth2.googleapis.com/tokeninfo',
            params={'id_token': id_token},
            timeout=10,
        )

        if google_response.status_code != 200:
            return Response({'error': 'Invalid Google token'}, status=status.HTTP_401_UNAUTHORIZED)

        payload = google_response.json()

        # Validate audience matches our client ID
        client_id = getattr(settings, 'GOOGLE_CLIENT_ID', '')
        if client_id and payload.get('aud') != client_id:
            return Response({'error': 'Token audience mismatch'}, status=status.HTTP_401_UNAUTHORIZED)

        google_id = payload.get('sub')
        email = payload.get('email')
        first_name = payload.get('given_name', '')
        last_name = payload.get('family_name', '')

        if not google_id or not email:
            return Response({'error': 'Incomplete Google profile'}, status=status.HTTP_400_BAD_REQUEST)

        from django.contrib.auth import get_user_model
        User = get_user_model()

        is_new_user = False

        user = User.objects.filter(google_id=google_id).first()
        if user is None:
            user = User.objects.filter(email=email).first()
            if user is not None:
                # Link existing account to Google
                user.google_id = google_id
                user.save(update_fields=['google_id'])
            else:
                # Create new user — phone/gender completed later in profile_completion
                base_username = email.split('@')[0]
                username = base_username
                counter = 1
                while User.objects.filter(username=username).exists():
                    username = f"{base_username}{counter}"
                    counter += 1

                user = User.objects.create(
                    username=username,
                    email=email,
                    first_name=first_name,
                    last_name=last_name,
                    google_id=google_id,
                )
                user.set_unusable_password()
                user.save()
                is_new_user = True

        refresh = JWTRefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'is_new_user': is_new_user,
        }, status=status.HTTP_200_OK)