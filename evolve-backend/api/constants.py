# Activity type definitions and their categories
ACTIVITY_TYPE_CATEGORIES = {
    # Fitness category
    'workout': 'Fitness',
    'weight tracking': 'Fitness',
    'personal record': 'Fitness',
    
    # Nutrition category
    'food log': 'Nutrition',
    'water intake': 'Nutrition',
    'caffeine log': 'Nutrition',
    'alcohol log': 'Nutrition',
    'recipe': 'Nutrition',
    'supplement log': 'Nutrition',
    
    # Mind category
    'journal': 'Mind',
    'meditation': 'Mind',
    'breathing': 'Mind',
    'mood check': 'Mind',
    'emotions check': 'Mind',
    'energy level log': 'Mind',
    
    # Sleep category
    'sleep tracking': 'Sleep',
    'sleep debt calculation': 'Sleep',
    
    # Other category
    'prescription log': 'Other',
    'sex log': 'Other',
    'symptoms log': 'Other',
    'cycle log': 'Other',
}

# Create a choices list for Django model field
ACTIVITY_TYPE_CHOICES = [(k, k.title()) for k in sorted(ACTIVITY_TYPE_CATEGORIES.keys())]

# Activity category choices (already defined in models)
ACTIVITY_CATEGORY_CHOICES = [
    ('Fitness', 'Fitness'),
    ('Nutrition', 'Nutrition'),
    ('Sleep', 'Sleep'),
    ('Mind', 'Mind'),
    ('Routine', 'Routine'),
    ('Other', 'Other'),
] 