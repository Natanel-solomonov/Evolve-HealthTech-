import requests
import json
import re
from typing import Dict, List, Optional, Tuple, Any
from urllib.parse import urlparse
import logging
import random
import time

# BeautifulSoup for HTML parsing
try:
    from bs4 import BeautifulSoup
    BEAUTIFULSOUP_AVAILABLE = True
except ImportError:
    BEAUTIFULSOUP_AVAILABLE = False
    logging.warning("BeautifulSoup not available. Install with: pip install beautifulsoup4")

logger = logging.getLogger(__name__)


class RecipeScraper:
    """
    Professional recipe scraper optimized for AllRecipes and Simply Recipes.
    Prioritizes JSON-LD structured data with robust HTML fallbacks.
    """
    
    USER_AGENTS = [
        # Chrome
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        # Firefox
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0',
        # Safari
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15',
        # Edge
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
        # Mobile Chrome
        'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        # Mobile Safari
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
    ]

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': random.choice(self.USER_AGENTS)
        })
        
        # Unit normalization mapping
        self.unit_mapping = {
            'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp': 'tbsp',
            'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp': 'tsp',
            'cup': 'cup', 'cups': 'cup',
            'pound': 'lb', 'pounds': 'lb', 'lb': 'lb',
            'ounce': 'oz', 'ounces': 'oz', 'oz': 'oz',
            'gram': 'g', 'grams': 'g', 'g': 'g',
            'kilogram': 'kg', 'kilograms': 'kg', 'kg': 'kg',
            'milliliter': 'ml', 'milliliters': 'ml', 'ml': 'ml',
            'liter': 'l', 'liters': 'l', 'l': 'l',
            'clove': 'clove', 'cloves': 'clove',
            'piece': 'piece', 'pieces': 'piece',
            'slice': 'slice', 'slices': 'slice',
            'can': 'can', 'cans': 'can',
            'jar': 'jar', 'jars': 'jar',
            'package': 'package', 'packages': 'package',
            'pinch': 'pinch', 'pinches': 'pinch',
            'pint': 'pint', 'pints': 'pint',
            'quart': 'quart', 'quarts': 'quart',
            'stick': 'stick', 'sticks': 'stick',
            'bunch': 'bunch', 'bunches': 'bunch',
            'sprig': 'sprig', 'sprigs': 'sprig',
            'large': 'large', 'small': 'small', 'medium': 'medium'
        }
        
        # Unicode fractions
        self.fraction_mapping = {
            '½': '0.5', '⅓': '0.333', '⅔': '0.667', '¼': '0.25', '¾': '0.75',
            '⅕': '0.2', '⅖': '0.4', '⅗': '0.6', '⅘': '0.8', '⅙': '0.167',
            '⅚': '0.833', '⅛': '0.125', '⅜': '0.375', '⅝': '0.625', '⅞': '0.875'
        }
    
    def _get_with_rotation(self, url, timeout=30):
        # Rotate user-agent and add random delay
        self.session.headers['User-Agent'] = random.choice(self.USER_AGENTS)
        delay = random.uniform(1, 4)
        time.sleep(delay)
        return self.session.get(url, timeout=timeout)

    def scrape_recipe(self, url: str) -> Dict:
        """
        Scrape recipe data from URL with intelligent extraction strategies.
        """
        try:
            response = self._get_with_rotation(url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Strategy 1: Try JSON-LD structured data first (most reliable)
            structured_data = self._extract_json_ld(soup)
            if structured_data and self._is_valid_recipe_data(structured_data):
                return self._process_structured_data(structured_data, url)
            
            # Strategy 2: Site-specific HTML parsing
            site = self._identify_site(url)
            
            if site == 'allrecipes':
                return self._extract_allrecipes_data(soup, url)
            elif site == 'simplyrecipes':
                return self._extract_simplyrecipes_data(soup, url)
            else:
                return self._extract_generic_data(soup, url)
            
        except Exception as e:
            logger.error(f"Failed to scrape recipe from {url}: {e}")
            raise
    
    def _identify_site(self, url: str) -> str:
        """Identify recipe site from URL."""
        domain = urlparse(url).netloc.lower()
        
        if 'allrecipes.com' in domain:
            return 'allrecipes'
        elif 'simplyrecipes.com' in domain:
            return 'simplyrecipes'
        else:
            return 'generic'
    
    def _extract_json_ld(self, soup) -> Optional[Dict]:
        """Extract recipe data from JSON-LD structured data."""
        scripts = soup.find_all('script', type='application/ld+json')
        
        for script in scripts:
            try:
                if not script.string:
                    continue
                    
                data = json.loads(script.string)
                
                # Handle arrays and nested structures
                if isinstance(data, list):
                    for item in data:
                        recipe = self._find_recipe_in_data(item)
                        if recipe:
                            return recipe
                else:
                    recipe = self._find_recipe_in_data(data)
                    if recipe:
                        return recipe
                        
            except (json.JSONDecodeError, AttributeError):
                continue
        
        return None
    
    def _find_recipe_in_data(self, data) -> Optional[Dict]:
        """Recursively find recipe data in structured data."""
        if not isinstance(data, dict):
            return None
        
        # Check if this is a recipe
        if self._is_recipe_schema(data):
            return data
        
        # Check nested structures
        for key, value in data.items():
            if isinstance(value, dict):
                recipe = self._find_recipe_in_data(value)
                if recipe:
                    return recipe
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, dict):
                        recipe = self._find_recipe_in_data(item)
                        if recipe:
                            return recipe
        
        return None
    
    def _is_recipe_schema(self, data: Dict) -> bool:
        """Check if data is a recipe schema."""
        if not isinstance(data, dict):
            return False
        
        schema_type = data.get('@type', '').lower()
        return 'recipe' in schema_type and 'name' in data
    
    def _is_valid_recipe_data(self, data: Dict) -> bool:
        """Validate that structured data contains actual recipe content."""
        # Check required fields - be more lenient
        if not data.get('name'):
            return False
        
        # Check if ingredients list has content
        ingredients = data.get('recipeIngredient', [])
        if not isinstance(ingredients, list) or len(ingredients) < 1:
            return False
        
        # Basic validation that first ingredient looks like an ingredient
        first_ingredient = str(ingredients[0]).lower()
        if any(term in first_ingredient for term in ['oops', 'error', 'loading', 'javascript']):
            return False
        
        # Check if instructions exist (but don't require them)
        instructions = data.get('recipeInstructions', [])
        if not isinstance(instructions, list):
            return False
        
        return True
    
    def _process_structured_data(self, data: Dict, url: str) -> Dict:
        """Process clean structured recipe data."""
        # Extract and parse ingredients
        raw_ingredients = data.get('recipeIngredient', [])
        ingredients = []
        for ing in raw_ingredients:
            if isinstance(ing, str) and len(ing) > 2:
                parsed = self._parse_ingredient(ing)
                if parsed and parsed.get('name'):
                    ingredients.append(parsed)
        
        # Extract and format instructions
        raw_instructions = data.get('recipeInstructions', [])
        instructions = []
        step_num = 1
        for inst in raw_instructions:
            text = self._extract_instruction_text(inst)
            if text and len(text) > 10:
                cleaned = self._clean_instruction_text(text)
                if cleaned:
                    instructions.append(f"{step_num}. {cleaned}")
                    step_num += 1
        
        # Extract metadata
        prep_time = self._parse_duration(data.get('prepTime', ''))
        cook_time = self._parse_duration(data.get('cookTime', ''))
        total_time = self._parse_duration(data.get('totalTime', ''))
        
        if not total_time and (prep_time or cook_time):
            total_time = (prep_time or 0) + (cook_time or 0)
        
        servings = self._extract_servings_from_yield(data.get('recipeYield', ''))
        
        # Build result
        result = {
            "title": self._clean_text(data.get('name', '')),
            "ingredients": ingredients,
            "instructions": instructions,
            "equipment": self._extract_equipment_from_text(str(data)),
            "source_url": url,
            "source_name": self._get_source_name_from_url(url),
            "placeholders": []
        }
        
        # Add optional fields if present
        if prep_time:
            result["prep_time"] = prep_time
        if cook_time:
            result["cook_time"] = cook_time
        if total_time:
            result["total_time"] = total_time
        if servings:
            result["servings"] = servings
        
        return result
    
    def _extract_allrecipes_data(self, soup, url: str) -> Dict:
        """Extract AllRecipes data with targeted HTML parsing."""
        # Build result step by step
        result = {
            "title": self._extract_allrecipes_title(soup),
            "ingredients": self._extract_allrecipes_ingredients(soup),
            "instructions": self._extract_allrecipes_instructions(soup),
            "equipment": [],
            "source_url": url,
            "source_name": "AllRecipes",
            "placeholders": []
        }
        
        # Add timing and servings
        prep_time = self._extract_allrecipes_time(soup, 'prep')
        cook_time = self._extract_allrecipes_time(soup, 'cook')
        servings = self._extract_allrecipes_servings(soup)
        
        if prep_time:
            result["prep_time"] = prep_time
        if cook_time:
            result["cook_time"] = cook_time
        if prep_time or cook_time:
            result["total_time"] = (prep_time or 0) + (cook_time or 0)
        if servings:
            result["servings"] = servings
        
        # Extract equipment from instructions
        if result["instructions"]:
            instruction_text = " ".join(result["instructions"])
            result["equipment"] = self._extract_equipment_from_text(instruction_text)
        
        return result
    
    def _extract_allrecipes_title(self, soup) -> str:
        """Extract title from AllRecipes."""
        selectors = [
            'h1.recipe-summary__h1',
            'h1[data-testid="recipe-title"]',
            '.recipe-title h1',
            'h1.entry-title',
            'h1'
        ]
        
        for selector in selectors:
            element = soup.select_one(selector)
            if element:
                title = element.get_text(strip=True)
                if title and len(title) > 3:
                    return self._clean_text(title)
        
        return ""
    
    def _extract_allrecipes_ingredients(self, soup) -> List[Dict]:
        """Extract ingredients from AllRecipes."""
        ingredients = []
        
        # Primary selectors for AllRecipes ingredients
        selectors = [
            '[data-testid="recipe-ingredients"] li span',
            '.recipe-ingredients li span',
            '.ingredients-item-name',
            '.ingredients-section span',
            '.recipe-ingredient',
            'ul.ingredients li span'
        ]
        
        for selector in selectors:
            elements = soup.select(selector)
            if elements:
                for element in elements:
                    text = element.get_text(strip=True)
                    if self._is_valid_ingredient_text(text):
                        parsed = self._parse_ingredient(text)
                        if parsed and parsed.get('name'):
                            ingredients.append(parsed)
                
                # If we found ingredients with this selector, stop looking
                if ingredients:
                    break
        
        # Fallback: Look for ingredients heading and list (like Simply Recipes)
        if not ingredients:
            headings = soup.find_all(['h2', 'h3', 'h4'], string=re.compile(r'ingredients', re.IGNORECASE))
            
            for heading in headings:
                next_list = heading.find_next(['ul', 'ol'])
                if next_list:
                    for li in next_list.find_all('li'):
                        text = li.get_text(strip=True)
                        if self._is_valid_ingredient_text(text):
                            parsed = self._parse_ingredient(text)
                            if parsed and parsed.get('name'):
                                ingredients.append(parsed)
                    
                    if ingredients:
                        break
        
        return self._deduplicate_ingredients(ingredients)
    
    def _extract_allrecipes_instructions(self, soup) -> List[str]:
        """Extract instructions from AllRecipes."""
        instructions = []
        
        # Primary selectors for AllRecipes instructions
        selectors = [
            '[data-testid="recipe-instructions"] li',
            '.recipe-instructions li',
            '.instructions-section li',
            '.recipe-directions li',
            'ol.instructions li'
        ]
        
        for selector in selectors:
            elements = soup.select(selector)
            if elements:
                step_num = 1
                for element in elements:
                    text = element.get_text(strip=True)
                    if self._is_valid_instruction_text(text):
                        cleaned = self._clean_instruction_text(text)
                        if cleaned:
                            instructions.append(f"{step_num}. {cleaned}")
                            step_num += 1
                
                # If we found instructions with this selector, stop looking
                if instructions:
                    break
        
        # Fallback: Look for directions heading and content (like Simply Recipes)
        if not instructions:
            headings = soup.find_all(['h2', 'h3', 'h4'], string=re.compile(r'directions', re.IGNORECASE))
            
            for heading in headings:
                step_num = 1
                next_element = heading.find_next_sibling()
                
                while next_element and next_element.name not in ['h1', 'h2', 'h3', 'h4']:
                    if next_element.name in ['ul', 'ol']:
                        for li in next_element.find_all('li'):
                            text = li.get_text(strip=True)
                            if self._is_valid_instruction_text(text):
                                cleaned = self._clean_instruction_text(text)
                                if cleaned:
                                    instructions.append(f"{step_num}. {cleaned}")
                                    step_num += 1
                        break
                    elif next_element.name == 'p':
                        text = next_element.get_text(strip=True)
                        if self._is_valid_instruction_text(text):
                            cleaned = self._clean_instruction_text(text)
                            if cleaned:
                                instructions.append(f"{step_num}. {cleaned}")
                                step_num += 1
                    elif next_element.name == 'div':
                        # Look for numbered steps within div
                        step_elements = next_element.find_all(['p', 'li'], string=re.compile(r'^\d+\.', re.IGNORECASE))
                        if step_elements:
                            for elem in step_elements:
                                text = elem.get_text(strip=True)
                                if self._is_valid_instruction_text(text):
                                    cleaned = self._clean_instruction_text(text)
                                    if cleaned:
                                        instructions.append(f"{step_num}. {cleaned}")
                                        step_num += 1
                            break
                        else:
                            # Look for any paragraphs that might be instructions
                            paragraphs = next_element.find_all('p')
                            for p in paragraphs:
                                text = p.get_text(strip=True)
                                if self._is_valid_instruction_text(text):
                                    cleaned = self._clean_instruction_text(text)
                                    if cleaned:
                                        instructions.append(f"{step_num}. {cleaned}")
                                        step_num += 1
                    
                    next_element = next_element.find_next_sibling()
                
                if instructions:
                    break
        
        return instructions
    
    def _extract_allrecipes_time(self, soup, time_type: str) -> Optional[int]:
        """Extract time from AllRecipes."""
        if time_type == 'prep':
            selectors = [
                '[data-testid="prep-time"]',
                '.recipe-summary__prep-time',
                '.prep-time'
            ]
        else:
            selectors = [
                '[data-testid="cook-time"]',
                '.recipe-summary__cook-time',
                '.cook-time'
            ]
        
        for selector in selectors:
            element = soup.select_one(selector)
            if element:
                time_text = element.get_text(strip=True)
                parsed_time = self._parse_time_to_minutes(time_text)
                if parsed_time:
                    return parsed_time
        
        return None
    
    def _extract_allrecipes_servings(self, soup) -> Optional[int]:
        """Extract servings from AllRecipes."""
        selectors = [
            '[data-testid="servings"]',
            '.recipe-summary__servings',
            '.recipe-yield'
        ]
        
        for selector in selectors:
            element = soup.select_one(selector)
            if element:
                servings_text = element.get_text(strip=True)
                parsed_servings = self._parse_servings_to_number(servings_text)
                if parsed_servings:
                    return parsed_servings
        
        return None
    
    def _extract_simplyrecipes_data(self, soup, url: str) -> Dict:
        """Extract Simply Recipes data with targeted parsing."""
        # Find main article content to focus search
        main_content = soup.find('article') or soup.find('main') or soup
        
        result = {
            "title": self._extract_simplyrecipes_title(main_content),
            "ingredients": self._extract_simplyrecipes_ingredients(main_content),
            "instructions": self._extract_simplyrecipes_instructions(main_content),
            "equipment": [],
            "source_url": url,
            "source_name": "Simply Recipes",
            "placeholders": []
        }
        
        # Add timing and servings from text analysis
        text_content = main_content.get_text()
        prep_time = self._extract_time_from_text(text_content, 'prep')
        cook_time = self._extract_time_from_text(text_content, 'cook')
        servings = self._extract_servings_from_text(text_content)
        
        if prep_time:
            result["prep_time"] = prep_time
        if cook_time:
            result["cook_time"] = cook_time
        if prep_time or cook_time:
            result["total_time"] = (prep_time or 0) + (cook_time or 0)
        if servings:
            result["servings"] = servings
        
        # Extract equipment from all content
        if result["instructions"]:
            instruction_text = " ".join(result["instructions"])
            result["equipment"] = self._extract_equipment_from_text(instruction_text)
        
        return result
    
    def _extract_simplyrecipes_title(self, soup) -> str:
        """Extract title from Simply Recipes."""
        selectors = [
            'h1.entry-title',
            'h1.recipe-title',
            'h1',
            '.post-title h1'
        ]
        
        for selector in selectors:
            element = soup.select_one(selector)
            if element:
                title = element.get_text(strip=True)
                if title and len(title) > 3:
                    return self._clean_text(title)
        
        return ""
    
    def _extract_simplyrecipes_ingredients(self, soup) -> List[Dict]:
        """Extract ingredients from Simply Recipes."""
        ingredients = []
        
        # Look for ingredients section heading followed by list
        headings = soup.find_all(['h2', 'h3', 'h4'], string=re.compile(r'ingredients', re.IGNORECASE))
        
        for heading in headings:
            # Find the next list after the ingredients heading
            next_list = heading.find_next(['ul', 'ol'])
            if next_list:
                for li in next_list.find_all('li'):
                    text = li.get_text(strip=True)
                    if self._is_valid_ingredient_text(text):
                        parsed = self._parse_ingredient(text)
                        if parsed and parsed.get('name'):
                            ingredients.append(parsed)
                
                # If we found ingredients, stop looking
                if ingredients:
                    break
        
        return self._deduplicate_ingredients(ingredients)
    
    def _extract_simplyrecipes_instructions(self, soup) -> List[str]:
        """Extract instructions from Simply Recipes."""
        instructions = []
        
        # Look for method/instructions/directions section
        method_terms = ['method', 'instructions', 'directions']
        headings = []
        for term in method_terms:
            headings += soup.find_all(['h2', 'h3', 'h4'], string=re.compile(term, re.IGNORECASE))
        if not headings:
            return instructions
        method_heading = headings[0]
        # Find the parent container (article or main)
        parent = method_heading.find_parent(['article', 'main']) or soup
        # Collect all elements after the method heading until the next heading
        found_method = False
        step_num = 1
        for elem in parent.descendants:
            if elem == method_heading:
                found_method = True
                continue
            if not found_method:
                continue
            # Stop if we hit another section heading
            if getattr(elem, 'name', None) in ['h1', 'h2', 'h3', 'h4']:
                break
            if getattr(elem, 'name', None) in ['p', 'li']:
                text = elem.get_text(strip=True)
                if self._is_valid_instruction_text(text):
                    cleaned = self._clean_instruction_text(text)
                    if cleaned:
                        instructions.append(f"{step_num}. {cleaned}")
                        step_num += 1
        return instructions
    
    def _extract_time_from_text(self, text: str, time_type: str) -> Optional[int]:
        """Extract time from text content."""
        if time_type == 'prep':
            patterns = [
                r'prep time[:\s]*(\d+)\s*(?:minutes?|mins?)',
                r'preparation[:\s]*(\d+)\s*(?:minutes?|mins?)'
            ]
        else:
            patterns = [
                r'cook time[:\s]*(\d+)\s*(?:minutes?|mins?)',
                r'cooking[:\s]*(\d+)\s*(?:minutes?|mins?)',
                r'bake[:\s]*(\d+)\s*(?:minutes?|mins?)'
            ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return int(match.group(1))
        
        return None
    
    def _extract_servings_from_text(self, text: str) -> Optional[int]:
        """Extract servings from text content."""
        patterns = [
            r'serves[:\s]*(\d+)',
            r'servings[:\s]*(\d+)',
            r'(\d+)\s*servings',
            r'yield[:\s]*(\d+)',
            r'makes[:\s]*(\d+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return int(match.group(1))
        
        return None
    
    def _extract_generic_data(self, soup, url: str) -> Dict:
        """Generic extraction for other sites."""
        return {
            "title": self._extract_generic_title(soup),
            "ingredients": [],
            "instructions": [],
            "equipment": [],
            "source_url": url,
            "source_name": self._get_source_name_from_url(url),
            "placeholders": []
        }
    
    def _extract_generic_title(self, soup) -> str:
        """Extract title from generic sites."""
        selectors = ['h1', '.title', '.recipe-title']
        
        for selector in selectors:
            element = soup.select_one(selector)
            if element:
                title = element.get_text(strip=True)
                if title and len(title) > 3:
                    return self._clean_text(title)
        
        return ""
    
    def _is_valid_ingredient_text(self, text: str) -> bool:
        """Check if text looks like a valid ingredient."""
        if not text or len(text) < 3:
            return False
        
        text_lower = text.lower()
        
        # Skip obvious UI text
        ui_terms = [
            'cook mode', 'keep screen', 'oops', 'something went wrong',
            'ingredient amounts', 'nutrition facts', 'calories', 'protein',
            'original recipe', 'scale perfectly', 'team is working'
        ]
        
        if any(term in text_lower for term in ui_terms):
            return False
        
        # Check for ingredient indicators
        has_quantity = bool(re.search(r'^\d+', text) or re.search(r'^\d+/', text))
        has_unit = any(unit in text_lower for unit in ['cup', 'tsp', 'tbsp', 'oz', 'lb', 'gram', 'clove'])
        has_food_word = any(word in text_lower for word in [
            'oil', 'salt', 'pepper', 'garlic', 'onion', 'butter', 'egg', 'flour',
            'sugar', 'milk', 'cheese', 'beef', 'chicken', 'tomato', 'potato'
        ])
        
        return has_quantity or has_unit or has_food_word
    
    def _is_valid_instruction_text(self, text: str) -> bool:
        """Check if text looks like a cooking instruction."""
        if not text or len(text) < 15:
            return False
        
        text_lower = text.lower()
        
        # Skip UI text
        ui_terms = [
            'cook mode', 'keep screen', 'oops', 'something went wrong',
            'nutrition facts', 'allrecipes', 'simply recipes'
        ]
        
        if any(term in text_lower for term in ui_terms):
            return False
        
        # Must contain cooking verbs
        cooking_verbs = [
            'preheat', 'heat', 'cook', 'bake', 'fry', 'boil', 'simmer',
            'mix', 'stir', 'whisk', 'combine', 'add', 'place', 'remove',
            'serve', 'season', 'chop', 'dice', 'slice', 'grill'
        ]
        
        return any(verb in text_lower for verb in cooking_verbs)
    
    def _parse_ingredient(self, text: str) -> Optional[Dict]:
        """Parse ingredient text into structured format."""
        if not text:
            return None
        
        text = self._clean_text(text)
        text = self._normalize_fractions(text)
        
        quantity, unit, name = self._extract_quantity_unit_name(text)
        
        if not name:
            return None
        
        result = {"name": name}
        
        if quantity is not None:
            result["quantity"] = quantity
        if unit is not None:
            result["unit"] = self.unit_mapping.get(unit.lower(), unit.lower())
        else:
            result["unit"] = "to taste"
        
        return result
    
    def _extract_quantity_unit_name(self, text: str) -> Tuple[Optional[float], Optional[str], str]:
        """Extract quantity, unit, and name from ingredient text."""
        text = text.strip()
        
        # Patterns for parsing ingredients
        patterns = [
            # "2 tablespoons olive oil"
            r'^(\d+(?:\.\d+)?)\s+(\w+)\s+(.+)$',
            # "1/2 cup flour"
            r'^(\d+/\d+)\s+(\w+)\s+(.+)$',
            # "2 large eggs"
            r'^(\d+)\s+(large|small|medium)\s+(.+)$',
            # "3 eggs"
            r'^(\d+)\s+(.+)$',
            # Just name
            r'^(.+)$'
        ]
        
        for pattern in patterns:
            match = re.match(pattern, text)
            if match:
                groups = match.groups()
                
                if len(groups) == 3:
                    quantity_str, unit, name = groups
                    try:
                        if '/' in quantity_str:
                            num, denom = quantity_str.split('/')
                            quantity = float(num) / float(denom)
                        else:
                            quantity = float(quantity_str)
                        
                        # Handle size descriptors
                        if unit.lower() in ['large', 'small', 'medium']:
                            name = f"{unit} {name}"
                            unit = None
                        
                        return quantity, unit, name
                    except ValueError:
                        pass
                        
                elif len(groups) == 2:
                    quantity_str, name = groups
                    try:
                        quantity = float(quantity_str)
                        return quantity, None, name
                    except ValueError:
                        pass
                        
                else:
                    return None, None, str(groups[0])
        
        return None, None, text
    
    def _clean_text(self, text: str) -> str:
        """Clean text of extra whitespace and artifacts."""
        if not text:
            return ""
        
        text = re.sub(r'\s+', ' ', text)
        text = text.strip()
        text = re.sub(r'[▢●◆■]', '', text)
        
        return text
    
    def _clean_instruction_text(self, text: str) -> str:
        """Clean instruction text."""
        text = self._clean_text(text)
        
        # Remove step numbers
        text = re.sub(r'^\d+\.\s*', '', text)
        text = re.sub(r'^Step\s+\d+:?\s*', '', text, flags=re.IGNORECASE)
        
        # Ensure proper ending
        if text and not text.endswith('.'):
            text += '.'
        
        return text
    
    def _normalize_fractions(self, text: str) -> str:
        """Convert unicode fractions to decimals."""
        for fraction, decimal in self.fraction_mapping.items():
            text = text.replace(fraction, decimal)
        return text
    
    def _parse_time_to_minutes(self, time_str: str) -> Optional[int]:
        """Parse time string to minutes."""
        if not time_str:
            return None
        
        numbers = re.findall(r'\d+', time_str.lower())
        if not numbers:
            return None
        
        minutes = int(numbers[0])
        
        if 'hour' in time_str.lower() or 'hr' in time_str.lower():
            minutes *= 60
        
        return minutes
    
    def _parse_servings_to_number(self, servings_str: str) -> Optional[int]:
        """Parse servings string to number."""
        if not servings_str:
            return None
        
        numbers = re.findall(r'\d+', servings_str)
        return int(numbers[0]) if numbers else None
    
    def _parse_duration(self, duration_str: str) -> Optional[int]:
        """Parse ISO 8601 duration to minutes."""
        if not duration_str:
            return None
        
        if duration_str.startswith('PT'):
            minutes = 0
            hours_match = re.search(r'(\d+)H', duration_str)
            mins_match = re.search(r'(\d+)M', duration_str)
            
            if hours_match:
                minutes += int(hours_match.group(1)) * 60
            if mins_match:
                minutes += int(mins_match.group(1))
            
            return minutes
        
        return self._parse_time_to_minutes(duration_str)
    
    def _extract_servings_from_yield(self, yield_data) -> Optional[int]:
        """Extract servings number from yield data."""
        if isinstance(yield_data, (list, tuple)) and yield_data:
            yield_str = str(yield_data[0])
        else:
            yield_str = str(yield_data)
        
        numbers = re.findall(r'\d+', yield_str)
        return int(numbers[0]) if numbers else None
    
    def _extract_instruction_text(self, instruction) -> str:
        """Extract text from instruction object."""
        if isinstance(instruction, str):
            return instruction
        elif isinstance(instruction, dict):
            return instruction.get('text', '')
        return ""
    
    def _extract_equipment_from_text(self, text: str) -> List[Dict]:
        """Extract equipment from text content."""
        equipment = set()
        text_lower = text.lower()
        
        equipment_terms = [
            'oven', 'grill', 'pan', 'skillet', 'pot', 'bowl', 'baking sheet',
            'whisk', 'spatula', 'spoon', 'tongs', 'thermometer'
        ]
        
        for term in equipment_terms:
            if term in text_lower:
                equipment.add(term.title())
        
        return [{"name": name} for name in sorted(equipment)]
    
    def _get_source_name_from_url(self, url: str) -> str:
        """Get source name from URL."""
        domain = urlparse(url).netloc.lower()
        domain = domain.replace('www.', '')
        
        if 'allrecipes' in domain:
            return 'AllRecipes'
        elif 'simplyrecipes' in domain:
            return 'Simply Recipes'
        else:
            return domain.split('.')[0].title()
    
    def _deduplicate_ingredients(self, ingredients: List[Dict]) -> List[Dict]:
        """Remove duplicate ingredients."""
        seen = set()
        result = []
        
        for ingredient in ingredients:
            name = ingredient.get('name', '').lower()
            if name and name not in seen and len(name) > 2:
                seen.add(name)
                result.append(ingredient)
        
        return result


def scrape_recipe_from_url(url: str) -> Dict:
    """
    Convenience function to scrape recipe from URL.
    """
    scraper = RecipeScraper()
    return scraper.scrape_recipe(url)