from django.contrib import admin
from .models import WaitlistedAppUser, University

@admin.register(WaitlistedAppUser)
class WaitlistedAppUserAdmin(admin.ModelAdmin):
    list_display = ('phone_number', 'first_name', 'last_name', 'school', 'position', 'referrals', 'referral_link')
    search_fields = ('phone_number', 'first_name', 'last_name', 'school__name', 'referral_link')
    readonly_fields = ('referral_link', 'position')
    list_filter = ('school',)

@admin.register(University)
class UniversityAdmin(admin.ModelAdmin):
    list_display = ('name', 'aliases')
    search_fields = ('name', 'aliases')
