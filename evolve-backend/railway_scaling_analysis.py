#!/usr/bin/env python3
import sys
import os
import django
import json
import math
from typing import Dict, List
from dataclasses import dataclass

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.models import Recipe, RecipeIngredient, InstructionStep, Equipment

@dataclass
class RailwayTier:
    """Railway compute tier specifications."""
    name: str
    cpu_cores: float
    memory_gb: float
    storage_gb: float
    monthly_cost: float
    max_connections: int
    request_rate_limit: int  # requests per minute

class RailwayScalingAnalyzer:
    """Analyze scaling limits for Railway deployment."""
    
    # Railway compute tiers (approximate)
    RAILWAY_TIERS = {
        'starter': RailwayTier('Starter', 0.5, 0.5, 1, 5, 10, 60),
        'basic': RailwayTier('Basic', 1, 1, 3, 20, 25, 120),
        'standard': RailwayTier('Standard', 2, 2, 10, 50, 50, 300),
        'pro': RailwayTier('Pro', 32, 32, 100, 100, 100, 600),  # Updated for your actual specs
        'business': RailwayTier('Business', 8, 8, 50, 200, 200, 1200),
    }
    
    # Database size estimates per recipe (based on actual data)
    RECIPE_SIZE_BYTES = {
        'recipe_metadata': 500,  # title, description, times, servings, etc.
        'ingredients': 200,      # per ingredient
        'instructions': 300,     # per instruction step
        'equipment': 100,        # per equipment item
        'indexes': 150,          # database indexes overhead
    }
    
    def __init__(self):
        self.analyze_existing_data()
    
    def analyze_existing_data(self):
        """Analyze existing recipe data to get real size estimates."""
        try:
            total_recipes = Recipe.objects.count()
            if total_recipes > 0:
                # Get actual database size
                from django.db import connection
                with connection.cursor() as cursor:
                    cursor.execute("""
                        SELECT pg_size_pretty(pg_total_relation_size('recipes_recipe')) as recipe_size,
                               pg_size_pretty(pg_total_relation_size('recipes_recipeingredient')) as ingredient_size,
                               pg_size_pretty(pg_total_relation_size('recipes_instructionstep')) as instruction_size,
                               pg_size_pretty(pg_total_relation_size('recipes_equipment')) as equipment_size
                    """)
                    sizes = cursor.fetchone()
                
                # Calculate average sizes
                avg_ingredients = RecipeIngredient.objects.count() / max(1, total_recipes)
                avg_instructions = InstructionStep.objects.count() / max(1, total_recipes)
                avg_equipment = Equipment.objects.count() / max(1, total_recipes)
                
                print(f"📊 Existing data analysis:")
                print(f"  Total recipes: {total_recipes}")
                print(f"  Avg ingredients per recipe: {avg_ingredients:.1f}")
                print(f"  Avg instructions per recipe: {avg_instructions:.1f}")
                print(f"  Avg equipment per recipe: {avg_equipment:.1f}")
                
                # Update size estimates based on real data
                self.RECIPE_SIZE_BYTES['ingredients'] = int(200 * avg_ingredients)
                self.RECIPE_SIZE_BYTES['instructions'] = int(300 * avg_instructions)
                self.RECIPE_SIZE_BYTES['equipment'] = int(100 * avg_equipment)
                
        except Exception as e:
            print(f"⚠️  Could not analyze existing data: {e}")
            print("Using default size estimates")
    
    def calculate_recipe_size(self, recipe_count: int) -> Dict:
        """Calculate database size for given number of recipes."""
        total_bytes = recipe_count * sum(self.RECIPE_SIZE_BYTES.values())
        total_gb = total_bytes / (1024**3)
        
        return {
            'recipe_count': recipe_count,
            'total_bytes': total_bytes,
            'total_gb': total_gb,
            'breakdown': {
                'metadata_gb': (recipe_count * self.RECIPE_SIZE_BYTES['recipe_metadata']) / (1024**3),
                'ingredients_gb': (recipe_count * self.RECIPE_SIZE_BYTES['ingredients']) / (1024**3),
                'instructions_gb': (recipe_count * self.RECIPE_SIZE_BYTES['instructions']) / (1024**3),
                'equipment_gb': (recipe_count * self.RECIPE_SIZE_BYTES['equipment']) / (1024**3),
                'indexes_gb': (recipe_count * self.RECIPE_SIZE_BYTES['indexes']) / (1024**3),
            }
        }
    
    def calculate_memory_usage(self, recipe_count: int) -> Dict:
        """Calculate memory usage for given number of recipes."""
        # Base Django memory usage
        base_memory_mb = 100
        
        # Memory per recipe (cached in memory)
        memory_per_recipe_mb = 0.1  # Very conservative estimate
        
        total_memory_mb = base_memory_mb + (recipe_count * memory_per_recipe_mb)
        total_memory_gb = total_memory_mb / 1024
        
        return {
            'recipe_count': recipe_count,
            'base_memory_mb': base_memory_mb,
            'recipe_memory_mb': recipe_count * memory_per_recipe_mb,
            'total_memory_mb': total_memory_mb,
            'total_memory_gb': total_memory_gb
        }
    
    def calculate_scraping_time(self, recipe_count: int, rate_limit_seconds: float = 2.0) -> Dict:
        """Calculate time to scrape given number of recipes."""
        # Account for success rate (not all URLs will work)
        success_rate = 0.7  # 70% success rate
        urls_to_scrape = recipe_count / success_rate
        
        # Time calculations
        total_seconds = urls_to_scrape * rate_limit_seconds
        total_hours = total_seconds / 3600
        total_days = total_hours / 24
        
        return {
            'recipe_count': recipe_count,
            'urls_to_scrape': int(urls_to_scrape),
            'success_rate': success_rate,
            'rate_limit_seconds': rate_limit_seconds,
            'total_seconds': total_seconds,
            'total_hours': total_hours,
            'total_days': total_days
        }
    
    def find_compute_cutoff(self, target_recipe_counts: List[int]) -> Dict:
        """Find the compute cutoff point for different recipe counts."""
        results = {}
        
        for recipe_count in target_recipe_counts:
            size_info = self.calculate_recipe_size(recipe_count)
            memory_info = self.calculate_memory_usage(recipe_count)
            scraping_info = self.calculate_scraping_time(recipe_count)
            
            # Check which Railway tier can handle this
            suitable_tiers = []
            for tier_name, tier in self.RAILWAY_TIERS.items():
                can_handle = True
                issues = []
                
                # Check storage
                if size_info['total_gb'] > tier.storage_gb:
                    can_handle = False
                    issues.append(f"Storage: {size_info['total_gb']:.2f}GB > {tier.storage_gb}GB")
                
                # Check memory
                if memory_info['total_memory_gb'] > tier.memory_gb:
                    can_handle = False
                    issues.append(f"Memory: {memory_info['total_memory_gb']:.2f}GB > {tier.memory_gb}GB")
                
                # Check request rate (for scraping)
                requests_per_minute = 60 / scraping_info['rate_limit_seconds']
                if requests_per_minute > tier.request_rate_limit:
                    can_handle = False
                    issues.append(f"Rate limit: {requests_per_minute:.0f}/min > {tier.request_rate_limit}/min")
                
                if can_handle:
                    suitable_tiers.append(tier_name)
                else:
                    issues.append(f"Tier: {tier_name}")
            
            results[recipe_count] = {
                'size_gb': size_info['total_gb'],
                'memory_gb': memory_info['total_memory_gb'],
                'scraping_days': scraping_info['total_days'],
                'suitable_tiers': suitable_tiers,
                'min_tier_cost': min([self.RAILWAY_TIERS[tier].monthly_cost for tier in suitable_tiers]) if suitable_tiers else None,
                'issues': issues if not suitable_tiers else []
            }
        
        return results
    
    def analyze_scaling(self):
        """Run comprehensive scaling analysis."""
        print("🚀 RAILWAY SCALING ANALYSIS")
        print("=" * 60)
        
        # Target recipe counts
        target_counts = [1000, 10000, 50000, 100000, 250000, 500000, 1000000]
        
        # Run analysis
        results = self.find_compute_cutoff(target_counts)
        
        print("\n📊 SCALING RESULTS:")
        print("-" * 60)
        
        for recipe_count, data in results.items():
            print(f"\n🔸 {recipe_count:,} RECIPES:")
            print(f"   Database Size: {data['size_gb']:.2f} GB")
            print(f"   Memory Usage: {data['memory_gb']:.2f} GB")
            print(f"   Scraping Time: {data['scraping_days']:.1f} days")
            
            if data['suitable_tiers']:
                print(f"   ✅ Suitable Tiers: {', '.join(data['suitable_tiers'])}")
                print(f"   💰 Min Monthly Cost: ${data['min_tier_cost']}")
            else:
                print(f"   ❌ No suitable Railway tier")
                print(f"   Issues: {', '.join(data['issues'])}")
        
        # Find cutoff point
        cutoff_point = None
        for recipe_count in target_counts:
            if not results[recipe_count]['suitable_tiers']:
                cutoff_point = recipe_count
                break
        
        print(f"\n🎯 COMPUTE CUTOFF:")
        print(f"   Maximum recipes before hitting Railway limits: {cutoff_point:,}" if cutoff_point else "No limit found in tested range")
        
        # Save results
        with open('railway_scaling_results.json', 'w') as f:
            json.dump({
                'analysis_timestamp': str(datetime.now()),
                'railway_tiers': {name: {
                    'cpu_cores': tier.cpu_cores,
                    'memory_gb': tier.memory_gb,
                    'storage_gb': tier.storage_gb,
                    'monthly_cost': tier.monthly_cost,
                    'max_connections': tier.max_connections,
                    'request_rate_limit': tier.request_rate_limit
                } for name, tier in self.RAILWAY_TIERS.items()},
                'recipe_size_estimates': self.RECIPE_SIZE_BYTES,
                'results': results,
                'cutoff_point': cutoff_point
            }, f, indent=2, default=str)
        
        print(f"\n💾 Results saved to railway_scaling_results.json")
        
        return results, cutoff_point

if __name__ == "__main__":
    from datetime import datetime
    analyzer = RailwayScalingAnalyzer()
    results, cutoff = analyzer.analyze_scaling() 