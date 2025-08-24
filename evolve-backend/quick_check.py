#!/usr/bin/env python3
"""
Quick Migration Status Check
"""

import os
import sys
import django
from django.db import connection
import subprocess

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

def quick_check():
    print("🔍 Quick Migration Status Check")
    print("=" * 50)
    
    # Check if migration is applied
    try:
        result = subprocess.run(['python', 'manage.py', 'showmigrations', 'nutrition'], 
                              capture_output=True, text=True)
        if '0018_foodproduct_search_vector' in result.stdout:
            if '[X]' in result.stdout.split('0018_foodproduct_search_vector')[0][-10:]:
                print("✅ Migration 0018 is APPLIED!")
            else:
                print("⏳ Migration 0018 is NOT applied yet")
        else:
            print("❌ Migration 0018 not found")
    except Exception as e:
        print(f"❌ Error checking migration: {e}")
    
    # Check PostgreSQL extensions
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT extname FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent')")
            extensions = [row[0] for row in cursor.fetchall()]
            print(f"🔧 Extensions: pg_trgm={'✅' if 'pg_trgm' in extensions else '❌'}, unaccent={'✅' if 'unaccent' in extensions else '❌'}")
    except Exception as e:
        print(f"❌ Error checking extensions: {e}")
    
    # Check if search_vector column exists
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT column_name FROM information_schema.columns 
                WHERE table_name = 'nutrition_foodproduct' 
                AND column_name = 'search_vector'
            """)
            if cursor.fetchone():
                print("✅ search_vector column EXISTS")
                
                # Check how many are populated
                cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct")
                total = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct WHERE search_vector IS NOT NULL")
                populated = cursor.fetchone()[0]
                
                print(f"📊 Total: {total:,}, Populated: {populated:,} ({populated/total*100:.1f}%)")
            else:
                print("❌ search_vector column NOT found")
    except Exception as e:
        print(f"❌ Error checking column: {e}")
    
    # Check for running migration processes
    try:
        result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
        migration_processes = [line for line in result.stdout.split('\n') if 'migrate' in line and 'python' in line]
        if migration_processes:
            print(f"🔄 Found {len(migration_processes)} migration process(es) running")
        else:
            print("💤 No migration processes found")
    except Exception as e:
        print(f"❌ Error checking processes: {e}")

if __name__ == "__main__":
    quick_check() 