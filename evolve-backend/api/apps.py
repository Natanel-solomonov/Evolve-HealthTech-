from django.apps import AppConfig


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        import api.signals # noqa: F401
        # The noqa: F401 comment tells linters (like flake8) to ignore the
        # "imported but unused" warning for this line, as its purpose is
        # to ensure the signals module is loaded and signals are registered.
