from django.urls import path
from .views import (
    affiliate_dashboard, create_promotion, redeem_code, 
    my_promotions, my_affiliate_code, waitlist_view, 
    position_view, waitlist_signup, user_position_view, 
    update_school, update_full_name, university_autocomplete,
    handle_referral_link,
    privacy_policy_view,
    terms_of_use_view,
)

urlpatterns = [
    path('waitlist/', waitlist_view, name='waitlist'),
    path('r/<str:referral_code>/',  handle_referral_link, name='handle_referral_link'),
    path('affiliate/', affiliate_dashboard, name='affiliate_dashboard'),
    path('create-promotion/', create_promotion, name='create_promotion'),
    path('redeem-code/', redeem_code, name='redeem_code'),
    path('my-promotions/', my_promotions, name='my_promotions'),
    path('my-affiliate-code/', my_affiliate_code, name='my_affiliate_code'),
    path('position/<uuid:user_id>/', user_position_view, name='user_position'),
    path('waitlist-signup/', waitlist_signup, name='waitlist_signup'),
    path('position/<uuid:user_id>/update-school/', update_school, name='update_school'),
    path('position/<uuid:user_id>/update-full-name/', update_full_name, name='update_full_name'),
    path('universities/autocomplete/', university_autocomplete, name='university_autocomplete'),
    path('privacy/', privacy_policy_view, name='privacy_policy'),
    path('terms/', terms_of_use_view, name='terms_of_use'),
]
