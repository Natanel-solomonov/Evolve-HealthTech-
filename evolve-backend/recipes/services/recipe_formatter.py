import re
from typing import Dict, List, Tuple, Optional
from django.db import transaction
from django.core.exceptions import ValidationError
import logging

from ..models import (
    Recipe, Ingredient, Equipment, RecipeIngredient, 
    InstructionStep, RecipeNutrition
)

logger = logging.getLogger(__name__)


class RecipeFormatter:
    """
    Converts scraped recipe data into Django model format with dynamic instruction templates.
    """
    
    def __init__(self):
        # Common unit mappings for ingredient parsing
        self.unit_mappings = {
            'tablespoon': 'tbsp',
            'tablespoons': 'tbsp',
            'tbsp': 'tbsp',
            'teaspoon': 'tsp',
            'teaspoons': 'tsp',
            'tsp': 'tsp',
            'cup': 'cup',
            'cups': 'cup',
            'pound': 'lb',
            'pounds': 'lb',
            'lb': 'lb',
            'ounce': 'oz',
            'ounces': 'oz',
            'oz': 'oz',
            'gram': 'g',
            'grams': 'g',
            'g': 'g',
            'kilogram': 'kg',
            'kilograms': 'kg',
            'kg': 'kg',
            'milliliter': 'ml',
            'milliliters': 'ml',
            'ml': 'ml',
            'liter': 'l',
            'liters': 'l',
            'l': 'l',
            'clove': 'clove',
            'cloves': 'clove',
            'bunch': 'bunch',
            'bunches': 'bunch',
            'sprig': 'sprig',
            'sprigs': 'sprig',
            'slice': 'slice',
            'slices': 'slice',
            'piece': 'piece',
            'pieces': 'piece',
            'can': 'can',
            'cans': 'can',
            'jar': 'jar',
            'jars': 'jar',
            'package': 'package',
            'packages': 'package',
            'packet': 'packet',
            'packets': 'packet',
            'pinch': 'pinch',
            'pinches': 'pinch',
            'dash': 'dash',
            'dashes': 'dash',
            'handful': 'handful',
            'handfuls': 'handful',
            'each': 'each',
            'whole': 'whole',
            'half': 'half',
            'quarter': 'quarter',
        }
        
        # Common equipment size mappings
        self.equipment_size_mappings = {
            'large': 'large',
            'medium': 'medium',
            'small': 'small',
            '12-inch': '12-inch',
            '10-inch': '10-inch',
            '8-inch': '8-inch',
            '6-inch': '6-inch',
            '9x13': '9x13',
            '8x8': '8x8',
            '9x5': '9x5',
        }
    
    def format_recipe_from_scraped_data(self, scraped_data: Dict) -> Recipe:
        """
        Convert scraped recipe data into a Django Recipe model with all related objects.
        
        Args:
            scraped_data: Dictionary containing scraped recipe data
            
        Returns:
            Recipe object with all related ingredients, equipment, and instructions
        """
        with transaction.atomic():
            # Create or get the main recipe
            recipe = self._create_recipe(scraped_data)
            
            # Process ingredients
            recipe_ingredients = self._process_ingredients(recipe, scraped_data.get('ingredients', []))
            
            # Process equipment
            equipment_objects = self._process_equipment(scraped_data.get('equipment', []))
            
            # Process instructions with dynamic templates
            self._process_instructions(recipe, scraped_data.get('instructions', []), recipe_ingredients, equipment_objects)
            
            return recipe
    
    def _create_recipe(self, scraped_data: Dict) -> Recipe:
        """Create the main Recipe object."""
        # Parse timing information
        prep_time = self._parse_time(scraped_data.get('prep_time', ''))
        cook_time = self._parse_time(scraped_data.get('cook_time', ''))
        servings = self._parse_servings(scraped_data.get('servings', ''))
        
        recipe = Recipe.objects.create(
            title=scraped_data.get('title', 'Untitled Recipe'),
            description=scraped_data.get('description', ''),
            prep_time=prep_time,
            cook_time=cook_time,
            servings=servings,
            source_url=scraped_data.get('source_url', ''),
            source_name=scraped_data.get('source_name', ''),
            image_url=scraped_data.get('image_url', ''),
            tags=[]  # Could be extracted from scraped data if available
        )
        
        logger.info(f"Created recipe: {recipe.title}")
        return recipe
    
    def _process_ingredients(self, recipe: Recipe, ingredients_list: List) -> List[RecipeIngredient]:
        """Process ingredients and create RecipeIngredient objects. Accepts both dict and string."""
        recipe_ingredients = []
        for i, ingredient in enumerate(ingredients_list):
            try:
                if isinstance(ingredient, dict):
                    ingredient_name = ingredient.get('name', '').strip().lower()
                    quantity = ingredient.get('quantity', 1.0)
                    unit = ingredient.get('unit', 'to taste')
                else:
                    # Parse ingredient text to extract quantity, unit, and name
                    quantity, unit, ingredient_name = self._parse_ingredient(ingredient)
                if not ingredient_name:
                    continue
                ingredient_obj, created = Ingredient.objects.get_or_create(
                    name=ingredient_name
                )
                recipe_ingredient = RecipeIngredient.objects.create(
                    recipe=recipe,
                    ingredient=ingredient_obj,
                    quantity=quantity,
                    unit=unit,
                    order=i
                )
                recipe_ingredients.append(recipe_ingredient)
                if created:
                    logger.info(f"Created new ingredient: {ingredient_name}")
            except Exception as e:
                logger.warning(f"Failed to process ingredient '{ingredient}': {e}")
                continue
        logger.info(f"Processed {len(recipe_ingredients)} ingredients for recipe {recipe.title}")
        return recipe_ingredients

    def _process_equipment(self, equipment_list: List) -> List[Equipment]:
        """Process equipment and create Equipment objects. Accepts both dict and string."""
        equipment_objects = []
        for equipment in equipment_list:
            try:
                if isinstance(equipment, dict):
                    equipment_name = equipment.get('name', '').strip().lower()
                    size = equipment.get('size', '')
                else:
                    size, equipment_name = self._parse_equipment(equipment)
                if not equipment_name:
                    continue
                equipment_obj, created = Equipment.objects.get_or_create(
                    name=equipment_name,
                    size=size
                )
                equipment_objects.append(equipment_obj)
                if created:
                    logger.info(f"Created new equipment: {equipment_name}")
            except Exception as e:
                logger.warning(f"Failed to process equipment '{equipment}': {e}")
                continue
        logger.info(f"Processed {len(equipment_objects)} equipment items")
        return equipment_objects
    
    def _process_instructions(self, recipe: Recipe, instructions_list: List[str], 
                            recipe_ingredients: List[RecipeIngredient], 
                            equipment_objects: List[Equipment]) -> None:
        """Process instructions and create dynamic templates."""
        
        for i, instruction_text in enumerate(instructions_list):
            try:
                # Create dynamic template by replacing ingredient and equipment names with placeholders
                template, used_ingredients, used_equipment = self._create_dynamic_template(
                    instruction_text, recipe_ingredients, equipment_objects
                )
                
                # Create InstructionStep
                step = InstructionStep.objects.create(
                    recipe=recipe,
                    order=i + 1,
                    template=template
                )
                
                # Link ingredients and equipment
                step.ingredients.set(used_ingredients)
                step.equipment.set(used_equipment)
                
                logger.info(f"Created instruction step {i + 1} with {len(used_ingredients)} ingredients and {len(used_equipment)} equipment")
                
            except Exception as e:
                logger.warning(f"Failed to process instruction '{instruction_text}': {e}")
                continue
    
    def _parse_ingredient(self, ingredient_text: str) -> Tuple[float, str, str]:
        """
        Parse ingredient text to extract quantity, unit, and ingredient name.
        
        Args:
            ingredient_text: Raw ingredient text like "2 tablespoons olive oil"
            
        Returns:
            Tuple of (quantity, unit, ingredient_name)
        """
        # Common patterns for ingredient parsing
        patterns = [
            # "2 tablespoons olive oil" -> (2.0, "tbsp", "olive oil")
            r'^(\d+(?:\.\d+)?)\s+(\w+)\s+(.+)$',
            # "1/2 cup flour" -> (0.5, "cup", "flour")
            r'^(\d+/\d+)\s+(\w+)\s+(.+)$',
            # "1 large onion" -> (1.0, "each", "large onion")
            r'^(\d+)\s+(large|medium|small)\s+(.+)$',
            # "salt to taste" -> (1.0, "to taste", "salt")
            r'^(.+)\s+to\s+taste$',
            # "olive oil" -> (1.0, "to taste", "olive oil")
            r'^(.+)$',
        ]
        
        ingredient_text = ingredient_text.strip().lower()
        
        for pattern in patterns:
            match = re.match(pattern, ingredient_text)
            if match:
                if pattern == r'^(\d+(?:\.\d+)?)\s+(\w+)\s+(.+)$':
                    quantity = float(match.group(1))
                    unit = self.unit_mappings.get(match.group(2), match.group(2))
                    ingredient_name = match.group(3).strip()
                    return quantity, unit, ingredient_name
                
                elif pattern == r'^(\d+/\d+)\s+(\w+)\s+(.+)$':
                    # Handle fractions
                    fraction = match.group(1)
                    if '/' in fraction:
                        num, denom = fraction.split('/')
                        quantity = float(num) / float(denom)
                    else:
                        quantity = float(fraction)
                    
                    unit = self.unit_mappings.get(match.group(2), match.group(2))
                    ingredient_name = match.group(3).strip()
                    return quantity, unit, ingredient_name
                
                elif pattern == r'^(\d+)\s+(large|medium|small)\s+(.+)$':
                    quantity = float(match.group(1))
                    size = match.group(2)
                    ingredient_name = f"{size} {match.group(3).strip()}"
                    return quantity, "each", ingredient_name
                
                elif pattern == r'^(.+)\s+to\s+taste$':
                    ingredient_name = match.group(1).strip()
                    return 1.0, "to taste", ingredient_name
                
                elif pattern == r'^(.+)$':
                    ingredient_name = match.group(1).strip()
                    return 1.0, "to taste", ingredient_name
        
        # Fallback
        return 1.0, "to taste", ingredient_text
    
    def _parse_equipment(self, equipment_text: str) -> Tuple[str, str]:
        """
        Parse equipment text to extract size and equipment name.
        
        Args:
            equipment_text: Raw equipment text like "large skillet"
            
        Returns:
            Tuple of (size, equipment_name)
        """
        equipment_text = equipment_text.strip().lower()
        
        # Check for size prefixes
        for size in self.equipment_size_mappings:
            if equipment_text.startswith(f"{size} "):
                equipment_name = equipment_text[len(f"{size} "):].strip()
                return size, equipment_name
        
        # No size specified
        return "", equipment_text
    
    def _create_dynamic_template(self, instruction_text: str, 
                                recipe_ingredients: List[RecipeIngredient],
                                equipment_objects: List[Equipment]) -> Tuple[str, List[RecipeIngredient], List[Equipment]]:
        """
        Create a dynamic template by replacing ingredient and equipment names with placeholders.
        
        Args:
            instruction_text: Raw instruction text
            recipe_ingredients: List of RecipeIngredient objects
            equipment_objects: List of Equipment objects
            
        Returns:
            Tuple of (template, used_ingredients, used_equipment)
        """
        template = instruction_text
        used_ingredients = []
        used_equipment = []
        
        # Replace ingredient references
        for ri in recipe_ingredients:
            ingredient_name = ri.ingredient.name.lower()
            # Check if ingredient name appears in instruction
            if ingredient_name in template.lower():
                placeholder = f"{{ri:{ri.id}}}"
                # Replace the first occurrence (case-insensitive)
                pattern = re.compile(re.escape(ingredient_name), re.IGNORECASE)
                template = pattern.sub(placeholder, template, count=1)
                used_ingredients.append(ri)
        
        # Replace equipment references
        for eq in equipment_objects:
            equipment_name = eq.name.lower()
            if equipment_name in template.lower():
                placeholder = f"{{eq:{eq.id}}}"
                pattern = re.compile(re.escape(equipment_name), re.IGNORECASE)
                template = pattern.sub(placeholder, template, count=1)
                used_equipment.append(eq)
        
        return template, used_ingredients, used_equipment
    
    def _parse_time(self, time_text) -> Optional[int]:
        """Parse time text and return minutes as integer."""
        if not time_text:
            return None
        
        # If already an integer, return it
        if isinstance(time_text, int):
            return time_text
        
        # Convert to string and parse
        time_text = str(time_text).lower().strip()
        
        # Extract numbers from time text
        numbers = re.findall(r'\d+', time_text)
        if not numbers:
            return None
        
        minutes = int(numbers[0])
        
        # Convert to minutes if hours are mentioned
        if 'hour' in time_text or 'hr' in time_text:
            minutes *= 60
            if len(numbers) > 1:
                minutes += int(numbers[1])
        
        return minutes
    
    def _parse_servings(self, servings_text) -> Optional[int]:
        """Parse servings text and return number as integer."""
        if not servings_text:
            return None
        
        # If already an integer, return it
        if isinstance(servings_text, int):
            return servings_text
        
        # Convert to string and parse
        servings_text = str(servings_text)
        
        # Extract numbers from servings text
        numbers = re.findall(r'\d+', servings_text)
        if numbers:
            return int(numbers[0])
        
        return None


def format_recipe_from_url(url: str) -> Recipe:
    """
    Convenience function to scrape and format a recipe from a URL.
    
    Args:
        url: The URL of the recipe to scrape and format
        
    Returns:
        Recipe object with all related objects created
    """
    from .recipe_scraper import scrape_recipe_from_url
    
    # Scrape the recipe
    scraped_data = scrape_recipe_from_url(url)
    
    # Format the recipe
    formatter = RecipeFormatter()
    recipe = formatter.format_recipe_from_scraped_data(scraped_data)
    
    return recipe 