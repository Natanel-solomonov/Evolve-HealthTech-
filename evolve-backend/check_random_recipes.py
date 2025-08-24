#!/usr/bin/env python3
"""
Standalone script to check random recipes in Railway production database
"""
import os
import sys
import django
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

# Configure for Railway production database
os.environ['DATABASE_URL'] = 'postgresql://postgres:qnnGfLhKCumgpFRzKoOvPbTtsDWIYiwp@shinkansen.proxy.rlwy.net:37235/railway'
os.environ['RAILWAY_ENVIRONMENT'] = 'production'

# Initialize Django
django.setup()

from django.db import connection
from django.db.models import Q
from recipes.models import Recipe, RecipeIngredient, InstructionStep, Ingredient, Equipment
import random


def display_recipe(recipe, index):
    """Display a single recipe with all its details"""
    print(f"\n{'='*60}")
    print(f"RANDOM RECIPE #{index}")
    print(f"{'='*60}")
    print(f"Title: {recipe.title}")
    print(f"ID: {recipe.id}")
    print(f"Source: {recipe.source_name or 'Unknown'}")
    print(f"URL: {recipe.source_url or 'N/A'}")
    
    if recipe.description:
        print(f"Description: {recipe.description[:100]}...")
    
    # Timing info
    timing_parts = []
    if recipe.prep_time:
        timing_parts.append(f"Prep: {recipe.prep_time}min")
    if recipe.cook_time:
        timing_parts.append(f"Cook: {recipe.cook_time}min")
    if recipe.total_time:
        timing_parts.append(f"Total: {recipe.total_time}min")
    if timing_parts:
        print(f"Time: {' | '.join(timing_parts)}")
    
    if recipe.servings:
        print(f"Servings: {recipe.servings}")
    if recipe.difficulty:
        print(f"Difficulty: {recipe.difficulty.title()}")
    if recipe.cuisine:
        print(f"Cuisine: {recipe.cuisine}")
    
    # Ingredients
    if recipe.recipe_ingredients.exists():
        print(f"\nINGREDIENTS:")
        for ri in recipe.recipe_ingredients.all():
            print(f"  • {ri.quantity} {ri.unit} {ri.ingredient.name}")
            if ri.notes:
                print(f"    Note: {ri.notes}")
    
    # Instructions
    if recipe.steps.exists():
        print(f"\nINSTRUCTIONS:")
        for step in recipe.steps.all():
            # Use the render() method to replace placeholders with actual names
            rendered_step = step.render()
            print(f"  {step.order}. {rendered_step}")
    
    # Nutrition info
    if hasattr(recipe, 'nutrition') and recipe.nutrition:
        nutrition = recipe.nutrition
        print(f"\nNUTRITION (per serving):")
        if nutrition.calories:
            print(f"  Calories: {nutrition.calories}")
        if nutrition.protein:
            print(f"  Protein: {nutrition.protein}g")
        if nutrition.carbs:
            print(f"  Carbs: {nutrition.carbs}g")
        if nutrition.fat:
            print(f"  Fat: {nutrition.fat}g")
        if nutrition.sugar:
            print(f"  Sugar: {nutrition.sugar}g")
        if nutrition.sodium:
            print(f"  Sodium: {nutrition.sodium}mg")
    
    # Tags
    if recipe.tags:
        print(f"\nTAGS:")
        print(f"  {', '.join(recipe.tags)}")
    
    print(f"\nCreated: {recipe.created_at}")
    print(f"Updated: {recipe.updated_at}")


def get_random_recipes(count=10):
    """Get random recipes from the database"""
    # Get all recipe IDs first
    recipe_ids = list(Recipe.objects.values_list('id', flat=True))
    
    if not recipe_ids:
        return []
    
    # Select random IDs
    if len(recipe_ids) <= count:
        selected_ids = recipe_ids
    else:
        selected_ids = random.sample(recipe_ids, count)
    
    # Get the actual recipes with related data
    recipes = Recipe.objects.filter(id__in=selected_ids).select_related('nutrition').prefetch_related(
        'recipe_ingredients__ingredient',
        'steps'
    )
    
    return list(recipes)


def main():
    count = 10
    if len(sys.argv) > 1:
        try:
            count = int(sys.argv[1])
        except ValueError:
            print("Usage: python check_random_recipes.py [count]")
            print("Default count is 10")
            return
    
    print(f"Connecting to Railway production database...")
    print(f"Fetching {count} random recipes...")
    
    try:
        # Get total count first
        total_recipes = Recipe.objects.count()
        print(f"Total recipes in database: {total_recipes}")
        
        if total_recipes == 0:
            print("No recipes found in the database.")
            return
        
        # Get random recipes
        recipes = get_random_recipes(count)
        
        if not recipes:
            print("No recipes found.")
            return
        
        print(f"\nDisplaying {len(recipes)} random recipes:")
        
        for i, recipe in enumerate(recipes, 1):
            display_recipe(recipe, i)
        
        # Show database connection info
        print(f"\n{'='*60}")
        print("DATABASE CONNECTION INFO:")
        print(f"Database: {connection.settings_dict['NAME']}")
        print(f"Host: {connection.settings_dict['HOST']}")
        print(f"Port: {connection.settings_dict['PORT']}")
        print(f"User: {connection.settings_dict['USER']}")
        
    except Exception as e:
        print(f"Error connecting to database: {str(e)}")
        print("Make sure you have the correct database settings and connection.")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main() 