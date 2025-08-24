from django.db import migrations, connection

def convert_appuser_related_ids_to_uuid(apps, schema_editor):
    with connection.cursor() as cursor:
        # --- api_appuser_groups ---
        cursor.execute('''
            ALTER TABLE api_appuser_groups
            ALTER COLUMN appuser_id DROP NOT NULL;
        ''')
        cursor.execute('''
            UPDATE api_appuser_groups
            SET appuser_id = NULL
            WHERE appuser_id::text !~* '^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$';
        ''')
        cursor.execute('''
            ALTER TABLE api_appuser_groups
            ALTER COLUMN appuser_id TYPE text USING appuser_id::text;
        ''')
        cursor.execute('''
            ALTER TABLE api_appuser_groups
            ALTER COLUMN appuser_id TYPE uuid USING appuser_id::uuid;
        ''')
        # --- api_appuser_user_permissions ---
        cursor.execute('''
            ALTER TABLE api_appuser_user_permissions
            ALTER COLUMN appuser_id DROP NOT NULL;
        ''')
        cursor.execute('''
            UPDATE api_appuser_user_permissions
            SET appuser_id = NULL
            WHERE appuser_id::text !~* '^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$';
        ''')
        cursor.execute('''
            ALTER TABLE api_appuser_user_permissions
            ALTER COLUMN appuser_id TYPE text USING appuser_id::text;
        ''')
        cursor.execute('''
            ALTER TABLE api_appuser_user_permissions
            ALTER COLUMN appuser_id TYPE uuid USING appuser_id::uuid;
        ''')

class Migration(migrations.Migration):

    dependencies = [
        ('api', '0065_alter_django_admin_log_user_id_to_uuid'),
    ]

    operations = [
        migrations.RunPython(convert_appuser_related_ids_to_uuid),
    ] 