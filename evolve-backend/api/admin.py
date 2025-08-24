from django.contrib import admin
from django import forms
from django.utils.html import format_html
from django.urls import reverse
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.db import models
import datetime

# Model imports
from .models import (
    Activity, Exercise, Workout, WorkoutExercise,
    AppUser, AppUserInfo, AppUserGoals, UserGoalDetail, Affiliate,
    AffiliatePromotion, AffiliatePromotionRedemption,
    FriendGroup, Member, ContentCard, ReadingContent,
    AppUserCurrentEmotion, AppUserDailyEmotion, FriendGroupEvent,
    UserScheduledActivity, UserCompletedLog, UserExerciseMax, AppUserFatigueModel,
    Shortcut, UserShortcut, Routine, RoutineStep, JournalEntry, UserProduct
)
from fitness.models import ExerciseTransferCoefficient
from nutrition.models import DailyCalorieTracker


# --- Content Related Admin Classes ---

class ContentCardInline(admin.TabularInline):
    """Inline admin for ContentCard model."""
    model = ContentCard
    fields = ('text', 'bolded_words', 'order')
    extra = 1
    ordering = ('order',)

    class ContentCardInlineForm(forms.ModelForm):
        class Meta:
            model = ContentCard
            fields = '__all__'
            widgets = {
                'text': forms.Textarea(attrs={'rows': 2}),
            }
        class Media:
            js = ('api/admin/js/char_count.js',)
    form = ContentCardInlineForm

@admin.register(ReadingContent)
class ReadingContentAdmin(admin.ModelAdmin):
    """Admin interface for ReadingContent model."""
    list_display = ('id', 'title', 'duration', 'description', 'cover_image', 'display_cover_image', 'category', 'created_at', 'updated_at')
    fields = ('title', 'duration', 'description', 'cover_image', 'category')
    search_fields = ('title', 'description', 'category')
    list_filter = ('created_at', 'updated_at', 'category')
    inlines = [ContentCardInline]
    
    def display_cover_image(self, obj):
        if obj.cover_image:
            return format_html('<img src="{}" width="100" />', obj.cover_image.url)
        return "No Image"
    display_cover_image.short_description = 'Cover Image Preview'

# --- Activity and Fitness Related Admin Classes ---

@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    """Admin interface for Activity model."""
    list_display = ('name', 'id', 'default_point_value', 'category_display', 'activity_type', 'associated_workout_link', 'associated_reading_link', 'is_archived')
    list_filter = ('is_archived', 'default_point_value', 'activity_type', 'category')
    search_fields = ('name', 'description', 'category', 'activity_type')
    autocomplete_fields = ['associated_workout', 'associated_reading']
    readonly_fields = ('id',)
    fieldsets = (
        (None, {'fields': ('id', 'name', 'description', 'default_point_value')}),
        ('Categorization & Associations', {'fields': ('category', 'activity_type', 'associated_workout', 'associated_reading')}),
        ('Status', {'fields': ('is_archived',)}),
    )

    def category_display(self, obj):
        return ", ".join(obj.category) if obj.category else '-'
    category_display.short_description = 'Category'

    def associated_workout_link(self, obj):
        if obj.associated_workout:
            link = reverse("admin:fitness_workout_change", args=[obj.associated_workout.id])
            return format_html('<a href="{}">{}</a>', link, obj.associated_workout)
        return "-"
    associated_workout_link.short_description = 'Associated Workout'
    associated_workout_link.admin_order_field = 'associated_workout'

    def associated_reading_link(self, obj):
        if obj.associated_reading:
            link = reverse("admin:api_readingcontent_change", args=[obj.associated_reading.id])
            return format_html('<a href="{}">{}</a>', link, obj.associated_reading)
        return "-"
    associated_reading_link.short_description = 'Associated Reading Content'
    associated_reading_link.admin_order_field = 'associated_reading'

class ExerciseTransferCoefficientInline(admin.TabularInline):
    """Inline admin for ExerciseTransferCoefficient model."""
    model = ExerciseTransferCoefficient
    fk_name = 'from_exercise'
    extra = 1
    fields = ('to_exercise', 'coefficient', 'derivation_method', 'notes')
    autocomplete_fields = ['to_exercise']
    verbose_name = "Transfer Coefficient (From)"
    verbose_name_plural = "Transfer Coefficients (From)"

class ExerciseTransferCoefficientToInline(admin.TabularInline):
    """Inline admin for ExerciseTransferCoefficient model showing incoming transfers."""
    model = ExerciseTransferCoefficient
    fk_name = 'to_exercise'
    extra = 1
    fields = ('from_exercise', 'coefficient', 'derivation_method', 'notes')
    autocomplete_fields = ['from_exercise']
    verbose_name = "Transfer Coefficient (To)"
    verbose_name_plural = "Transfer Coefficients (To)"

@admin.register(Exercise)
class ExerciseAdmin(admin.ModelAdmin):
    """Admin interface for Exercise model."""
    list_display = ('name', 'id', 'level', 'category', 'equipment', 'cluster', 'mechanic', 'force', 'isCardio', 'isDiagnostic', 'display_picture1_thumbnail', 'display_picture2_thumbnail')
    list_filter = ('level', 'category', 'equipment', 'cluster', 'mechanic', 'force', 'isCardio', 'isDiagnostic')
    search_fields = ('name', 'primary_muscles', 'secondary_muscles', 'instructions', 'id')
    inlines = [ExerciseTransferCoefficientInline, ExerciseTransferCoefficientToInline]
    readonly_fields = ('id', 'display_picture1_preview', 'display_picture2_preview')
    fieldsets = (
        (None, {'fields': ('id', 'name', 'category', 'level', 'equipment')}),
        ('Details', {'fields': ('force', 'mechanic', 'isCardio', 'isDiagnostic', 'cluster')}),
        ('Muscles & Instructions', {'fields': ('primary_muscles', 'secondary_muscles', 'instructions')}),
        ('Images', {'fields': ('picture1', 'display_picture1_preview', 'picture2', 'display_picture2_preview')}),
    )

    def _display_image(self, image_field, max_height="50px"):
        if image_field and hasattr(image_field, 'url'):
            return format_html('<img src="{}" style="max-height: {}; max-width: {};" />', image_field.url, max_height, max_height)
        return "No Image"

    def display_picture1_thumbnail(self, obj):
        return self._display_image(obj.picture1)
    display_picture1_thumbnail.short_description = 'Pic1'

    def display_picture2_thumbnail(self, obj):
        return self._display_image(obj.picture2)
    display_picture2_thumbnail.short_description = 'Pic2'

    def display_picture1_preview(self, obj):
        return self._display_image(obj.picture1, max_height="200px")
    display_picture1_preview.short_description = 'Picture 1 Preview'

    def display_picture2_preview(self, obj):
        return self._display_image(obj.picture2, max_height="200px")
    display_picture2_preview.short_description = 'Picture 2 Preview'

class WorkoutExerciseInline(admin.TabularInline):
    """Inline admin for WorkoutExercise model."""
    model = WorkoutExercise
    extra = 1

@admin.register(Workout)
class WorkoutAdmin(admin.ModelAdmin):
    """Admin interface for Workout model."""
    list_display = ('name', 'id', 'duration_display', 'created_at', 'updated_at')
    search_fields = ('name', 'description', 'id')
    inlines = [WorkoutExerciseInline]
    readonly_fields = ('id', 'created_at', 'updated_at')
    fieldsets = (
        (None, {'fields': ('id', 'name', 'description', 'duration')}),
        ('Timestamps', {'fields': ('created_at', 'updated_at'), 'classes': ('collapse',)}),
    )

    def duration_display(self, obj):
        if obj.duration and obj.duration != datetime.timedelta(0):
            return str(obj.duration)
        return "0s or N/A"
    duration_display.short_description = "Duration"
    duration_display.admin_order_field = 'duration'

@admin.register(WorkoutExercise)
class WorkoutExerciseAdmin(admin.ModelAdmin):
    """Admin interface for WorkoutExercise model."""
    list_display = ('id', 'workout_link', 'exercise_link', 'order', 'sets', 'reps', 'weight', 'equipment', 'time_display', 'isCompleted')
    list_filter = ('isCompleted', 'equipment', 'workout__name', 'exercise__name')
    search_fields = ('id', 'workout__name', 'exercise__name', 'equipment')
    ordering = ('workout__name', 'order',)
    readonly_fields = ('id',)
    fields = ('id', 'workout', 'exercise', 'order', 'sets', 'reps', 'weight', 'equipment', 'time', 'isCompleted')
    autocomplete_fields = ['workout', 'exercise']
    list_select_related = ('workout', 'exercise')

    def workout_link(self, obj):
        if obj.workout:
            link = reverse("admin:fitness_workout_change", args=[obj.workout.id])
            return format_html('<a href="{}">{}</a>', link, obj.workout)
        return "-"
    workout_link.short_description = 'Workout'
    workout_link.admin_order_field = 'workout__name'

    def exercise_link(self, obj):
        if obj.exercise:
            link = reverse("admin:fitness_exercise_change", args=[obj.exercise.id])
            return format_html('<a href="{}">{}</a>', link, obj.exercise)
        return "-"
    exercise_link.short_description = 'Exercise'
    exercise_link.admin_order_field = 'exercise__name'

    def time_display(self, obj):
        return str(obj.time) if obj.time else "N/A"
    time_display.short_description = "Time"
    time_display.admin_order_field = 'time'

# --- AppUser Related Admin Classes and Inlines ---

class AppUserInfoInline(admin.TabularInline):
    """Inline admin for AppUserInfo model."""
    model = AppUserInfo
    extra = 1
    max_num = 1

class AssignedPromotionsInline(admin.TabularInline):
    """Inline admin for assigned promotions through relationship."""
    model = AffiliatePromotion.assigned_users.through
    verbose_name = "Assigned Promotion"
    verbose_name_plural = "Assigned Promotions"
    extra = 0
    readonly_fields = ('affiliatepromotion',)
    autocomplete_fields = ['affiliatepromotion']
    can_delete = False



class UserGoalDetailForm(forms.ModelForm):
    goal_categories = forms.MultipleChoiceField(
        choices=AppUserGoals.GOALS_GENERAL_CHOICES,
        widget=forms.CheckboxSelectMultiple,
        required=False
    )
    class Meta:
        model = UserGoalDetail
        fields = '__all__'

class UserGoalDetailInline(admin.TabularInline):
    model = UserGoalDetail
    form = UserGoalDetailForm
    fields = ('goal_categories', 'text')
    extra = 1

class AppUserGoalsForm(forms.ModelForm):
    goals_general = forms.MultipleChoiceField(
        choices=AppUserGoals.GOALS_GENERAL_CHOICES,
        widget=forms.CheckboxSelectMultiple,
        required=False,
        label="General Goals"
    )
    class Meta:
        model = AppUserGoals
        fields = ('goals_general',)

class AppUserGoalsInline(admin.StackedInline):
    """Inline admin for AppUserGoals model."""
    model = AppUserGoals
    form = AppUserGoalsForm
    inlines = []
    extra = 0
    max_num = 1
    show_change_link = True

@admin.register(AppUserGoals)
class AppUserGoalsAdmin(admin.ModelAdmin):
    """Admin interface for AppUserGoals model."""
    form = AppUserGoalsForm
    inlines = [UserGoalDetailInline]
    list_display = ('user',)
    search_fields = ['user__first_name', 'user__last_name', 'user__phone']
    readonly_fields = ('user',)

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')

class DailyCalorieTrackerInline(admin.TabularInline):
    """Inline admin for DailyCalorieTracker model."""
    model = DailyCalorieTracker
    extra = 0
    fields = ('date', 'total_calories', 'calorie_goal', 'protein_grams', 'carbs_grams', 'fat_grams')
    readonly_fields = ('total_calories', 'protein_grams', 'carbs_grams', 'fat_grams')
    ordering = ('-date',)
    max_num = 7
    show_change_link = True

class UserScheduledActivityInline(admin.TabularInline):
    """Inline admin for UserScheduledActivity model."""
    model = UserScheduledActivity
    extra = 0
    fields = ('activity', 'scheduled_date', 'order_in_day', 'is_complete', 'completed_at', 'generated_description', 'custom_notes')
    readonly_fields = ('completed_at', 'is_generated')
    autocomplete_fields = ['activity']
    ordering = ('scheduled_date', 'order_in_day')
    show_change_link = True

class AppUserCurrentEmotionInline(admin.TabularInline):
    """Inline admin for AppUserCurrentEmotion model."""
    model = AppUserCurrentEmotion
    extra = 0
    fields = ('emotion', 'intensity', 'cause', 'biggest_impact', 'tracked_at')
    readonly_fields = ('tracked_at',)
    ordering = ('-tracked_at',)
    max_num = 5
    show_change_link = True

class AppUserDailyEmotionInline(admin.TabularInline):
    """Inline admin for AppUserDailyEmotion model."""
    model = AppUserDailyEmotion
    extra = 0
    fields = ('emotion', 'intensity', 'cause', 'biggest_impact', 'date', 'tracked_at')
    readonly_fields = ('date', 'tracked_at')
    ordering = ('-date',)
    max_num = 7
    show_change_link = True

class UserExerciseMaxInline(admin.TabularInline):
    """Inline admin for UserExerciseMax model."""
    model = UserExerciseMax
    extra = 0
    fields = ('exercise', 'one_rep_max', 'unit', 'date_recorded', 'previous_maxes')
    readonly_fields = ('previous_maxes',)
    autocomplete_fields = ['exercise']
    ordering = ('-date_recorded',)
    show_change_link = True

class AppUserFatigueModelInline(admin.TabularInline):
    """Inline admin for AppUserFatigueModel."""
    model = AppUserFatigueModel
    extra = 0
    fields = (
        'date_recorded', 'quadriceps', 'abdominals', 'abductors', 'adductors',
        'biceps', 'calves', 'cardiovascular', 'chest', 'forearms', 'full_body',
        'glutes', 'hamstrings', 'lats', 'lower_back', 'middle_back', 'neck',
        'shoulders', 'traps', 'triceps'
    )
    readonly_fields = ('date_recorded',)
    ordering = ('-date_recorded',)
    max_num = 5
    show_change_link = True

class UserShortcutInline(admin.TabularInline):
    """Inline admin for managing a user's selected shortcuts."""
    model = UserShortcut
    extra = 1
    fields = ('shortcut', 'order')
    autocomplete_fields = ['shortcut']
    ordering = ('order',)
    verbose_name = "Dashboard Shortcut"
    verbose_name_plural = "Dashboard Shortcuts"

class JournalEntryInline(admin.TabularInline):
    """Inline admin for JournalEntry model."""
    model = JournalEntry
    extra = 0
    fields = ('title', 'content', 'date_created', 'time_created')
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-date_created', '-time_created')
    show_change_link = True
    max_num = 10  # Limit displayed entries to keep the interface manageable

@admin.register(AppUser)
class AppUserAdmin(BaseUserAdmin):
    """Admin interface for AppUser model."""
    list_display = ('first_name', 'last_name', 'id', 'phone', 'backup_email', 'is_staff', 'is_active', 'isOnboarded', 'is_phone_verified', 'date_joined')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'groups', 'isOnboarded', 'is_phone_verified', 'date_joined')
    search_fields = ('phone', 'backup_email', 'first_name', 'last_name', 'id')
    ordering = ('-date_joined', 'phone',)
    filter_horizontal = ('groups', 'user_permissions')

    readonly_fields = ('id', 'last_login', 'date_joined', 'otp_code', 'otp_created_at')

    fieldsets = (
        (None, {'fields': ('id', 'phone', 'backup_email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'is_phone_verified', 'isOnboarded')}),
        ('Security & OTP', {'fields': ('otp_code', 'otp_created_at')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 
                                  'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
        ('Points & Savings', {'fields': ('lifetime_points', 'available_points', 'lifetime_savings')}),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('phone', 'backup_email', 'first_name', 'last_name', 'password'),
        }),
    )

    inlines = [
        AppUserInfoInline,
        AppUserGoalsInline,
        DailyCalorieTrackerInline,
        UserScheduledActivityInline,
        AppUserCurrentEmotionInline,
        AppUserDailyEmotionInline,
        AssignedPromotionsInline,
        UserExerciseMaxInline,
        AppUserFatigueModelInline,
        UserShortcutInline,
        JournalEntryInline
    ]

# --- Affiliate Related Admin Classes ---



class AffiliatePromotionRedemptionInline(admin.TabularInline):
    """Inline admin for AffiliatePromotionRedemption model."""
    model = AffiliatePromotionRedemption
    fields = ('user', 'redeemed_at')
    readonly_fields = ('redeemed_at',)
    extra = 0
    autocomplete_fields = ['user']

class AffiliatePromotionAdmin(admin.ModelAdmin):
    """Admin interface for AffiliatePromotion model."""
    list_display = ('title', 'affiliate', 'start_date', 'end_date', 'is_active')
    search_fields = ('title', 'affiliate__name')
    list_filter = ('is_active', 'affiliate')
    autocomplete_fields = ['affiliate']
    filter_horizontal = ('assigned_users',)
    inlines = [AffiliatePromotionRedemptionInline]

class AffiliateAdmin(admin.ModelAdmin):
    """Admin interface for Affiliate model."""
    list_display = ('name', 'contact_email', 'is_active', 'date_joined')
    search_fields = ('name', 'contact_email')



class AffiliatePromotionRedemptionAdmin(admin.ModelAdmin):
    """Admin interface for AffiliatePromotionRedemption model."""
    list_display = ('promotion', 'user', 'redeemed_at')
    list_filter = ('redeemed_at', 'promotion__affiliate', 'promotion')
    search_fields = ('user__phone', 'user__first_name', 'user__last_name', 'promotion__title')
    readonly_fields = ('redeemed_at',)
    autocomplete_fields = ['promotion', 'user']


@admin.register(UserProduct)
class UserProductAdmin(admin.ModelAdmin):
    """Admin interface for UserProduct model."""
    list_display = (
        'product_name', 'user', 'category', 'status', 'affiliate_name', 
        'points_spent', 'redeemed_at', 'is_favorite'
    )
    list_filter = (
        'status', 'category', 'is_favorite', 'redeemed_at', 'expires_at',
        'source_promotion__affiliate'
    )
    search_fields = (
        'product_name', 'user__phone', 'user__first_name', 'user__last_name',
        'affiliate_name', 'product_description'
    )
    readonly_fields = (
        'source_promotion', 'source_redemption', 'redeemed_at', 'created_at', 
        'updated_at', 'is_expired', 'days_until_expiry'
    )
    autocomplete_fields = ['user']
    
    fieldsets = (
        ('Product Information', {
            'fields': (
                'product_name', 'product_description', 'product_image', 
                'category', 'affiliate_name'
            )
        }),
        ('User & Source', {
            'fields': (
                'user', 'source_promotion', 'source_redemption'
            )
        }),
        ('Status & Lifecycle', {
            'fields': (
                'status', 'redeemed_at', 'expires_at', 'last_used_at',
                'is_expired', 'days_until_expiry'
            )
        }),
        ('Value & Points', {
            'fields': (
                'points_spent', 'original_value'
            )
        }),
        ('User Preferences', {
            'fields': (
                'is_favorite', 'user_notes'
            )
        }),
        ('Timestamps', {
            'fields': (
                'created_at', 'updated_at'
            ),
            'classes': ('collapse',)
        })
    )
    
    actions = ['mark_as_active', 'mark_as_expired', 'mark_as_favorite']
    
    def mark_as_active(self, request, queryset):
        """Mark selected products as active."""
        updated = queryset.update(status='active')
        self.message_user(request, f'{updated} products marked as active.')
    mark_as_active.short_description = "Mark selected products as active"
    
    def mark_as_expired(self, request, queryset):
        """Mark selected products as expired."""
        updated = queryset.update(status='expired')
        self.message_user(request, f'{updated} products marked as expired.')
    mark_as_expired.short_description = "Mark selected products as expired"
    
    def mark_as_favorite(self, request, queryset):
        """Mark selected products as favorites."""
        updated = queryset.update(is_favorite=True)
        self.message_user(request, f'{updated} products marked as favorites.')
    mark_as_favorite.short_description = "Mark selected products as favorites"
    
    def get_queryset(self, request):
        """Optimize queryset with select_related for better performance."""
        return super().get_queryset(request).select_related(
            'user', 'source_promotion', 'source_promotion__affiliate'
        )

# --- FriendGroup Related Admin Classes ---

class MemberInline(admin.TabularInline):
    """Inline admin for Member model."""
    model = Member
    extra = 1
    fields = ('user', 'date_joined', 'isAdmin')
    readonly_fields = ('date_joined',)

class FriendGroupEventInline(admin.TabularInline):
    """Inline admin for FriendGroupEvent model."""
    model = FriendGroupEvent
    extra = 0
    fields = ('timestamp', 'user', 'event_type', 'completed_activity_log')
    readonly_fields = ('timestamp', 'user', 'event_type', 'completed_activity_log')
    can_delete = False
    ordering = ('-timestamp',)

    def has_add_permission(self, request, obj=None):
        return False

@admin.register(FriendGroup)
class FriendGroupAdmin(admin.ModelAdmin):
    """Admin interface for FriendGroup model."""
    list_display = ('name', 'id', 'display_cover_image_thumbnail', 'member_count_display', 'date_created')
    search_fields = ('name', 'id')
    list_filter = ('date_created',)
    fields = ('id', 'name', 'cover_image', 'display_cover_image_preview', 'date_created')
    readonly_fields = ('id', 'date_created', 'display_cover_image_preview', 'get_member_count_for_form')
    inlines = [MemberInline, FriendGroupEventInline]

    def display_cover_image_thumbnail(self, obj):
        if obj.cover_image:
            return format_html('<span style="padding: 4px 8px; background-color: #e8f4fd; border: 1px solid #b8ddf2; border-radius: 4px; font-family: monospace; font-size: 11px; color: #2c5282;">{}</span>', obj.cover_image)
        return "No Asset"
    display_cover_image_thumbnail.short_description = 'Cover Asset'

    def display_cover_image_preview(self, obj):
        if obj.cover_image:
            return format_html(
                '<div style="padding: 12px; border: 1px solid #ddd; border-radius: 8px; background-color: #f9f9f9;">'
                '<strong>Asset Name:</strong><br>'
                '<code style="background-color: #e8f4fd; padding: 4px 8px; border-radius: 4px; font-size: 14px;">{}</code><br><br>'
                '<em style="color: #666; font-size: 12px;">This asset should exist in the iOS app bundle</em>'
                '</div>', 
                obj.cover_image
            )
        return "No Asset Selected"
    display_cover_image_preview.short_description = 'Cover Asset Preview'

    def member_count_display(self, obj):
        return obj.members.count()
    member_count_display.short_description = 'Members'
    member_count_display.admin_order_field = '_member_count'

    def get_member_count_for_form(self, obj):
        return obj.members.count()
    get_member_count_for_form.short_description = 'Number of Members'
    
    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        queryset = queryset.annotate(_member_count=models.Count('members', distinct=True))
        return queryset

# --- Routine Admin ---

class RoutineStepInline(admin.TabularInline):
    """Inline admin for RoutineStep model."""
    model = RoutineStep
    fields = ('name', 'icon', 'order')
    extra = 1
    ordering = ('order',)

@admin.register(Routine)
class RoutineAdmin(admin.ModelAdmin):
    """Admin interface for Routine model."""
    list_display = ('title', 'user', 'scheduled_time', 'created_at', 'updated_at')
    list_filter = ('user', 'created_at', 'updated_at')
    search_fields = ('title', 'description', 'user__first_name', 'user__last_name')
    autocomplete_fields = ['user']
    inlines = [RoutineStepInline]
    readonly_fields = ('created_at', 'updated_at')
    fieldsets = (
        (None, {'fields': ('user', 'title', 'description', 'scheduled_time')}),
        ('Timestamps', {'fields': ('created_at', 'updated_at'), 'classes': ('collapse',)}),
    )



# --- Emotion Related Admin Classes ---

@admin.register(AppUserCurrentEmotion)
class AppUserCurrentEmotionAdmin(admin.ModelAdmin):
    """Admin interface for AppUserCurrentEmotion model."""
    list_display = ('id', 'user', 'emotion', 'intensity', 'tracked_at')
    search_fields = ('user__phone', 'emotion')
    list_filter = ('tracked_at', 'emotion')
    autocomplete_fields = ['user']

@admin.register(AppUserDailyEmotion)
class AppUserDailyEmotionAdmin(admin.ModelAdmin):
    """Admin interface for AppUserDailyEmotion model."""
    list_display = ('id', 'user', 'emotion', 'intensity', 'date', 'tracked_at')
    search_fields = ('user__phone', 'emotion')
    list_filter = ('date', 'tracked_at', 'emotion')
    autocomplete_fields = ['user']

# --- Activity Tracking Admin Classes ---

@admin.register(UserScheduledActivity)
class UserScheduledActivityAdmin(admin.ModelAdmin):
    """Admin interface for UserScheduledActivity model."""
    list_display = ('user', 'activity', 'scheduled_date', 'scheduled_display_time', 'is_complete', 'completed_at', 'is_generated')
    list_filter = ('scheduled_date', 'is_complete', 'is_generated', 'user')
    search_fields = ('user__phone', 'activity__name', 'custom_notes')
    autocomplete_fields = ['user', 'activity']
    readonly_fields = ('id', 'completed_at',)
    fieldsets = (
        ('Schedule Details', {
            'fields': (
                'user',
                'activity',
                'scheduled_date',
                'scheduled_display_time',
                'order_in_day'
            )
        }),
        ('Status & Notes', {
            'fields': (
                'is_complete',
                'completed_at',
                'is_generated',
                'generated_description',
                'custom_notes'
            )
        }),
    )
    list_select_related = ('user', 'activity')

    def user_link(self, obj):
        if obj.user:
            link = reverse("admin:api_appuser_change", args=[obj.user.id])
            return format_html('<a href="{}">{}</a>', link, obj.user)
        return "-"
    user_link.short_description = 'User'
    user_link.admin_order_field = 'user'

    def activity_link(self, obj):
        if obj.activity:
            link = reverse("admin:api_activity_change", args=[obj.activity.id])
            return format_html('<a href="{}">{}</a>', link, obj.activity)
        return "-"
    activity_link.short_description = 'Activity'
    activity_link.admin_order_field = 'activity'

@admin.register(UserCompletedLog)
class UserCompletedLogAdmin(admin.ModelAdmin):
    """Admin interface for UserCompletedLog model."""
    list_display = ('user', 'activity_name_at_completion', 'completed_at', 'points_awarded', 'is_adhoc', 'source_scheduled_activity_link')
    list_filter = ('completed_at', 'is_adhoc', 'user')
    search_fields = ('user__phone', 'user__first_name', 'user__last_name', 'activity_name_at_completion')
    autocomplete_fields = ['user', 'activity', 'source_scheduled_activity']
    readonly_fields = ('completed_at',)
    list_select_related = ('user', 'activity', 'source_scheduled_activity')

    def source_scheduled_activity_link(self, obj):
        if obj.source_scheduled_activity:
            link = reverse("admin:api_userscheduledactivity_change", args=[obj.source_scheduled_activity.id])
            return format_html('<a href="{}">{}</a>', link, obj.source_scheduled_activity)
        return "-"
    source_scheduled_activity_link.short_description = 'Source Scheduled Activity'

# --- Shortcut Admin ---

@admin.register(Shortcut)
class ShortcutAdmin(admin.ModelAdmin):
    """Admin interface for available dashboard shortcuts."""
    list_display = ('name', 'id', 'category', 'action_identifier', 'description', 'is_active')
    list_filter = ('category', 'is_active')
    search_fields = ('name', 'action_identifier', 'description')
    readonly_fields = ('id',)

# --- Journal Admin ---

@admin.register(JournalEntry)
class JournalEntryAdmin(admin.ModelAdmin):
    """Admin interface for JournalEntry model."""
    list_display = ('title', 'user', 'date_created', 'time_created', 'created_at')
    list_filter = ('date_created', 'created_at', 'user')
    search_fields = ('title', 'content', 'user__first_name', 'user__last_name', 'user__phone')
    autocomplete_fields = ['user']
    readonly_fields = ('id', 'created_at', 'updated_at')
    fieldsets = (
        (None, {'fields': ('id', 'user', 'title', 'content')}),
        ('Timestamps', {'fields': ('date_created', 'time_created', 'created_at', 'updated_at')}),
    )
    ordering = ('-date_created', '-time_created')
    list_select_related = ('user',)

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')

# --- Model Registration ---

# Register models that aren't registered with decorators
admin.site.register(ExerciseTransferCoefficient)

# Keep these if their respective Admin classes are not decorated
admin.site.register(Affiliate, AffiliateAdmin)
admin.site.register(AffiliatePromotion, AffiliatePromotionAdmin)
admin.site.register(AffiliatePromotionRedemption, AffiliatePromotionRedemptionAdmin)