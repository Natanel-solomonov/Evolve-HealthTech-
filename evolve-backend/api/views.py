from rest_framework import generics, viewsets, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken, TokenError
from rest_framework import serializers

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.shortcuts import get_object_or_404
from django.db import transaction, models
from django.db.models import Q
from django.utils import timezone
from django.conf import settings

from twilio.rest import Client
import json
import random
import re
import logging
from decimal import Decimal, InvalidOperation
from datetime import date as datetime_date
import uuid
import os
import string
import traceback
from datetime import datetime, timedelta
from django.db import IntegrityError
from django.shortcuts import get_object_or_404, redirect

from .models import (
    Activity, Workout, Exercise, AppUser, AppUserInfo, AppUserGoals,
    Affiliate, AffiliatePromotion, AffiliatePromotionRedemption, FriendGroup, Member, ContentCard,
    ReadingContent, FriendGroupEvent, AppUserCurrentEmotion,
    AppUserDailyEmotion, UserScheduledActivity, UserCompletedLog,
    Shortcut, UserShortcut, Routine, RoutineStep, JournalEntry,
    UserProduct, FriendGroupInvitation
)
from .serializers import (
    ActivitySerializer, WorkoutSerializer, ExerciseSerializer,
    AppUserSerializer, AppUserGoalsSerializer, AffiliateSerializer,
    AffiliatePromotionSerializer, AffiliatePromotionRedemptionSerializer, FriendGroupSerializer,
    MemberSerializer, WorkoutGenerationSerializer, DailyCalorieTrackerSerializer,
    FoodEntrySerializer, FoodProductSerializer, ContentCardSerializer,
    ReadingContentSerializer, AppUserSimpleSerializer, AppUserUpdateSerializer,
    FriendGroupEventSerializer, AppUserCurrentEmotionSerializer,
    AppUserDailyEmotionSerializer, UserScheduledActivitySerializer,
    UserCompletedLogSerializer, BMRSerializer, CustomFoodSerializer,
    StreakSerializer, ShortcutSerializer, UserShortcutSerializer,
    RoutineSerializer, RoutineStepSerializer, JournalEntrySerializer,
    UserProductSerializer, UserProductUpdateSerializer,
    FriendGroupInvitationSerializer
)
from nutrition.models import DailyCalorieTracker, FoodEntry, FoodProduct, CustomFood
from fitness.services.openai_service import OpenAIService
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken
from max.ai import GroqClient
from max.services import get_user_details, get_latest_user_fatigue, get_user_1rm_stats
from max.services.custom_workout import generate_custom_workout, CustomWorkoutGenerationError
from website.models import WaitlistedAppUser

# --- Logging Configuration ---
logger = logging.getLogger(__name__)

# --- Custom Permissions ---

class IsOwnerOrAdmin(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object or admins to edit/view it.
    Assumes the object has a 'user' attribute or the view context provides user_id.
    """
    def has_object_permission(self, request, view, obj):
        # For AppUser model, obj is the AppUser instance itself
        if isinstance(obj, AppUser):
            return obj == request.user or request.user.is_staff
        # For other objects that have a .user attribute
        return obj.user == request.user or request.user.is_staff

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        user_id_in_url = view.kwargs.get('user_id') or view.kwargs.get('pk')
        if user_id_in_url:
            return str(request.user.id) == str(user_id_in_url) or request.user.is_staff
        
        return True


class IsTargetUserOrAdmin(permissions.BasePermission):
    """
    Custom permission for views operating on a user_id in the URL.
    Allows access if the request.user is the target user or an admin.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        target_user_id = view.kwargs.get('user_id')
        if target_user_id:
            return str(request.user.id) == str(target_user_id) or request.user.is_staff
        return False


class IsFriendGroupAdmin(permissions.BasePermission):
    """
    Custom permission to only allow admins of a friend group to update it.
    """
    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed for any authenticated user
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions are only allowed for admins of the friend group
        user = request.user
        try:
            membership = obj.friend_group_members.get(user=user)
            return membership.isAdmin
        except Member.DoesNotExist:
            return False


class IsMemberOfFriendGroup(permissions.BasePermission):
    """
    Custom permission to only allow members of a friend group to access related data.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        friend_group_id = view.kwargs.get('group_id')
        if not friend_group_id:
            return False
        
        try:
            friend_group = get_object_or_404(FriendGroup, pk=friend_group_id)
            return friend_group.members.filter(pk=request.user.pk).exists()
        except FriendGroup.DoesNotExist:
            return False

# --- Helper Functions ---

def clean_phone_number(phone):
    """
    Clean and validate the phone number to ensure it is in the format +11234567890.
    
    Args:
        phone (str): The phone number to clean
        
    Returns:
        str: The cleaned phone number
        
    Raises:
        ValueError: If the phone number is not in a valid format
    """
    # Remove common formatting characters but keep digits and leading +
    cleaned_phone = re.sub(r'[()\s-]', '', str(phone)) # Ensure phone is string

    if not cleaned_phone.startswith('+'):
        # If no country code, assume US and add +1 if it's a 10-digit number
        if len(cleaned_phone) == 10:
            cleaned_phone = '+1' + cleaned_phone
        # Or if it's an 11-digit number starting with 1 (like 18005551212)
        elif len(cleaned_phone) == 11 and cleaned_phone.startswith('1'):
            cleaned_phone = '+' + cleaned_phone
        else: # Can't safely assume +1 for other lengths without +
            # Fall through to final validation, which will likely fail and raise ValueError
            pass # Or raise ValueError("Phone number format unclear or missing country code and not a recognized US format.")
    
    # Final validation for + and 11 digits total (e.g. +1 and 10 more for US standard)
    if not re.match(r'^\+\d{11}$', cleaned_phone):
        raise ValueError('Phone number must be in the format +11234567890 (11 digits after initial +).')
    return cleaned_phone

# --- Activity Views ---

class ActivityListView(generics.ListCreateAPIView):
    """
    GET: List all activities
    POST: Create a new activity (admin only)
    """
    queryset = Activity.objects.all()
    serializer_class = ActivitySerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class ActivityDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific activity
    PUT/PATCH: Update an activity (admin only)
    DELETE: Remove an activity (admin only)
    """
    queryset = Activity.objects.all()
    serializer_class = ActivitySerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]

    def get_object(self):
        """
        Overrides the default get_object to handle UUID lookups.
        Django automatically handles UUID case-insensitivity in database queries.
        """
        queryset = self.get_queryset()
        pk = self.kwargs.get('pk')

        obj = get_object_or_404(queryset, pk=pk)
        self.check_object_permissions(self.request, obj)
        return obj

# --- Workout Views ---

class WorkoutListView(generics.ListCreateAPIView):
    """
    GET: List all workouts
    POST: Create a new workout (admin only)
    """
    queryset = Workout.objects.all()
    serializer_class = WorkoutSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class WorkoutDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific workout
    PUT/PATCH: Update a workout (admin only)
    DELETE: Remove a workout (admin only)
    """
    queryset = Workout.objects.all()
    serializer_class = WorkoutSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]

    def get_object(self):
        """
        Overrides the default get_object to handle UUID lookups with case-insensitivity.
        Accepts both uppercase and lowercase UUIDs from URL parameters.
        """
        queryset = self.get_queryset()
        pk_str = self.kwargs.get('pk')
        
        # Validate and normalize the UUID string
        try:
            import uuid
            # This will handle both uppercase and lowercase UUIDs
            normalized_uuid = uuid.UUID(pk_str)
        except (ValueError, TypeError):
            from django.http import Http404
            raise Http404("Invalid UUID format")

        obj = get_object_or_404(queryset, pk=normalized_uuid)
        self.check_object_permissions(self.request, obj)
        return obj


class ExerciseListView(generics.ListCreateAPIView):
    """
    GET: List all exercises
    POST: Create a new exercise (admin only)
    """
    queryset = Exercise.objects.all()
    serializer_class = ExerciseSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class ExerciseDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific exercise
    PUT/PATCH: Update an exercise (admin only)
    DELETE: Remove an exercise (admin only)
    """
    queryset = Exercise.objects.all()
    serializer_class = ExerciseSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]

# --- Authentication Views ---

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    """
    Send an OTP to a user's phone number.
    
    POST: Send OTP to the provided phone number
    """
    if request.method == "POST":
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"error": "Invalid JSON."}, status=400)
        
        phone = data.get("phone")
        if not phone:
            return JsonResponse({"error": "Phone number not provided."}, status=400)
        
        try:
            phone = clean_phone_number(phone)
        except ValueError as e:
            return JsonResponse({"error": str(e)}, status=400)
        
        user, created = AppUser.objects.get_or_create(
            phone=phone,
            defaults={'first_name': 'New', 'last_name': 'User'}
        )

        if getattr(settings, "TWILIO_USE_FAKE", False):
            otp_code = str(random.randint(100000, 999999))
            user.set_otp(otp_code) 
            print(f"TEST MODE: OTP for phone {phone} is {otp_code}")
            return JsonResponse({
                "message": "OTP generated successfully for test mode.",
                "otp_code": otp_code 
            })
        
        account_sid = settings.TWILIO_ACCOUNT_SID
        auth_token = settings.TWILIO_AUTH_TOKEN
        verify_sid = getattr(settings, "TWILIO_VERIFY_SERVICE_SID", None)

        if not verify_sid:
            logger.error("TWILIO_VERIFY_SERVICE_SID not configured in settings.")
            return JsonResponse({"error": "Twilio Verify Service SID not configured."}, status=500)

        client = Client(account_sid, auth_token)
        try:
            verification = client.verify.v2.services(verify_sid) \
                                        .verifications \
                                        .create(to=phone, channel='sms')
            logger.info(f"Twilio verification initiated with SID: {verification.sid} for phone: {phone}")
        except Exception as e:
            logger.error(f"Twilio Verify API error for phone {phone}: {str(e)}")
            return JsonResponse({"error": f"Failed to send OTP via Twilio Verify: {str(e)}"}, status=500)
        
        return JsonResponse({"message": "OTP sent successfully via Twilio Verify."})
    
    return JsonResponse({"error": "Invalid request method."}, status=405)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    """
    Verify an OTP and complete user registration.
    
    POST: Verify OTP and update user information
    """
    if request.method == "POST":
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"error": "Invalid JSON."}, status=400)

        phone = data.get("phone")
        otp = data.get("otp")

        if not phone or not otp:
            return JsonResponse({"error": "Phone number and OTP are required."}, status=400)

        try:
            phone = clean_phone_number(phone)
        except ValueError as e:
            return JsonResponse({"error": str(e)}, status=400)

        try:
            user = AppUser.objects.get(phone=phone)
        except AppUser.DoesNotExist:
            return JsonResponse({"error": "User does not exist. Please ensure send_otp was called first."}, status=404)

        otp_verified = False
        if getattr(settings, "TWILIO_USE_FAKE", False):
            if user.is_otp_valid(otp):
                otp_verified = True
            else:
                return JsonResponse({"error": "Invalid or expired OTP (test mode)."}, status=400)
        else:
            account_sid = settings.TWILIO_ACCOUNT_SID
            auth_token = settings.TWILIO_AUTH_TOKEN
            verify_sid = getattr(settings, "TWILIO_VERIFY_SERVICE_SID", None)
            if not verify_sid:
                logger.error("TWILIO_VERIFY_SERVICE_SID not configured in settings.")
                return JsonResponse({"error": "Twilio Verify Service SID not configured."}, status=500)
            client = Client(account_sid, auth_token)
            try:
                verification_check = client.verify.v2.services(verify_sid) \
                                                    .verification_checks \
                                                    .create(to=phone, code=otp)
                if verification_check.status == 'approved':
                    otp_verified = True
                    logger.info(f"Twilio verification successful for phone {phone}.")
                else:
                    logger.warning(f"Twilio verification failed for phone {phone}. Status: {verification_check.status}")
                    return JsonResponse({"error": "Invalid or expired OTP."}, status=400)
            except Exception as e:
                logger.error(f"Twilio Verify Check API error for phone {phone}: {str(e)}")
                return JsonResponse({"error": f"Failed to verify OTP via Twilio: {str(e)}"}, status=500)

        if otp_verified:
            user.is_phone_verified = True
            user.save(update_fields=["is_phone_verified"])
            
            refresh = RefreshToken.for_user(user)
            access_token = str(refresh.access_token)
            refresh_token = str(refresh)
            user_serializer = AppUserSerializer(user)

            return JsonResponse({
                "message": "OTP verified successfully.",
                "access_token": access_token,
                "refresh_token": refresh_token,
                "user": user_serializer.data
            })
        return JsonResponse({"error": "OTP verification failed unexpectedly."}, status=500)

    return JsonResponse({"error": "Invalid request method."}, status=405)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def logout_view(request):
    """
    Log out a user by blacklisting their refresh token.
    
    POST: Blacklist the current refresh token
    """
    try:
        refresh_token = request.data.get("refresh")
        if refresh_token is None:
            return Response({"error": "Refresh token not provided."}, status=status.HTTP_400_BAD_REQUEST)

        token = RefreshToken(refresh_token)
        token.blacklist()

        logger.info(f"User {request.user.id} logged out successfully. Refresh token blacklisted.")
        return Response({"message": "Logout successful."}, status=status.HTTP_205_RESET_CONTENT)
    except TokenError as e:
        logger.error(f"TokenError during logout for user {request.user.id if request.user and request.user.is_authenticated else 'UnknownUser'}: {e}")
        return Response({"error": "Invalid or expired refresh token."}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Exception during logout for user {request.user.id if request.user and request.user.is_authenticated else 'UnknownUser'}: {e}", exc_info=True)
        return Response({"error": "An error occurred during logout."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class WaitlistSignupAPIView(APIView):
    """
    API endpoint for waitlist signup from the new React frontend.
    """
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        phone_number_input = request.data.get("phone_number")

        if not phone_number_input:
            return Response({'error': 'Phone number is required.'}, status=status.HTTP_400_BAD_REQUEST)

        processed_phone_number = re.sub(r'\D', '', phone_number_input)
        
        if len(processed_phone_number) != 10:
             return Response({'error': 'A valid 10-digit phone number is required.'}, status=status.HTTP_400_BAD_REQUEST)

        # Using transaction.atomic to ensure all database operations succeed or fail together.
        try:
            with transaction.atomic():
                user, created = WaitlistedAppUser.objects.get_or_create(
                    phone_number=processed_phone_number,
                )
                
                # --- Referral Logic ---
                referral_code = request.session.get('referral_code')
                if created and referral_code:
                    try:
                        # Lock the referrer row to prevent race conditions when updating position/referrals
                        referrer = WaitlistedAppUser.objects.select_for_update().get(referral_link=referral_code)
                        
                        if referrer.id != user.id:
                            referrer.referrals = F('referrals') + 1
                            
                            new_position_target = None
                            if referrer.position is not None:
                                new_position_target = referrer.position - 5
                            
                            referrer.save(update_fields=['referrals'])
                            referrer.refresh_from_db(fields=['referrals'])

                            if new_position_target is not None:
                                referrer.change_position(new_position_target)
                            
                            request.session.pop('referral_code', None)
                    
                    except WaitlistedAppUser.DoesNotExist:
                        pass # Invalid code, do nothing silently

        except Exception as e:
            logger.error(f"Error during waitlist signup for phone {processed_phone_number}: {e}")
            return Response({'error': 'An unexpected server error occurred.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response({'user_id': user.id}, status=status.HTTP_200_OK)

# --- User Management Views ---

class AppUserListView(generics.ListAPIView):
    """
    GET: List all users (admin only) or search by phone number
    """
    def get_serializer_class(self):
        if 'phone' in self.request.query_params:
            return AppUserSimpleSerializer
        return AppUserSerializer

    def get_permissions(self):
        if self.request.method == 'GET' and 'phone' in self.request.query_params:
            return [permissions.AllowAny()]
        return [IsAdminUser()]

    def get_queryset(self):
        queryset = AppUser.objects.all()
        phone_number_param = self.request.query_params.get('phone')

        if phone_number_param is not None:
            try:
                normalized_phone = clean_phone_number(phone_number_param)
                queryset = queryset.filter(phone=normalized_phone)
            except ValueError:
                logger.warning(f"Invalid phone number format received in AppUserListView: {phone_number_param}")
                return AppUser.objects.none()
            except Exception as e:
                logger.error(f"Error processing phone number '{phone_number_param}' in AppUserListView: {e}")
                return AppUser.objects.none()
        return queryset


class AppUserDetailView(generics.RetrieveUpdateAPIView):
    """
    GET: Retrieve a specific user's details
    PUT/PATCH: Update a user's details and return the full updated user object.
    """
    queryset = AppUser.objects.all()
    permission_classes = [IsOwnerOrAdmin]

    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return AppUserUpdateSerializer
        return AppUserSerializer

    def update(self, request, *args, **kwargs):
        """
        Custom update method to validate admin transfer permissions.
        Only admins of a friend group can update member admin status.
        """
        member = self.get_object()
        print(f"MemberDetailView.update: Updating member {member.id} ({member.user.first_name} {member.user.last_name}) in circle {member.friend_group.name}")
        print(f"MemberDetailView.update: Request data: {request.data}")
        print(f"MemberDetailView.update: Available keys in request.data: {list(request.data.keys())}")
        print(f"MemberDetailView.update: Requesting user: {request.user.first_name} {request.user.last_name} (phone: {request.user.phone})")
        
        # Check if the request is trying to update admin status
        if 'isAdmin' in request.data or 'is_admin' in request.data:
            admin_value = request.data.get('isAdmin', request.data.get('is_admin'))
            print(f"MemberDetailView.update: Admin status update requested - setting isAdmin to {admin_value}")
            
            # Find the requesting user's membership in this friend group
            requesting_user_membership = Member.objects.filter(
                friend_group=member.friend_group,
                user=request.user,
                isAdmin=True
            ).first()
            
            if not requesting_user_membership:
                print(f"MemberDetailView.update: Permission denied - requesting user is not an admin of this circle")
                return Response(
                    {
                        "error": "Permission denied",
                        "message": "Only admins of this friend group can update member admin status."
                    },
                    status=status.HTTP_403_FORBIDDEN
                )
            else:
                print(f"MemberDetailView.update: Permission granted - requesting user is admin (membership ID: {requesting_user_membership.id})")
        
        result = super().update(request, *args, **kwargs)
        print(f"MemberDetailView.update: Update completed with status {result.status_code}")
        
        # Log the updated member state
        member.refresh_from_db()
        print(f"MemberDetailView.update: After update - member {member.id} isAdmin = {member.isAdmin}")
        
        return result

    def destroy(self, request, *args, **kwargs):
        """
        Custom delete method to prevent admins from leaving friend groups.
        Admins cannot leave unless they transfer admin privileges to another member.
        """
        member = self.get_object()
        
        # Check if the member trying to leave is an admin
        if member.isAdmin:
            # Count total number of admins in this friend group
            admin_count = Member.objects.filter(
                friend_group=member.friend_group, 
                isAdmin=True
            ).count()
            
            # If this is the only admin, prevent deletion
            if admin_count <= 1:
                return Response(
                    {
                        "error": "Cannot leave group",
                        "message": "You are the only admin of this friend group. Please transfer admin privileges to another member before leaving."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Allow deletion if not an admin or if there are other admins
        return super().destroy(request, *args, **kwargs)


class AppUserSimpleListView(generics.ListAPIView):
    """
    GET: Retrieve a lightweight list of all users (id, name, phone)
    """
    queryset = AppUser.objects.all()
    serializer_class = AppUserSimpleSerializer
    permission_classes = [AllowAny]


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def complete_user_onboarding(request):
    """
    Complete the user onboarding process by saving user info and goals.
    
    POST: Save user information and goals, mark user as onboarded
    """
    user = request.user
    data = request.data

    first_name = data.get("firstName")
    last_name = data.get("lastName")
    height = data.get("height")
    birthday = data.get("birthday")
    weight = data.get("weight")
    sex = data.get("sex")

    if not all([first_name, last_name, height, birthday, weight, sex]):
        return Response({
            "error": "First name, last name, height, birthday, weight, and sex are required for onboarding."
        }, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        height = float(height)
        weight = float(weight)
    except ValueError:
        return Response({
            "error": "Height and weight must be valid numbers."
        }, status=status.HTTP_400_BAD_REQUEST)

    if sex not in [choice[0] for choice in AppUserInfo.SEX_CHOICES]:
         return Response({"error": f"Invalid sex value. Choose from {AppUserInfo.SEX_CHOICES}"}, status=status.HTTP_400_BAD_REQUEST)

    user.first_name = first_name
    user.last_name = last_name

    AppUserInfo.objects.update_or_create(
        user=user,
        defaults={
            "height": height,
            "birthday": birthday,
            "weight": weight,
            "sex": sex
        }
    )

    goals_data = data.get("goals", {})
    goals_data['user'] = user.pk
    
    goals_instance, _ = AppUserGoals.objects.get_or_create(user=user)
    goals_serializer = AppUserGoalsSerializer(instance=goals_instance, data=goals_data, partial=True)

    if goals_serializer.is_valid():
        goals_serializer.save(user=user)
    else:
        return Response({"error": "Invalid goals data.", "details": goals_serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    if not user.isOnboarded:
        user.isOnboarded = True
    user.save()
    
    updated_user_serializer = AppUserSerializer(user)
    return Response({
        "message": "User onboarding completed successfully.",
        "user": updated_user_serializer.data
    }, status=status.HTTP_200_OK)

# --- Activity Management Views ---

@method_decorator(csrf_exempt, name='dispatch')
class UserScheduledActivityListView(generics.ListCreateAPIView):
    """
    GET: List all scheduled activities for the current user
    POST: Create a new scheduled activity
    """
    serializer_class = UserScheduledActivitySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = UserScheduledActivity.objects.filter(user=user)
        
        scheduled_date = self.request.query_params.get('scheduled_date')
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')

        if scheduled_date:
            queryset = queryset.filter(scheduled_date=scheduled_date)
        elif start_date and end_date:
            queryset = queryset.filter(scheduled_date__range=[start_date, end_date])
        
        return queryset.order_by('scheduled_date', 'order_in_day')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


@method_decorator(csrf_exempt, name='dispatch')
class UserScheduledActivityDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific scheduled activity
    PUT/PATCH: Update a scheduled activity
    DELETE: Remove a scheduled activity
    """
    serializer_class = UserScheduledActivitySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return UserScheduledActivity.objects.filter(user=self.request.user)

    def get_object(self):
        """
        Overrides the default get_object to handle UUID lookups.
        Django automatically handles UUID case-insensitivity in database queries.
        """
        queryset = self.get_queryset()
        pk = self.kwargs.get('pk')

        obj = get_object_or_404(queryset, pk=pk)
        self.check_object_permissions(self.request, obj)
        return obj

    @transaction.atomic
    def perform_update(self, serializer):
        instance = serializer.instance
        was_incomplete = not instance.is_complete
        is_now_complete = serializer.validated_data.get('is_complete', instance.is_complete)

        updated_completed_at = instance.completed_at
        log_action_taken = False

        if is_now_complete and was_incomplete:
            updated_completed_at = timezone.now()
            UserCompletedLog.objects.get_or_create(
                user=instance.user,
                source_scheduled_activity=instance,
                defaults={
                    'activity': instance.activity,
                    'activity_name_at_completion': instance.activity.name,
                    'description_at_completion': instance.activity.description,
                    'completed_at': updated_completed_at,
                    'points_awarded': instance.activity.default_point_value,
                    'is_adhoc': False
                }
            )
            log_action_taken = True
        elif not is_now_complete and not was_incomplete:
            updated_completed_at = None
            log_action_taken = True

        if log_action_taken or any(field in serializer.validated_data for field in serializer.fields if field != 'is_complete'):
            serializer.save(completed_at=updated_completed_at)
        else:
            serializer.save()


@method_decorator(csrf_exempt, name='dispatch')
class UserCompletedLogListView(generics.ListCreateAPIView):
    """
    GET: List all completed activities for the current user
    POST: Create a new completed activity log
    """
    serializer_class = UserCompletedLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return UserCompletedLog.objects.filter(user=self.request.user).order_by('-completed_at')
    
    def perform_create(self, serializer):
        """Automatically set the user field to the authenticated user"""
        serializer.save(user=self.request.user)


@method_decorator(csrf_exempt, name='dispatch')
class UserCompletedLogDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific completed activity log
    PUT/PATCH: Update a completed activity log
    DELETE: Remove a completed activity log
    """
    serializer_class = UserCompletedLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return UserCompletedLog.objects.filter(user=self.request.user)

    def get_object(self):
        """
        Overrides the default get_object to handle UUID lookups.
        Django automatically handles UUID case-insensitivity in database queries.
        """
        queryset = self.get_queryset()
        pk = self.kwargs.get('pk')

        obj = get_object_or_404(queryset, pk=pk)
        self.check_object_permissions(self.request, obj)
        return obj

    def perform_update(self, serializer):
        restricted_fields = ['user', 'activity', 'activity_name_at_completion', 'completed_at',
                               'points_awarded', 'source_scheduled_activity', 'is_adhoc']
        errors = {}
        for field_name in serializer.validated_data.keys():
            if field_name in restricted_fields:
                current_value = getattr(serializer.instance, field_name, None)
                new_value = serializer.validated_data[field_name]
                
                if isinstance(current_value, models.Model) and isinstance(new_value, models.Model):
                    if current_value.pk != new_value.pk:
                        errors[field_name] = f"Field '{field_name}' cannot be modified after creation."
                elif current_value != new_value:
                    if field_name in serializer.initial_data and serializer.initial_data[field_name] != current_value:
                         errors[field_name] = f"Field '{field_name}' cannot be modified after creation."
                    elif field_name not in ['user_notes_on_completion', 'description_at_completion']:
                         errors[field_name] = f"Field '{field_name}' cannot be modified after creation."

        if errors:
            raise serializers.ValidationError(errors)
        
        super().perform_update(serializer)

# --- Affiliate Management Views ---

class AffiliateListView(generics.ListCreateAPIView):
    """
    GET: List all affiliates
    POST: Create a new affiliate (admin only)
    """
    queryset = Affiliate.objects.all()
    serializer_class = AffiliateSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class AffiliateDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific affiliate
    PUT/PATCH: Update an affiliate (admin only)
    DELETE: Remove an affiliate (admin only)
    """
    queryset = Affiliate.objects.all()
    serializer_class = AffiliateSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class AffiliatePromotionListView(generics.ListCreateAPIView):
    """
    GET: List all affiliate promotions
    POST: Create a new affiliate promotion (admin only)
    """
    queryset = AffiliatePromotion.objects.all()
    serializer_class = AffiliatePromotionSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class AffiliatePromotionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific affiliate promotion
    PUT/PATCH: Update an affiliate promotion (admin only)
    DELETE: Remove an affiliate promotion (admin only)
    """
    queryset = AffiliatePromotion.objects.all()
    serializer_class = AffiliatePromotionSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class AffiliatePromotionRedemptionListView(generics.ListCreateAPIView):
    """
    GET: List all promotion redemptions (admin only)
    POST: Create a new promotion redemption (admin only)
    """
    queryset = AffiliatePromotionRedemption.objects.all()
    serializer_class = AffiliatePromotionRedemptionSerializer
    permission_classes = [IsAdminUser]


class AffiliatePromotionRedemptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific promotion redemption (admin only)
    PUT/PATCH: Update a promotion redemption (admin only)
    DELETE: Remove a promotion redemption (admin only)
    """
    queryset = AffiliatePromotionRedemption.objects.all()
    serializer_class = AffiliatePromotionRedemptionSerializer
    permission_classes = [IsAdminUser]


class UserProductListView(generics.ListAPIView):
    """
    GET: List user's products/services from redeemed promotions
    Supports filtering by status, category, and recent redemptions
    """
    serializer_class = UserProductSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        queryset = UserProduct.objects.filter(user=user)
        
        # Filter by status
        status = self.request.query_params.get('status', None)
        if status:
            queryset = queryset.filter(status=status)
        
        # Filter by category
        category = self.request.query_params.get('category', None)
        if category:
            queryset = queryset.filter(category=category)
        
        # Filter recent products (default to last 30 days if 'recent' param is provided)
        recent = self.request.query_params.get('recent', None)
        if recent:
            try:
                days = int(recent) if recent.isdigit() else 30
                queryset = queryset.recent(days=days)
            except ValueError:
                queryset = queryset.recent(days=30)
        
        # Filter active products only
        active_only = self.request.query_params.get('active_only', None)
        if active_only and active_only.lower() in ['true', '1']:
            queryset = queryset.active()
        
        # Filter favorites only
        favorites_only = self.request.query_params.get('favorites_only', None)
        if favorites_only and favorites_only.lower() in ['true', '1']:
            queryset = queryset.filter(is_favorite=True)
        
        return queryset.order_by('-redeemed_at')


class UserProductDetailView(generics.RetrieveUpdateAPIView):
    """
    GET: Retrieve a specific user product
    PUT/PATCH: Update user-modifiable fields (notes, favorite status, etc.)
    """
    serializer_class = UserProductSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return UserProduct.objects.filter(user=self.request.user)
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return UserProductUpdateSerializer
        return UserProductSerializer
    
    def patch(self, request, *args, **kwargs):
        """Handle partial updates with custom logic"""
        instance = self.get_object()
        
        # Mark as used when user interacts with product details
        instance.mark_as_used()
        
        return super().patch(request, *args, **kwargs)


class UserProductStatsView(APIView):
    """
    GET: Get statistics about user's products
    Returns counts by category, status, and recent activity
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        products = UserProduct.objects.filter(user=user)
        
        # Overall stats
        total_products = products.count()
        active_products = products.active().count()
        favorites_count = products.filter(is_favorite=True).count()
        
        # Category breakdown
        category_stats = {}
        for category, _ in UserProduct.CATEGORY_CHOICES:
            category_stats[category] = products.filter(category=category).count()
        
        # Status breakdown
        status_stats = {}
        for status, _ in UserProduct.STATUS_CHOICES:
            status_stats[status] = products.filter(status=status).count()
        
        # Recent activity (last 30 days)
        recent_products = products.recent(days=30).count()
        
        # Total value saved
        total_savings = products.aggregate(
            total_saved=models.Sum('original_value')
        )['total_saved'] or 0
        
        total_points_spent = products.aggregate(
            total_points=models.Sum('points_spent')
        )['total_points'] or 0
        
        return Response({
            'total_products': total_products,
            'active_products': active_products,
            'favorites_count': favorites_count,
            'recent_products': recent_products,
            'total_savings': float(total_savings),
            'total_points_spent': total_points_spent,
            'category_breakdown': category_stats,
            'status_breakdown': status_stats
        })


class RedeemPromotionView(APIView):
    """
    POST: Redeem an affiliate promotion for the authenticated user
    Handles validation, points deduction, and creates redemption record
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        try:
            promotion_id = request.data.get('promotion_id')
            if not promotion_id:
                return Response(
                    {'error': 'promotion_id is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            user = request.user
            
            # Get the promotion
            try:
                promotion = AffiliatePromotion.objects.get(id=promotion_id)
            except AffiliatePromotion.DoesNotExist:
                return Response(
                    {'error': 'Promotion not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Validation checks
            validation_error = self._validate_redemption(user, promotion)
            if validation_error:
                return Response(validation_error, status=status.HTTP_400_BAD_REQUEST)
            
            # Use database transaction to ensure atomicity
            with transaction.atomic():
                # Check if user already redeemed this promotion
                existing_redemption = AffiliatePromotionRedemption.objects.filter(
                    user=user, promotion=promotion
                ).first()
                
                if existing_redemption:
                    return Response(
                        {'error': 'You have already redeemed this promotion'}, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # Deduct points from user
                points_cost = promotion.point_value or 0
                if user.available_points < points_cost:
                    return Response(
                        {
                            'error': f'Insufficient points. You need {points_cost} points but have {user.available_points}'
                        }, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                user.available_points -= points_cost
                user.save(update_fields=['available_points'])
                
                # Create redemption record (this will trigger UserProduct creation via signal)
                redemption = AffiliatePromotionRedemption.objects.create(
                    user=user,
                    promotion=promotion
                )
                
                # Log the redemption
                logger.info(f"User {user.phone} redeemed promotion '{promotion.title}' for {points_cost} points")
                
                # Serialize the redemption for response
                serializer = AffiliatePromotionRedemptionSerializer(redemption)
                
                return Response({
                    'message': 'Promotion redeemed successfully',
                    'redemption': serializer.data,
                    'points_spent': points_cost,
                    'remaining_points': user.available_points,
                    'discount_code': self._get_discount_code(promotion, redemption)
                }, status=status.HTTP_201_CREATED)
                
        except Exception as e:
            logger.error(f"Error redeeming promotion {promotion_id} for user {request.user.phone}: {str(e)}")
            return Response(
                {'error': 'An error occurred while processing your redemption'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def _validate_redemption(self, user, promotion):
        """Validate if the redemption is allowed"""
        
        # Check if promotion is currently active
        if not promotion.is_currently_active:
            return {'error': 'This promotion is no longer active'}
        
        # Check if user is assigned to this promotion (if it uses user assignment)
        if promotion.assigned_users.exists() and user not in promotion.assigned_users.all():
            return {'error': 'You are not eligible for this promotion'}
        
        # Check if promotion has expiry date and is not expired
        if promotion.end_date and timezone.now() > promotion.end_date:
            return {'error': 'This promotion has expired'}
        
        return None
    
    def _get_discount_code(self, promotion, redemption):
        """Generate or retrieve discount code for the promotion"""
        # This is a placeholder - you might want to implement actual discount code generation
        # or retrieval based on your affiliate relationships
        return {
            'code': f"{promotion.affiliate.name.upper()}{redemption.id.hex[:8].upper()}",
            'instructions': 'Use this code at checkout with the affiliate partner',
            'affiliate_website': promotion.affiliate.website,
            'valid_until': promotion.end_date.isoformat() if promotion.end_date else None
        }


class UserRedemptionHistoryView(generics.ListAPIView):
    """
    GET: List the authenticated user's redemption history
    Shows all promotions the user has redeemed
    """
    serializer_class = AffiliatePromotionRedemptionSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        return AffiliatePromotionRedemption.objects.filter(user=user).select_related(
            'promotion', 'promotion__affiliate'
        ).order_by('-redeemed_at')

# --- Friend Group Views ---

class FriendGroupListView(generics.ListCreateAPIView):
    """
    GET: List all friend groups
    POST: Create a new friend group
    """
    queryset = FriendGroup.objects.all()
    serializer_class = FriendGroupSerializer
    permission_classes = [IsAuthenticated]


class FriendGroupDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific friend group
    PUT/PATCH: Update a friend group (admin only)
    DELETE: Remove a friend group (admin only)
    """
    queryset = FriendGroup.objects.all()
    serializer_class = FriendGroupSerializer
    permission_classes = [IsAuthenticated, IsFriendGroupAdmin]


class MemberListView(generics.ListCreateAPIView):
    """
    GET: List all members
    POST: Create a new member
    """
    queryset = Member.objects.all()
    serializer_class = MemberSerializer
    permission_classes = [IsAuthenticated]


class MemberDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific member
    PUT/PATCH: Update a member
    DELETE: Remove a member
    """
    queryset = Member.objects.all()
    serializer_class = MemberSerializer
    permission_classes = [IsAuthenticated]

    def update(self, request, *args, **kwargs):
        """
        Custom update method to validate admin transfer permissions.
        Only admins of a friend group can update member admin status.
        """
        member = self.get_object()
        print(f"MemberDetailView.update: Updating member {member.id} ({member.user.first_name} {member.user.last_name}) in circle {member.friend_group.name}")
        print(f"MemberDetailView.update: Request data: {request.data}")
        print(f"MemberDetailView.update: Available keys in request.data: {list(request.data.keys())}")
        print(f"MemberDetailView.update: Requesting user: {request.user.first_name} {request.user.last_name} (phone: {request.user.phone})")
        
        # Check if the request is trying to update admin status
        if 'isAdmin' in request.data or 'is_admin' in request.data:
            admin_value = request.data.get('isAdmin', request.data.get('is_admin'))
            print(f"MemberDetailView.update: Admin status update requested - setting isAdmin to {admin_value}")
            
            # Find the requesting user's membership in this friend group
            requesting_user_membership = Member.objects.filter(
                friend_group=member.friend_group,
                user=request.user,
                isAdmin=True
            ).first()
            
            if not requesting_user_membership:
                print(f"MemberDetailView.update: Permission denied - requesting user is not an admin of this circle")
                return Response(
                    {
                        "error": "Permission denied",
                        "message": "Only admins of this friend group can update member admin status."
                    },
                    status=status.HTTP_403_FORBIDDEN
                )
            else:
                print(f"MemberDetailView.update: Permission granted - requesting user is admin (membership ID: {requesting_user_membership.id})")
        
        result = super().update(request, *args, **kwargs)
        print(f"MemberDetailView.update: Update completed with status {result.status_code}")
        
        # Log the updated member state
        member.refresh_from_db()
        print(f"MemberDetailView.update: After update - member {member.id} isAdmin = {member.isAdmin}")
        
        return result

    def destroy(self, request, *args, **kwargs):
        """
        Custom delete method to prevent admins from leaving friend groups.
        Admins cannot leave unless they transfer admin privileges to another member.
        """
        member = self.get_object()
        
        # Check if the member trying to leave is an admin
        if member.isAdmin:
            # Count total number of admins in this friend group
            admin_count = Member.objects.filter(
                friend_group=member.friend_group, 
                isAdmin=True
            ).count()
            
            # If this is the only admin, prevent deletion
            if admin_count <= 1:
                return Response(
                    {
                        "error": "Cannot leave group",
                        "message": "You are the only admin of this friend group. Please transfer admin privileges to another member before leaving."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Allow deletion if not an admin or if there are other admins
        return super().destroy(request, *args, **kwargs)


class RemoveMemberView(APIView):
    """
    POST: Remove a member from a friend group (admin only)
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request, group_id, member_id):
        try:
            # Get the friend group
            friend_group = FriendGroup.objects.get(id=group_id)
            
            # Check if requesting user is an admin of the group
            requesting_user_membership = Member.objects.filter(
                friend_group=friend_group,
                user=request.user,
                isAdmin=True
            ).first()
            
            if not requesting_user_membership:
                return Response(
                    {"error": "Only admins can remove members"},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Get the member to remove
            member_to_remove = Member.objects.get(
                id=member_id,
                friend_group=friend_group
            )
            
            # Prevent removing yourself
            if member_to_remove.user == request.user:
                return Response(
                    {"error": "You cannot remove yourself from the group"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Prevent removing the last admin
            if member_to_remove.isAdmin:
                admin_count = Member.objects.filter(
                    friend_group=friend_group,
                    isAdmin=True
                ).count()
                
                if admin_count <= 1:
                    return Response(
                        {"error": "Cannot remove the last admin from the group"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Create a MEMBER_LEFT event before deletion
            FriendGroupEvent.objects.create(
                friend_group=friend_group,
                user=member_to_remove.user,
                event_type='MEMBER_LEFT'
            )
            
            # Store member info for response
            member_name = f"{member_to_remove.user.first_name} {member_to_remove.user.last_name}"
            
            # Remove the member
            member_to_remove.delete()
            
            return Response(
                {"message": f"{member_name} has been removed from the group"},
                status=status.HTTP_200_OK
            )
            
        except FriendCircle.DoesNotExist:
            return Response(
                {"error": "Friend circle not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Member.DoesNotExist:
            return Response(
                {"error": "Member not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {"error": f"An error occurred: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class FriendGroupEventListView(generics.ListAPIView):
    """
    GET: Retrieve the event log for a specific friend group
    """
    serializer_class = FriendGroupEventSerializer
    permission_classes = [IsAuthenticated, IsMemberOfFriendGroup]

    def get_queryset(self):
        group_id = self.kwargs.get('group_id')
        return FriendGroupEvent.objects.filter(
            friend_group_id=group_id
        ).select_related('user', 'completed_activity_log')


class CreateFriendGroupWithInvitationsView(APIView):
    """
    POST: Create a new friend group with initial invitations
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """
        Expected payload:
        {
            "name": "Circle Name",
            "cover_image": "friendcircleimage0",
            "invitee_phones": ["+11234567890", "+10987654321"]
        }
        """
        user = request.user
        name = request.data.get('name')
        cover_image = request.data.get('cover_image', '')
        invitee_phones = request.data.get('invitee_phones', [])
        
        if not name:
            return Response(
                {"error": "Friend circle name is required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create the friend group
        friend_group = FriendGroup.objects.create(
            name=name,
            cover_image=cover_image
        )
        
        # Add the creator as an admin member
        Member.objects.create(
            friend_group=friend_group,
            user=user,
            isAdmin=True
        )
        
        # Create invitations for provided phone numbers
        invitations_created = []
        errors = []
        
        for phone in invitee_phones:
            try:
                # Check if user exists with this phone
                invitee_user = None
                try:
                    invitee_user = AppUser.objects.get(phone=phone)
                except AppUser.DoesNotExist:
                    pass
                
                # Create invitation
                invitation = FriendGroupInvitation.objects.create(
                    friend_group=friend_group,
                    inviter=user,
                    invitee_phone=phone,
                    invitee_user=invitee_user
                )
                invitations_created.append(invitation)
                
            except IntegrityError:
                # Duplicate invitation
                errors.append(f"User with phone {phone} is already invited")
            except Exception as e:
                errors.append(f"Error inviting {phone}: {str(e)}")
        
        # Serialize the response
        group_serializer = FriendGroupSerializer(friend_group)
        invitation_serializer = FriendGroupInvitationSerializer(
            invitations_created, many=True
        )
        
        response_data = {
            "friend_group": group_serializer.data,
            "invitations": invitation_serializer.data,
            "errors": errors if errors else None
        }
        
        return Response(response_data, status=status.HTTP_201_CREATED)


class FriendGroupInvitationListView(generics.ListCreateAPIView):
    """
    GET: List invitations (received for users, sent for admins)
    POST: Create new invitations (admin only)
    """
    serializer_class = FriendGroupInvitationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        # Get pending invitations for the current user
        return FriendGroupInvitation.objects.filter(
            invitee_user=user,
            status='PENDING'
        ).select_related('friend_group', 'inviter', 'invitee_user')
        
    def perform_create(self, serializer):
        # Validate that user is admin of the friend group
        friend_group = serializer.validated_data.get('friend_group')
        if not Member.objects.filter(
            friend_group=friend_group,
            user=self.request.user,
            isAdmin=True
        ).exists():
            raise PermissionDenied("Only admins can send invitations")
        
        serializer.save()


class FriendGroupInvitationDetailView(generics.RetrieveUpdateAPIView):
    """
    GET: Retrieve a specific invitation
    PATCH: Update invitation status (accept/decline)
    """
    serializer_class = FriendGroupInvitationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        # Users can only see their own invitations
        return FriendGroupInvitation.objects.filter(
            invitee_user=self.request.user
        )
    
    def patch(self, request, *args, **kwargs):
        invitation = self.get_object()
        action = request.data.get('action')
        
        if action not in ['accept', 'decline']:
            return Response(
                {"error": "Action must be 'accept' or 'decline'"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if action == 'accept':
                invitation.accept()
            else:
                invitation.decline()
                
            serializer = self.get_serializer(invitation)
            return Response(serializer.data)
            
        except ValueError as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {"error": "An error occurred processing the invitation"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

# --- Shortcut Management Views ---

class ShortcutViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Provides a list of available shortcuts that users can add to their dashboard.
    """
    queryset = Shortcut.objects.filter(is_active=True)
    serializer_class = ShortcutSerializer
    permission_classes = [IsAuthenticated]


class UserShortcutViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing a user's selected shortcuts.
    Provides list, create, destroy, and a custom reorder action.
    Update is handled by the reorder action, so standard update is disabled.
    """
    serializer_class = UserShortcutSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'post', 'delete', 'put', 'head', 'options']

    def get_queryset(self):
        """
        This view returns a list of all the shortcuts for the currently authenticated user.
        """
        return UserShortcut.objects.filter(user=self.request.user).order_by('order')

    def get_object(self):
        """
        Overrides the default get_object to handle UUID lookups.
        Django automatically handles UUID case-insensitivity in database queries.
        """
        queryset = self.get_queryset()
        pk = self.kwargs.get('pk')

        obj = get_object_or_404(queryset, pk=pk)
        self.check_object_permissions(self.request, obj)
        return obj

    def perform_create(self, serializer):
        """
        Assign the currently authenticated user to the new shortcut selection.
        """
        # Prevent adding duplicates
        shortcut_id = self.request.data.get('shortcut_id')
        if self.get_queryset().filter(shortcut_id=shortcut_id).exists():
            raise serializers.ValidationError({"shortcut_id": "This shortcut has already been added."})
        
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['put'])
    def reorder(self, request, *args, **kwargs):
        """
        Receives a list of the user's shortcut selection IDs in the desired order.
        Example payload: { "ordered_ids": ["uuid1", "uuid2", "uuid3"] }
        """
        ordered_ids = request.data.get("ordered_ids")
        if not isinstance(ordered_ids, list):
            return Response({"error": "ordered_ids must be a list of IDs."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            user_shortcuts = {str(sc.id): sc for sc in self.get_queryset()}
            
            if len(ordered_ids) != len(user_shortcuts):
                 return Response({"error": "The number of provided IDs does not match the number of user shortcuts."}, status=status.HTTP_400_BAD_REQUEST)

            # Create a mapping from ID to shortcut instance for quick lookups
            shortcut_map = {str(sc.id): sc for sc in user_shortcuts}

            # Normalize incoming IDs to lowercase to match database representation
            ordered_ids_lower = [sid.lower() for sid in ordered_ids]

            # Check if all provided IDs are valid and belong to the user
            for shortcut_id in ordered_ids_lower:
                if shortcut_id not in shortcut_map:
                    return Response(
                        {'error': f'Shortcut with id {shortcut_id} not found or does not belong to user.'},
                        status=status.HTTP_404_NOT_FOUND
                    )
            
            # Update the order for each shortcut
            for index, shortcut_id in enumerate(ordered_ids_lower):
                shortcut_to_update = shortcut_map[shortcut_id]
                shortcut_to_update.order = index
                shortcut_to_update.save(update_fields=['order'])
        
        return Response(self.get_serializer(self.get_queryset(), many=True).data)

# --- Routine Management Views ---

class RoutineViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing user-defined routines and their steps.
    """
    serializer_class = RoutineSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        This view returns a list of all routines for the currently authenticated user.
        """
        return Routine.objects.filter(user=self.request.user).prefetch_related('steps').order_by('created_at')

    def perform_create(self, serializer):
        """
        Assign the currently authenticated user to the new routine.
        """
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['put'], serializer_class=RoutineStepSerializer, url_path='steps')
    def manage_steps(self, request, pk=None):
        """
        Update the steps for a specific routine. 
        Expects a list of step objects in the request data.
        """
        routine = self.get_object()
        steps_data = request.data
        if not isinstance(steps_data, list):
            return Response({"error": "Request data must be a list of steps."}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            # Clear existing steps
            routine.steps.all().delete()
            
            # Create new steps
            for step_data in steps_data:
                step_serializer = RoutineStepSerializer(data=step_data)
                if step_serializer.is_valid(raise_exception=True):
                    RoutineStep.objects.create(routine=routine, **step_serializer.validated_data)

        # Return the updated routine with its new steps
        return Response(self.get_serializer(routine).data)


# --- Content Management Views ---

class ContentCardViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing content cards
    """
    queryset = ContentCard.objects.all()
    serializer_class = ContentCardSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]


class ReadingContentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing reading content
    """
    queryset = ReadingContent.objects.all()
    serializer_class = ReadingContentSerializer
    permission_classes = [IsAdminUser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [IsAdminUser()]

# --- Emotion Tracking Views ---

class AppUserCurrentEmotionListView(generics.ListCreateAPIView):
    """
    GET: List all current emotions for the current user
    POST: Create a new current emotion
    """
    serializer_class = AppUserCurrentEmotionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = AppUserCurrentEmotion.objects.filter(user=user)
        return queryset.order_by('-tracked_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class AppUserCurrentEmotionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific current emotion
    PUT/PATCH: Update a current emotion
    DELETE: Remove a current emotion
    """
    serializer_class = AppUserCurrentEmotionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return AppUserCurrentEmotion.objects.filter(user=user)


class AppUserDailyEmotionListView(generics.ListCreateAPIView):
    """
    GET: List all daily emotions for the current user
    POST: Create a new daily emotion
    """
    serializer_class = AppUserDailyEmotionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = AppUserDailyEmotion.objects.filter(user=user)
        return queryset.order_by('-tracked_at')

    def perform_create(self, serializer):
        today = timezone.now().date()
        if AppUserDailyEmotion.objects.filter(user=self.request.user, date=today).exists():
            raise serializers.ValidationError("You have already logged your daily emotion for today.")
        serializer.save(user=self.request.user)


class AppUserDailyEmotionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific daily emotion
    PUT/PATCH: Update a daily emotion
    DELETE: Remove a daily emotion
    """
    serializer_class = AppUserDailyEmotionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return AppUserDailyEmotion.objects.filter(user=user)

# --- Nutrition Views ---

class FoodProductSearchView(generics.ListAPIView):
    """
    GET: Search for food products by name, combining public and user-created foods.
    Now uses PostgreSQL full-text search, Redis caching, and optimized rate limiting.
    
    NEW: Also checks if products should be mapped to alcohol/caffeine databases.
    """
    permission_classes = [IsAuthenticated]

    def list(self, request, *args, **kwargs):
        from django.core.cache import caches
        from django.db import models
        from nutrition.serializers import FoodProductSearchSerializer
        from nutrition.services import ProductMappingService
        import hashlib
        
        query = request.query_params.get('query', None)
        if not query:
            # Return popular foods when no query (empty-query suggestions)
            cache_key = f"popular_foods:{request.user.id}"
            search_cache = caches['search_cache']
            cached_popular = search_cache.get(cache_key)
            
            if cached_popular is None:
                popular_foods = FoodProduct.objects.filter(
                    Q(obsolete__isnull=True) | Q(obsolete=False),
                    popularity_key__gt=0
                ).order_by('-popularity_key')[:15]
                
                # Check each popular food for mappings
                enhanced_results = []
                for food in popular_foods:
                    food_data = FoodProductSearchSerializer(food).data
                    product_type, specialized_data = ProductMappingService.get_specialized_product_data(food)
                    
                    if specialized_data:
                        food_data['mapping'] = {
                            'type': product_type,
                            'specialized_product': specialized_data
                        }
                    
                    enhanced_results.append(food_data)
                
                search_cache.set(cache_key, enhanced_results, 3600)  # Cache for 1 hour
                cached_popular = enhanced_results
            
            return Response(cached_popular, status=status.HTTP_200_OK)

        # Clean the query and enforce minimum length
        clean_query = query.strip()
        if len(clean_query) < 2:  # Reduced from 3 to 2 for better UX
            return Response([], status=status.HTTP_200_OK)

        # Create cache key using query hash for consistent key length
        query_hash = hashlib.md5(clean_query.lower().encode()).hexdigest()
        cache_key = f"search:{request.user.id}:{query_hash}"
        
        # Try to get results from Redis cache first
        search_cache = caches['search_cache']
        cached_results = search_cache.get(cache_key)
        if cached_results is not None:
            return Response(cached_results, status=status.HTTP_200_OK)

        # Optimized rate limiting - use sliding window instead of simple counter
        rate_limit_key = f"rate_limit:search:{request.user.id}"
        default_cache = caches['default']
        
        # Get current timestamp and clean old entries
        import time
        current_time = int(time.time())
        search_timestamps = default_cache.get(rate_limit_key, [])
        
        # Remove timestamps older than 60 seconds
        search_timestamps = [ts for ts in search_timestamps if current_time - ts < 60]
        
        # Check rate limit (15 searches per minute - increased from 10)
        if len(search_timestamps) >= 15:
            return Response({
                "error": "Search rate limit exceeded. Please wait a moment.",
                "rate_limited": True,
                "retry_after": 60 - (current_time - min(search_timestamps))
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)
        
        # Add current timestamp and update cache
        search_timestamps.append(current_time)
        default_cache.set(rate_limit_key, search_timestamps, 60)

        # Use speed-optimized search methods from FoodProduct model
        from django.conf import settings
        if getattr(settings, 'FEATURES', {}).get('USE_OPTIMIZED_SEARCH', True):
            public_foods = FoodProduct.search_foods_simple_fast(clean_query, limit=18)
        else:
            # Fallback to original search if needed
            public_foods = FoodProduct.search_foods(clean_query, limit=18)
        public_data = FoodProductSearchSerializer(public_foods, many=True).data

        # Search user's custom foods with trigram similarity
        custom_foods = CustomFood.objects.filter(
            user=request.user
        ).extra(
            select={'similarity': "similarity(name, %s)"},
            select_params=[clean_query],
            where=["name %% %s OR barcode_id ILIKE %s"],
            params=[clean_query, f'%{clean_query}%'],
            order_by=['-similarity', 'name']
        )[:7]
        
        custom_data = CustomFoodSerializer(custom_foods, many=True).data

        # Check public foods for mappings and combine results
        enhanced_public_data = []
        for food_data in public_data:
            # Get the actual FoodProduct for mapping
            food_id = food_data.get('id')
            if food_id:
                try:
                    food_product = FoodProduct.objects.get(_id=food_id)
                    product_type, specialized_data = ProductMappingService.get_specialized_product_data(food_product)
                    
                    if specialized_data:
                        food_data['mapping'] = {
                            'type': product_type,
                            'specialized_product': specialized_data
                        }
                except FoodProduct.DoesNotExist:
                    pass  # Skip mapping if product not found
            
            enhanced_public_data.append(food_data)
        
        combined_results = list(enhanced_public_data)
        for custom_food in custom_data:
            adapted_food = {
                "_id": f"custom_{custom_food['id']}",
                "id": f"custom_{custom_food['id']}",
                "product_name": custom_food['name'],
                "brands": "Custom",
                "nutriscore_grade": None,
                "calories": custom_food['calories'],
                "protein": custom_food['protein'],
                "carbs": custom_food['carbs'],
                "fat": custom_food['fat'],
                "is_custom": True,
                "custom_food_id": custom_food['id'],
            }
            combined_results.append(adapted_food)
        
        # Sort combined results by relevance (exact matches first)
        def sort_key(item):
            name = item.get('product_name', '').lower()
            if name == clean_query.lower():
                return (0, name)  # Exact matches first
            elif name.startswith(clean_query.lower()):
                return (1, name)  # Prefix matches second
            elif clean_query.lower() in name:
                return (2, name)  # Contains matches third
            else:
                return (3, name)  # Others last

        combined_results.sort(key=sort_key)
        
        # Limit total results for optimal performance
        combined_results = combined_results[:25]

        # Cache results for 20 minutes (increased from 15)
        search_cache.set(cache_key, combined_results, 1200)
        
        return Response(combined_results, status=status.HTTP_200_OK)


class FoodAutocompleteView(generics.ListAPIView):
    """
    GET: Ultra-fast autocomplete for food search suggestions.
    Returns minimal data for instant typing feedback with aggressive caching.
    """
    permission_classes = [IsAuthenticated]

    def list(self, request, *args, **kwargs):
        from django.core.cache import caches
        import hashlib
        
        query = request.query_params.get('query', None)
        if not query or len(query.strip()) < 2:
            return Response([], status=status.HTTP_200_OK)

        clean_query = query.strip()
        
        # Create cache key for autocomplete
        query_hash = hashlib.md5(clean_query.lower().encode()).hexdigest()
        cache_key = f"autocomplete:{query_hash}"
        
        # Try cache first (20 minute cache for autocomplete)
        search_cache = caches['search_cache']
        cached_results = search_cache.get(cache_key)
        if cached_results is not None:
            return Response(cached_results, status=status.HTTP_200_OK)

        # Use ultra-fast autocomplete search
        suggestions = FoodProduct.autocomplete_search(clean_query, limit=6)  # Reduced from 8 to 6
        
        # Return minimal data for speed
        results = []
        for food in suggestions:
            results.append({
                'id': food._id,
                'name': food.product_name or 'Unknown',
                'brand': food.brands or '',
            })
        
        # Cache for 20 minutes
        search_cache.set(cache_key, results, 1200)
        
        return Response(results, status=status.HTTP_200_OK)


class DailyCalorieTrackerListView(generics.ListCreateAPIView):
    """
    GET: List all daily calorie trackers
    POST: Create a new daily calorie tracker
    """
    serializer_class = DailyCalorieTrackerSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = DailyCalorieTracker.objects.all()
        user_id = self.request.query_params.get('user')
        date = self.request.query_params.get('date')
        
        if user_id:
            try:
                # Attempt to validate user_id as a UUID
                uuid.UUID(user_id, version=4)
                queryset = queryset.filter(user__id=user_id)
            except (ValueError, TypeError):
                # Log the issue and return an empty queryset if ID is not a valid UUID
                logger.warning(f"Invalid UUID format for user filter: {user_id}")
                return queryset.none()
        if date:
            queryset = queryset.filter(date=date)
            
        return queryset

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class DailyCalorieTrackerDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific daily calorie tracker
    PUT/PATCH: Update a daily calorie tracker
    DELETE: Remove a daily calorie tracker
    """
    serializer_class = DailyCalorieTrackerSerializer
    permission_classes = [IsOwnerOrAdmin]

    def get_queryset(self):
        if self.request.user.is_staff:
            return DailyCalorieTracker.objects.all()
        return DailyCalorieTracker.objects.filter(user=self.request.user)


class FoodEntryListView(generics.ListCreateAPIView):
    """
    GET: List all food entries for the current user.
    POST: Create a new food entry. It intelligently handles both standard
          FoodProduct IDs and custom food IDs (e.g., 'custom_123').
    """
    serializer_class = FoodEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user_logs = DailyCalorieTracker.objects.filter(user=self.request.user)
        
        # Check if date filter is provided
        date_param = self.request.query_params.get('date')
        print(f"DEBUG: Date parameter received: {date_param}")
        print(f"DEBUG: User logs count before filtering: {user_logs.count()}")
        
        if date_param:
            try:
                # Parse the date parameter (expected format: YYYY-MM-DD)
                from datetime import datetime
                target_date = datetime.strptime(date_param, '%Y-%m-%d').date()
                print(f"DEBUG: Parsed target date: {target_date}")
                
                # Filter by date - use __date lookup to compare date fields
                user_logs = user_logs.filter(date=target_date)
                print(f"DEBUG: User logs count after filtering: {user_logs.count()}")
                
            except ValueError as e:
                print(f"DEBUG: Date parsing error: {e}")
                # If date parsing fails, return empty queryset
                return FoodEntry.objects.none()
        
        food_entries = FoodEntry.objects.filter(daily_log__in=user_logs)
        print(f"DEBUG: Food entries found: {food_entries.count()}")
        return food_entries

    def create(self, request, *args, **kwargs):
        mutable_data = request.data.copy()
        food_id = mutable_data.get('food_product_id')

        # Check if the provided ID is for a custom food.
        if food_id and isinstance(food_id, str) and food_id.startswith('custom_'):
            # It's a custom food. Re-map the ID to the correct field.
            try:
                custom_food_pk = food_id.split('_')[1]
                mutable_data.pop('food_product_id', None)
                mutable_data['custom_food_id'] = custom_food_pk
            except (IndexError, ValueError):
                return Response(
                    {"error": "Invalid custom food ID format. Expected 'custom_<id>'."},
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Check if the provided ID is from a diary entry (entry_123 or manual_123 format)
        elif food_id and isinstance(food_id, str) and (food_id.startswith('entry_') or food_id.startswith('manual_')):
            # These are fake IDs created by the frontend for re-adding foods from diary
            # We need to allow creating the food entry but without linking to a specific food product
            # The nutritional data should come from the frontend calculation
            mutable_data.pop('food_product_id', None)
            # Don't set custom_food_id either - this will be a manual entry
        
        # Proceed with standard creation using the (potentially modified) data.
        serializer = self.get_serializer(data=mutable_data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        # The user is derived from the authenticated request, not from payload.
        serializer.save()


class FoodEntryDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific food entry
    PUT/PATCH: Update a food entry
    DELETE: Remove a food entry
    """
    serializer_class = FoodEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user_logs = DailyCalorieTracker.objects.filter(user=self.request.user)
        return FoodEntry.objects.filter(daily_log__in=user_logs)


class FoodProductListView(generics.ListCreateAPIView):
    """
    GET: List all food products
    POST: Create a new food product
    """
    queryset = FoodProduct.objects.all()
    serializer_class = FoodProductSerializer
    permission_classes = [AllowAny]


class FoodProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific food product
    PUT/PATCH: Update a food product
    DELETE: Remove a food product
    """
    queryset = FoodProduct.objects.all()
    serializer_class = FoodProductSerializer
    permission_classes = [AllowAny]


class FoodProductByBarcodeView(APIView):
    """
    GET: Retrieve a food product by its barcode (_id).
    This view checks for standard food products first, then for user-created custom foods
    with a matching barcode. It returns data in a format consistent with the FoodProductSearchView.
    
    NEW: Now also checks if the product should be mapped to alcohol/caffeine databases.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        from nutrition.services import ProductMappingService
        
        barcode = kwargs.get('_id')
        if not barcode:
            return Response({"error": "Barcode not provided."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Try to find a standard FoodProduct
        food_product = FoodProduct.objects.filter(_id=barcode).first()
        if food_product:
            # Check if this should be mapped to alcohol/caffeine
            product_type, specialized_data = ProductMappingService.get_specialized_product_data(food_product)
            
            if product_type == 'alcohol' and specialized_data:
                return Response({
                    'type': 'alcohol',
                    'specialized_product': specialized_data,
                    'original_food_product': FoodProductSerializer(food_product).data
                })
            elif product_type == 'caffeine' and specialized_data:
                return Response({
                    'type': 'caffeine', 
                    'specialized_product': specialized_data,
                    'original_food_product': FoodProductSerializer(food_product).data
                })
            else:
                # Return normal food product
                serializer = FoodProductSerializer(food_product)
            return Response(serializer.data)

        # 2. If not found, check for a user-specific CustomFood with this barcode
        custom_food = CustomFood.objects.filter(barcode_id=barcode, user=request.user).first()
        if custom_food:
            # Manually construct a dictionary that matches the frontend's expected format
            custom_food_result = {
                'id': f'custom_{custom_food.id}', # Keep 'id' consistent
                'product_name': custom_food.name,
                'brands': "Custom",
                'nutriments': {}, # Provide empty dict for consistency
                'calories': custom_food.calories,
                'protein': custom_food.protein,
                'carbs': custom_food.carbs,
                'fat': custom_food.fat,
                'is_custom': True,
            }
            return Response(custom_food_result)

        # 3. If nothing is found, return 404
        return Response({"error": "Product not found."}, status=status.HTTP_404_NOT_FOUND)

# --- User Points Management ---

@api_view(['POST'])
@permission_classes([IsTargetUserOrAdmin])
def update_user_points(request, user_id):
    """
    Update a user's points and savings.
    
    POST: Update user points and savings
    Required fields:
        - points_to_add (int): Points to add to both lifetime and available points
        - savings_to_add (decimal): Savings to add to lifetime savings
    Optional fields:
        - points_to_spend (int): Points to deduct from available points
    """
    try:
        user = get_object_or_404(AppUser, id=user_id)
        
        points_to_add_raw = request.data.get('points_to_add', 0)
        savings_to_add_raw = request.data.get('savings_to_add', 0) # Default to 0 for int
        points_to_spend_raw = request.data.get('points_to_spend', 0)
        
        try:
            points_to_add = int(points_to_add_raw)
            points_to_spend = int(points_to_spend_raw)
            savings_to_add = int(savings_to_add_raw)
        except (ValueError, TypeError) as e:
            logger.error(f"Invalid input types for points/savings: {e}. Data: points_add={points_to_add_raw}, savings_add={savings_to_add_raw}, points_spend={points_to_spend_raw}")
            return Response(
                {"error": "Invalid input types. Points and savings must be integers."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if points_to_spend > user.available_points:
            return Response(
                {"error": f"Cannot spend {points_to_spend} points. User only has {user.available_points} available."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        with transaction.atomic():
            user.lifetime_points += points_to_add
            user.available_points = user.available_points + points_to_add - points_to_spend
            user.lifetime_savings += savings_to_add
            user.save()
        
        serializer = AppUserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)
        
    except AppUser.DoesNotExist:
        return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error updating user points for user {user_id}: {e}", exc_info=True)
        return Response(
            {"error": f"An error occurred while updating points: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

# --- User Goals Management ---

class AppUserGoalsCreateUpdateView(APIView):
    """
    POST: Create or update the goals for a specific user
    """
    serializer_class = AppUserGoalsSerializer
    permission_classes = [IsTargetUserOrAdmin]

    def post(self, request, user_id):
        try:
            target_user = get_object_or_404(AppUser, id=user_id)

            goals_instance, created = AppUserGoals.objects.get_or_create(
                user=target_user
            )

            serializer = self.serializer_class(
                instance=goals_instance,
                data=request.data,
                context={'request': request}
            )

            if serializer.is_valid():
                serializer.save(user=target_user)
                response_status = status.HTTP_201_CREATED if created else status.HTTP_200_OK
                return Response(serializer.data, status=response_status)
            else:
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        except AppUser.DoesNotExist:
             return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error creating/updating user goals for user {user_id}: {e}", exc_info=True)
            return Response(
                {"error": f"An error occurred: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

# --- User Affiliate Promotion Views ---

@api_view(['GET'])
@permission_classes([IsTargetUserOrAdmin])
def user_affiliate_promotions(request, user_id):
    """
    GET: Retrieve affiliate promotions assigned to a specific user
    Query parameters:
    - active_only (bool): If 'true', returns only currently active promotions (default: true)
    """
    try:
        user = get_object_or_404(AppUser, id=user_id)
        
        # Check if we should filter for active promotions only (default: true)
        active_only = request.GET.get('active_only', 'true').lower() == 'true'
        
        if active_only:
            user_promotions = AffiliatePromotion.objects.active_for_user(user)
        else:
            user_promotions = user.assigned_promotions.all()
        
        response_data = []
        
        for promotion in user_promotions:
            promotion_data = AffiliatePromotionSerializer(promotion).data
            response_data.append(promotion_data)
        
        return Response(response_data, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error retrieving user promotions: {e}", exc_info=True)
        return Response(
            {"error": f"An error occurred while retrieving promotions: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

# --- Workout Generation ---

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def generate_workout(request):
    """
    Generate a workout plan using OpenAI based on provided parameters.
    
    POST: Generate a workout plan based on user preferences
    """
    serializer = WorkoutGenerationSerializer(data=request.data)
    
    if serializer.is_valid():
        try:
            exercise_results = []
            
            search_params = {
                'level': serializer.validated_data.get('experience_level'),
                'equipment': serializer.validated_data.get('available_equipment', None),
                'primary_muscles': serializer.validated_data.get('target_muscles'),
                'secondary_muscles': None,
                'category': serializer.validated_data.get('workout_category')
            }
            
            exercises = Exercise.search_exercises(**search_params)
            
            for exercise in exercises:
                exercise_results.append({
                    'id': str(exercise.id),
                    'name': exercise.name
                })
                
            if not exercise_results:
                return Response(
                    {"error": "No exercises found matching the search criteria."},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            openai_service = OpenAIService()
            
            result = openai_service.generate_workout_plan(
                duration=serializer.validated_data['duration'],
                target_muscles=serializer.validated_data['target_muscles'],
                experience_level=serializer.validated_data['experience_level'],
                workout_category=serializer.validated_data['workout_category'],
                exercise_list=exercise_results,
                available_equipment=serializer.validated_data.get('available_equipment')
            )
            
            if "error" in result:
                return Response(
                    {"error": result["error"]},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
            return Response(result, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    return Response(
        serializer.errors,
        status=status.HTTP_400_BAD_REQUEST
    )

# --- Views from user_profile_api ---

class UserBMRView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user # This is an AppUser instance
        try:
            # AppUserInfo is accessed via the 'info' related_name on AppUser.
            # The serializer (BMRSerializer) is designed to handle an AppUser instance
            # and access user.info itself.
            user_info = getattr(user, 'info', None)

            if not user_info:
                return Response({"error": "User profile information (AppUserInfo) not found."}, status=status.HTTP_404_NOT_FOUND)
            
            # Check for necessary fields directly on user_info for BMR calculation pre-check
            if not all([user_info.height, user_info.weight, user_info.sex, user_info.birthday]):
                return Response({
                    "error": "Missing necessary information in profile (height, weight, sex, or birthday) to calculate BMR."
                }, status=status.HTTP_400_BAD_REQUEST)

            serializer = BMRSerializer(instance=user) 
            return Response(serializer.data, status=status.HTTP_200_OK)
            
        except AttributeError as e: 
            # This might catch issues if 'info' isn't found, though getattr handles it.
            # More likely to catch other attribute errors on user or user_info if structure is unexpected.
            logger.error(f"AttributeError in UserBMRView for user {user.id if user else 'Unknown'}: {str(e)}", exc_info=True)
            return Response({"error": "User profile related information access issue."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error in UserBMRView for user {user.id if user else 'Unknown'}: {str(e)}", exc_info=True)
            return Response({"error": "An unexpected error occurred while calculating BMR."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- View for User Daily Log (NutritionViewModel) ---

class UserDailyLogView(APIView):
    permission_classes = [IsAuthenticated] # Ensures user is logged in

    def get_or_create_daily_log(self, request_user, target_user_id, date_iso_str):
        """
        Helper to get or create a DailyCalorieTracker instance.
        Also checks for permission.
        """
        try:
            target_user = get_object_or_404(AppUser, pk=target_user_id)
        except AppUser.DoesNotExist:
            return None, Response({"error": "Target user not found."}, status=status.HTTP_404_NOT_FOUND)

        # Permission check: Requesting user must be the target user or an admin/staff
        if request_user != target_user and not request_user.is_staff:
            return None, Response({"error": "You do not have permission to access this log."}, status=status.HTTP_403_FORBIDDEN)

        try:
            log_date = datetime_date.fromisoformat(date_iso_str)
        except ValueError:
            return None, Response({"error": "Invalid date format. Please use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

        # Get or create the daily log
        # DailyCalorieTracker has a default calorie_goal=2000
        daily_log, created = DailyCalorieTracker.objects.get_or_create(
            user=target_user,
            date=log_date
            # Defaults for calorie_goal, etc., are handled by the model's definition
        )
        return daily_log, created # Return log and created status

    def get(self, request, user_id, date_iso):
        """
        Handles GET requests. Retrieves or creates a daily log.
        Frontend expects this to create if not found and return the log.
        """
        daily_log, created_flag_or_error_response = self.get_or_create_daily_log(request.user, user_id, date_iso)

        if isinstance(created_flag_or_error_response, Response): # It's an error response
            return created_flag_or_error_response
        
        # If we are here, daily_log is valid.
        # 'created_flag_or_error_response' is the 'created' boolean from get_or_create.
        serializer = DailyCalorieTrackerSerializer(daily_log)
        # If it was newly created by this GET request, status should ideally still be 200,
        # as GET typically doesn't imply creation with 201.
        # However, the client might interpret data presence as success regardless of 200 vs 201.
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, user_id, date_iso):
        """
        Handles POST requests. Primarily for creating a daily log if it doesn't exist.
        The frontend logs suggest it calls POST to this specific URL to create.
        """
        daily_log, created_flag_or_error_response = self.get_or_create_daily_log(request.user, user_id, date_iso)

        if isinstance(created_flag_or_error_response, Response): # It's an error response
            return created_flag_or_error_response

        # If we are here, daily_log is valid.
        # 'created_flag_or_error_response' is the 'created' boolean.
        created = created_flag_or_error_response 
        
        serializer = DailyCalorieTrackerSerializer(daily_log)
        response_status = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(serializer.data, status=response_status)

class CustomFoodViewSet(viewsets.ModelViewSet):
    """
    ViewSet for users to manage their own custom food creations.
    """
    serializer_class = CustomFoodSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        This view should only return the list of foods for the currently
        authenticated user.
        """
        user = self.request.user
        return CustomFood.objects.filter(user=user)

    def perform_create(self, serializer):
        """
        Assign the currently authenticated user to the new custom food.
        """
        serializer.save(user=self.request.user)

# --- Streak Tracking Views ---

class StreakDataView(generics.RetrieveAPIView):
    """
    GET: Retrieve streak information for the current user
    """
    serializer_class = StreakSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class ShareStreakView(APIView):
    """
    POST: Share streak message (simulate sending)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        streak_count = user.current_streak
        
        # Generate the message
        if streak_count == 0:
            message = "I'm starting my food tracking journey with Evolve! 🌱 #EvolveApp #HealthyHabits"
        elif streak_count == 1:
            message = f"Day {streak_count} of tracking my nutrition with Evolve! Let's keep it going! 💪 #EvolveApp #StreakLife"
        elif streak_count < 10:
            message = f"{streak_count} days strong tracking my nutrition with Evolve! Building healthy habits one day at a time 🔥 #EvolveApp #StreakLife"
        elif streak_count % 10 == 0:
            message = f"🎉 {streak_count} day streak! Crushing my nutrition goals with Evolve! Who wants to join me? 🚀 #EvolveApp #StreakChampion"
        else:
            message = f"{streak_count} days of consistent nutrition tracking with Evolve! Feeling stronger every day 💯 #EvolveApp #StreakLife"
        
        # In a real implementation, you might integrate with social media APIs
        # For now, we'll just return the message that would be shared
        return Response({
            "message": message,
            "streak_count": streak_count,
            "success": True
        }, status=status.HTTP_200_OK)

class CustomWorkoutAPIView(APIView):
    """Generate a bespoke workout on-demand (wraps max.services.custom_workout)."""

    permission_classes = [IsAuthenticated]

    class InputSerializer(serializers.Serializer):
        muscle_groups = serializers.ListField(child=serializers.CharField(), min_length=1)
        duration = serializers.ChoiceField(choices=[20, 40, 60])
        intensity = serializers.ChoiceField(choices=["low", "medium", "high"], default="medium")
        include_cardio = serializers.BooleanField(default=False)
        schedule_for_today = serializers.BooleanField(default=True)

    def post(self, request):
        serializer = self.InputSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        try:
            workout_data = generate_custom_workout(
                user_id=str(request.user.id), **serializer.validated_data
            )
            return Response(workout_data, status=status.HTTP_201_CREATED)
        except CustomWorkoutGenerationError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error generating custom workout for user {request.user.id}: {e}")
            return Response(
                {"error": "An unexpected error occurred."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

# --- User Journal Views ---

class JournalEntryListView(generics.ListCreateAPIView):
    """
    GET: List all journal entries for the current user
    POST: Create a new journal entry
    """
    serializer_class = JournalEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Filter journal entries by the current user."""
        return JournalEntry.objects.filter(user=self.request.user).order_by('-date_created', '-time_created')

    def perform_create(self, serializer):
        """Set the user to the current authenticated user when creating."""
        journal_entry = serializer.save(user=self.request.user)
        
        # Create a UserCompletedLog entry for this journal creation
        self._create_completion_log(journal_entry)

    def _create_completion_log(self, journal_entry):
        """
        Creates a UserCompletedLog entry for the journal entry with is_adhoc=True.
        This allows the journal entry to appear in the activity tab.
        """
        try:
            # Get or create a Journal activity template
            journal_activity = Activity.objects.filter(
                activity_type='Journal',
                name__icontains='journal'
            ).first()
            
            if not journal_activity:
                # Create a default Journal activity if none exists
                journal_activity = Activity.objects.create(
                    name='Journal Entry',
                    description='Create a personal journal entry to reflect on thoughts, feelings, and experiences.',
                    default_point_value=10,
                    category=['Mind'],
                    activity_type='Journal',
                    is_archived=False
                )
            
            # Create the completion log
            UserCompletedLog.objects.create(
                user=journal_entry.user,
                activity=journal_activity,
                activity_name_at_completion=f"{journal_entry.title}",
                description_at_completion=f"Created a journal entry titled '{journal_entry.title}' with {len(journal_entry.content)} characters of content.",
                completed_at=journal_entry.created_at,
                points_awarded=journal_activity.default_point_value,
                is_adhoc=True,
                user_notes_on_completion=f"Journal entry content preview: {journal_entry.content[:100]}{'...' if len(journal_entry.content) > 100 else ''}"
            )
            
            # Update user's points
            user = journal_entry.user
            user.lifetime_points += journal_activity.default_point_value
            user.available_points += journal_activity.default_point_value
            user.save(update_fields=['lifetime_points', 'available_points'])
            
        except Exception as e:
            # Log the error but don't prevent journal entry creation
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to create completion log for journal entry {journal_entry.id}: {str(e)}")


class JournalEntryDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET: Retrieve a specific journal entry
    PUT/PATCH: Update a journal entry
    DELETE: Remove a journal entry
    """
    serializer_class = JournalEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Ensure users can only access their own journal entries."""
        return JournalEntry.objects.filter(user=self.request.user)

    def get_object(self):
        """
        Overrides the default get_object to handle UUID lookups.
        Django automatically handles UUID case-insensitivity in database queries.
        """
        queryset = self.get_queryset()
        pk = self.kwargs.get('pk')

        obj = get_object_or_404(queryset, pk=pk)
        self.check_object_permissions(self.request, obj)
        return obj

    def perform_update(self, serializer):
        """Ensure the user cannot change the ownership when updating."""
        serializer.save(user=self.request.user)


class FoodProductProgressiveSearchView(generics.ListAPIView):
    """
    Progressive search that returns results in fast batches:
    1. Exact matches (instant)
    2. Prefix matches (very fast)
    3. Contains matches (fast)
    4. Full-text search (slower but comprehensive)

    This allows users to see results immediately rather than waiting 6-8 seconds.
    """
    permission_classes = [IsAuthenticated]

    def list(self, request, *args, **kwargs):
        query = request.query_params.get("name", "").strip()
        if not query:
            return Response([], status=status.HTTP_200_OK)

        # Combine results from all search tiers
        exact_matches = self.get_exact_matches(query)
        prefix_matches = self.get_prefix_matches(query)
        contains_matches = self.get_contains_matches(query)
        fulltext_matches = self.get_fulltext_matches(query)

        # Use a dictionary to ensure unique items based on a composite key
        # This prevents duplicates and maintains order of importance
        combined_results = {}
        for item in exact_matches + prefix_matches + contains_matches + fulltext_matches:
            # Use a tuple of primary keys to uniquely identify an entry
            item_key = (item.get('id'), item.get('custom_food_id'))
            if item_key not in combined_results:
                combined_results[item_key] = item
        
        # Convert back to a list
        final_results = list(combined_results.values())

        return Response(final_results, status=status.HTTP_200_OK)

    def get_exact_matches(self, query):
        """Finds exact, case-insensitive matches."""
        # Query both FoodProduct and CustomFood
        product_matches = FoodProduct.objects.filter(name__iexact=query)
        custom_matches = CustomFood.objects.filter(name__iexact=query, user=self.request.user)

        # Serialize and combine
        product_serializer = FoodProductSerializer(product_matches, many=True)
        custom_serializer = CustomFoodSerializer(custom_matches, many=True)
        
        # Add a 'type' field to distinguish them
        serialized_products = [{'type': 'standard', **p} for p in product_serializer.data]
        serialized_customs = [{'type': 'custom', **c} for c in custom_serializer.data]
        
        return serialized_products + serialized_customs

    def get_prefix_matches(self, query):
        """Finds case-insensitive prefix matches (e.g., 'appl' for 'apple')."""
        # Exclude exact matches already found
        product_matches = FoodProduct.objects.filter(name__istartswith=query).exclude(name__iexact=query)
        custom_matches = CustomFood.objects.filter(name__istartswith=query, user=self.request.user).exclude(name__iexact=query)

        product_serializer = FoodProductSerializer(product_matches, many=True)
        custom_serializer = CustomFoodSerializer(custom_matches, many=True)
        
        serialized_products = [{'type': 'standard', **p} for p in product_serializer.data]
        serialized_customs = [{'type': 'custom', **c} for c in custom_serializer.data]
        
        return serialized_products + serialized_customs

    def get_contains_matches(self, query):

        """Get contains matches - fast with indexes"""
        return FoodProduct.objects.filter(
            Q(obsolete__isnull=True) | Q(obsolete=False)
        ).filter(
            Q(product_name__icontains=query) |
            Q(brands__icontains=query)
        ).exclude(
            product_name__isnull=True
        ).exclude(
            product_name=''
        ).exclude(
            # Exclude exact and prefix matches already returned
            Q(product_name__iexact=query) |
            Q(brands__iexact=query) |
            Q(product_name__istartswith=query) |
            Q(brands__istartswith=query)
        ).order_by('-popularity_key')[:8]
    
    def get_fulltext_matches(self, query):
        """Get full-text search matches - slower but comprehensive"""
        # Use speed-optimized search but exclude previous results
        from django.conf import settings
        if getattr(settings, 'FEATURES', {}).get('USE_OPTIMIZED_SEARCH', True):
            all_results = FoodProduct.search_foods_simple_fast(query, limit=15)
        else:
            all_results = FoodProduct.search_foods(query, limit=15)

        """Finds case-insensitive containment matches (e.g., 'le' in 'apple')."""
        # Exclude exact and prefix matches
        product_matches = FoodProduct.objects.filter(name__icontains=query).exclude(name__istartswith=query)
        custom_matches = CustomFood.objects.filter(
            name__icontains=query, user=self.request.user
        ).exclude(name__istartswith=query)

        product_serializer = FoodProductSerializer(product_matches, many=True)
        custom_serializer = CustomFoodSerializer(custom_matches, many=True)

        
        serialized_products = [{'type': 'standard', **p} for p in product_serializer.data]
        serialized_customs = [{'type': 'custom', **c} for c in custom_serializer.data]
        
        return serialized_products + serialized_customs

    def get_fulltext_matches(self, query):
        """Finds matches using full-text search, for more complex queries."""
        # This is a placeholder for a more advanced full-text search.
        # For simplicity, we'll just return an empty list here.
        # A real implementation would use something like Django's SearchVector.
        return []
