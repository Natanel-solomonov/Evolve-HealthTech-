import uuid
from django.db import models
from django.contrib.postgres.fields import ArrayField


class BaseModel(models.Model):
    """Base model with common fields"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class DrugCategory(BaseModel):
    """Drug categories like Pain Relief, Digestive Health, etc."""
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    parent_category = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True)

    class Meta:
        verbose_name_plural = "Drug Categories"

    def __str__(self):
        return self.name


class Manufacturer(BaseModel):
    """Drug manufacturers and companies"""
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    website = models.URLField(blank=True)
    
    def __str__(self):
        return self.name


class PrescriptionMedication(BaseModel):
    """FDA-approved prescription medications"""
    # Basic Information
    brand_name = models.CharField(max_length=255, db_index=True)
    generic_name = models.CharField(max_length=255, db_index=True)
    active_ingredients = ArrayField(
        models.CharField(max_length=255),
        blank=True,
        default=list,
        help_text="List of active ingredients"
    )
    
    # FDA Data
    ndc_number = models.CharField(max_length=20, unique=True, db_index=True, help_text="National Drug Code")
    fda_application_number = models.CharField(max_length=20, blank=True)
    approval_date = models.DateField(null=True, blank=True)
    
    # Drug Details
    strength = models.CharField(max_length=255, blank=True)
    dosage_form = models.CharField(max_length=100, blank=True)  # tablet, capsule, injection, etc.
    route_of_administration = models.CharField(max_length=100, blank=True)  # oral, intravenous, etc.
    
    # Classification
    manufacturer = models.ForeignKey(Manufacturer, on_delete=models.CASCADE)
    categories = models.ManyToManyField(DrugCategory, blank=True)
    
    # Label Information
    drug_label_text = models.TextField(blank=True, help_text="FDA drug label content")
    indications = models.TextField(blank=True, help_text="What the drug is used for")
    contraindications = models.TextField(blank=True, help_text="When not to use the drug")
    warnings_precautions = models.TextField(blank=True)
    side_effects = models.TextField(blank=True)
    dosage_instructions = models.TextField(blank=True)
    
    # Images
    label_image_url = models.URLField(blank=True, help_text="URL to drug label image")
    pill_image_url = models.URLField(blank=True, help_text="URL to pill/product image")
    
    # Search and Status
    is_active = models.BooleanField(default=True)
    search_keywords = ArrayField(
        models.CharField(max_length=100),
        blank=True,
        default=list,
        help_text="Keywords for search optimization"
    )

    class Meta:
        indexes = [
            models.Index(fields=['brand_name', 'generic_name']),
            models.Index(fields=['ndc_number']),
            models.Index(fields=['manufacturer']),
        ]

    def __str__(self):
        return f"{self.brand_name} ({self.generic_name})"


class OTCMedication(BaseModel):
    """Over-the-counter medications and supplements"""
    # Basic Information
    product_name = models.CharField(max_length=255, db_index=True)
    brand_name = models.CharField(max_length=255, blank=True, db_index=True)
    active_ingredients = ArrayField(
        models.CharField(max_length=255),
        blank=True,
        default=list,
        help_text="List of active ingredients"
    )
    inactive_ingredients = ArrayField(
        models.CharField(max_length=255),
        blank=True,
        default=list,
        help_text="List of inactive ingredients"
    )
    
    # Product Details
    strength = models.CharField(max_length=255, blank=True)
    dosage_form = models.CharField(max_length=100, blank=True)  # tablet, liquid, cream, etc.
    package_size = models.CharField(max_length=100, blank=True)  # 100 tablets, 8 fl oz, etc.
    
    # Classification
    manufacturer = models.ForeignKey(Manufacturer, on_delete=models.CASCADE)
    categories = models.ManyToManyField(DrugCategory, blank=True)
    
    # OTC-specific fields
    otc_monograph = models.CharField(max_length=255, blank=True, help_text="FDA OTC monograph classification")
    upc_code = models.CharField(max_length=20, blank=True, help_text="Universal Product Code")
    
    # Drug Facts Label
    drug_facts = models.JSONField(blank=True, default=dict, help_text="Structured drug facts data")
    purpose = models.CharField(max_length=255, blank=True, help_text="What the product is for")
    uses = models.TextField(blank=True, help_text="What the product treats")
    warnings = models.TextField(blank=True)
    directions = models.TextField(blank=True, help_text="How to use the product")
    other_information = models.TextField(blank=True)
    
    # Images
    label_image_url = models.URLField(blank=True, help_text="URL to drug facts label image")
    package_image_url = models.URLField(blank=True, help_text="URL to product package image")
    
    # Search and Status
    is_active = models.BooleanField(default=True)
    search_keywords = ArrayField(
        models.CharField(max_length=100),
        blank=True,
        default=list,
        help_text="Keywords for search optimization"
    )

    class Meta:
        indexes = [
            models.Index(fields=['product_name', 'brand_name']),
            models.Index(fields=['manufacturer']),
            models.Index(fields=['upc_code']),
        ]

    def __str__(self):
        return f"{self.product_name} - {self.brand_name if self.brand_name else self.manufacturer.name}"


class Supplement(BaseModel):
    """Dietary supplements and vitamins"""
    # Basic Information
    product_name = models.CharField(max_length=255, db_index=True)
    brand_name = models.CharField(max_length=255, blank=True, db_index=True)
    supplement_ingredients = ArrayField(
        models.CharField(max_length=255),
        blank=True,
        default=list,
        help_text="List of supplement ingredients"
    )
    other_ingredients = ArrayField(
        models.CharField(max_length=255),
        blank=True,
        default=list,
        help_text="List of other ingredients"
    )
    
    # Product Details
    serving_size = models.CharField(max_length=100, blank=True)
    servings_per_container = models.CharField(max_length=50, blank=True)
    dosage_form = models.CharField(max_length=100, blank=True)  # capsule, tablet, powder, liquid
    
    # Classification
    manufacturer = models.ForeignKey(Manufacturer, on_delete=models.CASCADE)
    categories = models.ManyToManyField(DrugCategory, blank=True)
    
    # Supplement-specific fields
    supplement_facts = models.JSONField(blank=True, default=dict, help_text="Structured supplement facts data")
    upc_code = models.CharField(max_length=20, blank=True, help_text="Universal Product Code")
    
    # Label Information
    intended_use = models.TextField(blank=True, help_text="What the supplement is intended for")
    directions = models.TextField(blank=True, help_text="How to use the supplement")
    warnings = models.TextField(blank=True)
    other_information = models.TextField(blank=True)
    
    # Images
    label_image_url = models.URLField(blank=True, help_text="URL to supplement facts label image")
    package_image_url = models.URLField(blank=True, help_text="URL to product package image")
    
    # Search and Status
    is_active = models.BooleanField(default=True)
    search_keywords = ArrayField(
        models.CharField(max_length=100),
        blank=True,
        default=list,
        help_text="Keywords for search optimization"
    )

    class Meta:
        indexes = [
            models.Index(fields=['product_name', 'brand_name']),
            models.Index(fields=['manufacturer']),
            models.Index(fields=['upc_code']),
        ]

    def __str__(self):
        return f"{self.product_name} - {self.brand_name if self.brand_name else self.manufacturer.name}"


class UserMedication(BaseModel):
    """User's personal medication tracking"""
    user = models.ForeignKey('api.AppUser', on_delete=models.CASCADE, related_name='medications')
    
    # Medication Reference (one of these will be set)
    prescription_medication = models.ForeignKey(PrescriptionMedication, on_delete=models.CASCADE, null=True, blank=True)
    otc_medication = models.ForeignKey(OTCMedication, on_delete=models.CASCADE, null=True, blank=True)
    supplement = models.ForeignKey(Supplement, on_delete=models.CASCADE, null=True, blank=True)
    
    # User-specific information
    custom_name = models.CharField(max_length=255, blank=True, help_text="User's custom name for this medication")
    dosage = models.CharField(max_length=100, blank=True)
    frequency = models.CharField(max_length=100, blank=True)  # once daily, twice daily, as needed, etc.
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    
    # Tracking
    is_active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    prescribing_doctor = models.CharField(max_length=255, blank=True)
    
    class Meta:
        unique_together = [
            ['user', 'prescription_medication'],
            ['user', 'otc_medication'],
            ['user', 'supplement'],
        ]

    def __str__(self):
        med_name = self.custom_name
        if not med_name:
            if self.prescription_medication:
                med_name = self.prescription_medication.brand_name
            elif self.otc_medication:
                med_name = self.otc_medication.product_name
            elif self.supplement:
                med_name = self.supplement.product_name
        return f"{self.user.phone} - {med_name}"


class MedicationDose(BaseModel):
    """Individual medication dose tracking"""
    user_medication = models.ForeignKey(UserMedication, on_delete=models.CASCADE, related_name='doses')
    scheduled_time = models.DateTimeField()
    taken_time = models.DateTimeField(null=True, blank=True)
    was_taken = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['user_medication', 'scheduled_time']),
            models.Index(fields=['scheduled_time']),
        ]

    def __str__(self):
        return f"{self.user_medication} - {self.scheduled_time}"