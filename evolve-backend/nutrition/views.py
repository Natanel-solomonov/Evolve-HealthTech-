from django.shortcuts import render
from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import FoodProduct, DailyCalorieTracker, FoodEntry, AlcoholicBeverage, CaffeineProduct, WaterEntry
from .serializers import (
    FoodProductSerializer, DailyCalorieTrackerSerializer, FoodEntrySerializer, 
    LogFoodEntrySerializer, AlcoholicBeverageSerializer, AlcoholCategorySerializer,
    LogAlcoholEntrySerializer, CaffeineProductSerializer, CaffeineCategorySerializer,
    LogCaffeineEntrySerializer, WaterEntrySerializer, WaterEntryResponseSerializer, 
    LogWaterEntrySerializer, WaterSettingsSerializer
)
from api.models import AppUser
from django.utils import timezone
from django.db.models import Sum, Q
from datetime import date

# Create your views here.
class FoodProductViewSet(viewsets.ModelViewSet):
    """ViewSet for FoodProduct model with search functionality"""
    queryset = FoodProduct.objects.all()
    serializer_class = FoodProductSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        search_query = self.request.query_params.get('search', None)
        if search_query:
            queryset = queryset.filter(product_name__icontains=search_query)
        return queryset

class DailyCalorieTrackerViewSet(viewsets.ModelViewSet):
    """ViewSet for DailyCalorieTracker model"""
    queryset = DailyCalorieTracker.objects.all()
    serializer_class = DailyCalorieTrackerSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return DailyCalorieTracker.objects.filter(user=user)

class FoodEntryViewSet(viewsets.ModelViewSet):
    """ViewSet for FoodEntry model"""
    queryset = FoodEntry.objects.all()
    serializer_class = FoodEntrySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return FoodEntry.objects.filter(daily_log__user=user)

class DailyLogDetailView(generics.RetrieveAPIView):
    """
    GET: Retrieve a specific daily log by user phone and date.
    """
    serializer_class = DailyCalorieTrackerSerializer
    permission_classes = [permissions.AllowAny]

    def get_object(self):
        user_phone = self.request.query_params.get('user_phone')
        date_str = self.request.query_params.get('date')

        if not user_phone or not date_str:
            return None

        try:
            user = AppUser.objects.get(phone=user_phone)
            log = DailyCalorieTracker.objects.get(user=user, date=date_str)
            return log
        except (AppUser.DoesNotExist, DailyCalorieTracker.DoesNotExist):
            return None

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance is None:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

class DailyLogHistoryView(generics.ListAPIView):
    """
    GET: Retrieve all daily logs for a specific user.
    """
    serializer_class = DailyCalorieTrackerSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user_phone = self.request.query_params.get('user_phone')

        if not user_phone:
            return DailyCalorieTracker.objects.none()

        try:
            user = AppUser.objects.get(phone=user_phone)
            return DailyCalorieTracker.objects.filter(user=user).order_by('-date')
        except AppUser.DoesNotExist:
            return DailyCalorieTracker.objects.none()

class LogFoodEntryView(generics.CreateAPIView):
    """Create a new food entry for a user"""
    serializer_class = LogFoodEntrySerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            try:
                # Get user by phone
                user_phone = serializer.validated_data['user_phone']
                user = AppUser.objects.get(phone=user_phone)
                
                # Get food product
                food_product_id = serializer.validated_data['food_product_id']
                food_product = FoodProduct.objects.get(_id=food_product_id)
                
                # Get or create daily log
                time_consumed = serializer.validated_data['time_consumed']
                log_date = time_consumed.date()
                daily_log, created = DailyCalorieTracker.objects.get_or_create(
                    user=user, 
                    date=log_date
                )
                
                # Create food entry
                food_entry = FoodEntry.objects.create(
                    daily_log=daily_log,
                    food_product=food_product,
                    serving_size=serializer.validated_data['serving_size'],
                    meal_type=serializer.validated_data['meal_type'],
                    time_consumed=time_consumed
                )
                
                return Response(
                    FoodEntrySerializer(food_entry).data,
                    status=status.HTTP_201_CREATED
                )
                
            except AppUser.DoesNotExist:
                return Response(
                    {'error': 'User not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except FoodProduct.DoesNotExist:
                return Response(
                    {'error': 'Food product not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except Exception as e:
                return Response(
                    {'error': str(e)}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class NutritionHistoryView(generics.ListAPIView):
    """Retrieve nutrition history for a user"""
    serializer_class = DailyCalorieTrackerSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user_id = self.request.query_params.get('user_id')
        
        if not user_id:
            return DailyCalorieTracker.objects.none()

        try:
            user = AppUser.objects.get(id=user_id)
            return DailyCalorieTracker.objects.filter(user=user).order_by('-date')
        except AppUser.DoesNotExist:
            return DailyCalorieTracker.objects.none()

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        
        # Add calculated fields for frontend
        history_data = []
        for item in serializer.data:
            history_item = dict(item)
            # Add calories burned (0 for now, can be extended later)
            history_item['calories_burned'] = 0
            # Calculate calories remaining
            calories_remaining = max(
                0, 
                history_item['calorie_goal'] - 
                history_item['total_calories'] - 
                history_item['calories_burned']
            )
            history_item['calories_remaining'] = calories_remaining
            history_data.append(history_item)
        
        return Response(history_data)

    def delete(self, request, *args, **kwargs):
        """
        Delete a daily log and all its food entries
        """
        log_id = request.query_params.get('log_id')
        user_id = request.query_params.get('user_id')
        
        if not log_id or not user_id:
            return Response(
                {"error": "Both log_id and user_id are required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = AppUser.objects.get(id=user_id)
            daily_log = DailyCalorieTracker.objects.get(id=log_id, user=user)
            
            # Delete the daily log (this will cascade delete all food entries)
            daily_log.delete()
            
            return Response(
                {"message": "Daily log and all associated food entries deleted successfully"}, 
                status=status.HTTP_204_NO_CONTENT
            )
            
        except AppUser.DoesNotExist:
            return Response(
                {"error": "User not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except DailyCalorieTracker.DoesNotExist:
            return Response(
                {"error": "Daily log not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {"error": f"Failed to delete daily log: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AlcoholCategoriesView(generics.ListAPIView):
    """Get all alcohol categories with counts"""
    serializer_class = AlcoholCategorySerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        """Get unique categories with counts"""
        return AlcoholicBeverage.objects.values('category').distinct().order_by('category')
    
    def list(self, request, *args, **kwargs):
        """Return categories with proper serialization"""
        categories = self.get_queryset()
        
        # Get one beverage from each category to access the properties
        category_objects = []
        for cat in categories:
            # Get the first beverage in this category to access properties
            beverage = AlcoholicBeverage.objects.filter(category=cat['category']).first()
            if beverage:
                category_objects.append(beverage)
        
        serializer = self.get_serializer(category_objects, many=True)
        return Response({'categories': serializer.data})


class AlcoholBeverageSearchView(generics.ListAPIView):
    """Search alcoholic beverages by query and category"""
    serializer_class = AlcoholicBeverageSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        query = self.request.query_params.get('q', '').strip()
        category = self.request.query_params.get('category', '').strip()
        page = int(self.request.query_params.get('page', 1))
        page_size = int(self.request.query_params.get('page_size', 25))
        
        queryset = AlcoholicBeverage.objects.all()
        
        # Filter by category if provided
        if category:
            queryset = queryset.filter(category=category)
        
        # Filter by search query if provided
        if query:
            queryset = queryset.filter(
                Q(name__icontains=query) |
                Q(brand__icontains=query)
            )
        
        # Order by popularity and name
        queryset = queryset.order_by('-popularity_score', 'name')
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        """Return paginated results with metadata"""
        page = int(request.query_params.get('page', 1))
        page_size = int(request.query_params.get('page_size', 25))
        
        queryset = self.get_queryset()
        total_count = queryset.count()
        
        # Manual pagination
        start = (page - 1) * page_size
        end = start + page_size
        paginated_queryset = queryset[start:end]
        
        serializer = self.get_serializer(paginated_queryset, many=True)
        
        return Response({
            'beverages': serializer.data,
            'total_count': total_count,
            'has_more': end < total_count
        })


class AlcoholBeverageDetailView(generics.RetrieveAPIView):
    """Get details for a specific alcoholic beverage"""
    serializer_class = AlcoholicBeverageSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = '_id'
    queryset = AlcoholicBeverage.objects.all()


class LogAlcoholEntryView(generics.CreateAPIView):
    """Log an alcoholic beverage entry"""
    serializer_class = LogAlcoholEntrySerializer
    permission_classes = [permissions.AllowAny]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        
        if serializer.is_valid():
            try:
                # Get the user
                user_phone = serializer.validated_data['user_phone']
                user = AppUser.objects.get(phone=user_phone)
                
                # Get the alcoholic beverage
                beverage_id = serializer.validated_data['alcoholic_beverage']
                beverage = AlcoholicBeverage.objects.get(_id=beverage_id)
                
                # Get or create daily log
                consumed = serializer.validated_data.get('time_consumed')
                log_date = consumed.date() if consumed else date.today()
                daily_log, _ = DailyCalorieTracker.get_or_create_for_date(user=user, date=log_date)
                
                # Calculate quantities
                quantity = serializer.validated_data['quantity']
                alcohol_grams = beverage.alcohol_grams * quantity
                calories = beverage.calories * quantity
                carbs = beverage.carbs_grams * quantity
                
                # Create the food entry
                food_entry = FoodEntry.objects.create(
                    daily_log=daily_log,
                    alcoholic_beverage=beverage,
                    food_name=serializer.validated_data['food_name'],
                    serving_size=quantity,
                    serving_unit='standard drink',
                    calories=calories,
                    carbs=carbs,
                    alcohol_grams=alcohol_grams,
                    standard_drinks=quantity,
                    alcohol_category=beverage.category,
                    meal_type=serializer.validated_data.get('meal_type', 'alcohol'),
                    time_consumed=consumed or timezone.now()
                )
                
                # Update daily totals
                daily_log.update_totals()
                
                return Response({
                    'message': f'Successfully logged {quantity} standard drink(s) of {beverage.name}',
                    'entry_id': food_entry.id
                }, status=status.HTTP_201_CREATED)
                
            except AppUser.DoesNotExist:
                return Response(
                    {'error': 'User not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except AlcoholicBeverage.DoesNotExist:
                return Response(
                    {'error': 'Alcoholic beverage not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except Exception as e:
                return Response(
                    {'error': str(e)}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# --- Caffeine Related Views ---

class CaffeineCategoriesView(generics.ListAPIView):
    """Get all caffeine categories with counts"""
    serializer_class = CaffeineCategorySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        # Get unique categories efficiently
        from django.db.models import Count
        return CaffeineProduct.objects.values('category').annotate(
            count=Count('category')
        ).order_by('category')
    
    def list(self, request, *args, **kwargs):
        # Get category data efficiently
        from django.db.models import Count
        categories_data = CaffeineProduct.objects.values('category').annotate(
            count=Count('category')
        ).order_by('category')
        
        # Create category objects for serialization
        category_objects = []
        for cat_data in categories_data:
            # Get a sample product from each category for display info
            sample_product = CaffeineProduct.objects.filter(category=cat_data['category']).first()
            if sample_product:
                category_objects.append({
                    'key': cat_data['category'],
                    'name': sample_product.category_display,
                    'icon': sample_product.category_icon,
                    'count': cat_data['count']
                })
        
        return Response({
            'categories': category_objects
        })


class CaffeineProductSearchView(generics.ListAPIView):
    """Search caffeine products by query and category"""
    serializer_class = CaffeineProductSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        queryset = CaffeineProduct.objects.all()
        
        # Filter by search query
        search_query = self.request.query_params.get('q', '').strip()
        if search_query:
            queryset = queryset.filter(
                Q(name__icontains=search_query) |
                Q(brand__icontains=search_query) |
                Q(flavor_or_variant__icontains=search_query)
            )
        
        # Filter by category
        category = self.request.query_params.get('category', '').strip()
        if category:
            queryset = queryset.filter(category=category)
        
        # Order by caffeine content (highest first) then by name
        return queryset.order_by('-caffeine_mg_per_serving', 'name')
    
    def list(self, request, *args, **kwargs):
        """Return paginated results with metadata"""
        page = int(request.query_params.get('page', 1))
        page_size = int(request.query_params.get('page_size', 25))
        
        queryset = self.get_queryset()
        total_count = queryset.count()
        
        # Manual pagination
        start = (page - 1) * page_size
        end = start + page_size
        paginated_queryset = queryset[start:end]
        
        serializer = self.get_serializer(paginated_queryset, many=True)
        
        return Response({
            'products': serializer.data,
            'total_count': total_count,
            'has_more': end < total_count
        })


class CaffeineProductDetailView(generics.RetrieveAPIView):
    """Get details for a specific caffeine product"""
    serializer_class = CaffeineProductSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = '_id'
    queryset = CaffeineProduct.objects.all()


class LogCaffeineEntryView(generics.CreateAPIView):
    """Log a caffeine product entry"""
    serializer_class = LogCaffeineEntrySerializer
    permission_classes = [permissions.AllowAny]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        
        if serializer.is_valid():
            try:
                # Get the user
                user_phone = serializer.validated_data['user_phone']
                user = AppUser.objects.get(phone=user_phone)
                
                # Get the caffeine product
                product_id = serializer.validated_data['caffeine_product']
                product = CaffeineProduct.objects.get(_id=product_id)
                
                # Get or create daily log
                consumed = serializer.validated_data.get('time_consumed')
                log_date = consumed.date() if consumed else date.today()
                daily_log, _ = DailyCalorieTracker.get_or_create_for_date(user=user, date=log_date)
                
                # Calculate quantities
                quantity = serializer.validated_data['quantity']
                caffeine_mg = product.caffeine_mg_per_serving * quantity
                calories = product.calories_per_serving * quantity
                
                # Create the food entry
                food_entry = FoodEntry.objects.create(
                    daily_log=daily_log,
                    caffeine_product=product,
                    food_name=serializer.validated_data['food_name'],
                    serving_size=quantity,
                    serving_unit='serving',
                    calories=calories,
                    caffeine_mg=caffeine_mg,
                    caffeine_category=product.category,
                    meal_type=serializer.validated_data.get('meal_type', 'caffeine'),
                    time_consumed=consumed or timezone.now()
                )
                
                # Update daily totals
                daily_log.update_totals()
                
                return Response({
                    'message': f'Successfully logged {quantity} serving(s) of {product.name}',
                    'entry_id': food_entry.id
                }, status=status.HTTP_201_CREATED)
                
            except AppUser.DoesNotExist:
                return Response(
                    {'error': 'User not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except CaffeineProduct.DoesNotExist:
                return Response(
                    {'error': 'Caffeine product not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except Exception as e:
                return Response(
                    {'error': str(e)}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# --- Water Tracking Views ---

class LogWaterView(generics.CreateAPIView):
    """
    Log water intake
    POST /api/nutrition/water-entries/log_water/
    """
    serializer_class = LogWaterEntrySerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        
        if serializer.is_valid():
            try:
                # Get or create daily log for today
                daily_log, created = DailyCalorieTracker.objects.get_or_create(
                    user=request.user,
                    date=date.today(),
                    defaults={
                        'calorie_goal': 2000,
                        'water_goal_ml': 2000.0
                    }
                )
                
                # Create water entry
                water_entry = WaterEntry.objects.create(
                    daily_log=daily_log,
                    amount_ml=serializer.validated_data['amount_ml'],
                    container_type=serializer.validated_data['container_type'],
                    time_consumed=serializer.validated_data.get('time_consumed', timezone.now())
                )
                
                # Return the created entry
                response_serializer = WaterEntryResponseSerializer(water_entry)
                return Response(response_serializer.data, status=status.HTTP_201_CREATED)
                
            except Exception as e:
                # Better error logging
                import traceback
                error_trace = traceback.format_exc()
                print(f"Water logging error: {str(e)}")
                print(f"Traceback: {error_trace}")
                
                return Response(
                    {'error': f'Failed to log water: {str(e)}'}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class WaterSettingsView(generics.RetrieveUpdateAPIView):
    """
    Get or update water settings for the user
    GET/PATCH /api/nutrition/water-entries/settings/
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        # Get current settings from today's daily log or defaults
        try:
            daily_log = DailyCalorieTracker.objects.get(
                user=request.user,
                date=date.today()
            )
            water_goal_ml = daily_log.water_goal_ml
        except DailyCalorieTracker.DoesNotExist:
            water_goal_ml = 2000.0  # Default
        
        return Response({
            'water_goal_ml': water_goal_ml,
            'preferred_unit': 'ml'  # Default for now
        })

    def patch(self, request, *args, **kwargs):
        serializer = WaterSettingsSerializer(data=request.data)
        
        if serializer.is_valid():
            # Update or create today's daily log with new water goal
            daily_log, _ = DailyCalorieTracker.objects.get_or_create(
                user=request.user,
                date=date.today(),
                defaults={'calorie_goal': 2000}
            )
            
            daily_log.water_goal_ml = serializer.validated_data['water_goal_ml']
            daily_log.save()
            
            return Response({
                'water_goal_ml': daily_log.water_goal_ml,
                'preferred_unit': serializer.validated_data['preferred_unit']
            })
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class WaterDailySummaryView(generics.RetrieveAPIView):
    """
    Get daily water intake summary
    GET /api/nutrition/water-entries/daily_summary/
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        date_param = request.query_params.get('date', date.today().isoformat())
        
        try:
            target_date = timezone.datetime.strptime(date_param, '%Y-%m-%d').date()
        except ValueError:
            target_date = date.today()
        
        try:
            daily_log = DailyCalorieTracker.objects.get(
                user=request.user,
                date=target_date
            )
            
            return Response({
                'date': target_date,
                'water_consumed_ml': daily_log.water_ml,
                'water_goal_ml': daily_log.water_goal_ml,
                'progress_percentage': (daily_log.water_ml / daily_log.water_goal_ml * 100) if daily_log.water_goal_ml > 0 else 0,
                'entries_count': daily_log.water_entries.count(),
                'entries': WaterEntrySerializer(daily_log.water_entries.all(), many=True).data
            })
            
        except DailyCalorieTracker.DoesNotExist:
            return Response({
                'date': target_date,
                'water_consumed_ml': 0.0,
                'water_goal_ml': 2000.0,
                'progress_percentage': 0.0,
                'entries_count': 0,
                'entries': []
            })


class WaterEntryListView(generics.ListAPIView):
    """
    List water entries for the current user
    GET /api/nutrition/water-entries/
    """
    serializer_class = WaterEntrySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = WaterEntry.objects.filter(daily_log__user=user)
        
        # Optional date filtering
        date_param = self.request.query_params.get('date')
        if date_param:
            try:
                target_date = timezone.datetime.strptime(date_param, '%Y-%m-%d').date()
                queryset = queryset.filter(daily_log__date=target_date)
            except ValueError:
                pass  # Invalid date format, ignore filter
        
        return queryset.order_by('-time_consumed')
