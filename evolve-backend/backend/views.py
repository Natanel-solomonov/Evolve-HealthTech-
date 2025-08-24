from django.shortcuts import render
from django.views.generic import TemplateView

def custom_page_not_found(request, exception):
    return render(request, '404.html', status=404)

class ReactAppView(TemplateView):
    """Serves the compiled React SPA (or dev server during DEBUG).

    The template simply loads the Vite entry point using django-vite tags.
    The route using this view should be placed **after** all other server-side
    URL patterns so it acts as a fallback that lets the React Router handle
    client-side navigation.
    """

    template_name = 'index.html' 