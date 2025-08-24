from django.db import migrations, connection

UUID_REGEX = r'^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$'

def convert_outstandingtoken_user_id_to_uuid(apps, schema_editor):
    """Convert token_blacklist_outstandingtoken.user_id (bigint) → uuid."""

    drop_fk_sql = """
    DO $$
    DECLARE
        constr_name text;
    BEGIN
        SELECT tc.constraint_name INTO constr_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'token_blacklist_outstandingtoken'
          AND kcu.column_name = 'user_id'
          AND tc.constraint_type = 'FOREIGN KEY';

        IF constr_name IS NOT NULL THEN
            EXECUTE format('ALTER TABLE token_blacklist_outstandingtoken DROP CONSTRAINT %I', constr_name);
        END IF;
    END$$;
    """

    with connection.cursor() as cursor:
        cursor.execute(drop_fk_sql)

        # allow NULLs (already nullable but safe)
        cursor.execute(
            """
            ALTER TABLE token_blacklist_outstandingtoken
            ALTER COLUMN user_id DROP NOT NULL;
            """
        )

        # Null-out non-uuid IDs
        cursor.execute(
            f"""
            UPDATE token_blacklist_outstandingtoken
            SET user_id = NULL
            WHERE user_id IS NOT NULL
              AND user_id::text !~* '{UUID_REGEX}';
            """
        )

        # Cast bigint -> text
        cursor.execute(
            """
            ALTER TABLE token_blacklist_outstandingtoken
            ALTER COLUMN user_id TYPE text USING user_id::text;
            """
        )

        # Cast text -> uuid
        cursor.execute(
            """
            ALTER TABLE token_blacklist_outstandingtoken
            ALTER COLUMN user_id TYPE uuid USING user_id::uuid;
            """
        )

        # Recreate FK
        cursor.execute(
            """
            ALTER TABLE token_blacklist_outstandingtoken
            ADD CONSTRAINT token_blacklist_outstandingtoken_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES api_appuser(id)
            DEFERRABLE INITIALLY DEFERRED;
            """
        )


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0066_alter_appuser_related_ids_to_uuid'),
    ]

    operations = [
        migrations.RunPython(convert_outstandingtoken_user_id_to_uuid),
    ] 