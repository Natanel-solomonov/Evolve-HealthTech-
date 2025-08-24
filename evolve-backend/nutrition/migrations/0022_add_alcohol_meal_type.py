# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('nutrition', '0021_dailycalorietracker_alcohol_grams_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='foodentry',
            name='meal_type',
            field=models.CharField(
                choices=[
                    ('breakfast', 'Breakfast'), 
                    ('lunch', 'Lunch'), 
                    ('dinner', 'Dinner'), 
                    ('snack', 'Snack'), 
                    ('alcohol', 'Alcohol')
                ], 
                default='snack', 
                help_text='The meal this food was consumed with.', 
                max_length=20
            ),
        ),
    ] 