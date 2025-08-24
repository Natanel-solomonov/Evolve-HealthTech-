from datetime import date
from rest_framework import serializers
from .models import DailyCalorieTracker, FoodEntry, FoodProduct, CustomFood, UserFeedback, AlcoholicBeverage, CaffeineProduct, WaterEntry
from api.models import AppUser

# --- Nutrition Related Serializers ---

class FoodProductSearchSerializer(serializers.ModelSerializer):
    """
    Ultra-lightweight serializer for search results - only essential fields.
    Optimized for minimal data transfer and maximum speed.
    """
    id = serializers.CharField(source='_id', read_only=True)
    calories = serializers.SerializerMethodField()
    protein = serializers.SerializerMethodField()
    carbs = serializers.SerializerMethodField()
    fat = serializers.SerializerMethodField()
    
    class Meta:
        model = FoodProduct
        fields = [
            'id', 'product_name', 'brands', 'nutriscore_grade',
            'calories', 'protein', 'carbs', 'fat'
        ]

    def get_calories(self, obj):
        return self.get_from_nutriments(obj, 'energy-kcal_100g') or self.get_from_nutriments(obj, 'energy-kcal', 0)

    def get_protein(self, obj):
        return self.get_from_nutriments(obj, 'proteins_100g') or self.get_from_nutriments(obj, 'proteins', 0)

    def get_carbs(self, obj):
        return self.get_from_nutriments(obj, 'carbohydrates_100g') or self.get_from_nutriments(obj, 'carbohydrates', 0)

    def get_fat(self, obj):
        return self.get_from_nutriments(obj, 'fat_100g') or self.get_from_nutriments(obj, 'fat', 0)

    def get_from_nutriments(self, obj, key, default=0):
        """Helper to safely get a value from the nutriments JSON field."""
        if isinstance(obj.nutriments, dict):
            return obj.nutriments.get(key, default)
        return default

#FoodProductSerializer
class FoodProductSerializer(serializers.ModelSerializer):
    """
    Serializer for FoodProduct model, extracting key nutritional information
    from the 'nutriments' JSON field into top-level fields for easy frontend consumption.
    Implements fallback logic: per-serving first, then per-100g, then 0.
    """
    id = serializers.CharField(source='_id', read_only=True)
    calories = serializers.SerializerMethodField()
    protein = serializers.SerializerMethodField()
    carbs = serializers.SerializerMethodField()
    fat = serializers.SerializerMethodField()
    
    # Micronutrients
    calcium = serializers.SerializerMethodField()
    iron = serializers.SerializerMethodField()
    potassium = serializers.SerializerMethodField()
    vitamin_a = serializers.SerializerMethodField()
    vitamin_c = serializers.SerializerMethodField()
    vitamin_b12 = serializers.SerializerMethodField()
    fiber = serializers.SerializerMethodField()
    folate = serializers.SerializerMethodField()
    
    # Indicate whether data is per-serving or per-100g
    nutrition_basis = serializers.SerializerMethodField()

    class Meta:
        model = FoodProduct
        fields = [
            'id', 'product_name', 'brands', 'nutriscore_grade', 'nutriments',
            'calories', 'protein', 'carbs', 'fat',
            'calcium', 'iron', 'potassium', 'vitamin_a', 'vitamin_c', 'vitamin_b12',
            'fiber', 'folate', 'nutrition_basis'
        ]

    def get_from_nutriments(self, obj, key, default=0):
        """Helper to safely get a value from the nutriments JSON field."""
        if isinstance(obj.nutriments, dict):
            return obj.nutriments.get(key, default)
        return default

    def get_nutrition_value_with_fallback(self, obj, serving_key, per_100g_key, default=0):
        """Get nutrition value with fallback logic: serving -> 100g -> default"""
        # First try per-serving value
        serving_value = self.get_from_nutriments(obj, serving_key)
        if serving_value and serving_value > 0:
            return serving_value, 'per_serving'
        
        # Then try per-100g value
        per_100g_value = self.get_from_nutriments(obj, per_100g_key)
        if per_100g_value and per_100g_value > 0:
            return per_100g_value, 'per_100g'
        
        # Finally return default
        return default, 'per_serving'

    def get_calories(self, obj):
        value, _ = self.get_nutrition_value_with_fallback(obj, 'energy-kcal_serving', 'energy-kcal_100g')
        return value

    def get_protein(self, obj):
        value, _ = self.get_nutrition_value_with_fallback(obj, 'proteins_serving', 'proteins_100g')
        return value

    def get_carbs(self, obj):
        value, _ = self.get_nutrition_value_with_fallback(obj, 'carbohydrates_serving', 'carbohydrates_100g')
        return value

    def get_fat(self, obj):
        value, _ = self.get_nutrition_value_with_fallback(obj, 'fat_serving', 'fat_100g')
        return value
        
    def get_calcium(self, obj):
        # Get value in mg (convert from g if needed)
        serving_value = self.get_from_nutriments(obj, 'calcium_serving')
        if serving_value and serving_value > 0:
            return serving_value * 1000 if serving_value < 1 else serving_value
        
        per_100g_value = self.get_from_nutriments(obj, 'calcium_100g')
        if per_100g_value and per_100g_value > 0:
            return per_100g_value * 1000 if per_100g_value < 1 else per_100g_value
        
        return 0

    def get_iron(self, obj):
        value, basis = self.get_nutrition_value_with_fallback(obj, 'iron_serving', 'iron_100g')
        return value

    def get_potassium(self, obj):
        # Get value in mg (convert from g if needed)
        serving_value = self.get_from_nutriments(obj, 'potassium_serving')
        if serving_value and serving_value > 0:
            return serving_value * 1000 if serving_value < 1 else serving_value
        
        per_100g_value = self.get_from_nutriments(obj, 'potassium_100g')
        if per_100g_value and per_100g_value > 0:
            return per_100g_value * 1000 if per_100g_value < 1 else per_100g_value
        
        return 0

    def get_vitamin_a(self, obj):
        # Convert from IU to mcg RAE if needed (1 IU = 0.3 mcg RAE)
        serving_value = self.get_from_nutriments(obj, 'vitamin-a_serving')
        if serving_value and serving_value > 0:
            return serving_value * 0.3 if serving_value > 100 else serving_value
        
        per_100g_value = self.get_from_nutriments(obj, 'vitamin-a_100g')
        if per_100g_value and per_100g_value > 0:
            return per_100g_value * 0.3 if per_100g_value > 100 else per_100g_value
        
        return 0

    def get_vitamin_c(self, obj):
        # Convert from g to mg if needed
        serving_value = self.get_from_nutriments(obj, 'vitamin-c_serving')
        if serving_value and serving_value > 0:
            return serving_value * 1000 if serving_value < 1 else serving_value
        
        per_100g_value = self.get_from_nutriments(obj, 'vitamin-c_100g')
        if per_100g_value and per_100g_value > 0:
            return per_100g_value * 1000 if per_100g_value < 1 else per_100g_value
        
        return 0

    def get_vitamin_b12(self, obj):
        # Convert from g to mcg if needed
        serving_value = self.get_from_nutriments(obj, 'vitamin-b12_serving')
        if serving_value and serving_value > 0:
            return serving_value * 1000000 if serving_value < 1 else serving_value
        
        per_100g_value = self.get_from_nutriments(obj, 'vitamin-b12_100g')
        if per_100g_value and per_100g_value > 0:
            return per_100g_value * 1000000 if per_100g_value < 1 else per_100g_value
        
        return 0

    def get_fiber(self, obj):
        value, _ = self.get_nutrition_value_with_fallback(obj, 'fiber_serving', 'fiber_100g')
        return value

    def get_folate(self, obj):
        value, _ = self.get_nutrition_value_with_fallback(obj, 'folate_serving', 'folate_100g')
        return value

    def get_nutrition_basis(self, obj):
        """Determine if nutrition data is primarily per-serving or per-100g"""
        # Check the main macronutrients to determine basis
        calories_serving = self.get_from_nutriments(obj, 'energy-kcal_serving')
        protein_serving = self.get_from_nutriments(obj, 'proteins_serving')
        carbs_serving = self.get_from_nutriments(obj, 'carbohydrates_serving')
        fat_serving = self.get_from_nutriments(obj, 'fat_serving')
        
        # If any serving values exist and are > 0, consider it per-serving
        if any(val and val > 0 for val in [calories_serving, protein_serving, carbs_serving, fat_serving]):
            return 'per_serving'
        
        # Otherwise, check for 100g values
        calories_100g = self.get_from_nutriments(obj, 'energy-kcal_100g')
        protein_100g = self.get_from_nutriments(obj, 'proteins_100g')
        carbs_100g = self.get_from_nutriments(obj, 'carbohydrates_100g')
        fat_100g = self.get_from_nutriments(obj, 'fat_100g')
        
        if any(val and val > 0 for val in [calories_100g, protein_100g, carbs_100g, fat_100g]):
            return 'per_100g'
        
        return 'per_serving'  # Default fallback


class CustomFoodSerializer(serializers.ModelSerializer):
    """Serializer for the CustomFood model."""
    user = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = CustomFood
        fields = [
            'id', 'user', 'name', 'barcode_id', 'calories', 'protein',
            'carbs', 'fat', 'calcium', 'iron', 'potassium', 'vitamin_a',
            'vitamin_c', 'vitamin_b12', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']


class FoodEntrySerializer(serializers.ModelSerializer):
    """Serializer for FoodEntry model with user phone number handling"""
    user_phone = serializers.SlugRelatedField(
        slug_field='phone',
        queryset=AppUser.objects.all(),
        write_only=True,
        help_text="The AppUser's phone (e.g. +12159136110)"
    )
    daily_log = serializers.PrimaryKeyRelatedField(read_only=True)
    food_product_id = serializers.PrimaryKeyRelatedField(
        source='food_product',
        queryset=FoodProduct.objects.all(),
        write_only=True,
        required=False, # Can be a custom food
        allow_null=True
    )
    custom_food_id = serializers.PrimaryKeyRelatedField(
        source='custom_food',
        queryset=CustomFood.objects.all(),
        write_only=True,
        required=False, # Can be a food product
        allow_null=True
    )

    class Meta:
        model = FoodEntry
        fields = [
            'id', 'user_phone', 'daily_log', 'food_product_id', 'custom_food_id',
            'food_name', 'serving_size', 'serving_unit',
            'calories', 'protein', 'carbs', 'fat',
            'fiber_grams', 'iron_milligrams', 'calcium_milligrams', 'vitamin_a_micrograms',
            'vitamin_c_milligrams', 'vitamin_b12_micrograms', 'folate_micrograms', 'potassium_milligrams',
            # ALCOHOL TRACKING FIELDS
            'alcoholic_beverage', 'alcohol_grams', 'standard_drinks', 'alcohol_category',
            # CAFFEINE TRACKING FIELDS
            'caffeine_product', 'caffeine_mg', 'caffeine_category',
            'meal_type', 'time_consumed',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'daily_log', 'created_at', 'updated_at']
        # Note: Nutritional fields are now writable to support manual entries from diary re-adding

    def validate(self, data):
        # Allow manual entries (where neither food_product nor custom_food is provided)
        # This happens when re-adding foods from diary entries
        has_food_product = bool(data.get('food_product'))
        has_custom_food = bool(data.get('custom_food'))
        
        if has_food_product and has_custom_food:
            raise serializers.ValidationError("Cannot provide both 'food_product_id' and 'custom_food_id'.")
        
        # If neither is provided, ensure we have required nutritional data for manual entry
        if not has_food_product and not has_custom_food:
            food_name = data.get('food_name')
            if not food_name:
                raise serializers.ValidationError("For manual entries, 'food_name' is required.")
        
        return data

    def create(self, validated_data):
        user = validated_data.pop('user_phone')
        consumed = validated_data.get('time_consumed')
        log_date = consumed.date() if consumed else date.today()
        
        # Use the method that handles streak tracking
        daily_log, _ = DailyCalorieTracker.get_or_create_for_date(
            user=user,
            date=log_date
        )
        
        validated_data['daily_log'] = daily_log
        return super().create(validated_data)


class DailyCalorieTrackerSerializer(serializers.ModelSerializer):
    """Serializer for DailyCalorieTracker model with nested FoodEntry details"""
    user_details = serializers.CharField(source='user.phone', read_only=True)
    food_entries = FoodEntrySerializer(many=True, read_only=True)
    
    class Meta:
        model = DailyCalorieTracker
        fields = [
            'id', 'user_details', 'date', 
            'total_calories', 'calorie_goal', 
            'protein_grams', 'carbs_grams', 'fat_grams',
            'fiber_grams', 'iron_milligrams', 'calcium_milligrams', 'vitamin_a_micrograms',
            'vitamin_c_milligrams', 'vitamin_b12_micrograms', 'folate_micrograms', 'potassium_milligrams',
            # ALCOHOL TRACKING FIELDS
            'alcohol_grams', 'standard_drinks',
            # CAFFEINE TRACKING FIELDS
            'caffeine_mg',
            # WATER TRACKING FIELDS
            'water_ml', 'water_goal_ml',
            'created_at', 'updated_at', 'food_entries'
        ]
        read_only_fields = ['total_calories', 'protein_grams', 'carbs_grams', 'fat_grams',
                            'fiber_grams', 'iron_milligrams', 'calcium_milligrams', 
                            'vitamin_a_micrograms', 'vitamin_c_milligrams', 'vitamin_b12_micrograms',
                            'folate_micrograms', 'potassium_milligrams', 
                            # ALCOHOL TRACKING FIELDS
                            'alcohol_grams', 'standard_drinks',
            # CAFFEINE TRACKING FIELDS
            'caffeine_mg',
            # WATER TRACKING FIELDS
            'water_ml',
                            'created_at', 'updated_at'] 

class LogFoodEntrySerializer(serializers.Serializer):
    """
    Serializer for logging a food entry. It takes the necessary identifiers
    (user phone, food product id) and entry details to create a new FoodEntry.
    """
    user_phone = serializers.CharField(
        help_text="The AppUser's phone (e.g. +12159136110)"
    )
    food_product_id = serializers.CharField(
        help_text="The _id of the FoodProduct being logged."
    )
    serving_size = serializers.FloatField(
        help_text="Amount of food consumed (e.g., in grams)."
    )
    meal_type = serializers.ChoiceField(
        choices=['breakfast', 'lunch', 'dinner', 'snack'],
        help_text="The meal category for this entry."
    )
    time_consumed = serializers.DateTimeField(
        required=False,
        help_text="Timestamp when the food was consumed. Defaults to now if not provided."
    )

    def to_internal_value(self, data):
        # Lowercase meal_type for validation
        meal_type = data.get('meal_type')
        if meal_type and isinstance(meal_type, str):
            data['meal_type'] = meal_type.lower()

        return super().to_internal_value(data) 
    #For Redeploy
        return super().to_internal_value(data)


class UserFeedbackSerializer(serializers.ModelSerializer):
    """Serializer for the UserFeedback model."""
    user = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = UserFeedback
        fields = ['id', 'user', 'feedback', 'created_at', 'updated_at']
        read_only_fields = ['id', 'user', 'created_at', 'updated_at'] 


class AlcoholicBeverageSerializer(serializers.ModelSerializer):
    """Serializer for AlcoholicBeverage model"""
    
    class Meta:
        model = AlcoholicBeverage
        fields = [
            '_id', 'name', 'brand', 'category', 'alcohol_content_percent',
            'alcohol_grams', 'calories', 'carbs_grams', 'serving_size_ml',
            'serving_description', 'description', 'popularity_score',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['_id', 'created_at', 'updated_at']


class AlcoholCategorySerializer(serializers.ModelSerializer):
    """Serializer for alcohol categories with count"""
    key = serializers.CharField(source='category')
    name = serializers.CharField(source='category_display')
    icon = serializers.CharField(source='category_icon')
    count = serializers.SerializerMethodField()
    
    class Meta:
        model = AlcoholicBeverage
        fields = ['key', 'name', 'icon', 'count']
    
    def get_count(self, obj):
        """Get count of beverages in this category"""
        return AlcoholicBeverage.objects.filter(category=obj.category).count()


class AlcoholCategoriesResponseSerializer(serializers.Serializer):
    """Response serializer for alcohol categories endpoint"""
    categories = AlcoholCategorySerializer(many=True)


class AlcoholSearchResponseSerializer(serializers.Serializer):
    """Response serializer for alcohol search endpoint"""
    beverages = AlcoholicBeverageSerializer(many=True)
    total_count = serializers.IntegerField()
    has_more = serializers.BooleanField()


class LogAlcoholEntrySerializer(serializers.Serializer):
    """
    Serializer for logging an alcoholic beverage entry.
    """
    user_phone = serializers.CharField(
        help_text="The AppUser's phone (e.g. +12159136110)"
    )
    alcoholic_beverage = serializers.CharField(
        help_text="The _id of the AlcoholicBeverage being logged."
    )
    food_name = serializers.CharField(
        help_text="Name of the alcoholic beverage for display."
    )
    serving_unit = serializers.CharField(
        default="standard drink",
        help_text="Unit of measurement (always 'standard drink')."
    )
    quantity = serializers.IntegerField(
        min_value=1,
        max_value=10,
        help_text="Number of standard drinks consumed."
    )
    meal_type = serializers.ChoiceField(
        choices=['breakfast', 'lunch', 'dinner', 'snack', 'alcohol'],
        default='alcohol',
        required=False,
        help_text="The meal category for this entry. Defaults to 'alcohol' for alcoholic beverages."
    )
    time_consumed = serializers.DateTimeField(
        required=False,
        help_text="Timestamp when the beverage was consumed. Defaults to now if not provided."
    )

    def to_internal_value(self, data):
        # Lowercase meal_type for validation
        meal_type = data.get('meal_type')
        if meal_type and isinstance(meal_type, str):
            data['meal_type'] = meal_type.lower()
        
        # Ensure serving_unit is always "standard drink"
        data['serving_unit'] = 'standard drink'
        
        return super().to_internal_value(data) 


# --- Caffeine Related Serializers ---

class CaffeineProductSerializer(serializers.ModelSerializer):
    """Serializer for CaffeineProduct model"""
    
    class Meta:
        model = CaffeineProduct
        fields = [
            '_id', 'name', 'brand', 'category', 'sub_category', 'flavor_or_variant',
            'serving_size_ml', 'serving_size_desc', 'caffeine_mg_per_serving',
            'caffeine_mg_per_100ml', 'calories_per_serving', 'sugar_g_per_serving',
            'upc', 'source', 'created_at', 'updated_at'
        ]
        read_only_fields = ['_id', 'created_at', 'updated_at']


class CaffeineCategorySerializer(serializers.ModelSerializer):
    """Serializer for caffeine categories with count"""
    key = serializers.CharField(source='category')
    name = serializers.CharField(source='category_display')
    icon = serializers.CharField(source='category_icon')
    count = serializers.SerializerMethodField()
    
    class Meta:
        model = CaffeineProduct
        fields = ['key', 'name', 'icon', 'count']
    
    def get_count(self, obj):
        return CaffeineProduct.objects.filter(category=obj.category).count()


class CaffeineCategoriesResponseSerializer(serializers.Serializer):
    """Response serializer for caffeine categories endpoint"""
    categories = CaffeineCategorySerializer(many=True)


class CaffeineSearchResponseSerializer(serializers.Serializer):
    """Response serializer for caffeine search endpoint"""
    products = CaffeineProductSerializer(many=True)
    total_count = serializers.IntegerField()
    has_more = serializers.BooleanField()


class LogCaffeineEntrySerializer(serializers.Serializer):
    """
    Serializer for logging a caffeine product entry.
    """
    user_phone = serializers.CharField(
        help_text="The AppUser's phone (e.g. +12159136110)"
    )
    caffeine_product = serializers.CharField(
        help_text="The _id of the CaffeineProduct being logged."
    )
    food_name = serializers.CharField(
        help_text="Name of the caffeine product for display."
    )
    serving_unit = serializers.CharField(
        default="serving",
        help_text="Unit of measurement (defaults to 'serving')."
    )
    quantity = serializers.FloatField(
        min_value=0.1,
        max_value=10.0,
        help_text="Number of servings consumed."
    )
    meal_type = serializers.ChoiceField(
        choices=['breakfast', 'lunch', 'dinner', 'snack', 'caffeine'],
        default='caffeine',
        required=False,
        help_text="The meal category for this entry. Defaults to 'caffeine' for caffeine products."
    )
    time_consumed = serializers.DateTimeField(
        help_text="When the caffeine product was consumed."
    )
    
    def to_internal_value(self, data):
        # Lowercase meal_type for validation
        if 'meal_type' in data:
            data['meal_type'] = data['meal_type'].lower()
        return super().to_internal_value(data) 


# --- Water Tracking Serializers ---

class WaterEntrySerializer(serializers.ModelSerializer):
    """Serializer for WaterEntry model"""
    user_phone = serializers.SlugRelatedField(
        slug_field='phone',
        queryset=AppUser.objects.all(),
        write_only=True,
        help_text="The AppUser's phone (e.g. +12159136110)",
        required=False
    )
    daily_log = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = WaterEntry
        fields = [
            'id', 'user_phone', 'daily_log', 'amount_ml', 'container_type',
            'time_consumed', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'daily_log', 'created_at', 'updated_at']

    def create(self, validated_data):
        user_phone = validated_data.pop('user_phone', None)
        if user_phone:
            user = AppUser.objects.get(phone=user_phone)
        else:
            # Fallback to request user if available
            user = getattr(self.context.get('request'), 'user', None)
            if not user or not user.is_authenticated:
                raise serializers.ValidationError("User authentication required")
        
        # Get or create daily log for today
        daily_log, _ = DailyCalorieTracker.objects.get_or_create(
            user=user,
            date=date.today(),
            defaults={'calorie_goal': 2000, 'water_goal_ml': 2000.0}
        )
        
        validated_data['daily_log'] = daily_log
        return super().create(validated_data)


class WaterEntryResponseSerializer(serializers.ModelSerializer):
    """Simple response serializer for WaterEntry without user_phone field"""
    class Meta:
        model = WaterEntry
        fields = [
            'id', 'daily_log', 'amount_ml', 'container_type',
            'time_consumed', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'daily_log', 'created_at', 'updated_at']


class LogWaterEntrySerializer(serializers.Serializer):
    """Simplified serializer for logging water intake"""
    amount_ml = serializers.FloatField(
        min_value=1,
        max_value=5000,  # Maximum 5 liters per entry
        help_text="Amount of water in milliliters (1-5000ml)."
    )
    container_type = serializers.ChoiceField(
        choices=[
            ('glass', 'Glass (250ml)'),
            ('cup', 'Cup (240ml)'),
            ('bottle_small', 'Small Bottle (330ml)'),
            ('bottle_large', 'Large Bottle (500ml)'),
            ('bottle_xl', 'XL Bottle (1000ml)'),
            ('custom', 'Custom Amount'),
        ],
        default='glass',
        help_text="Type of container used."
    )
    time_consumed = serializers.DateTimeField(
        required=False,
        help_text="When the water was consumed. Defaults to now."
    )

    def to_internal_value(self, data):
        # Set default time_consumed to now if not provided
        if 'time_consumed' not in data or not data['time_consumed']:
            from django.utils import timezone
            data['time_consumed'] = timezone.now()
        return super().to_internal_value(data)


class WaterSettingsSerializer(serializers.Serializer):
    """Serializer for water goal settings"""
    water_goal_ml = serializers.FloatField(
        min_value=500,
        max_value=10000,  # 500ml to 10L
        help_text="Daily water goal in milliliters."
    )
    preferred_unit = serializers.ChoiceField(
        choices=[
            ('ml', 'Milliliters'),
            ('fl_oz', 'Fluid Ounces'),
            ('cups', 'Cups'),
            ('glasses', 'Glasses'),
        ],
        default='ml',
        help_text="Preferred unit for displaying water intake."
    )

