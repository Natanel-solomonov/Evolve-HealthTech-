from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
import json
import logging

from recipes.services.recipe_formatter import format_recipe_from_url
from recipes.models import Recipe, Ingredient, Equipment, RecipeIngredient, InstructionStep

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Scrape and format a recipe from a URL into the database'

    def add_arguments(self, parser):
        parser.add_argument('url', type=str, help='URL of the recipe to scrape')
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be created without actually creating it',
        )
        parser.add_argument(
            '--verbose',
            action='store_true',
            help='Show detailed output',
        )

    def handle(self, *args, **options):
        url = options['url']
        dry_run = options['dry_run']
        verbose = options['verbose']

        self.stdout.write(f"Scraping recipe from: {url}")
        
        try:
            if dry_run:
                self._dry_run_scrape(url, verbose)
            else:
                self._scrape_and_save(url, verbose)
                
        except Exception as e:
            raise CommandError(f"Failed to scrape recipe: {e}")

    def _dry_run_scrape(self, url: str, verbose: bool):
        """Perform a dry run to show what would be created."""
        from recipes.services.recipe_scraper import scrape_recipe_from_url
        
        # Scrape the recipe data
        scraped_data = scrape_recipe_from_url(url)
        
        self.stdout.write(self.style.SUCCESS("✓ Successfully scraped recipe data"))
        
        # Display scraped data
        self.stdout.write("\n" + "="*50)
        self.stdout.write("SCRAPED RECIPE DATA")
        self.stdout.write("="*50)
        
        self.stdout.write(f"Title: {scraped_data.get('title', 'N/A')}")
        self.stdout.write(f"Description: {scraped_data.get('description', 'N/A')[:100]}...")
        self.stdout.write(f"Prep Time: {scraped_data.get('prep_time', 'N/A')}")
        self.stdout.write(f"Cook Time: {scraped_data.get('cook_time', 'N/A')}")
        self.stdout.write(f"Servings: {scraped_data.get('servings', 'N/A')}")
        self.stdout.write(f"Source: {scraped_data.get('source_name', 'N/A')}")
        
        # Show ingredients
        ingredients = scraped_data.get('ingredients', [])
        self.stdout.write(f"\nIngredients ({len(ingredients)}):")
        for i, ingredient in enumerate(ingredients, 1):
            self.stdout.write(f"  {i}. {ingredient}")
        
        # Show equipment
        equipment = scraped_data.get('equipment', [])
        self.stdout.write(f"\nEquipment ({len(equipment)}):")
        for i, item in enumerate(equipment, 1):
            self.stdout.write(f"  {i}. {item}")
        
        # Show instructions
        instructions = scraped_data.get('instructions', [])
        self.stdout.write(f"\nInstructions ({len(instructions)}):")
        for i, instruction in enumerate(instructions, 1):
            self.stdout.write(f"  {i}. {instruction[:100]}...")
        
        if verbose:
            # Show full JSON data
            self.stdout.write("\n" + "="*50)
            self.stdout.write("FULL SCRAPED DATA (JSON)")
            self.stdout.write("="*50)
            self.stdout.write(json.dumps(scraped_data, indent=2))

    def _scrape_and_save(self, url: str, verbose: bool):
        """Actually scrape and save the recipe to the database."""
        with transaction.atomic():
            # Format and save the recipe
            recipe = format_recipe_from_url(url)
            
            self.stdout.write(self.style.SUCCESS(f"✓ Successfully created recipe: {recipe.title}"))
            
            # Display created objects
            self.stdout.write("\n" + "="*50)
            self.stdout.write("CREATED DATABASE OBJECTS")
            self.stdout.write("="*50)
            
            self.stdout.write(f"Recipe ID: {recipe.id}")
            self.stdout.write(f"Recipe Title: {recipe.title}")
            self.stdout.write(f"Total Time: {recipe.total_time} minutes")
            self.stdout.write(f"Servings: {recipe.servings}")
            
            # Show recipe ingredients
            recipe_ingredients = recipe.recipe_ingredients.all()
            self.stdout.write(f"\nRecipe Ingredients ({recipe_ingredients.count()}):")
            for ri in recipe_ingredients:
                self.stdout.write(f"  • {ri}")
            
            # Show instruction steps
            steps = recipe.steps.all()
            self.stdout.write(f"\nInstruction Steps ({steps.count()}):")
            for step in steps:
                self.stdout.write(f"  Step {step.order}: {step.template[:80]}...")
                if verbose:
                    self.stdout.write(f"    Rendered: {step.render()}")
                    self.stdout.write(f"    Ingredients: {[str(ri) for ri in step.ingredients.all()]}")
                    self.stdout.write(f"    Equipment: {[str(eq) for eq in step.equipment.all()]}")
            
            # Show equipment
            equipment = Equipment.objects.filter(instruction_steps__recipe=recipe).distinct()
            self.stdout.write(f"\nEquipment Used ({equipment.count()}):")
            for eq in equipment:
                self.stdout.write(f"  • {eq}")
            
            # Show new ingredients created
            new_ingredients = Ingredient.objects.filter(
                recipe_ingredients__recipe=recipe
            ).distinct()
            self.stdout.write(f"\nIngredients ({new_ingredients.count()}):")
            for ingredient in new_ingredients:
                self.stdout.write(f"  • {ingredient.name}")
            
            self.stdout.write("\n" + "="*50)
            self.stdout.write(self.style.SUCCESS("Recipe successfully saved to database!"))
            
            if verbose:
                # Show database query counts
                self.stdout.write(f"\nDatabase Statistics:")
                self.stdout.write(f"  Total Recipes: {Recipe.objects.count()}")
                self.stdout.write(f"  Total Ingredients: {Ingredient.objects.count()}")
                self.stdout.write(f"  Total Equipment: {Equipment.objects.count()}")
                self.stdout.write(f"  Total Recipe Ingredients: {RecipeIngredient.objects.count()}")
                self.stdout.write(f"  Total Instruction Steps: {InstructionStep.objects.count()}")


def test_recipe_scraping():
    """
    Test function to demonstrate the recipe scraping functionality.
    This can be called from Django shell or used for testing.
    """
    # Test URL from the user's example
    test_url = "https://downshiftology.com/recipes/mediterranean-ground-beef-stir-fry/"
    
    print("Testing recipe scraping and formatting...")
    print(f"URL: {test_url}")
    
    try:
        # Scrape and format the recipe
        recipe = format_recipe_from_url(test_url)
        
        print(f"\n✓ Successfully created recipe: {recipe.title}")
        print(f"Recipe ID: {recipe.id}")
        
        # Show some details
        print(f"\nIngredients:")
        for ri in recipe.recipe_ingredients.all():
            print(f"  • {ri}")
        
        print(f"\nInstructions:")
        for step in recipe.steps.all():
            print(f"  Step {step.order}: {step.render()}")
        
        return recipe
        
    except Exception as e:
        print(f"✗ Error: {e}")
        return None 