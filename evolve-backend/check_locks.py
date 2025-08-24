#!/usr/bin/env python3
"""
Check for database locks and restart migration
"""

import os
import sys
import django
from django.db import connection

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

def check_locks_and_restart():
    print("🔍 Checking Database Locks")
    print("=" * 50)
    
    try:
        with connection.cursor() as cursor:
            # Check for active queries
            cursor.execute("""
                SELECT pid, query, state, query_start, now() - query_start AS duration 
                FROM pg_stat_activity 
                WHERE state = 'active' 
                AND query NOT LIKE '%pg_stat_activity%'
                ORDER BY query_start DESC
            """)
            
            active_queries = cursor.fetchall()
            if active_queries:
                print("🔄 Active database queries:")
                for pid, query, state, start_time, duration in active_queries:
                    print(f"  PID: {pid}, State: {state}, Duration: {duration}")
                    print(f"  Query: {query[:100]}...")
                    print()
            else:
                print("✅ No active queries blocking migration")
            
            # Check for locks
            cursor.execute("""
                SELECT locktype, database, relation, page, tuple, virtualxid, transactionid, 
                       classid, objid, objsubid, virtualtransaction, pid, mode, granted
                FROM pg_locks 
                WHERE NOT granted
            """)
            
            locks = cursor.fetchall()
            if locks:
                print("🔒 Database locks found:")
                for lock in locks:
                    print(f"  Lock: {lock}")
            else:
                print("✅ No database locks found")
                
            # Check migration status
            cursor.execute("""
                SELECT column_name FROM information_schema.columns 
                WHERE table_name = 'nutrition_foodproduct' 
                AND column_name = 'search_vector'
            """)
            
            if cursor.fetchone():
                print("✅ search_vector column exists")
            else:
                print("❌ search_vector column NOT found")
                
            # Check extensions
            cursor.execute("SELECT extname FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent')")
            extensions = [row[0] for row in cursor.fetchall()]
            print(f"🔧 Extensions: pg_trgm={'✅' if 'pg_trgm' in extensions else '❌'}, unaccent={'✅' if 'unaccent' in extensions else '❌'}")
            
    except Exception as e:
        print(f"❌ Error checking database: {e}")
        return False
    
    return True

if __name__ == "__main__":
    check_locks_and_restart() 