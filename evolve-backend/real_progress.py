#!/usr/bin/env python3
"""
Real Migration Progress Monitor
Shows actual search vector population progress
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

def show_real_progress():
    print("🔍 Real Migration Progress")
    print("=" * 60)
    
    try:
        with connection.cursor() as cursor:
            # Check for the UPDATE query that's running
            cursor.execute("""
                SELECT query, state, query_start, now() - query_start AS duration, pid
                FROM pg_stat_activity 
                WHERE query LIKE '%UPDATE nutrition_foodproduct%'
                AND query LIKE '%search_vector%'
                AND state = 'active'
            """)
            
            active_update = cursor.fetchone()
            if active_update:
                query, state, start_time, duration, pid = active_update
                print(f"🔄 Migration IS RUNNING!")
                print(f"   PID: {pid}")
                print(f"   State: {state}")
                print(f"   Duration: {duration}")
                print(f"   Started: {start_time}")
                print()
                
                # Try to get progress if possible
                try:
                    # Check if we can query the table safely
                    cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct WHERE search_vector IS NOT NULL")
                    populated = cursor.fetchone()[0]
                    
                    cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct")
                    total = cursor.fetchone()[0]
                    
                    if total > 0:
                        progress = (populated / total) * 100
                        print(f"📊 Progress: {populated:,} / {total:,} ({progress:.2f}%)")
                        
                        if progress > 0:
                            remaining = total - populated
                            print(f"⏳ Remaining: {remaining:,} records")
                            
                            # Estimate completion time
                            if duration.total_seconds() > 0:
                                rate = populated / duration.total_seconds()
                                if rate > 0:
                                    eta_seconds = remaining / rate
                                    eta_minutes = eta_seconds / 60
                                    if eta_minutes < 60:
                                        print(f"⏰ ETA: ~{eta_minutes:.1f} minutes")
                                    else:
                                        eta_hours = eta_minutes / 60
                                        print(f"⏰ ETA: ~{eta_hours:.1f} hours")
                                    
                                    print(f"⚡ Rate: {rate:.1f} records/second")
                        
                except Exception as e:
                    print(f"⚠️  Can't check progress during active migration: {e}")
                    print("   This is normal - the table is being updated")
            else:
                print("💤 No active UPDATE query found")
                
                # Check if migration completed
                cursor.execute("""
                    SELECT column_name FROM information_schema.columns 
                    WHERE table_name = 'nutrition_foodproduct' 
                    AND column_name = 'search_vector'
                """)
                
                if cursor.fetchone():
                    print("✅ search_vector column exists")
                    
                    try:
                        cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct WHERE search_vector IS NOT NULL")
                        populated = cursor.fetchone()[0]
                        
                        cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct")
                        total = cursor.fetchone()[0]
                        
                        if populated == total:
                            print("🎉 Migration might be COMPLETE!")
                        else:
                            print(f"📊 {populated:,} / {total:,} records have search vectors")
                            
                    except Exception as e:
                        print(f"⚠️  Can't check completion: {e}")
                else:
                    print("❌ search_vector column not found")
                    
    except Exception as e:
        print(f"❌ Error checking progress: {e}")

if __name__ == "__main__":
    show_real_progress() 