from datetime import date, datetime
from rest_framework import serializers
from .models import (
    Activity, Workout, Exercise, AppUser, AppUserInfo,
    WorkoutExercise, AppUserGoals, UserGoalDetail, Affiliate,
    AffiliatePromotion, AffiliatePromotionRedemption, FriendGroup, Member, ContentCard, ReadingContent, 
    FriendGroupEvent, AppUserCurrentEmotion, AppUserDailyEmotion, 
    UserScheduledActivity, UserCompletedLog, AppUserEquipment, UserExerciseMax, AppUserFatigueModel,
    Shortcut, UserShortcut, Routine, RoutineStep, JournalEntry, UserProduct, FriendGroupInvitation
)
from fitness.models import CardioWorkout, ExerciseTransferCoefficient
from nutrition.serializers import (
    DailyCalorieTrackerSerializer, FoodEntrySerializer, FoodProductSerializer, CustomFoodSerializer, UserFeedbackSerializer
)

# --- Exercise and Workout Related Serializers ---

class ExerciseSerializer(serializers.ModelSerializer):
    """Basic serializer for Exercise model"""
    class Meta:
        model = Exercise
        fields = '__all__'

class WorkoutExerciseSerializer(serializers.ModelSerializer):
    """Serializer for WorkoutExercise model with nested Exercise details"""
    exercise = ExerciseSerializer(read_only=True)

    class Meta:
        model = WorkoutExercise
        fields = '__all__'

class WorkoutSerializer(serializers.ModelSerializer):
    """Serializer for Workout model with nested WorkoutExercise details"""
    workoutexercises = WorkoutExerciseSerializer(
        many=True, 
        read_only=True, 
        source='workoutexercise_set'
    )

    class Meta:
        model = Workout
        fields = [
            'id', 'name', 'description', 'duration', 
            'created_at', 'updated_at', 'workoutexercises'
        ]

class ExerciseTransferCoefficientSerializer(serializers.ModelSerializer):
    """Serializer for ExerciseTransferCoefficient model."""
    from_exercise = ExerciseSerializer(read_only=True)
    to_exercise = ExerciseSerializer(read_only=True)

    class Meta:
        model = ExerciseTransferCoefficient
        fields = '__all__'


class CardioWorkoutSerializer(serializers.ModelSerializer):
    """Serializer for CardioWorkout model."""
    class Meta:
        model = CardioWorkout
        fields = '__all__'

# --- Content Related Serializers ---

class ContentCardSerializer(serializers.ModelSerializer):
    """Serializer for ContentCard model"""
    class Meta:
        model = ContentCard
        fields = ['id', 'text', 'bolded_words']

class ReadingContentSerializer(serializers.ModelSerializer):
    """Serializer for ReadingContent model with nested ContentCard details"""
    content_cards_data = ContentCardSerializer(
        many=True, 
        read_only=True, 
        source='content_cards'
    )
    content_card_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=ContentCard.objects.all(),
        write_only=True,
        source='content_cards'
    )

    class Meta:
        model = ReadingContent
        fields = [
            'id', 'title', 'duration', 'description', 'cover_image', 
            'category', 'content_cards_data', 'content_card_ids', 
        ]
        read_only_fields = ['content_cards_data']

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        representation['content_cards'] = representation.get('content_cards_data', [])
        if 'content_cards_data' in representation:
            del representation['content_cards_data']
        
        return representation

class ActivitySerializer(serializers.ModelSerializer):
    """Serializer for Activity model with nested Workout and ReadingContent details"""
    associated_workout = WorkoutSerializer(read_only=True)
    associated_reading = ReadingContentSerializer(read_only=True)

    class Meta:
        model = Activity
        fields = '__all__'

# --- User Related Serializers ---

class AppUserEquipmentSerializer(serializers.ModelSerializer):
    """Serializer for AppUserEquipment model."""
    class Meta:
        model = AppUserEquipment
        fields = '__all__'


class UserExerciseMaxSerializer(serializers.ModelSerializer):
    """Serializer for UserExerciseMax model."""
    exercise = ExerciseSerializer(read_only=True)

    class Meta:
        model = UserExerciseMax
        fields = '__all__'


class AppUserFatigueModelSerializer(serializers.ModelSerializer):
    """Serializer for AppUserFatigueModel."""
    class Meta:
        model = AppUserFatigueModel
        fields = '__all__'

# --- Journal Serializers ---

class JournalEntrySerializer(serializers.ModelSerializer):
    """Serializer for JournalEntry model."""
    user = serializers.CharField(source="user.phone", read_only=True)
    
    class Meta:
        model = JournalEntry
        fields = [
            'id', 'user', 'title', 'content', 'date_created', 
            'time_created', 'created_at', 'updated_at'
        ]
        read_only_fields = ['user', 'created_at', 'updated_at']

# --- Shortcut and User Management Serializers ---

class ShortcutSerializer(serializers.ModelSerializer):
    """Serializer for Shortcut model"""
    class Meta:
        model = Shortcut
        fields = ['id', 'name', 'category', 'action_identifier', 'description']

class UserShortcutSerializer(serializers.ModelSerializer):
    """Serializer for UserShortcut model, including nested shortcut details."""
    shortcut = ShortcutSerializer(read_only=True)
    shortcut_id = serializers.PrimaryKeyRelatedField(
        queryset=Shortcut.objects.filter(is_active=True),
        source='shortcut',
        write_only=True,
        help_text="ID of the Shortcut to add."
    )
    
    class Meta:
        model = UserShortcut
        fields = ['id', 'shortcut', 'shortcut_id', 'order']

class AppUserInfoSerializer(serializers.ModelSerializer):
    """Serializer for AppUserInfo model"""
    user = serializers.SerializerMethodField()
    height = serializers.SerializerMethodField()
    weight = serializers.SerializerMethodField()
    
    class Meta:
        model = AppUserInfo
        fields = '__all__'

    def get_user(self, obj):
        if obj.user:
            return obj.user.phone
        return None
    
    def get_height(self, obj):
        # Convert float to integer to avoid Swift decoding issues
        # Return height in tenths of inches to maintain precision
        if obj.height is not None:
            return int(obj.height * 10)  # Convert to tenths of inches
        return None
    
    def get_weight(self, obj):
        # Convert float to integer to avoid Swift decoding issues
        # Return weight in tenths of pounds to maintain precision
        if obj.weight is not None:
            return int(obj.weight * 10)  # Convert to tenths of pounds
        return None

class UserGoalDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserGoalDetail
        fields = ['id', 'goal_categories', 'text']
        read_only_fields = ['id']

class AppUserGoalsSerializer(serializers.ModelSerializer):
    """Serializer for AppUserGoals model"""
    user = serializers.SerializerMethodField()
    details = UserGoalDetailSerializer(many=True, required=False)
    
    class Meta:
        model = AppUserGoals
        fields = ['id', 'user', 'goals_general', 'details']

    def get_user(self, obj):
        if obj.user:
            return obj.user.phone
        return None

    def create(self, validated_data):
        details_data = validated_data.pop('details', [])
        app_user_goals = AppUserGoals.objects.create(**validated_data)
        for detail_data in details_data:
            UserGoalDetail.objects.create(app_user_goals=app_user_goals, **detail_data)
        return app_user_goals

    def update(self, instance, validated_data):
        details_data = validated_data.pop('details', None)

        instance.goals_general = validated_data.get('goals_general', instance.goals_general)
        instance.save()

        if details_data is not None:
            instance.details.all().delete()
            for detail_data in details_data:
                UserGoalDetail.objects.create(app_user_goals=instance, **detail_data)
        
        return instance

class AppUserInfoForUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppUserInfo
        fields = ('height', 'birthday', 'weight', 'sex')
        extra_kwargs = {
            'height': {'required': False},
            'birthday': {'required': False},
            'weight': {'required': False},
            'sex': {'required': False},
        }

class AppUserUpdateSerializer(serializers.ModelSerializer):
    info = AppUserInfoForUpdateSerializer(required=False)
    backup_email = serializers.EmailField(allow_blank=True, required=False, allow_null=True)
    
    class Meta:
        model = AppUser
        fields = ('first_name', 'last_name', 'backup_email', 'info')

    def update(self, instance, validated_data):
        info_data = validated_data.pop('info', None)
        
        # Update the AppUser instance
        instance.first_name = validated_data.get('first_name', instance.first_name)
        instance.last_name = validated_data.get('last_name', instance.last_name)
        if 'backup_email' in validated_data:
            instance.backup_email = validated_data.get('backup_email')
        instance.save()
        
        # Update or create the AppUserInfo instance
        if info_data:
            info_instance, created = AppUserInfo.objects.get_or_create(user=instance)
            for attr, value in info_data.items():
                setattr(info_instance, attr, value)
            info_instance.save()
        
        return instance

class AppUserSimpleSerializer(serializers.ModelSerializer):
    """Lightweight serializer for basic user information"""
    class Meta:
        model = AppUser
        fields = ['id', 'first_name', 'last_name', 'phone']

# --- Affiliate Related Serializers ---

class AffiliateSerializer(serializers.ModelSerializer):
    """Serializer for Affiliate model"""
    class Meta:
        model = Affiliate
        fields = [
            'id', 'name', 'contact_email', 'contact_phone', 
            'logo', 'website', 'location', 'is_active'
        ]

class AffiliatePromotionSerializer(serializers.ModelSerializer):
    """Serializer for AffiliatePromotion model with nested Affiliate details"""
    affiliate = AffiliateSerializer(read_only=True)
    affiliate_id = serializers.PrimaryKeyRelatedField(
        source='affiliate', 
        queryset=Affiliate.objects.all(), 
        write_only=True
    )
    assigned_users = AppUserSimpleSerializer(many=True, read_only=True)
    assigned_user_ids = serializers.PrimaryKeyRelatedField(
        source='assigned_users', 
        queryset=AppUser.objects.all(), 
        many=True, 
        write_only=True,
        required=False
    )
    is_currently_active = serializers.ReadOnlyField()
    days_until_expiry = serializers.ReadOnlyField()

    class Meta:
        model = AffiliatePromotion
        fields = [
            'id', 'affiliate', 'affiliate_id', 'title', 'description',
            'original_price', 'point_value', 'product_image',
            'start_date', 'end_date', 'is_active', 'is_currently_active',
            'days_until_expiry', 'assigned_users', 'assigned_user_ids'
        ]

class AffiliatePromotionRedemptionSerializer(serializers.ModelSerializer):
    """Serializer for AffiliatePromotionRedemption model"""
    promotion = AffiliatePromotionSerializer(read_only=True)
    promotion_id = serializers.PrimaryKeyRelatedField(
        source='promotion',
        queryset=AffiliatePromotion.objects.all(),
        write_only=True
    )
    user = serializers.SerializerMethodField()
    user_id = serializers.PrimaryKeyRelatedField(
        source='user',
        queryset=AppUser.objects.all(),
        write_only=True,
        allow_null=True,
        required=False
    )

    class Meta:
        model = AffiliatePromotionRedemption
        fields = ['id', 'promotion', 'promotion_id', 'user', 'user_id', 'redeemed_at']
        read_only_fields = ['redeemed_at']

    def get_user(self, obj):
        if obj.user:
            return obj.user.phone
        return None


class UserProductSerializer(serializers.ModelSerializer):
    """Serializer for UserProduct model"""
    user = serializers.CharField(source="user.phone", read_only=True)
    source_promotion = AffiliatePromotionSerializer(read_only=True)
    affiliate_name = serializers.CharField(read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    days_until_expiry = serializers.IntegerField(read_only=True)
    
    # Frontend-compatible fields to match ProductItem structure
    id = serializers.UUIDField(read_only=True)
    name = serializers.CharField(source='product_name', read_only=True)
    imageName = serializers.SerializerMethodField()
    
    class Meta:
        model = UserProduct
        fields = [
            'id', 'user', 'source_promotion', 'product_name', 'name', 'product_description',
            'product_image', 'imageName', 'category', 'category_display', 'status', 'status_display',
            'redeemed_at', 'expires_at', 'last_used_at', 'affiliate_name', 'points_spent',
            'original_value', 'user_notes', 'is_favorite', 'is_expired', 'days_until_expiry',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'redeemed_at', 'created_at', 'updated_at', 'is_expired', 'days_until_expiry'
        ]
    
    def get_imageName(self, obj):
        """
        Return the image name/path for frontend compatibility.
        This matches the ProductItem.imageName field expected by the frontend.
        """
        if obj.product_image:
            # Return just the filename without the path for local assets
            # or the full URL for remote images
            if hasattr(obj.product_image, 'name'):
                return obj.product_image.name.split('/')[-1].split('.')[0]  # Get filename without extension
            return str(obj.product_image)
        return obj.product_name.replace(' ', '')  # Fallback to product name without spaces


class UserProductUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating UserProduct fields that users can modify"""
    
    class Meta:
        model = UserProduct
        fields = ['user_notes', 'is_favorite', 'status']
        
    def validate_status(self, value):
        """Only allow certain status transitions by users"""
        allowed_statuses = ['active', 'cancelled']
        if value not in allowed_statuses:
            raise serializers.ValidationError(
                f"Users can only set status to: {', '.join(allowed_statuses)}"
            )
        return value

# --- Activity Tracking Serializers ---

class UserScheduledActivitySerializer(serializers.ModelSerializer):
    """Serializer for UserScheduledActivity model"""
    user = serializers.CharField(source="user.phone", read_only=True)
    activity = ActivitySerializer(read_only=True)
    activity_id = serializers.PrimaryKeyRelatedField(
        queryset=Activity.objects.filter(is_archived=False),
        source='activity',
        write_only=True,
        help_text="ID of the Activity to schedule."
    )

    class Meta:
        model = UserScheduledActivity
        fields = [
            'id', 'user', 'activity', 'activity_id', 'scheduled_date',
            'scheduled_display_time', 'is_generated', 'order_in_day', 
            'is_complete', 'completed_at', 'generated_description', 'custom_notes'
        ]
        read_only_fields = ['user', 'completed_at', 'is_generated']

class UserCompletedLogSerializer(serializers.ModelSerializer):
    """Serializer for UserCompletedLog model"""
    user = serializers.CharField(source="user.phone", read_only=True)
    activity = ActivitySerializer(read_only=True, required=False, allow_null=True)
    source_scheduled_activity = UserScheduledActivitySerializer(
        read_only=True, 
        required=False, 
        allow_null=True
    )
    activity_id = serializers.PrimaryKeyRelatedField(
        queryset=Activity.objects.all(),
        source='activity',
        write_only=True,
        required=False,
        allow_null=True,
        help_text="ID of the Activity template, if this log links to one."
    )
    source_scheduled_activity_id = serializers.PrimaryKeyRelatedField(
        queryset=UserScheduledActivity.objects.all(),
        source='source_scheduled_activity',
        write_only=True,
        required=False,
        allow_null=True,
        help_text="ID of the UserScheduledActivity, if this log is for a scheduled item."
    )

    class Meta:
        model = UserCompletedLog
        fields = [
            'id', 'user', 'activity', 'activity_id', 'activity_name_at_completion',
            'description_at_completion', 'completed_at', 'points_awarded',
            'source_scheduled_activity', 'source_scheduled_activity_id',
            'is_adhoc', 'user_notes_on_completion'
        ]
        read_only_fields = ['user', 'completed_at']

# --- Main User Serializer ---
class AppUserSerializer(serializers.ModelSerializer):
    """Main serializer for AppUser model with all related data"""
    info = AppUserInfoSerializer(read_only=True)
    equipment = AppUserEquipmentSerializer(read_only=True)
    exercise_maxes = UserExerciseMaxSerializer(many=True, read_only=True)
    muscle_fatigue = AppUserFatigueModelSerializer(many=True, read_only=True)
    scheduled_activities = UserScheduledActivitySerializer(many=True, read_only=True)
    shortcut_selections = UserShortcutSerializer(many=True, read_only=True)
    completion_logs = UserCompletedLogSerializer(many=True, read_only=True)
    goals = AppUserGoalsSerializer(read_only=True)
    calorie_logs = DailyCalorieTrackerSerializer(many=True, read_only=True)
    feedback = UserFeedbackSerializer(many=True, read_only=True)
    assigned_promotions = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    promotion_redemptions = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    journal_entries = JournalEntrySerializer(many=True, read_only=True)
    lifetime_savings = serializers.SerializerMethodField()
    is_onboarded = serializers.BooleanField(source='isOnboarded', read_only=True)
    backup_email = serializers.EmailField(allow_null=True, required=False)

    class Meta:
        model = AppUser
        fields = [
            'id', 'phone', 'backup_email', 'first_name', 'last_name', 'is_phone_verified', 'date_joined',
            'lifetime_points', 'available_points', 'lifetime_savings', 'is_onboarded',
            'info', 'equipment', 'exercise_maxes', 'muscle_fatigue', 'shortcut_selections', 'scheduled_activities', 'completion_logs', 'goals',
            'calorie_logs', 'feedback', 'assigned_promotions',
            'promotion_redemptions', 'journal_entries'
        ]
        extra_kwargs = {
            'otp_code': {'write_only': True, 'required': False},
            'otp_created_at': {'read_only': True},
            'password': {'write_only': True}
        }

    def get_lifetime_savings(self, obj):
        # Convert decimal to integer to avoid Swift decoding issues
        # Return savings in cents to maintain precision
        savings = getattr(obj, 'lifetime_savings', 0)
        if hasattr(savings, 'quantize'):
            # It's a Decimal object
            return int(savings * 100)  # Convert to cents
        return int(savings * 100) if savings else 0

# --- Routine Serializers ---

class RoutineStepSerializer(serializers.ModelSerializer):
    """Serializer for RoutineStep model."""
    class Meta:
        model = RoutineStep
        fields = ['id', 'name', 'icon', 'order']

class RoutineSerializer(serializers.ModelSerializer):
    """Serializer for Routine model with nested steps."""
    steps = RoutineStepSerializer(many=True, read_only=True)
    user = AppUserSimpleSerializer(read_only=True)

    class Meta:
        model = Routine
        fields = [
            'id', 'user', 'title', 'description', 
            'scheduled_time', 'created_at', 'updated_at', 'steps'
        ]
        read_only_fields = ['user', 'created_at', 'updated_at']

# --- Friend Group Related Serializers ---

class MemberSerializer(serializers.ModelSerializer):
    """Serializer for Member model"""
    user = AppUserSimpleSerializer(read_only=True, allow_null=True)
    user_id = serializers.PrimaryKeyRelatedField(
        queryset=AppUser.objects.all(),
        source='user',
        write_only=True,
        allow_null=True,
        required=False
    )
    friend_group_id = serializers.PrimaryKeyRelatedField(
        queryset=FriendGroup.objects.all(),
        source='friend_group',
        write_only=True
    )

    class Meta:
        model = Member
        fields = [
            'id', 'friend_group', 'friend_group_id', 'user', 'user_id',
            'date_joined', 'isAdmin'
        ]
        read_only_fields = ['friend_group', 'user', 'date_joined']

    def to_internal_value(self, data):
        # Handle both camelCase 'isAdmin' and snake_case 'is_admin'
        if 'is_admin' in data and 'isAdmin' not in data:
            data = data.copy()
            data['isAdmin'] = data.pop('is_admin')
        return super().to_internal_value(data)

class FriendGroupSerializer(serializers.ModelSerializer):
    """Serializer for FriendGroup model with nested Member details"""
    members = MemberSerializer(many=True, read_only=True, source='friend_group_members')
    
    class Meta:
        model = FriendGroup
        fields = ['id', 'name', 'members', 'cover_image']

class FriendGroupEventSerializer(serializers.ModelSerializer):
    """Serializer for FriendGroupEvent model"""
    user = AppUserSimpleSerializer(read_only=True, allow_null=True)
    completed_activity_log = UserCompletedLogSerializer(
        read_only=True,
        required=False,
        allow_null=True
    )
    timestamp = serializers.DateTimeField(format='iso-8601')

    class Meta:
        model = FriendGroupEvent
        fields = [
            'id', 'friend_group', 'user', 'event_type', 'timestamp',
            'completed_activity_log'
        ]
        read_only_fields = [
            'id', 'friend_group', 'user', 'event_type', 
            'timestamp', 'completed_activity_log'
        ]


class FriendGroupInvitationSerializer(serializers.ModelSerializer):
    """Serializer for FriendGroupInvitation model"""
    friend_group = FriendGroupSerializer(read_only=True)
    friend_group_id = serializers.PrimaryKeyRelatedField(
        queryset=FriendGroup.objects.all(),
        source='friend_group',
        write_only=True
    )
    inviter = AppUserSimpleSerializer(read_only=True)
    invitee_user = AppUserSimpleSerializer(read_only=True, allow_null=True)
    
    class Meta:
        model = FriendGroupInvitation
        fields = [
            'id', 'friend_group', 'friend_group_id', 'inviter', 
            'invitee_phone', 'invitee_user', 'status', 
            'created_at', 'responded_at'
        ]
        read_only_fields = [
            'id', 'inviter', 'invitee_user', 'created_at', 'responded_at'
        ]
        
    def create(self, validated_data):
        """Create invitation and check if invitee has an account."""
        invitee_phone = validated_data.get('invitee_phone')
        
        # Check if user with this phone number exists
        try:
            invitee_user = AppUser.objects.get(phone=invitee_phone)
            validated_data['invitee_user'] = invitee_user
        except AppUser.DoesNotExist:
            # User doesn't exist yet, that's okay
            pass
            
        # Set the inviter from request context
        validated_data['inviter'] = self.context['request'].user
        
        return super().create(validated_data)


class AppUserCurrentEmotionSerializer(serializers.ModelSerializer):
    """Serializer for AppUserCurrentEmotion model"""
    user_details = serializers.SerializerMethodField()
    feeling = serializers.CharField(source="emotion")
    causes = serializers.CharField(source="cause")
    impacts = serializers.CharField(source="biggest_impact")

    class Meta:
        model = AppUserCurrentEmotion
        fields = ['id', 'user_details', 'feeling', 'intensity', 'causes', 'impacts', 'tracked_at']
        read_only_fields = ['tracked_at']

    def get_user_details(self, obj):
        if obj.user:
            return obj.user.phone
        return None

class AppUserDailyEmotionSerializer(serializers.ModelSerializer):
    """Serializer for AppUserDailyEmotion model"""
    user_details = serializers.SerializerMethodField()
    feeling = serializers.CharField(source="emotion")
    causes = serializers.CharField(source="cause")
    impacts = serializers.CharField(source="biggest_impact")

    class Meta:
        model = AppUserDailyEmotion
        fields = [
            'id', 'user_details', 'feeling', 'intensity', 'causes', 'impacts',
            'tracked_at', 'date'
        ]
        read_only_fields = ['tracked_at', 'date']

    def get_user_details(self, obj):
        if obj.user:
            return obj.user.phone
        return None

# --- Workout Generation Serializer ---

class WorkoutGenerationSerializer(serializers.Serializer):
    """Serializer for workout generation requests"""
    duration = serializers.IntegerField(
        required=True,
        help_text="Workout duration in minutes"
    )
    target_muscles = serializers.ListField(
        child=serializers.CharField(),
        required=True,
        help_text="List of muscles to target"
    )
    experience_level = serializers.ChoiceField(
        choices=['beginner', 'intermediate', 'advanced'],
        required=True,
        help_text="User experience level"
    )
    workout_category = serializers.ChoiceField(
        choices=['strength', 'cardio', 'flexibility', 'balance', 'hiit'],
        required=True,
        help_text="Type of workout"
    )
    available_equipment = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        help_text="Optional list of available equipment"
    )

    def create(self, validated_data):
        return validated_data


# --- Serializers from user_profile_api ---

class BMRSerializer(serializers.Serializer):
    bmr = serializers.ReadOnlyField()
    tdee = serializers.ReadOnlyField()
    
    class Meta:
        fields = ['bmr', 'tdee']


class StreakSerializer(serializers.ModelSerializer):
    """
    Serializer for user streak tracking information.
    """
    
    class Meta:
        model = AppUser
        fields = [
            'current_streak',
            'longest_streak', 
            'streak_points'
        ]
        read_only_fields = [
            'current_streak',
            'longest_streak',
            'streak_points'
        ]
