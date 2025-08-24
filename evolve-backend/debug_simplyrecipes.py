#!/usr/bin/env python3
import requests
from bs4 import BeautifulSoup
import json

def debug_simplyrecipes_structure():
    url = "https://www.simplyrecipes.com/easy-steak-au-poivre-recipe-8785647"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        print("=== DEBUGGING SIMPLY RECIPES STRUCTURE ===")
        print(f"URL: {url}")
        print(f"Status: {response.status_code}")
        print(f"Content length: {len(response.content)}")
        
        # Look for ingredients section
        print("\n=== LOOKING FOR INGREDIENTS ===")
        
        # Try different selectors
        selectors = [
            '.recipe-ingredients li',
            '.ingredients li', 
            '.ingredient-item',
            '.ingredient',
            '[data-testid="ingredient"]',
            '.recipe-ingredients-list li',
            'ul li',  # All list items
            '.ingredients-list li',
        ]
        
        for selector in selectors:
            elements = soup.select(selector)
            if elements:
                print(f"\nFound {len(elements)} elements with selector: {selector}")
                for i, element in enumerate(elements[:5]):  # Show first 5
                    text = element.get_text(strip=True)
                    if text and len(text) > 10:
                        print(f"  {i+1}. {text[:100]}...")
                break
        
        # Look for ingredients by text content
        print("\n=== LOOKING FOR INGREDIENTS BY TEXT ===")
        all_text = soup.get_text()
        
        # Find ingredients section
        ingredients_patterns = [
            r'ingredients\s*:?\s*(.+?)(?:\n\s*method|\n\s*directions|\n\s*instructions|\n\s*$)', 
            r'ingredients\s*:?\s*(.+?)(?=\n\s*[A-Z][a-z]+:)',
        ]
        
        for pattern in ingredients_patterns:
            match = re.search(pattern, all_text, re.I | re.S)
            if match:
                ingredients_text = match.group(1)
                print(f"Found ingredients section with pattern: {pattern}")
                print("Ingredients text:")
                print(ingredients_text[:500] + "..." if len(ingredients_text) > 500 else ingredients_text)
                break
        
        # Look for specific ingredient patterns
        print("\n=== LOOKING FOR SPECIFIC INGREDIENT PATTERNS ===")
        ingredient_patterns = [
            r'\d+\s*(?:/\d+)?\s*(?:cup|tsp|tbsp|teaspoon|tablespoon|ounce|pound)s?\s*\([^)]*\)\s*[^.\n]*',
            r'\d+\s*(?:/\d+)?\s*(?:cup|tsp|tbsp|teaspoon|tablespoon|ounce|pound)s?\s+[^.\n]*',
            r'flank steak',
            r'peppercorns',
            r'cognac',
            r'beef broth',
        ]
        
        for pattern in ingredient_patterns:
            matches = re.findall(pattern, all_text, re.IGNORECASE)
            if matches:
                print(f"Pattern '{pattern}' found {len(matches)} matches:")
                for match in matches[:3]:  # Show first 3
                    print(f"  - {match}")
        
        # Look for the ingredients list in HTML
        print("\n=== LOOKING FOR INGREDIENTS IN HTML ===")
        
        # Find all lists
        lists = soup.find_all(['ul', 'ol'])
        for i, lst in enumerate(lists):
            items = lst.find_all('li')
            if items:
                print(f"\nList {i+1} has {len(items)} items:")
                for j, item in enumerate(items[:3]):  # Show first 3
                    text = item.get_text(strip=True)
                    if text and len(text) > 5:
                        print(f"  {j+1}. {text[:80]}...")
        
        # Look for the specific ingredients section
        print("\n=== LOOKING FOR INGREDIENTS SECTION ===")
        
        # Try to find by heading
        headings = soup.find_all(['h1', 'h2', 'h3', 'h4'])
        for heading in headings:
            text = heading.get_text(strip=True).lower()
            if 'ingredient' in text:
                print(f"Found ingredients heading: '{heading.get_text(strip=True)}'")
                # Look at next siblings
                current = heading.find_next_sibling()
                count = 0
                while current and count < 5:
                    if current.name in ['ul', 'ol']:
                        items = current.find_all('li')
                        print(f"  Found list with {len(items)} items:")
                        for item in items[:3]:
                            print(f"    - {item.get_text(strip=True)}")
                        break
                    current = current.find_next_sibling()
                    count += 1
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    import re
    debug_simplyrecipes_structure() 