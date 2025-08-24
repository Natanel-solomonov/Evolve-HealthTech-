URLs
====

This section contains documentation for all URL patterns in the Evolve Backend API.

API URLs
-------

.. automodule:: api.urls
   :members:
   :undoc-members:
   :show-inheritance:

URL Patterns
-----------

The following URL patterns are available in the API:

.. code-block:: python

    # User endpoints
    /api/users/
    /api/users/{id}/
    /api/users/info/
    /api/users/goals/

    # Activity endpoints
    /api/activities/
    /api/activities/{id}/
    /api/activity-plans/
    /api/activity-plans/{id}/

    # Workout endpoints
    /api/exercises/
    /api/exercises/{id}/
    /api/workouts/
    /api/workouts/{id}/
    /api/workout-exercises/
    /api/workout-exercises/{id}/

    # Affiliate endpoints
    /api/affiliates/
    /api/affiliates/{id}/
    /api/affiliate-promotions/
    /api/affiliate-promotions/{id}/
    /api/affiliate-discount-codes/
    /api/affiliate-discount-codes/{id}/
    /api/affiliate-redemptions/
    /api/affiliate-redemptions/{id}/