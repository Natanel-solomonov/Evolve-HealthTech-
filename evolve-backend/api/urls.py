from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    ActivityListView, ActivityDetailView,
    WorkoutListView, WorkoutDetailView, ExerciseListView, ExerciseDetailView,
    send_otp, verify_otp, complete_user_onboarding,
    AppUserListView, AppUserDetailView, AppUserSimpleListView,
    AffiliateListView, AffiliateDetailView,
    AffiliatePromotionListView, AffiliatePromotionDetailView,
    AffiliatePromotionRedemptionListView, AffiliatePromotionRedemptionDetailView,
    UserProductListView, UserProductDetailView, UserProductStatsView,
    RedeemPromotionView, UserRedemptionHistoryView,
    FriendGroupListView, FriendGroupDetailView,
    MemberListView, MemberDetailView,
    generate_workout,
    DailyCalorieTrackerListView, DailyCalorieTrackerDetailView,
    FoodEntryListView, FoodEntryDetailView,
    FoodProductListView, FoodProductDetailView, FoodProductSearchView, FoodAutocompleteView,
    CustomFoodViewSet,
    ContentCardViewSet, ReadingContentViewSet,
    FriendGroupEventListView, update_user_points, user_affiliate_promotions,
    AppUserGoalsCreateUpdateView,
    AppUserCurrentEmotionListView, AppUserCurrentEmotionDetailView,
    AppUserDailyEmotionListView, AppUserDailyEmotionDetailView,
    UserScheduledActivityListView, UserScheduledActivityDetailView,
    UserCompletedLogListView, UserCompletedLogDetailView,
    logout_view,
    UserBMRView,
    UserDailyLogView,
    FoodProductByBarcodeView,
    # AlcoholicBeverageSearchView, AlcoholicBeverageCategoryView, 
    # AlcoholicBeverageDetailView, AlcoholicBeverageCategoriesListView,
    StreakDataView, ShareStreakView,
    # create_totp_device,
    # verify_totp_device,
    CustomWorkoutAPIView,
    ShortcutViewSet, UserShortcutViewSet, RoutineViewSet,
    JournalEntryListView, JournalEntryDetailView,
    CreateFriendGroupWithInvitationsView, FriendGroupInvitationListView, FriendGroupInvitationDetailView,
    RemoveMemberView
)

from .views_waitlist import (
    WaitlistSignupAPIView,
    WaitlistPositionAPIView,
    UpdateSchoolAPIView,
    UpdateFullNameAPIView,
    WaitlistStatsAPIView,
)

router = DefaultRouter()
router.register(r'content-cards', ContentCardViewSet)
router.register(r'reading-contents', ReadingContentViewSet)
router.register(r'custom-foods', CustomFoodViewSet, basename='customfood')
router.register(r'shortcuts', ShortcutViewSet)
router.register(r'user-shortcuts', UserShortcutViewSet, basename='user-shortcut')
router.register(r'routines', RoutineViewSet, basename='routine')


urlpatterns = [
    # Authentication & User Management
    path('', include(router.urls)),
    path('api-auth/', include('rest_framework.urls', namespace='rest_framework_api_auth')),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/logout/', logout_view, name='auth_logout'),
    path('send-otp/', send_otp, name='send_otp'),
    path('verify-otp/', verify_otp, name='verify_otp'),
    path('complete-onboarding/', complete_user_onboarding, name='complete_user_onboarding'),
    path('waitlist-signup/', WaitlistSignupAPIView.as_view(), name='api_waitlist_signup'),
    path('waitlist/<uuid:user_id>/', WaitlistPositionAPIView.as_view(), name='api_waitlist_position'),
    path('waitlist/<uuid:user_id>/update-school/', UpdateSchoolAPIView.as_view(), name='api_update_school'),
    path('waitlist/<uuid:user_id>/update-full-name/', UpdateFullNameAPIView.as_view(), name='api_update_full_name'),
    path('waitlist-stats/', WaitlistStatsAPIView.as_view(), name='api_waitlist_stats'),

    # User Management
    path('users/', AppUserListView.as_view(), name='appuser-list'),
    path('users/simple/', AppUserSimpleListView.as_view(), name='appuser-simple-list'),
    path('users/<uuid:pk>/', AppUserDetailView.as_view(), name='appuser-detail'),
    path('users/<uuid:user_id>/points/', update_user_points, name='update-user-points'),
    path('users/<uuid:user_id>/affiliate-promotions/', user_affiliate_promotions, name='user-affiliate-promotions'),
    path('users/<uuid:user_id>/goals/', AppUserGoalsCreateUpdateView.as_view(), name='appuser-goals-create-update'),

    # Activity
    path('activities/', ActivityListView.as_view(), name='activity-list'),
    path('activities/<uuid:pk>/', ActivityDetailView.as_view(), name='activity-detail'),
    
    # Workout & Exercise Management
    path('generate-workout/', generate_workout, name='generate-workout'),
    path('workouts/', WorkoutListView.as_view(), name='workout-list'),
    path('workouts/<str:pk>/', WorkoutDetailView.as_view(), name='workout-detail'),
    path('exercises/', ExerciseListView.as_view(), name='exercise-list'),
    path('exercises/<uuid:pk>/', ExerciseDetailView.as_view(), name='exercise-detail'),

    # User Schedule & Completion Tracking
    path('user-schedule/', UserScheduledActivityListView.as_view(), name='user-schedule-list'),
    path('user-schedule/<uuid:pk>/', UserScheduledActivityDetailView.as_view(), name='user-schedule-detail'),
    path('user-completion-logs/', UserCompletedLogListView.as_view(), name='user-completion-log-list'),
    path('user-completion-logs/<uuid:pk>/', UserCompletedLogDetailView.as_view(), name='user-completion-log-detail'),

    # User Journal
    path('journal-entries/', JournalEntryListView.as_view(), name='journal-entry-list'),
    path('journal-entries/<uuid:pk>/', JournalEntryDetailView.as_view(), name='journal-entry-detail'),

    # Nutrition & Food Tracking
    path('food-products/search/', FoodProductSearchView.as_view(), name='foodproduct-search'),
    path('food-products/autocomplete/', FoodAutocompleteView.as_view(), name='foodproduct-autocomplete'),
    path('food-products/barcode/<str:_id>/', FoodProductByBarcodeView.as_view(), name='foodproduct-by-barcode'),
    path('food-products/', FoodProductListView.as_view(), name='foodproduct-list'),
    path('food-products/<str:pk>/', FoodProductDetailView.as_view(), name='foodproduct-detail'),
    path('food-entries/', FoodEntryListView.as_view(), name='foodentry-list'),
    path('food-entries/<int:pk>/', FoodEntryDetailView.as_view(), name='foodentry-detail'),
    path('daily-calorie-trackers/', DailyCalorieTrackerListView.as_view(), name='dailycalorietracker-list'),
    path('daily-calorie-trackers/<int:pk>/', DailyCalorieTrackerDetailView.as_view(), name='dailycalorietracker-detail'),

    # Alcohol Tracking
    # path('alcoholic-beverages/search/', AlcoholicBeverageSearchView.as_view(), name='alcoholic-beverage-search'),
    # path('alcoholic-beverages/categories/', AlcoholicBeverageCategoriesListView.as_view(), name='alcoholic-beverage-categories'),
    # path('alcoholic-beverages/category/<str:category>/', AlcoholicBeverageCategoryView.as_view(), name='alcoholic-beverage-category'),
    # path('alcoholic-beverages/<str:_id>/', AlcoholicBeverageDetailView.as_view(), name='alcoholic-beverage-detail'),

    # Social & Community Features
    path('friend-groups/create-with-invitations/', CreateFriendGroupWithInvitationsView.as_view(), name='friend-group-create-with-invitations'),
    path('friend-groups/', FriendGroupListView.as_view(), name='friend-group-list'),
    path('friend-groups/<int:pk>/', FriendGroupDetailView.as_view(), name='friend-group-detail'),
    path('members/', MemberListView.as_view(), name='member-list'),
    path('members/<int:pk>/', MemberDetailView.as_view(), name='member-detail'),
    path('friend-groups/<int:group_id>/members/<int:member_id>/remove/', RemoveMemberView.as_view(), name='remove-member'),
    path('friend-groups/<int:group_id>/events/', FriendGroupEventListView.as_view(), name='friend-group-event-list'),
    path('friend-group-invitations/', FriendGroupInvitationListView.as_view(), name='friend-group-invitation-list'),
    path('friend-group-invitations/<uuid:pk>/', FriendGroupInvitationDetailView.as_view(), name='friend-group-invitation-detail'),

    # Affiliate & Rewards System
    path('affiliates/', AffiliateListView.as_view(), name='affiliate-list'),
    path('affiliates/<uuid:pk>/', AffiliateDetailView.as_view(), name='affiliate-detail'),
    path('affiliate-promotions/', AffiliatePromotionListView.as_view(), name='affiliate-promotion-list'),
    path('affiliate-promotions/<uuid:pk>/', AffiliatePromotionDetailView.as_view(), name='affiliate-promotion-detail'),
    path('affiliate-promotion-redemptions/', AffiliatePromotionRedemptionListView.as_view(), name='affiliate-promotion-redemption-list'),
    path('affiliate-promotion-redemptions/<uuid:pk>/', AffiliatePromotionRedemptionDetailView.as_view(), name='affiliate-promotion-redemption-detail'),
    
    # User Products (from redeemed promotions)
    path('user-products/', UserProductListView.as_view(), name='user-product-list'),
    path('user-products/<uuid:pk>/', UserProductDetailView.as_view(), name='user-product-detail'),
    path('user-products/stats/', UserProductStatsView.as_view(), name='user-product-stats'),
    
    # Promotion Redemption (user-facing)
    path('redeem-promotion/', RedeemPromotionView.as_view(), name='redeem-promotion'),
    path('redemption-history/', UserRedemptionHistoryView.as_view(), name='redemption-history'),

    # Emotion Tracking
    path('current-emotions/', AppUserCurrentEmotionListView.as_view(), name='current-emotions-list'),
    path('current-emotions/<int:pk>/', AppUserCurrentEmotionDetailView.as_view(), name='current-emotions-detail'),
    path('daily-emotions/', AppUserDailyEmotionListView.as_view(), name='daily-emotions-list'),
    path('daily-emotions/<int:pk>/', AppUserDailyEmotionDetailView.as_view(), name='daily-emotions-detail'),

    # User Profile specific (merged from user_profile_api)
    path('user/bmr/', UserBMRView.as_view(), name='user_bmr'),

    # Streak Tracking
    path('streak/', StreakDataView.as_view(), name='streak-data'),
    path('streak/share/', ShareStreakView.as_view(), name='share-streak'),

    # Nutrition User Daily Log (for NutritionViewModel)
    path('user_daily_log/<uuid:user_id>/<str:date_iso>/', UserDailyLogView.as_view(), name='user_daily_log_by_date'),

    # Custom Workout Generation
    path('custom-workouts/', CustomWorkoutAPIView.as_view(), name='custom-workouts'),
]