"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from website.views import waitlist_view
# from django_otp.admin import OTPAdminSite
from django.views.defaults import page_not_found
from backend.views import ReactAppView

# Configure the admin site to use OTPAdminSite
# admin.site.__class__ = OTPAdminSite

urlpatterns = [
    path('csaRlJLWcz02L9WRbuAs1c4mFJUyIKL6-system-dashboard-q5U9k7TVMmU4q1BA4it0ELqQaySozLYn/', admin.site.urls),
    path('api/', include('api.urls')), 
    path('api-auth/', include('rest_framework.urls', namespace='rest_framework')),  # DRF's login URLs
    path('finances/', include('finances.urls')),
    path('nutrition/', include('nutrition.urls')),  # Add nutrition URLs
    path('api/nutrition/', include('nutrition.urls')),  # Add nutrition URLs under /api/nutrition/
    path('api/medications/', include('medications.urls')),  # Add medication URLs under /api/medications/
    # All website-specific Django-rendered pages
    path('', include('website.urls')),
    # path('api/user/', include('user_profile_api.urls')), # REMOVED: This was for the old app, functionality merged into api.urls
]

# Serve media files during development
if settings.DEBUG:
    # This must come BEFORE the React catch-all
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Catch-all React SPA (must be last)
urlpatterns.append(re_path(r'^(?:.*)/?$', ReactAppView.as_view(), name='react_app'))

# Define custom 404 handler
handler404 = 'backend.views.custom_page_not_found'
