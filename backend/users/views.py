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
            user.save()

            return Response({
                "message": "User Created successfully.",
                "user": user.data
            }, status=status.HTTP_201_CREATED)
        
        return Response(
            {
                "errors": user.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
class Login(APIView):
    permission_classes = [AllowAny]

    def post(self,request):
        username = request.data['username']
        password = request.data['password']

        user = authenticate(username=username, password=password)

        if user is not None:
            refresh = JWTRefreshToken.for_user(user)
            response = Response(
                {
                    "message": "Login successful",
                    "access": str(refresh.access_token),
                },
                status=status.HTTP_200_OK
            )
            response.set_cookie(
                key="refresh_token",
                value=str(refresh),
                httponly=True,
                secure=True,
                samesite="Strict"
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
        refresh_token = request.COOKIES.get("refresh_token")

        if not refresh_token:
            return Response(
                {"error": "Refresh token not provided"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            refresh = JWTRefreshToken(refresh_token)
            new_access_token = str(refresh.access_token)
            
            return Response(
                {"access": new_access_token},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {"error": "Invalid refresh token"},
                status=status.HTTP_401_UNAUTHORIZED
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