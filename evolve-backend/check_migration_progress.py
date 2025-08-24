#!/usr/bin/env python3
"""
Migration Progress Monitor
Check the status of the full-text search migration
"""

import os
import sys
import django
from django.db import connection
from datetime import datetime
import time

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from nutrition.models import FoodProduct

def check_migration_progress():
    """Check various aspects of the migration progress"""
    
    print("🔍 Migration Progress Monitor")
    print("=" * 50)
    
    with connection.cursor() as cursor:
        # Check if search_vector column exists
        cursor.execute("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'nutrition_foodproduct' 
            AND column_name = 'search_vector'
        """)
        
        if cursor.fetchone():
            print("✅ search_vector column exists")
        else:
            print("❌ search_vector column not found")
            return
        
        # Check total records
        cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct")
        total_records = cursor.fetchone()[0]
        print(f"📊 Total food products: {total_records:,}")
        
        # Check how many have search_vector populated
        cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct WHERE search_vector IS NOT NULL")
        populated_records = cursor.fetchone()[0]
        print(f"✅ Records with search_vector: {populated_records:,}")
        
        # Calculate progress
        if total_records > 0:
            progress_percent = (populated_records / total_records) * 100
            print(f"📈 Progress: {progress_percent:.1f}%")
            
            if progress_percent < 100:
                remaining = total_records - populated_records
                print(f"⏳ Remaining records: {remaining:,}")
            else:
                print("🎉 Migration complete!")
        
        # Check active queries
        cursor.execute("""
            SELECT query, state, query_start, now() - query_start AS duration 
            FROM pg_stat_activity 
            WHERE query LIKE '%nutrition_foodproduct%' 
            AND state = 'active'
            AND query NOT LIKE '%pg_stat_activity%'
        """)
        
        active_queries = cursor.fetchall()
        if active_queries:
            print("\n🔄 Active migration queries:")
            for query, state, start_time, duration in active_queries:
                print(f"  State: {state}")
                print(f"  Duration: {duration}")
                print(f"  Query: {query[:100]}..." if len(query) > 100 else f"  Query: {query}")
        else:
            print("\n💤 No active migration queries found")
        
        # Check indexes
        cursor.execute("""
            SELECT indexname, indexdef 
            FROM pg_indexes 
            WHERE tablename = 'nutrition_foodproduct' 
            AND indexname LIKE '%search%'
        """)
        
        indexes = cursor.fetchall()
        if indexes:
            print(f"\n📋 Search-related indexes ({len(indexes)}):")
            for name, definition in indexes:
                print(f"  • {name}")
        
        # Check if extensions are enabled
        cursor.execute("SELECT extname FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent')")
        extensions = [row[0] for row in cursor.fetchall()]
        
        print(f"\n🔧 PostgreSQL Extensions:")
        print(f"  • pg_trgm: {'✅' if 'pg_trgm' in extensions else '❌'}")
        print(f"  • unaccent: {'✅' if 'unaccent' in extensions else '❌'}")

if __name__ == "__main__":
    try:
        check_migration_progress()
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1) 