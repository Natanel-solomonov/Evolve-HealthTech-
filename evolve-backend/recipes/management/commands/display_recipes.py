from django.core.management.base import BaseCommand
from django.db import connection
from recipes.models import Recipe, RecipeIngredient, InstructionStep, Ingredient, Equipment
from django.core.management import execute_from_command_line
import os
import sys


class Command(BaseCommand):
    help = 'Display 5 recipes from the Railway production database'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count',
            type=int,
            default=5,
            help='Number of recipes to display (default: 5)'
        )
        parser.add_argument(
            '--production',
            action='store_true',
            help='Use Railway production database settings'
        )

    def handle(self, *args, **options):
        count = options['count']
        use_production = options['production']
        
        if use_production:
            # Set production environment variables
            os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
            os.environ['DATABASE_URL'] = 'postgresql://postgres:password@containers-us-west-207.railway.app:5432/railway'
            os.environ['RAILWAY_ENVIRONMENT'] = 'production'
            
            self.stdout.write(
                self.style.SUCCESS(f'Connecting to Railway production database...')
            )
        
        try:
            # Get recipes with related data
            recipes = Recipe.objects.select_related('nutrition').prefetch_related(
                'recipe_ingredients__ingredient',
                'steps'
            )[:count]
            
            if not recipes:
                self.stdout.write(
                    self.style.WARNING('No recipes found in the database.')
                )
                return
            
            self.stdout.write(
                self.style.SUCCESS(f'Found {recipes.count()} recipes in the database:')
            )
            self.stdout.write('=' * 80)
            
            for i, recipe in enumerate(recipes, 1):
                self.display_recipe(recipe, i)
                if i < len(recipes):
                    self.stdout.write('-' * 80)
            
            # Show database connection info
            self.stdout.write('\n' + '=' * 80)
            self.stdout.write('DATABASE CONNECTION INFO:')
            self.stdout.write(f'Database: {connection.settings_dict["NAME"]}')
            self.stdout.write(f'Host: {connection.settings_dict["HOST"]}')
            self.stdout.write(f'Port: {connection.settings_dict["PORT"]}')
            self.stdout.write(f'User: {connection.settings_dict["USER"]}')
            
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error connecting to database: {str(e)}')
            )
            self.stdout.write(
                self.style.WARNING('Make sure you have the correct database settings and connection.')
            )

    def display_recipe(self, recipe, index):
        """Display a single recipe with all its details"""
        self.stdout.write(f'\n{self.style.SUCCESS(f"RECIPE #{index}")}')
        self.stdout.write(f'Title: {recipe.title}')
        self.stdout.write(f'ID: {recipe.id}')
        self.stdout.write(f'Source: {recipe.source_name or "Unknown"}')
        self.stdout.write(f'URL: {recipe.source_url or "N/A"}')
        
        if recipe.description:
            self.stdout.write(f'Description: {recipe.description[:100]}...')
        
        # Timing info
        timing_parts = []
        if recipe.prep_time:
            timing_parts.append(f'Prep: {recipe.prep_time}min')
        if recipe.cook_time:
            timing_parts.append(f'Cook: {recipe.cook_time}min')
        if recipe.total_time:
            timing_parts.append(f'Total: {recipe.total_time}min')
        if timing_parts:
            self.stdout.write(f'Time: {" | ".join(timing_parts)}')
        
        if recipe.servings:
            self.stdout.write(f'Servings: {recipe.servings}')
        if recipe.difficulty:
            self.stdout.write(f'Difficulty: {recipe.difficulty.title()}')
        if recipe.cuisine:
            self.stdout.write(f'Cuisine: {recipe.cuisine}')
        
        # Ingredients
        if recipe.recipe_ingredients.exists():
            self.stdout.write(f'\n{self.style.WARNING("INGREDIENTS:")}')
            for ri in recipe.recipe_ingredients.all():
                self.stdout.write(f'  • {ri.quantity} {ri.unit} {ri.ingredient.name}')
                if ri.notes:
                    self.stdout.write(f'    Note: {ri.notes}')
        
        # Instructions
        if recipe.steps.exists():
            self.stdout.write(f'\n{self.style.WARNING("INSTRUCTIONS:")}')
            for step in recipe.steps.all():
                self.stdout.write(f'  {step.order}. {step.template}')
        
        # Nutrition info
        if hasattr(recipe, 'nutrition') and recipe.nutrition:
            nutrition = recipe.nutrition
            self.stdout.write(f'\n{self.style.WARNING("NUTRITION (per serving):")}')
            if nutrition.calories:
                self.stdout.write(f'  Calories: {nutrition.calories}')
            if nutrition.protein:
                self.stdout.write(f'  Protein: {nutrition.protein}g')
            if nutrition.carbs:
                self.stdout.write(f'  Carbs: {nutrition.carbs}g')
            if nutrition.fat:
                self.stdout.write(f'  Fat: {nutrition.fat}g')
            if nutrition.sugar:
                self.stdout.write(f'  Sugar: {nutrition.sugar}g')
            if nutrition.sodium:
                self.stdout.write(f'  Sodium: {nutrition.sodium}mg')
        
        # Tags
        if recipe.tags:
            self.stdout.write(f'\n{self.style.WARNING("TAGS:")}')
            self.stdout.write(f'  {", ".join(recipe.tags)}')
        
        self.stdout.write(f'\nCreated: {recipe.created_at}')
        self.stdout.write(f'Updated: {recipe.updated_at}') 