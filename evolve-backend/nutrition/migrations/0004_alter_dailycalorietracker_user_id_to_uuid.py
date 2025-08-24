from django.db import migrations, connection

UUID_REGEX = r'^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$'


def convert_dailycalorietracker_user_id_to_uuid(apps, schema_editor):
    """
    Change nutrition_dailycalorietracker.user_id from bigint → uuid.

    Steps (executed in raw SQL because Django cannot automatically cast an
    FK column that also changes type):
      1. Drop the existing FK constraint (name can vary between DBs).
      2. Allow NULLs temporarily so invalid values can be set to NULL.
      3. Null-out any values that are not valid UUID strings.
      4. Cast the column to text, then to uuid.
      5. Re-create the FK constraint to api_appuser(id).
    """

    drop_fk_sql = """
    DO $$
    DECLARE
        constr_name text;
    BEGIN
        SELECT tc.constraint_name INTO constr_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'nutrition_dailycalorietracker'
          AND kcu.column_name = 'user_id'
          AND tc.constraint_type = 'FOREIGN KEY';

        IF constr_name IS NOT NULL THEN
            EXECUTE format('ALTER TABLE nutrition_dailycalorietracker DROP CONSTRAINT %I', constr_name);
        END IF;
    END$$;
    """

    with connection.cursor() as cursor:
        # 1. Drop FK (if it exists)
        cursor.execute(drop_fk_sql)

        # 2. Make column nullable so bad rows can be nulled
        cursor.execute(
            """
            ALTER TABLE nutrition_dailycalorietracker
            ALTER COLUMN user_id DROP NOT NULL;
            """
        )

        # 3. Set to NULL any value that cannot be cast to uuid
        cursor.execute(
            f"""
            UPDATE nutrition_dailycalorietracker
            SET user_id = NULL
            WHERE user_id::text !~* '{UUID_REGEX}';
            """
        )

        # 4a. Cast bigint → text
        cursor.execute(
            """
            ALTER TABLE nutrition_dailycalorietracker
            ALTER COLUMN user_id TYPE text USING user_id::text;
            """
        )

        # 4b. Cast text → uuid
        cursor.execute(
            """
            ALTER TABLE nutrition_dailycalorietracker
            ALTER COLUMN user_id TYPE uuid USING user_id::uuid;
            """
        )

        # 5. Re-add FK to api_appuser(id) – deferable so that existing NULLs are fine.
        cursor.execute(
            """
            ALTER TABLE nutrition_dailycalorietracker
            ADD CONSTRAINT nutrition_dailycalorietracker_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES api_appuser(id)
            DEFERRABLE INITIALLY DEFERRED;
            """
        )


class Migration(migrations.Migration):

    dependencies = [
        ('nutrition', '0003_remove_foodproduct_nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients_and_m'),
        ('api', '0066_alter_appuser_related_ids_to_uuid'),
    ]

    operations = [
        migrations.RunPython(convert_dailycalorietracker_user_id_to_uuid),
    ] 