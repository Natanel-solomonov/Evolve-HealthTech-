from django.apps import AppConfig


class RecipesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'recipes'
    
    def ready(self):
        # Import admin to ensure it's registered
        import recipes.admin
