from rest_framework.views import Response, status, APIView
from .serializers import UserSerializer
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken

class NewUser(APIView):
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
    def post(self,request):
        username = request.data['username']
        password = request.data['password']

        user = authenticate(username=username, password=password)

        if user is not None:
            refresh = RefreshToken.for_user(user)
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