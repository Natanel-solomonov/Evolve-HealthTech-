from django.urls import path, include
from rest_framework.routers import DefaultRouter
from api.views import FoodProductByBarcodeView
from .views import (
    FoodProductViewSet, 
    DailyCalorieTrackerViewSet, 
    FoodEntryViewSet, 
    DailyLogDetailView,
    DailyLogHistoryView,
    LogFoodEntryView,
    NutritionHistoryView,
    AlcoholCategoriesView,
    AlcoholBeverageSearchView,
    AlcoholBeverageDetailView,
    LogAlcoholEntryView,
    # Caffeine views
    CaffeineCategoriesView,
    CaffeineProductSearchView,
    CaffeineProductDetailView,
    LogCaffeineEntryView,
    # Water views
    LogWaterView,
    WaterSettingsView,
    WaterDailySummaryView,
    WaterEntryListView,
)

router = DefaultRouter()
router.register(r'food-products', FoodProductViewSet)
router.register(r'daily-calorie-trackers', DailyCalorieTrackerViewSet)
router.register(r'food-entries', FoodEntryViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('daily-log/', DailyLogDetailView.as_view(), name='daily-log-detail'),
    path('daily-logs/', DailyLogHistoryView.as_view(), name='daily-log-history'),
    path('log-food/', LogFoodEntryView.as_view(), name='log-food-entry'),
    path('history/', NutritionHistoryView.as_view(), name='nutrition-history'),
    
    # Alcohol API endpoints
    path('alcoholic-beverages/categories/', AlcoholCategoriesView.as_view(), name='alcohol-categories'),
    path('alcoholic-beverages/search/', AlcoholBeverageSearchView.as_view(), name='alcohol-search'),
    path('alcoholic-beverages/log/', LogAlcoholEntryView.as_view(), name='log-alcohol-entry'),
    path('alcoholic-beverages/<str:_id>/', AlcoholBeverageDetailView.as_view(), name='alcohol-detail'),
    
    # Caffeine API endpoints
    path('caffeine-products/categories/', CaffeineCategoriesView.as_view(), name='caffeine-categories'),
    path('caffeine-products/search/', CaffeineProductSearchView.as_view(), name='caffeine-search'),
    path('caffeine-products/log/', LogCaffeineEntryView.as_view(), name='log-caffeine-entry'),
    path('caffeine-products/<str:_id>/', CaffeineProductDetailView.as_view(), name='caffeine-detail'),
    
    # Water API endpoints
    path('water-entries/', WaterEntryListView.as_view(), name='water-entry-list'),
    path('water-entries/log_water/', LogWaterView.as_view(), name='log-water'),
    path('water-entries/settings/', WaterSettingsView.as_view(), name='water-settings'),
    path('water-entries/daily_summary/', WaterDailySummaryView.as_view(), name='water-daily-summary'),
] 