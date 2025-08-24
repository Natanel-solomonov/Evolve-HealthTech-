from django.urls import path
from . import views

app_name = 'medications'

urlpatterns = [
    # Drug categories and manufacturers
    path('categories/', views.DrugCategoryListView.as_view(), name='drug-categories'),
    path('manufacturers/', views.ManufacturerListView.as_view(), name='manufacturers'),
    
    # Search endpoints
    path('prescription/search/', views.search_prescription_medications, name='search-prescription'),
    path('otc/search/', views.search_otc_medications, name='search-otc'),
    path('supplements/search/', views.search_supplements, name='search-supplements'),
    
    # Detailed medication information
    path('prescription/<uuid:pk>/', views.PrescriptionMedicationDetailView.as_view(), name='prescription-detail'),
    path('otc/<uuid:pk>/', views.OTCMedicationDetailView.as_view(), name='otc-detail'),
    path('supplements/<uuid:pk>/', views.SupplementDetailView.as_view(), name='supplement-detail'),
    
    # User medication tracking
    path('my-medications/', views.UserMedicationListCreateView.as_view(), name='user-medications'),
    path('my-medications/<uuid:pk>/', views.UserMedicationDetailView.as_view(), name='user-medication-detail'),
    
    # Dose tracking
    path('doses/', views.MedicationDoseListCreateView.as_view(), name='medication-doses'),
    path('doses/<uuid:pk>/', views.MedicationDoseDetailView.as_view(), name='medication-dose-detail'),
    path('doses/<uuid:dose_id>/mark-taken/', views.mark_dose_taken, name='mark-dose-taken'),
]