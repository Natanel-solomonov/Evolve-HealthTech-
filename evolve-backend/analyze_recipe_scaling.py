#!/usr/bin/env python3
import sys
import os
import django
import json
import time
import psutil
import requests
from typing import Dict, List, Tuple
from dataclasses import dataclass
import logging

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.db import connection
from django.conf import settings
from recipes.models import Recipe, Ingredient, Equipment, RecipeIngredient, InstructionStep
from recipes.services.recipe_scraper import scrape_recipe_from_url

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class ScalingAnalysis:
    """Data class to hold scaling analysis results."""
    recipe_count: int
    estimated_size_gb: float
    estimated_memory_mb: float
    estimated_storage_cost_monthly: float
    estimated_compute_cost_monthly: float
    database_queries_per_recipe: int
    total_queries: int
    estimated_scraping_time_hours: float

class RecipeScalingAnalyzer:
    """Analyze scaling requirements for recipe database."""
    
    def __init__(self):
        self.base_recipe_size_bytes = 0
        self.base_ingredient_size_bytes = 0
        self.base_equipment_size_bytes = 0
        self.base_instruction_size_bytes = 0
        
    def analyze_current_database_size(self) -> Dict:
        """Analyze current database size and get baseline metrics."""
        print("Analyzing current database size...")
        
        # Get current counts
        recipe_count = Recipe.objects.count()
        ingredient_count = Ingredient.objects.count()
        equipment_count = Equipment.objects.count()
        instruction_count = InstructionStep.objects.count()
        recipe_ingredient_count = RecipeIngredient.objects.count()
        
        # Estimate sizes (rough estimates based on typical data)
        recipe_size = 500  # bytes per recipe (title, description, metadata)
        ingredient_size = 100  # bytes per ingredient
        equipment_size = 80  # bytes per equipment
        instruction_size = 300  # bytes per instruction step
        recipe_ingredient_size = 50  # bytes per recipe-ingredient link
        
        total_size_bytes = (
            recipe_count * recipe_size +
            ingredient_count * ingredient_size +
            equipment_count * equipment_size +
            instruction_count * instruction_size +
            recipe_ingredient_count * recipe_ingredient_size
        )
        
        total_size_gb = total_size_bytes / (1024**3)
        
        print(f"Current database stats:")
        print(f"  Recipes: {recipe_count}")
        print(f"  Ingredients: {ingredient_count}")
        print(f"  Equipment: {equipment_count}")
        print(f"  Instructions: {instruction_count}")
        print(f"  Recipe-Ingredient links: {recipe_ingredient_count}")
        print(f"  Estimated size: {total_size_gb:.4f} GB")
        
        return {
            'recipe_count': recipe_count,
            'ingredient_count': ingredient_count,
            'equipment_count': equipment_count,
            'instruction_count': instruction_count,
            'recipe_ingredient_count': recipe_ingredient_count,
            'total_size_gb': total_size_gb,
            'avg_recipe_size_bytes': recipe_size,
            'avg_ingredient_size_bytes': ingredient_size,
            'avg_equipment_size_bytes': equipment_size,
            'avg_instruction_size_bytes': instruction_size,
            'avg_recipe_ingredient_size_bytes': recipe_ingredient_size
        }
    
    def estimate_scaling_requirements(self, target_recipe_counts: List[int]) -> List[ScalingAnalysis]:
        """Estimate scaling requirements for different recipe counts."""
        baseline = self.analyze_current_database_size()
        
        results = []
        
        for recipe_count in target_recipe_counts:
            print(f"\nAnalyzing {recipe_count:,} recipes...")
            
            # Estimate database growth
            # Assume 8 ingredients, 4 equipment, 6 instructions per recipe on average
            estimated_ingredients = recipe_count * 8
            estimated_equipment = recipe_count * 4
            estimated_instructions = recipe_count * 6
            estimated_recipe_ingredients = recipe_count * 8  # one per ingredient
            
            # Calculate total size
            total_size_bytes = (
                recipe_count * baseline['avg_recipe_size_bytes'] +
                estimated_ingredients * baseline['avg_ingredient_size_bytes'] +
                estimated_equipment * baseline['avg_equipment_size_bytes'] +
                estimated_instructions * baseline['avg_instruction_size_bytes'] +
                estimated_recipe_ingredients * baseline['avg_recipe_ingredient_size_bytes']
            )
            
            total_size_gb = total_size_bytes / (1024**3)
            
            # Estimate memory requirements (rough estimate: 2x database size for indexes, caching)
            estimated_memory_mb = (total_size_bytes * 2) / (1024**2)
            
            # Estimate costs (Railway pricing estimates)
            storage_cost_monthly = total_size_gb * 0.10  # $0.10/GB/month
            compute_cost_monthly = max(5, total_size_gb * 2)  # $5 minimum + $2/GB/month
            
            # Estimate database queries (rough estimate)
            queries_per_recipe = 15  # create recipe + ingredients + equipment + instructions
            total_queries = recipe_count * queries_per_recipe
            
            # Estimate scraping time (assuming 2 seconds per recipe, 80% success rate)
            success_rate = 0.8
            recipes_to_scrape = recipe_count / success_rate
            scraping_time_seconds = recipes_to_scrape * 2
            scraping_time_hours = scraping_time_seconds / 3600
            
            analysis = ScalingAnalysis(
                recipe_count=recipe_count,
                estimated_size_gb=total_size_gb,
                estimated_memory_mb=estimated_memory_mb,
                estimated_storage_cost_monthly=storage_cost_monthly,
                estimated_compute_cost_monthly=compute_cost_monthly,
                database_queries_per_recipe=queries_per_recipe,
                total_queries=total_queries,
                estimated_scraping_time_hours=scraping_time_hours
            )
            
            results.append(analysis)
            
            print(f"  Estimated size: {total_size_gb:.2f} GB")
            print(f"  Estimated memory: {estimated_memory_mb:.0f} MB")
            print(f"  Storage cost/month: ${storage_cost_monthly:.2f}")
            print(f"  Compute cost/month: ${compute_cost_monthly:.2f}")
            print(f"  Scraping time: {scraping_time_hours:.1f} hours")
        
        return results
    
    def determine_compute_limits(self, analyses: List[ScalingAnalysis]) -> Dict:
        """Determine where compute limits are hit."""
        print("\n" + "="*60)
        print("COMPUTE LIMIT ANALYSIS")
        print("="*60)
        
        # Railway limits (approximate)
        railway_memory_limit_gb = 8  # 8GB RAM limit
        railway_storage_limit_gb = 100  # 100GB storage limit
        railway_cost_limit_monthly = 50  # $50/month budget limit
        
        limits_hit = {}
        
        for analysis in analyses:
            print(f"\n{analysis.recipe_count:,} recipes:")
            
            # Check memory limit
            if analysis.estimated_memory_mb > (railway_memory_limit_gb * 1024):
                print(f"  ❌ MEMORY LIMIT: {analysis.estimated_memory_mb:.0f} MB > {railway_memory_limit_gb * 1024} MB")
                limits_hit[analysis.recipe_count] = "memory"
            else:
                print(f"  ✅ Memory OK: {analysis.estimated_memory_mb:.0f} MB")
            
            # Check storage limit
            if analysis.estimated_size_gb > railway_storage_limit_gb:
                print(f"  ❌ STORAGE LIMIT: {analysis.estimated_size_gb:.2f} GB > {railway_storage_limit_gb} GB")
                limits_hit[analysis.recipe_count] = "storage"
            else:
                print(f"  ✅ Storage OK: {analysis.estimated_size_gb:.2f} GB")
            
            # Check cost limit
            total_cost = analysis.estimated_storage_cost_monthly + analysis.estimated_compute_cost_monthly
            if total_cost > railway_cost_limit_monthly:
                print(f"  ❌ COST LIMIT: ${total_cost:.2f} > ${railway_cost_limit_monthly}")
                limits_hit[analysis.recipe_count] = "cost"
            else:
                print(f"  ✅ Cost OK: ${total_cost:.2f}")
        
        return limits_hit
    
    def find_optimal_recipe_limit(self, analyses: List[ScalingAnalysis]) -> int:
        """Find the optimal recipe limit before hitting compute constraints."""
        limits_hit = self.determine_compute_limits(analyses)
        
        # Find the highest recipe count that doesn't hit limits
        optimal_limit = 0
        for analysis in analyses:
            if analysis.recipe_count not in limits_hit:
                optimal_limit = analysis.recipe_count
            else:
                break
        
        print(f"\n🎯 OPTIMAL RECIPE LIMIT: {optimal_limit:,} recipes")
        return optimal_limit

class RecipeURLFinder:
    """Find recipe URLs from popular recipe websites."""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
    
    def get_allrecipes_urls(self, max_pages: int = 100) -> List[str]:
        """Get recipe URLs from AllRecipes sitemap or search pages."""
        urls = []
        
        # AllRecipes has recipe URLs in format: /recipe/{id}/{slug}/
        # We can try different approaches:
        
        # Approach 1: Try common recipe ID ranges
        print("Searching AllRecipes for recipe URLs...")
        for page in range(1, max_pages + 1):
            try:
                # Try to find recipe listings
                response = self.session.get(f"https://www.allrecipes.com/recipes/?page={page}", timeout=10)
                if response.status_code == 200:
                    # Extract recipe URLs from the page
                    import re
                    recipe_urls = re.findall(r'href="(/recipe/\d+/[^"]+)"', response.text)
                    for url in recipe_urls:
                        full_url = f"https://www.allrecipes.com{url}"
                        urls.append(full_url)
                    
                    print(f"  Page {page}: Found {len(recipe_urls)} recipes")
                    
                    if len(recipe_urls) == 0:
                        break  # No more recipes found
                        
            except Exception as e:
                print(f"  Error on page {page}: {e}")
                break
        
        return urls[:1000]  # Limit to 1000 for testing
    
    def get_simplyrecipes_urls(self, max_pages: int = 100) -> List[str]:
        """Get recipe URLs from Simply Recipes."""
        urls = []
        
        print("Searching Simply Recipes for recipe URLs...")
        for page in range(1, max_pages + 1):
            try:
                response = self.session.get(f"https://www.simplyrecipes.com/recipes/?page={page}", timeout=10)
                if response.status_code == 200:
                    import re
                    recipe_urls = re.findall(r'href="(/recipes/[^"]+)"', response.text)
                    for url in recipe_urls:
                        if '/recipes/' in url and not url.endswith('/'):
                            full_url = f"https://www.simplyrecipes.com{url}"
                            urls.append(full_url)
                    
                    print(f"  Page {page}: Found {len(recipe_urls)} recipes")
                    
                    if len(recipe_urls) == 0:
                        break
                        
            except Exception as e:
                print(f"  Error on page {page}: {e}")
                break
        
        return urls[:1000]  # Limit to 1000 for testing
    
    def get_recipe_urls_by_traffic(self, target_count: int) -> List[str]:
        """Get recipe URLs ordered by estimated traffic (simplified approach)."""
        print(f"Finding recipe URLs to reach {target_count:,} recipes...")
        
        all_urls = []
        
        # Get URLs from multiple sources
        allrecipes_urls = self.get_allrecipes_urls(max_pages=50)
        simply_urls = self.get_simplyrecipes_urls(max_pages=50)
        
        all_urls.extend(allrecipes_urls)
        all_urls.extend(simply_urls)
        
        # Remove duplicates
        unique_urls = list(set(all_urls))
        
        print(f"Found {len(unique_urls)} unique recipe URLs")
        
        # For now, return all URLs (in a real implementation, you'd rank by traffic)
        return unique_urls[:target_count * 2]  # Return 2x target for failed scrapes

def main():
    """Main analysis function."""
    print("RECIPE SCALING ANALYSIS")
    print("="*60)
    
    # Initialize analyzer
    analyzer = RecipeScalingAnalyzer()
    
    # Analyze scaling for different recipe counts
    target_counts = [10_000, 100_000, 1_000_000]
    analyses = analyzer.estimate_scaling_requirements(target_counts)
    
    # Find optimal limit
    optimal_limit = analyzer.find_optimal_recipe_limit(analyses)
    
    # Find recipe URLs
    url_finder = RecipeURLFinder()
    recipe_urls = url_finder.get_recipe_urls_by_traffic(optimal_limit)
    
    print(f"\n📊 SUMMARY")
    print(f"="*60)
    print(f"Optimal recipe limit: {optimal_limit:,}")
    print(f"Available recipe URLs: {len(recipe_urls):,}")
    
    # Save results
    results = {
        'optimal_recipe_limit': optimal_limit,
        'available_urls': len(recipe_urls),
        'scaling_analyses': [
            {
                'recipe_count': a.recipe_count,
                'estimated_size_gb': a.estimated_size_gb,
                'estimated_memory_mb': a.estimated_memory_mb,
                'estimated_storage_cost_monthly': a.estimated_storage_cost_monthly,
                'estimated_compute_cost_monthly': a.estimated_compute_cost_monthly,
                'estimated_scraping_time_hours': a.estimated_scraping_time_hours
            }
            for a in analyses
        ]
    }
    
    with open('scaling_analysis_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to scaling_analysis_results.json")
    
    return results

if __name__ == "__main__":
    main() 