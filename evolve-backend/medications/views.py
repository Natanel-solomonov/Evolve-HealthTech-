from django.db.models import Q
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from .models import (
    DrugCategory, Manufacturer, PrescriptionMedication, 
    OTCMedication, Supplement, UserMedication, MedicationDose
)
from .serializers import (
    DrugCategorySerializer, ManufacturerSerializer,
    PrescriptionMedicationSerializer, PrescriptionMedicationSearchSerializer,
    OTCMedicationSerializer, OTCMedicationSearchSerializer,
    SupplementSerializer, SupplementSearchSerializer,
    UserMedicationSerializer, UserMedicationCreateSerializer,
    MedicationDoseSerializer, MedicationDoseCreateSerializer
)


class MedicationPagination(PageNumberPagination):
    """Custom pagination for medication search results"""
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class DrugCategoryListView(generics.ListAPIView):
    """List all drug categories"""
    queryset = DrugCategory.objects.all().order_by('name')
    serializer_class = DrugCategorySerializer
    permission_classes = [IsAuthenticated]


class ManufacturerListView(generics.ListAPIView):
    """List all manufacturers"""
    queryset = Manufacturer.objects.all().order_by('name')
    serializer_class = ManufacturerSerializer
    permission_classes = [IsAuthenticated]


@api_view(['GET'])
@permission_classes([AllowAny])  # Allow public access for testing
def search_prescription_medications(request):
    """
    Search prescription medications by name, active ingredients, or NDC number
    Query parameters:
    - q: Search query string
    - manufacturer: Filter by manufacturer ID
    - category: Filter by category ID
    - dosage_form: Filter by dosage form
    """
    query = request.GET.get('q', '').strip()
    manufacturer_id = request.GET.get('manufacturer')
    category_id = request.GET.get('category')
    dosage_form = request.GET.get('dosage_form')
    
    # Start with active medications
    queryset = PrescriptionMedication.objects.filter(is_active=True)
    
    # Apply search query
    if query:
        queryset = queryset.filter(
            Q(brand_name__icontains=query) |
            Q(generic_name__icontains=query) |
            Q(active_ingredients__icontains=query) |
            Q(ndc_number__icontains=query) |
            Q(search_keywords__icontains=query)
        )
    
    # Apply filters
    if manufacturer_id:
        queryset = queryset.filter(manufacturer_id=manufacturer_id)
    
    if category_id:
        queryset = queryset.filter(categories__id=category_id)
    
    if dosage_form:
        queryset = queryset.filter(dosage_form__icontains=dosage_form)
    
    # Order by relevance (brand name first, then generic name)
    queryset = queryset.select_related('manufacturer').prefetch_related('categories')
    queryset = queryset.order_by('brand_name', 'generic_name')
    
    # Paginate results
    paginator = MedicationPagination()
    page = paginator.paginate_queryset(queryset, request)
    
    if page is not None:
        serializer = PrescriptionMedicationSearchSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)
    
    serializer = PrescriptionMedicationSearchSerializer(queryset, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([AllowAny])  # Allow public access for testing
def search_otc_medications(request):
    """
    Search OTC medications by name, active ingredients, or UPC code
    Query parameters:
    - q: Search query string
    - manufacturer: Filter by manufacturer ID
    - category: Filter by category ID
    - dosage_form: Filter by dosage form
    """
    query = request.GET.get('q', '').strip()
    manufacturer_id = request.GET.get('manufacturer')
    category_id = request.GET.get('category')
    dosage_form = request.GET.get('dosage_form')
    
    # Start with active medications
    queryset = OTCMedication.objects.filter(is_active=True)
    
    # Apply search query
    if query:
        queryset = queryset.filter(
            Q(product_name__icontains=query) |
            Q(brand_name__icontains=query) |
            Q(active_ingredients__icontains=query) |
            Q(upc_code__icontains=query) |
            Q(purpose__icontains=query) |
            Q(search_keywords__icontains=query)
        )
    
    # Apply filters
    if manufacturer_id:
        queryset = queryset.filter(manufacturer_id=manufacturer_id)
    
    if category_id:
        queryset = queryset.filter(categories__id=category_id)
    
    if dosage_form:
        queryset = queryset.filter(dosage_form__icontains=dosage_form)
    
    # Order by relevance
    queryset = queryset.select_related('manufacturer').prefetch_related('categories')
    queryset = queryset.order_by('product_name', 'brand_name')
    
    # Paginate results
    paginator = MedicationPagination()
    page = paginator.paginate_queryset(queryset, request)
    
    if page is not None:
        serializer = OTCMedicationSearchSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)
    
    serializer = OTCMedicationSearchSerializer(queryset, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def search_supplements(request):
    """
    Search supplements by name, ingredients, or UPC code
    Query parameters:
    - q: Search query string
    - manufacturer: Filter by manufacturer ID
    - category: Filter by category ID
    - dosage_form: Filter by dosage form
    """
    query = request.GET.get('q', '').strip()
    manufacturer_id = request.GET.get('manufacturer')
    category_id = request.GET.get('category')
    dosage_form = request.GET.get('dosage_form')
    
    # Start with active supplements
    queryset = Supplement.objects.filter(is_active=True)
    
    # Apply search query
    if query:
        queryset = queryset.filter(
            Q(product_name__icontains=query) |
            Q(brand_name__icontains=query) |
            Q(supplement_ingredients__icontains=query) |
            Q(upc_code__icontains=query) |
            Q(intended_use__icontains=query) |
            Q(search_keywords__icontains=query)
        )
    
    # Apply filters
    if manufacturer_id:
        queryset = queryset.filter(manufacturer_id=manufacturer_id)
    
    if category_id:
        queryset = queryset.filter(categories__id=category_id)
    
    if dosage_form:
        queryset = queryset.filter(dosage_form__icontains=dosage_form)
    
    # Order by relevance
    queryset = queryset.select_related('manufacturer').prefetch_related('categories')
    queryset = queryset.order_by('product_name', 'brand_name')
    
    # Paginate results
    paginator = MedicationPagination()
    page = paginator.paginate_queryset(queryset, request)
    
    if page is not None:
        serializer = SupplementSearchSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)
    
    serializer = SupplementSearchSerializer(queryset, many=True)
    return Response(serializer.data)


class PrescriptionMedicationDetailView(generics.RetrieveAPIView):
    """Get detailed information about a prescription medication"""
    queryset = PrescriptionMedication.objects.filter(is_active=True)
    serializer_class = PrescriptionMedicationSerializer
    permission_classes = [IsAuthenticated]


class OTCMedicationDetailView(generics.RetrieveAPIView):
    """Get detailed information about an OTC medication"""
    queryset = OTCMedication.objects.filter(is_active=True)
    serializer_class = OTCMedicationSerializer
    permission_classes = [IsAuthenticated]


class SupplementDetailView(generics.RetrieveAPIView):
    """Get detailed information about a supplement"""
    queryset = Supplement.objects.filter(is_active=True)
    serializer_class = SupplementSerializer
    permission_classes = [IsAuthenticated]


class UserMedicationListCreateView(generics.ListCreateAPIView):
    """List user's medications or add a new medication"""
    serializer_class = UserMedicationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return UserMedication.objects.filter(
            user=self.request.user,
            is_active=True
        ).select_related(
            'prescription_medication__manufacturer',
            'otc_medication__manufacturer',
            'supplement__manufacturer'
        ).order_by('-created_at')
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return UserMedicationCreateSerializer
        return UserMedicationSerializer


class UserMedicationDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update, or delete a user's medication"""
    serializer_class = UserMedicationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return UserMedication.objects.filter(user=self.request.user)
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return UserMedicationCreateSerializer
        return UserMedicationSerializer


class MedicationDoseListCreateView(generics.ListCreateAPIView):
    """List medication doses or create a new dose record"""
    serializer_class = MedicationDoseSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user_medication_id = self.request.GET.get('user_medication')
        queryset = MedicationDose.objects.filter(
            user_medication__user=self.request.user
        ).select_related('user_medication').order_by('-scheduled_time')
        
        if user_medication_id:
            queryset = queryset.filter(user_medication_id=user_medication_id)
        
        return queryset
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return MedicationDoseCreateSerializer
        return MedicationDoseSerializer


class MedicationDoseDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update, or delete a medication dose record"""
    serializer_class = MedicationDoseSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return MedicationDose.objects.filter(user_medication__user=self.request.user)
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return MedicationDoseCreateSerializer
        return MedicationDoseSerializer


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_dose_taken(request, dose_id):
    """Mark a medication dose as taken"""
    try:
        dose = MedicationDose.objects.get(
            id=dose_id,
            user_medication__user=request.user
        )
        
        from django.utils import timezone
        dose.was_taken = True
        dose.taken_time = timezone.now()
        dose.save()
        
        serializer = MedicationDoseSerializer(dose)
        return Response(serializer.data)
        
    except MedicationDose.DoesNotExist:
        return Response(
            {"error": "Medication dose not found"},
            status=status.HTTP_404_NOT_FOUND
        )