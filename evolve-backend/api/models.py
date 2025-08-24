from django.db import models
from django.utils import timezone
from django.core.validators import RegexValidator
from django.contrib.postgres.fields import ArrayField
from django.core.exceptions import ValidationError
from django.contrib.auth.models import (
    AbstractBaseUser, BaseUserManager, PermissionsMixin,
    Group, Permission
)
from fitness.models import Exercise, Workout, WorkoutExercise # don't delete
import uuid
import datetime

# --- User Management Models ---

class AppUserManager(BaseUserManager):
    """
    Custom manager for the AppUser model.
    Handles creation of regular users and superusers.
    """
    def create_user(self, phone, first_name, last_name, password=None, **extra_fields):
        """
        Creates and saves an AppUser with the given phone, first_name, last_name, and password.
        
        Args:
            phone (str): User's phone number
            first_name (str): User's first name
            last_name (str): User's last name
            password (str, optional): User's password
            **extra_fields: Additional fields to set on the user
            
        Returns:
            AppUser: The created user instance
            
        Raises:
            ValueError: If phone, first_name or last_name is not provided
        """
        if not phone:
            raise ValueError('The Phone number must be set')
        if not first_name:
            raise ValueError('The First Name must be set')
        if not last_name:
            raise ValueError('The Last Name must be set')
        
        user = self.model(phone=phone, first_name=first_name, last_name=last_name, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
            
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, first_name, last_name, password, **extra_fields):
        """
        Creates and saves a superuser with the given phone, name, and password.
        
        Args:
            phone (str): User's phone number
            first_name (str): User's first name
            last_name (str): User's last name
            password (str): User's password
            **extra_fields: Additional fields to set on the user
            
        Returns:
            AppUser: The created superuser instance
            
        Raises:
            ValueError: If required superuser fields are not set
        """
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self.create_user(phone, first_name, last_name, password, **extra_fields)


class AppUser(AbstractBaseUser, PermissionsMixin):
    """
    Custom user model for the application.
    Uses phone number as the primary identifier instead of username.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(
        max_length=15,
        unique=True,
        help_text="Format: +11234567890 (Used as username)"
    )    
    backup_email = models.EmailField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Optional backup email address for the user."
    )
    first_name = models.CharField(
        max_length=150,
        help_text="User's first name.",
        default=''
    )
    last_name = models.CharField(
        max_length=150,
        help_text="User's last name.",
        default=''
    )
    password = models.CharField(
        max_length=128,
        verbose_name='password',
        default=''
    )
    otp_code = models.CharField(
        max_length=6,
        blank=True,
        null=True,
        help_text="Latest OTP code sent to the user."
    )
    otp_created_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Timestamp when the OTP was generated."
    )
    is_phone_verified = models.BooleanField(
        default=False,
        help_text="Indicates whether the user has verified their phone number."
    )
    date_joined = models.DateTimeField(default=timezone.now)
    lifetime_points = models.IntegerField(
        default=0,
        help_text="Total points earned by the user over their lifetime."
    )
    available_points = models.IntegerField(
        default=0,
        help_text="Points currently available for the user to spend."
    )
    lifetime_savings = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        default=0.00,
        help_text="Total savings earned by the user over their lifetime in dollars (e.g., 115.30)."
    )
    isOnboarded = models.BooleanField(
        default=False,
        help_text="Indicates whether the user has completed the onboarding process."
    )
    current_streak = models.IntegerField(
        default=0,
        help_text="User's current daily tracking streak."
    )
    longest_streak = models.IntegerField(
        default=0,
        help_text="User's longest all-time daily tracking streak."
    )
    streak_points = models.IntegerField(
        default=0,
        help_text="Points earned from streaks."
    )
    shortcuts = models.ManyToManyField(
        'Shortcut',
        through='UserShortcut',
        related_name='shortcut_users',
        blank=True,
        help_text="User's selected dashboard shortcuts."
    )
    is_staff = models.BooleanField(
        default=False,
        help_text='Designates whether the user can log into this admin site.',
    )
    is_active = models.BooleanField(
        default=True,
        help_text=(
            'Designates whether this user should be treated as active. '
            'Unselect this instead of deleting accounts.'
        ),
    )

    objects = AppUserManager()

    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    groups = models.ManyToManyField(
        Group,
        verbose_name='groups',
        blank=True,
        help_text=(
            'The groups this user belongs to. A user will get all permissions '
            'granted to each of their groups.'
        ),
        related_name="appuser_set",
        related_query_name="appuser",
    )
    user_permissions = models.ManyToManyField(
        Permission,
        verbose_name='user permissions',
        blank=True,
        help_text='Specific permissions for this user.',
        related_name="appuser_set",
        related_query_name="appuser",
    )

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.phone})"

    def set_otp(self, otp):
        """
        Set a new OTP code and update the OTP creation timestamp.
        
        Args:
            otp (str): The new OTP code to set
        """
        self.otp_code = otp
        self.otp_created_at = timezone.now()
        self.save(update_fields=["otp_code", "otp_created_at"])

    def is_otp_valid(self, otp, expiry=300):
        """
        Validate the OTP code.
        
        Args:
            otp (str): The OTP code to validate
            expiry (int): Expiry time in seconds (default: 300)
            
        Returns:
            bool: True if OTP is valid, False otherwise
        """
        if not self.otp_code or self.otp_code != otp:
            return False
        if not self.otp_created_at:
            return False
        time_diff = (timezone.now() - self.otp_created_at).total_seconds()
        return time_diff <= expiry

    def get_active_promotions(self):
        """
        Get all currently active promotions assigned to this user.
        
        Returns:
            QuerySet: Active AffiliatePromotion instances assigned to this user
        """
        return self.assigned_promotions.filter(
            is_active=True,
            start_date__lte=timezone.now(),
            end_date__gte=timezone.now()
        )


class AppUserEquipment(models.Model):
    """
    Stores the list of fitness equipment available to a user.
    """
    user = models.OneToOneField(
        AppUser,
        on_delete=models.CASCADE,
        related_name="equipment",
        help_text="The AppUser associated with this equipment list."
    )
    
    EQUIPMENT_CHOICES = [
        ('bands', 'Bands'),
        ('barbell', 'Barbell'),
        ('body only', 'Body Only'),
        ('cable', 'Cable'),
        ('dumbbell', 'Dumbbell'),
        ('e-z curl bar', 'E-Z Curl Bar'),
        ('exercise ball', 'Exercise Ball'),
        ('foam roll', 'Foam Roll'),
        ('kettlebells', 'Kettlebells'),
        ('machine', 'Machine'),
        ('medicine ball', 'Medicine Ball'),
        ('none', 'None'),
        ('other', 'Other'),
    ]

    available_equipment = ArrayField(
        models.CharField(max_length=50, choices=EQUIPMENT_CHOICES),
        blank=True,
        default=list,
        help_text="A list of fitness equipment available to the user."
    )

    def __str__(self):
        return f"Equipment for {self.user.first_name} {self.user.last_name}"


class AppUserInfo(models.Model):
    """
    Additional user information including physical attributes.
    """
    user = models.OneToOneField(
        AppUser,
        on_delete=models.CASCADE,
        related_name="info",
        help_text="The AppUser associated with this extra info.",
        null=True,
        blank=True
    )
    height = models.FloatField(help_text="Height in inches.", null=True, blank=True)
    birthday = models.DateField(help_text="Birthday of the user.", null=True, blank=True)
    weight = models.FloatField(help_text="Weight in pounds.", null=True, blank=True)
    
    SEX_CHOICES = (
        ('M', 'Male'),
        ('F', 'Female'),
        ('O', 'Other')
    )
    sex = models.CharField(
        max_length=1,
        choices=SEX_CHOICES,
        help_text="Sex of the user.",
        null=True, blank=True
    )
    include_cardio = models.BooleanField(
        default=True,
        help_text="User's preference for including cardio in their weekly plan."
    )

    def __str__(self):
        user_display = f"{self.user.first_name} {self.user.last_name} ({self.user.phone})" if self.user else "Anonymous User"
        return f"Info for {user_display}"


class AppUserGoals(models.Model):
    """
    User's wellness goals.
    """
    user = models.OneToOneField(
        AppUser,
        on_delete=models.CASCADE,
        related_name="goals",
        help_text="The AppUser associated with this goal set.",
        null=True,
        blank=True
    )

    GOALS_GENERAL_CHOICES = [
        ('lose_weight', 'Lose weight'),
        ('build_muscle', 'Build muscle'),
        ('get_more_flexible', 'Get more flexible'),
        ('get_stronger', 'Get stronger'),
        ('eat_healthier', 'Eat healthier'),
        ('regulate_energy', 'Regulate energy'),
        ('sleep_better', 'Sleep better'),
        ('manage_stress', 'Manage stress'),
        ('drink_more_water', 'Drink more water'),
    ]

    goals_general = ArrayField(
        models.CharField(max_length=50, choices=GOALS_GENERAL_CHOICES),
        blank=True,
        default=list,
        help_text="The user's chosen general wellness goals."
    )

    def __str__(self):
        user_display = f"{self.user.first_name} {self.user.last_name} ({self.user.phone})" if self.user else "Anonymous User"
        return f"Goals for {user_display}"


class UserGoalDetail(models.Model):
    """
    Specific detail associated with one of a user's general wellness goals.
    """
    app_user_goals = models.ForeignKey(
        AppUserGoals,
        on_delete=models.CASCADE,
        related_name='details',
        help_text="The set of user goals this detail belongs to."
    )
    goal_categories = ArrayField(
        models.CharField(max_length=50, choices=AppUserGoals.GOALS_GENERAL_CHOICES),
        blank=True,
        default=list,
        help_text="The general goal categories this detail pertains to (can be multiple).",
        db_column="goal_category"
    )
    text = models.TextField(
        help_text="The specific detail or plan for the associated goal category."
    )

    class Meta:
        ordering = ['app_user_goals']
        verbose_name = "User Goal Detail"
        verbose_name_plural = "User Goal Details"

    def get_goal_categories_display_names(self):
        if not self.goal_categories:
            return []
        choices_dict = dict(AppUserGoals.GOALS_GENERAL_CHOICES)
        return [choices_dict.get(cat, cat) for cat in self.goal_categories]

    def __str__(self):
        categories_str = ", ".join(self.get_goal_categories_display_names())
        if not categories_str:
            categories_str = "Uncategorized"
        return f"Detail ({categories_str}): {self.text[:30]}..."

class Shortcut(models.Model):
    """
    Defines an available shortcut that can be added to a user's dashboard.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(
        max_length=100,
        help_text="The display name of the shortcut."
    )

    CATEGORY_CHOICES = [
        ('Fitness', 'Fitness'),
        ('Nutrition', 'Nutrition'),
        ('Mind', 'Mind'),
        ('Sleep', 'Sleep'),
        ('Other', 'Other'),
    ]
    category = models.CharField(
        max_length=50,
        choices=CATEGORY_CHOICES,
        help_text="The category the shortcut belongs to."
    )
    action_identifier = models.CharField(
        max_length=100,
        unique=True,
        help_text="A unique key for the frontend to identify the shortcut's action."
    )
    description = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Optional description of what the shortcut does."
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this shortcut is available for users to select."
    )

    def __str__(self):
        return f"{self.name} ({self.category})"

    class Meta:
        ordering = ['category', 'name']
        verbose_name = "Dashboard Shortcut"
        verbose_name_plural = "Dashboard Shortcuts"

class UserShortcut(models.Model):
    """
    Links an AppUser to a Shortcut, storing the display order.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='shortcut_selections',
        help_text="The user who has this shortcut."
    )
    shortcut = models.ForeignKey(
        Shortcut,
        on_delete=models.CASCADE,
        related_name='user_selections',
        help_text="The shortcut selected by the user."
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="The display order of the shortcut on the user's dashboard."
    )
    
    class Meta:
        ordering = ['user', 'order']
        unique_together = ('user', 'shortcut')
        verbose_name = "User Shortcut"
        verbose_name_plural = "User Shortcuts"

    def __str__(self):
        return f"{self.user.phone}'s shortcut: {self.shortcut.name} (Order: {self.order})"

# --- Activity Management Models ---

class Activity(models.Model):
    """
    Template for activities that users can complete.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255, db_index=True)
    description = models.TextField()
    default_point_value = models.IntegerField(db_index=True)

    CATEGORY_CHOICES = [
        ('Fitness', 'Fitness'),
        ('Nutrition', 'Nutrition'),
        ('Sleep', 'Sleep'),
        ('Mind', 'Mind'),
        ('Routine', 'Routine'),
        ('Other', 'Other'),
    ]
    
    category = ArrayField(
        models.CharField(max_length=50, choices=CATEGORY_CHOICES),
        blank=True,
        default=list,
        help_text="Category or categories of the activity."
    )
    
    # Activity type choices based on frontend ActivityTypeHelper.swift
    ACTIVITY_TYPE_CHOICES = [
        # Fitness types
        ('Workout', 'Workout'),
        ('Weight Tracking', 'Weight Tracking'),
        ('Personal Record', 'Personal Record'),
        
        # Nutrition types
        ('Food Log', 'Food Log'),
        ('Water Intake', 'Water Intake'),
        ('Caffeine Log', 'Caffeine Log'),
        ('Alcohol Log', 'Alcohol Log'),
        ('Recipe', 'Recipe'),
        ('Supplement Log', 'Supplement Log'),
        
        # Mind types
        ('Journal', 'Journal'),
        ('Meditation', 'Meditation'),
        ('Breathing', 'Breathing'),
        ('Mood Check', 'Mood Check'),
        ('Emotions Check', 'Emotions Check'),
        ('Energy Level Log', 'Energy Level Log'),
        
        # Sleep types
        ('Sleep Tracking', 'Sleep Tracking'),
        ('Sleep Debt Calculation', 'Sleep Debt Calculation'),
        
        # Other types
        ('Prescription Log', 'Prescription Log'),
        ('Sex Log', 'Sex Log'),
        ('Symptoms Log', 'Symptoms Log'),
        ('Cycle Log', 'Cycle Log'),
        
        # Additional types (for existing data compatibility)
        ('Routine', 'Routine'),
        ('Mindfulness', 'Mindfulness'),
        ('Other', 'Other'),
    ]
    
    # Activity type defines what is displayed in the UI (e.g., "Workout", "Recipe", "Meditation")
    activity_type = models.CharField(
        max_length=50,
        choices=ACTIVITY_TYPE_CHOICES,
        blank=True,
        null=True,
        help_text="The type of activity displayed in the UI."
    )
    
    associated_workout = models.ForeignKey(
        Workout,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='activities',
        verbose_name='Associated Workout'
    )

    associated_reading = models.ForeignKey(
        'ReadingContent',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='activities',
        verbose_name='Associated Reading Content'
    )

    is_archived = models.BooleanField(
        default=False,
        help_text="Set to true to hide this activity template from new selections."
    )

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['name']
        verbose_name_plural = "Activities"


class UserScheduledActivity(models.Model):
    """
    Represents an activity scheduled for a specific user on a specific date.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='scheduled_activities',
        help_text="The user for whom this activity is scheduled."
    )
    activity = models.ForeignKey(
        Activity,
        on_delete=models.PROTECT,
        help_text="The specific activity template scheduled."
    )
    scheduled_date = models.DateField(
        db_index=True,
        help_text="The date this activity is scheduled for completion."
    )
    scheduled_display_time = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Display time for the activity (e.g., 'Morning', '9:30 AM')."
    )
    is_generated = models.BooleanField(
        default=False,
        help_text="True if generated by the system, False if manually added by the user."
    )
    order_in_day = models.PositiveIntegerField(
        default=0,
        help_text="Order of the activity within the scheduled day if multiple activities."
    )
    is_complete = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Indicates if this specific scheduled activity has been completed."
    )
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when this scheduled activity was marked as completed."
    )
    generated_description = models.TextField(
        blank=True,
        null=True,
        help_text="System-generated description for this scheduled activity instance."
    )
    custom_notes = models.TextField(
        blank=True,
        null=True,
        help_text="User's notes specifically for this scheduled instance."
    )

    class Meta:
        ordering = ['user', 'scheduled_date', 'order_in_day']
        unique_together = ('user', 'activity', 'scheduled_date', 'order_in_day')
        verbose_name = "User Scheduled Activity"
        verbose_name_plural = "User Scheduled Activities"

    def __str__(self):
        return f"{self.user.phone} - {self.activity.name} on {self.scheduled_date} ({'Completed' if self.is_complete else 'Pending'})"


class UserCompletedLog(models.Model):
    """
    Records when a user completes an activity.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='completion_logs',
        db_index=True,
        help_text="The user who completed the activity."
    )
    activity = models.ForeignKey(
        Activity,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        help_text="Link to the original activity template, if applicable."
    )
    activity_name_at_completion = models.CharField(
        max_length=255,
        help_text="Denormalized name of the activity as it was when completed."
    )
    description_at_completion = models.TextField(
        blank=True,
        help_text="Denormalized description of the activity as it was when completed."
    )
    completed_at = models.DateTimeField(
        default=timezone.now,
        db_index=True,
        help_text="Timestamp when the activity was marked as completed."
    )
    points_awarded = models.IntegerField(
        help_text="Points actually awarded for this specific completion."
    )
    source_scheduled_activity = models.ForeignKey(
        UserScheduledActivity,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='completion_log_entries',
        help_text="Link to the UserScheduledActivity instance if this completion corresponds to one."
    )
    is_adhoc = models.BooleanField(
        default=False,
        help_text="True if this was an activity completed outside of a pre-defined schedule."
    )
    user_notes_on_completion = models.TextField(
        blank=True,
        null=True,
        help_text="General notes from the user about this specific completion instance."
    )

    class Meta:
        ordering = ['-completed_at']
        verbose_name = "User Completion Log"
        verbose_name_plural = "User Completion Logs"

    def __str__(self):
        return f"{self.user.phone} completed {self.activity_name_at_completion} at {self.completed_at}"

# --- Affiliate Management Models ---

class Affiliate(models.Model):
    """
    Represents a business partner or affiliate.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(
        max_length=255,
        unique=True,
        help_text="Name of the partner brand."
    )
    contact_email = models.EmailField(
        unique=True,
        blank=True,
        null=True,
        help_text="Primary contact email for the affiliate."
    )
    contact_phone = models.CharField(
        validators=[
            RegexValidator(
                regex=r'^\d{10}$',
                message="Phone number must be entered in the format: '1234567890'. Exactly 10 digits allowed."
            )
        ],
        max_length=10,
        blank=True,
        null=True,
        help_text="Contact phone number in 1234567890 format."
    )
    logo = models.ImageField(
        upload_to='affiliate_logos/',
        blank=True,
        null=True,
        help_text="Logo of the affiliate."
    )
    website = models.URLField(
        blank=True,
        null=True,
        help_text="Website URL for the affiliate."
    )
    location = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Location of the affiliate."
    )
    date_joined = models.DateTimeField(default=timezone.now)
    is_active = models.BooleanField(
        default=True,
        help_text="Indicates if the affiliate is active."
    )

    def __str__(self):
        return self.name


class AffiliatePromotionQuerySet(models.QuerySet):
    """
    Custom QuerySet for AffiliatePromotion with active filtering methods.
    """
    def active(self):
        """
        Filter promotions that are currently active based on is_active flag and date range.
        """
        now = timezone.now()
        return self.filter(
            is_active=True,
            start_date__lte=now,
            end_date__gte=now
        )
    
    def for_user(self, user):
        """
        Filter promotions assigned to a specific user.
        """
        return self.filter(assigned_users=user)
    
    def active_for_user(self, user):
        """
        Get active promotions for a specific user.
        """
        return self.active().for_user(user)


class AffiliatePromotionManager(models.Manager):
    """
    Custom manager for AffiliatePromotion model.
    """
    def get_queryset(self):
        return AffiliatePromotionQuerySet(self.model, using=self._db)
    
    def active(self):
        return self.get_queryset().active()
    
    def for_user(self, user):
        return self.get_queryset().for_user(user)
    
    def active_for_user(self, user):
        return self.get_queryset().active_for_user(user)


class AffiliatePromotion(models.Model):
    """
    Represents a promotion or deal offered by an affiliate.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    affiliate = models.ForeignKey(
        Affiliate,
        on_delete=models.CASCADE,
        related_name='promotions'
    )
    title = models.CharField(
        max_length=255,
        help_text="Title of the promotion. (i.e. Free Salad)"
    )
    description = models.TextField(
        help_text="Description of the deal/promotion being offered."
    )
    original_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original price of the product/service before the promotion, in dollars."
    )
    point_value = models.IntegerField(
        default=0,
        help_text="Amount of points this promotions costs."
    )
    product_image = models.ImageField(
        upload_to='affiliate_product_images/',
        blank=True,
        null=True,
        help_text="Image of the product being offered."
    )
    start_date = models.DateTimeField(
        help_text="Start date of the promotion."
    )
    end_date = models.DateTimeField(
        help_text="End date of the promotion."
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Indicates if the promotion is currently active."
    )
    assigned_users = models.ManyToManyField(
        AppUser,
        related_name='assigned_promotions',
        blank=True,
        help_text="Users who are assigned this promotion."
    )

    # Custom manager
    objects = AffiliatePromotionManager()

    @property
    def is_currently_active(self):
        """
        Check if the promotion is currently active based on is_active flag and date range.
        
        Returns:
            bool: True if promotion is currently active, False otherwise
        """
        if not self.is_active:
            return False
        
        now = timezone.now()
        return self.start_date <= now <= self.end_date

    @property
    def days_until_expiry(self):
        """
        Calculate days until promotion expires.
        
        Returns:
            int: Days until expiry (negative if expired)
        """
        now = timezone.now()
        delta = self.end_date - now
        return delta.days

    def __str__(self):
        return f"{self.title} by {self.affiliate.name}"


class AffiliatePromotionRedemption(models.Model):
    """
    Records when a user redeems an affiliate promotion.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    promotion = models.ForeignKey(
        AffiliatePromotion,
        on_delete=models.CASCADE,
        related_name='redemptions'
    )
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='promotion_redemptions',
        null=True,
        blank=True
    )
    redeemed_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Timestamp of when the promotion was redeemed."
    )

    class Meta:
        unique_together = ('promotion', 'user')

    def __str__(self):
        user_display = self.user.phone if self.user else "Anonymous User"
        return f"{user_display} claimed {self.promotion.title}"


class UserProductQuerySet(models.QuerySet):
    """
    Custom QuerySet for UserProduct with filtering methods.
    """
    def active(self):
        """Filter products that are currently active."""
        return self.filter(status='active')
    
    def by_category(self, category):
        """Filter products by category."""
        return self.filter(category=category)
    
    def recent(self, days=30):
        """Filter products redeemed within the last N days."""
        cutoff_date = timezone.now() - timezone.timedelta(days=days)
        return self.filter(redeemed_at__gte=cutoff_date)


class UserProductManager(models.Manager):
    """
    Custom manager for UserProduct model.
    """
    def get_queryset(self):
        return UserProductQuerySet(self.model, using=self._db)
    
    def active(self):
        return self.get_queryset().active()
    
    def by_category(self, category):
        return self.get_queryset().by_category(category)
    
    def recent(self, days=30):
        return self.get_queryset().recent(days)


class UserProduct(models.Model):
    """
    Tracks products/services that users have redeemed from affiliate promotions.
    This provides a dedicated tracking system for the "My Products" section.
    """
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('expired', 'Expired'),
        ('cancelled', 'Cancelled'),
        ('suspended', 'Suspended'),
    ]
    
    CATEGORY_CHOICES = [
        ('Fitness', 'Fitness'),
        ('Nutrition', 'Nutrition'),
        ('Health', 'Health'),
        ('Wellness', 'Wellness'),
        ('Beauty', 'Beauty'),
        ('Supplements', 'Supplements'),
        ('Food', 'Food'),
        ('Other', 'Other'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='user_products',
        help_text="The user who owns this product."
    )
    
    # Reference to original promotion and redemption for audit trail
    source_promotion = models.ForeignKey(
        AffiliatePromotion,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='user_products',
        help_text="The original promotion that was redeemed (nullable for data integrity)."
    )
    source_redemption = models.OneToOneField(
        AffiliatePromotionRedemption,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='user_product',
        help_text="The redemption record that created this product."
    )
    
    # Denormalized product data for performance and stability
    product_name = models.CharField(
        max_length=255,
        help_text="Name of the product/service (denormalized from promotion title)."
    )
    product_description = models.TextField(
        blank=True,
        help_text="Description of the product/service (denormalized from promotion)."
    )
    product_image = models.ImageField(
        upload_to='user_product_images/',
        blank=True,
        null=True,
        help_text="Image of the product (copied from promotion or custom uploaded)."
    )
    category = models.CharField(
        max_length=50,
        choices=CATEGORY_CHOICES,
        default='Other',
        help_text="Category of the product for organization in UI."
    )
    
    # Product status and lifecycle tracking
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='active',
        help_text="Current status of the user's product."
    )
    
    # Timestamps
    redeemed_at = models.DateTimeField(
        help_text="When the user redeemed this product (copied from redemption)."
    )
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When this product expires (if applicable)."
    )
    last_used_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the user last interacted with this product."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Additional tracking fields
    affiliate_name = models.CharField(
        max_length=255,
        help_text="Name of the affiliate (denormalized for display)."
    )
    points_spent = models.IntegerField(
        default=0,
        help_text="Points spent to redeem this product."
    )
    original_value = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original monetary value of the product."
    )
    
    # User notes and customization
    user_notes = models.TextField(
        blank=True,
        help_text="Personal notes the user can add about this product."
    )
    is_favorite = models.BooleanField(
        default=False,
        help_text="Whether the user has marked this as a favorite product."
    )

    # Custom manager
    objects = UserProductManager()

    class Meta:
        ordering = ['-redeemed_at']
        verbose_name = "User Product"
        verbose_name_plural = "User Products"
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', 'category']),
            models.Index(fields=['user', 'redeemed_at']),
        ]

    def save(self, *args, **kwargs):
        """
        Override save to automatically set category based on affiliate/promotion data.
        """
        if not self.category or self.category == 'Other':
            self.category = self._determine_category()
        super().save(*args, **kwargs)

    def _determine_category(self):
        """
        Automatically determine product category based on promotion data.
        """
        if self.source_promotion:
            title = self.source_promotion.title.lower()
            description = self.source_promotion.description.lower()
            
            # Category mapping based on keywords
            category_keywords = {
                'Nutrition': ['protein', 'supplement', 'vitamin', 'meal', 'food', 'nutrition', 'diet'],
                'Fitness': ['workout', 'gym', 'fitness', 'exercise', 'training', 'muscle'],
                'Health': ['therapy', 'medical', 'health', 'wellness', 'doctor', 'treatment'],
                'Beauty': ['beauty', 'skin', 'cosmetic', 'facial', 'moisturizer', 'cream'],
                'Supplements': ['supplement', 'vitamin', 'mineral', 'probiotic', 'omega'],
            }
            
            for category, keywords in category_keywords.items():
                if any(keyword in title or keyword in description for keyword in keywords):
                    return category
        
        return 'Other'

    @property
    def is_expired(self):
        """Check if the product has expired."""
        if not self.expires_at:
            return False
        return timezone.now() > self.expires_at

    @property
    def days_until_expiry(self):
        """Get days until expiry (negative if expired)."""
        if not self.expires_at:
            return None
        delta = self.expires_at - timezone.now()
        return delta.days

    def mark_as_used(self):
        """Update the last_used_at timestamp."""
        self.last_used_at = timezone.now()
        self.save(update_fields=['last_used_at'])

    def deactivate(self, reason='cancelled'):
        """Deactivate the product."""
        if reason in dict(self.STATUS_CHOICES):
            self.status = reason
            self.save(update_fields=['status'])

    def __str__(self):
        return f"{self.user.first_name}'s {self.product_name} ({self.status})"

# --- Friend Group Models ---

class FriendGroup(models.Model):
    """
    Represents a group of users who can interact and share activities.
    """
    name = models.CharField(
        max_length=255,
        help_text="Name of the friend group."
    )
    date_created = models.DateTimeField(
        auto_now_add=True,
        help_text="Timestamp when the friend group was created."
    )
    members = models.ManyToManyField(
        AppUser,
        through='Member',
        related_name='friend_groups',
        help_text="Members of the friend group."
    )
    cover_image = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Cover image asset name for the friend group (e.g., 'friendgroupimage0')."
    )

    def __str__(self):
        return self.name


class Member(models.Model):
    """
    Represents a user's membership in a friend group.
    """
    friend_group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name='friend_group_members',
        help_text="The friend group to which this membership belongs."
    )
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='group_memberships',
        help_text="Reference to the AppUser who is a member of the friend group.",
        null=True,
        blank=True
    )
    date_joined = models.DateTimeField(
        auto_now_add=True,
        help_text="Timestamp when the user joined the friend group."
    )
    isAdmin = models.BooleanField(
        default=False,
        help_text="Designates whether this member is an admin of the friend group."
    )

    def __str__(self):
        user_name = f"{self.user.first_name} {self.user.last_name}" if self.user else "Anonymous"
        return f"{user_name} in {self.friend_group.name}"


class FriendGroupEvent(models.Model):
    """
    Represents an event occurring within a FriendGroup.
    """
    EVENT_TYPES = [
        ('MEMBER_JOINED', 'Member Joined'),
        ('MEMBER_LEFT', 'Member Left'),
        ('ACTIVITY_COMPLETED', 'Activity Completed'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    friend_group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name='events',
        help_text="The friend group where the event occurred."
    )
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='friend_group_events',
        help_text="The user associated with the event.",
        null=True,
        blank=True
    )
    event_type = models.CharField(
        max_length=50,
        choices=EVENT_TYPES,
        db_index=True,
        help_text="The type of event that occurred."
    )
    timestamp = models.DateTimeField(
        default=timezone.now,
        db_index=True,
        help_text="When the event occurred."
    )
    completed_activity_log = models.ForeignKey(
        UserCompletedLog,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='friend_group_event_links',
        help_text="Link to the UserCompletedLog record, if applicable."
    )

    class Meta:
        ordering = ['-timestamp']
        verbose_name = "Friend Group Event"
        verbose_name_plural = "Friend Group Events"

    def __str__(self):
        user_id = self.user.id if self.user else "Anonymous"
        return f"{self.event_type} event for user {user_id} in group {self.friend_group.name} at {self.timestamp}"


class FriendGroupInvitation(models.Model):
    """
    Represents an invitation to join a friend group.
    """
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('ACCEPTED', 'Accepted'),
        ('DECLINED', 'Declined'),
        ('EXPIRED', 'Expired'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    friend_group = models.ForeignKey(
        FriendGroup,
        on_delete=models.CASCADE,
        related_name='invitations',
        help_text="The friend group for which the invitation is sent."
    )
    inviter = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='sent_invitations',
        help_text="The user who sent the invitation."
    )
    invitee_phone = models.CharField(
        max_length=15,
        help_text="Phone number of the person being invited (format: +11234567890)."
    )
    invitee_user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='received_invitations',
        null=True,
        blank=True,
        help_text="The AppUser if they have an account (populated when invitation is sent)."
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING',
        db_index=True,
        help_text="Current status of the invitation."
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the invitation was created."
    )
    responded_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the invitation was accepted or declined."
    )
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = "Friend Group Invitation"
        verbose_name_plural = "Friend Group Invitations"
        unique_together = ('friend_group', 'invitee_phone')  # Prevent duplicate invitations
        
    def __str__(self):
        return f"Invitation to {self.friend_group.name} for {self.invitee_phone} (Status: {self.status})"
    
    def accept(self):
        """Accept the invitation and add user to friend group."""
        if self.status != 'PENDING':
            raise ValueError("Only pending invitations can be accepted")
            
        if not self.invitee_user:
            raise ValueError("Cannot accept invitation without a valid user")
            
        # Create Member entry
        Member.objects.create(
            friend_group=self.friend_group,
            user=self.invitee_user,
            isAdmin=False
        )
        
        # Update invitation status
        self.status = 'ACCEPTED'
        self.responded_at = timezone.now()
        self.save()
        
        # Create friend group event
        FriendGroupEvent.objects.create(
            friend_group=self.friend_group,
            user=self.invitee_user,
            event_type='MEMBER_JOINED'
        )
        
    def decline(self):
        """Decline the invitation."""
        if self.status != 'PENDING':
            raise ValueError("Only pending invitations can be declined")
            
        self.status = 'DECLINED'
        self.responded_at = timezone.now()
        self.save()


# --- Content Management Models ---

class ContentCard(models.Model):
    """
    Represents a single card of content within a reading piece.
    """
    text = models.TextField(
        help_text="The main content of the card."
    )
    bolded_words = models.JSONField(
        default=list,
        null=True,
        blank=True,
        help_text="Optional list of words that should be bolded in the text."
    )
    reading_content = models.ForeignKey(
        'ReadingContent',
        on_delete=models.CASCADE,
        related_name='content_cards',
        null=True,
        help_text="The ReadingContent this card belongs to."
    )
    order = models.PositiveIntegerField(
        default=0,
        help_text="Order of the card within the reading content."
    )

    def clean(self):
        """
        Ensure that all bolded words exist in the text.
        """
        missing_words = [word for word in self.bolded_words if word not in self.text]
        if missing_words:
            raise ValidationError(
                f"The following bolded words are not present in the text: {', '.join(missing_words)}"
            )

    def __str__(self):
        return f"ContentCardPage with text: {self.text[:30]}..."


class ReadingContent(models.Model):
    """
    Represents a piece of reading content that can be associated with activities.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(
        max_length=255,
        help_text="Title of the reading content."
    )
    duration = models.DurationField(
        blank=True,
        default=datetime.timedelta(0)
    )
    description = models.TextField(
        blank=True,
        null=True,
        help_text="Description of the reading content."
    )
    cover_image = models.ImageField(
        upload_to='cover_images/',
        blank=True,
        null=True,
        help_text="Cover image for the reading content."
    )

    CATEGORY_CHOICES = [
        ('Fitness', 'Fitness'),
        ('Nutrition', 'Nutrition'),
        ('Sleep', 'Sleep'),
        ('Mind', 'Mind'),
    ]
    
    category = ArrayField(
        models.CharField(max_length=50, choices=CATEGORY_CHOICES),
        blank=True,
        default=list,
        help_text="Category or categories of the reading content."
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Timestamp when the reading content was created."
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Timestamp when the reading content was last updated."
    )

    def __str__(self):
        return self.title

# --- Emotion Tracking Models ---

class AppUserCurrentEmotion(models.Model):
    """
    Tracks a user's current emotional state.
    """
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='current_emotions',
        null=True,
        blank=True
    )
    emotion = models.CharField(
        max_length=20,
        default='neutral'
    )
    intensity = models.IntegerField(
        default=5
    )
    cause = models.TextField(
        default=''
    )
    biggest_impact = models.TextField(
        default=''
    )
    tracked_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        ordering = ['-tracked_at']

    def __str__(self):
        user_name = f"{self.user.first_name} {self.user.last_name}" if self.user else "Anonymous"
        return f"Current emotion for {user_name} at {self.tracked_at}"


class AppUserDailyEmotion(models.Model):
    """
    Tracks a user's daily emotional state.
    """
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='daily_emotions',
        null=True,
        blank=True
    )
    emotion = models.CharField(
        max_length=20,
        default='neutral'
    )
    intensity = models.IntegerField(
        default=5
    )
    cause = models.TextField(
        default=''
    )
    biggest_impact = models.TextField(
        default=''
    )
    date = models.DateField(
        auto_now_add=True
    )
    tracked_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        ordering = ['-tracked_at']
        unique_together = ['user', 'date']

    def __str__(self):
        user_name = f"{self.user.first_name} {self.user.last_name}" if self.user else "Anonymous"
        return f"Daily emotion for {user_name} on {self.date}"


# --- User Routine Models ---

class Routine(models.Model):
    """
    Represents a user-defined routine containing a series of steps.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='routines',
        help_text="The user who owns this routine."
    )
    title = models.CharField(
        max_length=255,
        help_text="The title of the routine."
    )
    description = models.TextField(
        blank=True,
        help_text="A description of the routine."
    )
    scheduled_time = models.TimeField(
        blank=True,
        null=True,
        help_text="The time at which this routine is scheduled."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.first_name}'s Routine: {self.title}"

    class Meta:
        ordering = ['user', 'created_at']
        unique_together = ('user', 'title')
        verbose_name = "User Routine"
        verbose_name_plural = "User Routines"


class RoutineStep(models.Model):
    """
    Represents a single step within a user's routine.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    routine = models.ForeignKey(
        Routine,
        on_delete=models.CASCADE,
        related_name='steps',
        help_text="The routine this step belongs to."
    )
    name = models.CharField(
        max_length=255,
        help_text="The name of the routine step."
    )
    icon = models.CharField(
        max_length=50,
        blank=True,
        help_text="Icon name (e.g., from SF Symbols) for the step."
    )
    order = models.PositiveIntegerField(
        help_text="The order of this step within the routine."
    )

    def __str__(self):
        return f"{self.order}: {self.name}"

    class Meta:
        ordering = ['routine', 'order']
        unique_together = ('routine', 'order')
        verbose_name = "Routine Step"
        verbose_name_plural = "Routine Steps"


# --- User Exercise Performance Models ---

class UserExerciseMax(models.Model):
    """
    Tracks the 1-rep maximum (1RM) for a specific user and exercise.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='exercise_maxes',
        help_text="The user for whom this 1RM is recorded."
    )
    exercise = models.ForeignKey(
        'fitness.Exercise',  # Use string reference to avoid circular import issues at parse time
        on_delete=models.CASCADE,
        related_name='user_maxes',
        help_text="The exercise for which this 1RM is recorded."
    )
    one_rep_max = models.FloatField(
        help_text="The current 1-rep maximum weight (e.g., in lbs or kg)."
    )
    date_recorded = models.DateField(
        default=timezone.now,
        help_text="The date when the current 1RM was achieved or recorded."
    )
    previous_maxes = models.JSONField(
        default=list,
        blank=True,
        null=True,
        help_text="A list of previous 1-rep maximums, e.g., [{'value': 100, 'date': 'YYYY-MM-DD'}, ...]"
    )
    unit = models.CharField(max_length=10, default='lbs', choices=[('lbs', 'Pounds'), ('kg', 'Kilograms')])
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['user', '-date_recorded', 'exercise']
        # unique_together ensures one current 1RM record per user per exercise.
        # History is stored in the 'previous_maxes' field.
        unique_together = ('user', 'exercise')
        verbose_name = "User Exercise Max"
        verbose_name_plural = "User Exercise Maxes"


    def __str__(self):
        return f"{self.user.first_name} {self.user.last_name}'s 1RM for {self.exercise.name}: {self.one_rep_max}{self.unit} on {self.date_recorded}"


class AppUserFatigueModel(models.Model):
    """
    Tracks the fatigue levels for each muscle group for a specific user.
    Values typically range from 0 (no fatigue) to 1 (complete fatigue).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='muscle_fatigue',
        help_text="The user whose muscle fatigue is being tracked.",
        null=True,
        blank=True
    )
    date_recorded = models.DateTimeField(
        default=timezone.now,
        help_text="When this fatigue measurement was recorded."
    )
    
    # Muscle group fatigue levels
    quadriceps = models.FloatField(
        default=0.0,
        help_text="Fatigue level for quadriceps (0-1)"
    )
    abdominals = models.FloatField(
        default=0.0,
        help_text="Fatigue level for abdominals (0-1)"
    )
    abductors = models.FloatField(
        default=0.0,
        help_text="Fatigue level for abductors (0-1)"
    )
    adductors = models.FloatField(
        default=0.0,
        help_text="Fatigue level for adductors (0-1)"
    )
    biceps = models.FloatField(
        default=0.0,
        help_text="Fatigue level for biceps (0-1)"
    )
    calves = models.FloatField(
        default=0.0,
        help_text="Fatigue level for calves (0-1)"
    )
    cardiovascular = models.FloatField(
        default=0.0,
        help_text="Fatigue level for cardiovascular system (0-1)"
    )
    chest = models.FloatField(
        default=0.0,
        help_text="Fatigue level for chest (0-1)"
    )
    forearms = models.FloatField(
        default=0.0,
        help_text="Fatigue level for forearms (0-1)"
    )
    full_body = models.FloatField(
        default=0.0,
        help_text="Overall full body fatigue level (0-1)"
    )
    glutes = models.FloatField(
        default=0.0,
        help_text="Fatigue level for glutes (0-1)"
    )
    hamstrings = models.FloatField(
        default=0.0,
        help_text="Fatigue level for hamstrings (0-1)"
    )
    lats = models.FloatField(
        default=0.0,
        help_text="Fatigue level for lats (0-1)"
    )
    lower_back = models.FloatField(
        default=0.0,
        help_text="Fatigue level for lower back (0-1)"
    )
    middle_back = models.FloatField(
        default=0.0,
        help_text="Fatigue level for middle back (0-1)"
    )
    neck = models.FloatField(
        default=0.0,
        help_text="Fatigue level for neck (0-1)"
    )
    shoulders = models.FloatField(
        default=0.0,
        help_text="Fatigue level for shoulders (0-1)"
    )
    traps = models.FloatField(
        default=0.0,
        help_text="Fatigue level for traps (0-1)"
    )
    triceps = models.FloatField(
        default=0.0,
        help_text="Fatigue level for triceps (0-1)"
    )

    class Meta:
        ordering = ['-date_recorded']
        verbose_name = "User Muscle Fatigue"
        verbose_name_plural = "User Muscle Fatigue Records"

    def __str__(self):
        user_display = f"{self.user.first_name} {self.user.last_name} ({self.user.phone})" if self.user else "Anonymous User"
        return f"Fatigue Model for {user_display} recorded on {self.date_recorded.strftime('%Y-%m-%d %H:%M')}"

    def clean(self):
        """
        Validate that all fatigue values are between 0 and 1.
        """
        for field in self._meta.fields:
            if isinstance(field, models.FloatField) and field.name not in ['id']:
                value = getattr(self, field.name)
                if value < 0 or value > 1:
                    raise ValidationError(f"{field.name} fatigue level must be between 0 and 1")


# --- User Journal Models ---

class JournalEntry(models.Model):
    """
    Represents a user's journal entry with title, content, and timestamps.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        AppUser,
        on_delete=models.CASCADE,
        related_name='journal_entries',
        help_text="The user who created this journal entry."
    )
    title = models.CharField(
        max_length=255,
        help_text="The title of the journal entry."
    )
    content = models.TextField(
        help_text="The main content/body of the journal entry."
    )
    date_created = models.DateField(
        default=timezone.now,
        help_text="The date when this journal entry was created."
    )
    time_created = models.TimeField(
        default=timezone.now,
        help_text="The time when this journal entry was created."
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Full timestamp when the journal entry was created."
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Full timestamp when the journal entry was last updated."
    )

    class Meta:
        ordering = ['-date_created', '-time_created']
        verbose_name = "Journal Entry"
        verbose_name_plural = "Journal Entries"

    def __str__(self):
        user_display = f"{self.user.first_name} {self.user.last_name}" if self.user else "Anonymous User"
        return f"{user_display}'s Journal: {self.title} ({self.date_created})"