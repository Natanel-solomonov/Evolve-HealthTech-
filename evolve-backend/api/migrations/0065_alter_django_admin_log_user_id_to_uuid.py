from django.db import migrations, connection

def convert_admin_log_user_id_to_uuid(apps, schema_editor):
    with connection.cursor() as cursor:
        # 1. Allow NULLs in user_id
        cursor.execute('''
            ALTER TABLE django_admin_log
            ALTER COLUMN user_id DROP NOT NULL;
        ''')
        # 2. Set user_id to NULL where it cannot be cast to UUID (i.e., old int IDs)
        cursor.execute('''
            UPDATE django_admin_log
            SET user_id = NULL
            WHERE user_id::text !~* '^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$';
        ''')
        # 3. Convert the column to text
        cursor.execute('''
            ALTER TABLE django_admin_log
            ALTER COLUMN user_id TYPE text USING user_id::text;
        ''')
        # 4. Now alter the column type to uuid
        cursor.execute('''
            ALTER TABLE django_admin_log
            ALTER COLUMN user_id TYPE uuid USING user_id::uuid;
        ''')

class Migration(migrations.Migration):

    dependencies = [
        ('api', '0064_alter_affiliatepromotiondiscountcode_assigned_user_and_more'),
    ]

    operations = [
        migrations.RunPython(convert_admin_log_user_id_to_uuid),
    ] 