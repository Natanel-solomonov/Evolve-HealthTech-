from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from api.waitlist_models import WaitlistedAppUser, University
from django.db.models import F, Q
from django.shortcuts import get_object_or_404

class WaitlistStatsAPIView(APIView):
    """Return the total number of people on the wait-list."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({"total_waitlisted_users": WaitlistedAppUser.objects.count()})

class WaitlistSignupAPIView(APIView):
    """Handle wait-list sign-up from the SPA form."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone_number = request.data.get("phone_number", "").strip()
        if not phone_number.isdigit() or len(phone_number) != 10:
            return Response({"error": "Phone number must be 10 digits."}, status=status.HTTP_400_BAD_REQUEST)

        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()

        user, created = WaitlistedAppUser.objects.get_or_create(
            phone_number=phone_number,
            defaults={"first_name": first_name, "last_name": last_name},
        )

        if not created:
            # update names if provided
            updates = {}
            if first_name and user.first_name != first_name:
                updates["first_name"] = first_name
            if last_name and user.last_name != last_name:
                updates["last_name"] = last_name
            if updates:
                for k, v in updates.items():
                    setattr(user, k, v)
                user.save(update_fields=list(updates.keys()))

        return Response({"user_id": user.id})

class WaitlistPositionAPIView(APIView):
    """Return position data for a given user."""
    permission_classes = [permissions.AllowAny]

    def get(self, request, user_id):
        user = get_object_or_404(WaitlistedAppUser, id=user_id)
        data = {
            "id": str(user.id),
            "position": user.position,
            "referral_link": request.build_absolute_uri(f"/r/{user.referral_link}"),
            "friends_invited": user.referrals,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "school": user.school.name if user.school else None,
        }
        return Response(data)

class UpdateSchoolAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, user_id):
        school_name = request.data.get("school_name", "").strip()
        user = get_object_or_404(WaitlistedAppUser, id=user_id)
        if not school_name:
            user.school = None
            user.save(update_fields=["school"])
            return Response(status=status.HTTP_204_NO_CONTENT)
        try:
            school = University.objects.get(name__iexact=school_name)
        except University.DoesNotExist:
            return Response({"error": "Invalid school."}, status=status.HTTP_400_BAD_REQUEST)
        user.school = school
        user.save(update_fields=["school"])
        return Response(status=status.HTTP_204_NO_CONTENT)

class UpdateFullNameAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, user_id):
        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()
        user = get_object_or_404(WaitlistedAppUser, id=user_id)
        updates = {}
        if first_name and user.first_name != first_name:
            updates["first_name"] = first_name
        if last_name and user.last_name != last_name:
            updates["last_name"] = last_name
        if updates:
            for k, v in updates.items():
                setattr(user, k, v)
            user.save(update_fields=list(updates.keys()))
        return Response(status=status.HTTP_204_NO_CONTENT) 