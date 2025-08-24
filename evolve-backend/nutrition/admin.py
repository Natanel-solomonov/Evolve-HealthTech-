from django.contrib import admin
from .models import FoodProduct, DailyCalorieTracker, FoodEntry, CustomFood, UserFeedback, AlcoholicBeverage
from django.db import models
from django.db.models import Q
from datetime import datetime
from django.core.paginator import Paginator
from django.core.cache import cache

# Custom paginator to avoid counting for large datasets
class LargePaginator(Paginator):
    """
    Custom paginator that avoids counting for very large datasets
    """
    @property
    def count(self):
        # Cache the count to avoid repeated expensive queries
        cache_key = f'foodproduct_count'
        cached_count = cache.get(cache_key)
        if cached_count is not None:
            return cached_count
        
        # For very large datasets, return an estimated count
        # This prevents timeouts in admin
        try:
            # Try to get actual count with timeout
            count = self.object_list.count()
            # Cache for 1 hour
            cache.set(cache_key, count, 3600)
            return count
        except:
            # If count times out, return estimated count
            estimated_count = 1600000  # Approximate count
            cache.set(cache_key, estimated_count, 3600)
            return estimated_count

# Register your models here.
@admin.register(FoodProduct)
class FoodProductAdmin(admin.ModelAdmin):
    list_display = ('_id', 'product_name', 'brands', 'nutriscore_grade', 'nova_group', 'product_quantity', 'popularity_key')
    list_filter = (
        'nutriscore_grade', 
        'nova_group', 
        'obsolete',
        'brand_owner',
        ('product_quantity', admin.EmptyFieldListFilter),
    )
    search_fields = (
        'product_name', 
        'product_name_en', 
        'brands', 
        'brand_owner',
        '_id',
        'generic_name',
        'ingredients_text'
    )
    readonly_fields = ('_id', 'last_updated_datetime')
    list_per_page = 25  # Increased slightly since we're optimizing other areas
    show_full_result_count = False  # Critical: don't show full count
    list_select_related = False  # Disable since we're using only()
    ordering = ('-popularity_key', 'product_name')
    actions = ['mark_as_obsolete', 'mark_as_active', 'export_selected_products']
    paginator = LargePaginator  # Use our custom paginator
    
    autocomplete_fields = []
    
    fieldsets = (
        ('Basic Information', {
            'fields': (
                '_id', 
                'product_name', 
                'product_name_en',
                'generic_name',
                'brands', 
                'brand_owner',
                'product_quantity', 
                'quantity',
                'serving_size',
                'serving_quantity'
            )
        }),
        ('Nutrition & Health', {
            'fields': (
                'nutriscore_grade', 
                'nutriscore_score',
                'nova_group',
                'nutrition_data_per', 
                'nutriments',
                'nutrition_grades',
                'environmental_score_grade'
            )
        }),
        ('Categories and Classification', {
            'fields': (
                'categories', 
                'categories_tags', 
                'food_groups',
                'food_groups_tags', 
                'pnns_groups_1',
                'pnns_groups_2'
            )
        }),
        ('Ingredients & Allergens', {
            'fields': (
                'ingredients_text',
                'ingredients_n',
                'allergens_tags',
                'traces_tags',
                'additives_tags'
            )
        }),
        ('Product Details', {
            'fields': (
                'countries',
                'origin',
                'packaging',
                'conservation_conditions',
                'preparation'
            ),
            'classes': ('collapse',)
        }),
        ('Data Quality', {
            'fields': (
                'completeness',
                'obsolete',
                'obsolete_since_date',
                'data_quality_tags',
                'popularity_key',
                'scans_n',
                'last_updated_datetime'
            ),
            'classes': ('collapse',)
        }),
    )
    
    def get_queryset(self, request):
        """Highly optimized queryset for large datasets"""
        queryset = super().get_queryset(request)
        
        # Only fetch the minimal fields needed for list display
        queryset = queryset.only(
            '_id', 'product_name', 'brands', 'nutriscore_grade', 
            'nova_group', 'product_quantity', 'popularity_key',
            'brand_owner', 'obsolete', 'last_updated_t'
        )
        
        # Add database hints for better performance
        queryset = queryset.order_by('-popularity_key', 'product_name')
        
        # If there's a search term, don't apply default ordering to avoid slow queries
        search_term = request.GET.get('q')
        if search_term:
            # For searches, limit results aggressively and don't order by popularity
            queryset = queryset.filter(
                Q(product_name__icontains=search_term) |
                Q(product_name_en__icontains=search_term) |
                Q(brands__icontains=search_term) |
                Q(brand_owner__icontains=search_term) |
                Q(_id__icontains=search_term)
            )[:100]  # Limit search results to 100 for performance
        
        return queryset
        
    def get_search_results(self, request, queryset, search_term):
        """Enhanced search functionality with aggressive performance optimization"""
        if search_term:
            # Very limited search to avoid timeout
            queryset = queryset.filter(
                Q(product_name__icontains=search_term) |
                Q(product_name_en__icontains=search_term) |
                Q(brands__icontains=search_term) |
                Q(brand_owner__icontains=search_term) |
                Q(_id__icontains=search_term)
            )[:100]  # Very aggressive limit
        return queryset, False  # Don't use distinct to avoid performance issues
    
    def last_updated_datetime(self, obj):
        """Converts timestamp to datetime"""
        if obj.last_updated_t:
            return datetime.fromtimestamp(obj.last_updated_t).strftime('%Y-%m-%d %H:%M:%S')
        return None
    last_updated_datetime.admin_order_field = 'last_updated_t'
    last_updated_datetime.short_description = 'Last Updated'
    
    @admin.action(description="Mark selected products as obsolete")
    def mark_as_obsolete(self, request, queryset):
        """Mark selected products as obsolete"""
        # Limit bulk actions to avoid timeout
        if queryset.count() > 1000:
            self.message_user(request, "Cannot update more than 1000 products at once. Please filter your selection.", level='ERROR')
            return
        updated = queryset.update(obsolete=True)
        self.message_user(request, f"{updated} products marked as obsolete.")
    
    @admin.action(description="Mark selected products as active")
    def mark_as_active(self, request, queryset):
        """Mark selected products as active (not obsolete)"""
        # Limit bulk actions to avoid timeout
        if queryset.count() > 1000:
            self.message_user(request, "Cannot update more than 1000 products at once. Please filter your selection.", level='ERROR')
            return
        updated = queryset.update(obsolete=False)
        self.message_user(request, f"{updated} products marked as active.")
    
    @admin.action(description="Export selected products")
    def export_selected_products(self, request, queryset):
        """Export selected products (placeholder for future implementation)"""
        if queryset.count() > 100:
            self.message_user(request, "Cannot export more than 100 products at once. Please filter your selection.", level='ERROR')
            return
        self.message_user(request, f"Export functionality for {queryset.count()} products would be implemented here.")

    def changelist_view(self, request, extra_context=None):
        """Override changelist view to handle large datasets efficiently"""
        extra_context = extra_context or {}
        
        # Add warning for large dataset
        extra_context['large_dataset_warning'] = True
        
        # Use cached count to avoid expensive queries
        cache_key = 'foodproduct_count'
        total_count = cache.get(cache_key)
        if total_count is None:
            # Set a default estimated count without querying
            total_count = "1,500,000+ (estimated)"
            cache.set(cache_key, total_count, 3600)
        
        extra_context['total_count'] = total_count
        extra_context['performance_mode'] = True
        extra_context['search_help_text'] = "Search is limited to 100 results for performance. Use specific terms."
        
        return super().changelist_view(request, extra_context)
    
    def has_add_permission(self, request):
        """Disable add permission to prevent accidental manual additions"""
        return False


class FoodEntryInline(admin.TabularInline):
    model = FoodEntry
    extra = 1
    fields = ('food_product', 'serving_size', 'serving_unit', 'calories', 
              'protein', 'carbs', 'fat', 'meal_type', 'time_consumed')
    autocomplete_fields = ['food_product']
    readonly_fields = ('calories', 'protein', 'carbs', 'fat')  # These are auto-calculated


@admin.register(DailyCalorieTracker)
class DailyCalorieTrackerAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'total_calories', 'calorie_goal', 'protein_grams', 'carbs_grams', 'fat_grams')
    list_filter = ('date', 'user')
    search_fields = ('user__first_name', 'user__last_name', 'user__phone')
    readonly_fields = ('total_calories', 'protein_grams', 'carbs_grams', 'fat_grams', 'created_at', 'updated_at')
    date_hierarchy = 'date'
    autocomplete_fields = ['user']
    
    fieldsets = (
        ('User Information', {
            'fields': ('user', 'date')
        }),
        ('Calorie Information', {
            'fields': ('total_calories', 'calorie_goal')
        }),
        ('Macronutrients', {
            'fields': ('protein_grams', 'carbs_grams', 'fat_grams')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    inlines = [FoodEntryInline]
    
    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        return queryset.select_related('user').order_by('-date')


@admin.register(FoodEntry)
class FoodEntryAdmin(admin.ModelAdmin):
    list_display = ('food_product', 'daily_log', 'meal_type', 'calories', 'serving_size', 'serving_unit', 'time_consumed')
    list_filter = ('meal_type', 'daily_log__date', 'daily_log__user')
    search_fields = ('food_product__product_name', 'daily_log__user__first_name', 'daily_log__user__last_name', 'daily_log__user__phone')
    autocomplete_fields = ['food_product', 'daily_log']
    
    fieldsets = (
        ('Log Information', {
            'fields': ('daily_log', 'time_consumed', 'meal_type')
        }),
        ('Food Information', {
            'fields': ('food_product', 'food_name', 'serving_size', 'serving_unit')
        }),
        ('Nutritional Information', {
            'fields': ('calories', 'protein', 'carbs', 'fat'),
            'description': 'These values are auto-calculated from the food product but can be manually overridden.'
        }),
    )
    
    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        return queryset.select_related('daily_log', 'daily_log__user', 'food_product').order_by('-time_consumed')


@admin.register(CustomFood)
class CustomFoodAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'barcode_id', 'calories', 'protein', 'carbs', 'fat', 'created_at')
    list_filter = ('created_at', 'user')
    search_fields = ('name', 'user__first_name', 'user__last_name', 'user__phone', 'barcode_id')
    readonly_fields = ('created_at', 'updated_at')
    autocomplete_fields = ['user']
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('user', 'name', 'barcode_id')
        }),
        ('Macronutrients (per serving)', {
            'fields': ('calories', 'protein', 'carbs', 'fat')
        }),
        ('Micronutrients (per serving)', {
            'fields': ('calcium', 'iron', 'potassium', 'vitamin_a', 'vitamin_c', 'vitamin_b12'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        return queryset.select_related('user').order_by('-created_at')


@admin.register(AlcoholicBeverage)
class AlcoholicBeverageAdmin(admin.ModelAdmin):
    list_display = [
        '_id', 
        'name', 
        'brand', 
        'category', 
        'alcohol_content_percent', 
        'calories', 
        'popularity_score'
    ]
    list_filter = [
        'category',
        'alcohol_content_percent',
        'brand'
    ]
    search_fields = [
        'name', 
        'brand', 
        'description'
    ]
    ordering = ['-popularity_score', 'category', 'name']
    
    fieldsets = (
        ('Basic Information', {
            'fields': (
                '_id',
                'name', 
                'brand',
                'category',
                'description'
            )
        }),
        ('Nutritional Information', {
            'fields': (
                'alcohol_content_percent',
                'alcohol_grams',
                'calories',
                'carbs_grams'
            )
        }),
        ('Serving Information', {
            'fields': (
                'serving_size_ml',
                'serving_description'
            )
        }),
        ('Metadata', {
            'fields': (
                'popularity_score',
                'created_at',
                'updated_at'
            ),
            'classes': ('collapse',)
        })
    )
    
    readonly_fields = ['created_at', 'updated_at']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related()
