from django.db import models
from django.core.exceptions import ValidationError
from django.utils import timezone
import uuid


class Ingredient(models.Model):
    """
    Represents a basic ingredient that can be used in recipes.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True, db_index=True)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name = "Ingredient"
        verbose_name_plural = "Ingredients"

    def __str__(self):
        return self.name


class Equipment(models.Model):
    """
    Represents cooking equipment that can be used in recipes.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, db_index=True)
    size = models.CharField(max_length=50, blank=True, help_text="e.g. 'large', '12-inch'")
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name = "Equipment"
        verbose_name_plural = "Equipment"
        unique_together = ['name', 'size']

    def __str__(self):
        if self.size:
            return f"{self.size} {self.name}".strip()
        return self.name


class Recipe(models.Model):
    """
    Represents a complete recipe with metadata.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=200, db_index=True)
    description = models.TextField(blank=True, null=True)
    prep_time = models.PositiveIntegerField(blank=True, null=True, help_text="Preparation time in minutes")
    cook_time = models.PositiveIntegerField(blank=True, null=True, help_text="Cooking time in minutes")
    total_time = models.PositiveIntegerField(blank=True, null=True, help_text="Total time in minutes")
    servings = models.PositiveIntegerField(blank=True, null=True, help_text="Number of servings")
    difficulty = models.CharField(
        max_length=20,
        choices=[
            ('easy', 'Easy'),
            ('medium', 'Medium'),
            ('hard', 'Hard'),
        ],
        blank=True,
        null=True
    )
    cuisine = models.CharField(max_length=100, blank=True, null=True)
    source_url = models.URLField(blank=True, null=True, help_text="Original source URL if scraped")
    source_name = models.CharField(max_length=200, blank=True, null=True, help_text="Original source name")
    image_url = models.URLField(blank=True, null=True)
    tags = models.JSONField(default=list, blank=True, help_text="List of tags for categorization")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Recipe"
        verbose_name_plural = "Recipes"

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        # Auto-calculate total_time if not provided
        if not self.total_time and (self.prep_time or self.cook_time):
            self.total_time = (self.prep_time or 0) + (self.cook_time or 0)
        super().save(*args, **kwargs)


class RecipeIngredient(models.Model):
    """
    Links ingredients to recipes with quantities and units.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipe = models.ForeignKey(Recipe, related_name="recipe_ingredients", on_delete=models.CASCADE)
    ingredient = models.ForeignKey(Ingredient, on_delete=models.PROTECT)
    quantity = models.FloatField()
    unit = models.CharField(max_length=20, help_text="'cups', 'tbsp', 'each', etc.")
    notes = models.TextField(blank=True, null=True, help_text="Additional notes about this ingredient")
    order = models.PositiveIntegerField(default=0, help_text="Order of ingredient in the list")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['recipe', 'order']
        verbose_name = "Recipe Ingredient"
        verbose_name_plural = "Recipe Ingredients"
        unique_together = ['recipe', 'ingredient', 'quantity', 'unit']

    def __str__(self):
        return f"{self.quantity} {self.unit} {self.ingredient.name}"


class InstructionStep(models.Model):
    """
    Represents a single step in a recipe's instructions with dynamic ingredient/equipment references.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipe = models.ForeignKey(Recipe, related_name="steps", on_delete=models.CASCADE)
    order = models.PositiveIntegerField()
    # Free-form action template with placeholders: {ri:<id>} or {eq:<id>}
    template = models.TextField(
        help_text="Use {ri:1}, {eq:2} etc. to mark RecipeIngredient or Equipment by PK."
    )
    ingredients = models.ManyToManyField(RecipeIngredient, blank=True, related_name="instruction_steps")
    equipment = models.ManyToManyField(Equipment, blank=True, related_name="instruction_steps")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["recipe", "order"]
        verbose_name = "Instruction Step"
        verbose_name_plural = "Instruction Steps"
        unique_together = ['recipe', 'order']

    def __str__(self):
        return f"Step {self.order}: {self.template[:50]}..."

    def render(self):
        """
        Renders the instruction step by replacing placeholders with actual ingredient/equipment names.
        """
        text = self.template
        
        # Inject quantities + ingredient names
        for ri in self.ingredients.all():
            label = f"{{ri:{ri.id}}}"
            text = text.replace(label, str(ri))
        
        # Inject equipment names
        for eq in self.equipment.all():
            label = f"{{eq:{eq.id}}}"
            text = text.replace(label, str(eq))
        
        return text

    def clean(self):
        """
        Validate that all placeholders in the template have corresponding ingredients/equipment.
        """
        super().clean()
        
        # Check for unmatched placeholders
        import re
        
        # Find all {ri:id} and {eq:id} placeholders
        ri_pattern = r'\{ri:([^}]+)\}'
        eq_pattern = r'\{eq:([^}]+)\}'
        
        ri_placeholders = re.findall(ri_pattern, self.template)
        eq_placeholders = re.findall(eq_pattern, self.template)
        
        # Check if all ri placeholders have corresponding ingredients
        ingredient_ids = [str(ri.id) for ri in self.ingredients.all()]
        for placeholder_id in ri_placeholders:
            if placeholder_id not in ingredient_ids:
                raise ValidationError(
                    f"Placeholder {{ri:{placeholder_id}}} in template has no corresponding RecipeIngredient"
                )
        
        # Check if all eq placeholders have corresponding equipment
        equipment_ids = [str(eq.id) for eq in self.equipment.all()]
        for placeholder_id in eq_placeholders:
            if placeholder_id not in equipment_ids:
                raise ValidationError(
                    f"Placeholder {{eq:{placeholder_id}}} in template has no corresponding Equipment"
                )


class RecipeNutrition(models.Model):
    """
    Stores nutrition information for a recipe (per serving).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipe = models.OneToOneField(Recipe, on_delete=models.CASCADE, related_name="nutrition")
    calories = models.PositiveIntegerField(blank=True, null=True)
    protein = models.FloatField(blank=True, null=True, help_text="Protein in grams")
    carbs = models.FloatField(blank=True, null=True, help_text="Carbohydrates in grams")
    fat = models.FloatField(blank=True, null=True, help_text="Fat in grams")
    fiber = models.FloatField(blank=True, null=True, help_text="Fiber in grams")
    sugar = models.FloatField(blank=True, null=True, help_text="Sugar in grams")
    sodium = models.FloatField(blank=True, null=True, help_text="Sodium in milligrams")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Recipe Nutrition"
        verbose_name_plural = "Recipe Nutrition"

    def __str__(self):
        return f"Nutrition for {self.recipe.title}"
