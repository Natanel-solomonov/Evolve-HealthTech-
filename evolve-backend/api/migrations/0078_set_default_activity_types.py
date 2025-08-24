# Generated manually

from django.db import migrations

def set_default_activity_types(apps, schema_editor):
    """
    Set default activity_type values for existing activities based on their categories and names.
    """
    Activity = apps.get_model('api', 'Activity')
    
    # Update activities based on their category and name patterns
    for activity in Activity.objects.all():
        if activity.activity_type:
            # Skip if already has a type
            continue
            
        # Determine activity type based on category and name
        activity_type = None
        
        if activity.category:
            first_category = activity.category[0] if activity.category else None
            
            if first_category == 'Fitness':
                # Check if it's a workout
                if activity.associated_workout or 'workout' in activity.name.lower():
                    activity_type = 'Workout'
                else:
                    activity_type = 'Exercise'
                    
            elif first_category == 'Nutrition':
                # Check common nutrition activity types
                if 'breakfast' in activity.name.lower() or 'lunch' in activity.name.lower() or 'dinner' in activity.name.lower():
                    activity_type = 'Nutrition'
                elif 'recipe' in activity.name.lower():
                    activity_type = 'Recipe'
                else:
                    activity_type = 'Nutrition'
                    
            elif first_category == 'Mind':
                # Check common mind activity types
                if 'meditation' in activity.name.lower():
                    activity_type = 'Mindfulness'
                elif 'journal' in activity.name.lower():
                    activity_type = 'Journal'
                else:
                    activity_type = 'Mindfulness'
                    
            elif first_category == 'Sleep':
                activity_type = 'Sleep'
                
            elif first_category == 'Routine':
                activity_type = 'Routine'
                
            elif first_category == 'Other':
                activity_type = 'Other'
        
        # If we determined a type, update the activity
        if activity_type:
            activity.activity_type = activity_type
            activity.save(update_fields=['activity_type'])

def reverse_set_default_activity_types(apps, schema_editor):
    """
    Reverse the data migration by clearing activity_type values.
    """
    Activity = apps.get_model('api', 'Activity')
    Activity.objects.update(activity_type=None)

class Migration(migrations.Migration):

    dependencies = [
        ('api', '0077_add_activity_type_and_routine_category'),
    ]

    operations = [
        migrations.RunPython(set_default_activity_types, reverse_set_default_activity_types),
    ] 