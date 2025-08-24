"""Database-aware service layer callable by LLM or other adapters.

During initial migration this package simply re-imports implementations from
`max.tools.*`.  Over time the logic will move here directly and old paths will
be deprecated.
"""

from .activity_service import create_activity_for_workout, schedule_activity, create_cardio_activity, generate_activity_description
from .exercise_service import search_exercises
from .fatigue_service import (
    apply_workout_to_fatigue_model,
    calculate_workout_fatigue,
    get_latest_user_fatigue,
    get_projected_central_recovery,
    simulate_rest_day_recovery,
)
from .user_service import get_user_details, get_user_1rm_stats, infer_workout_schedule, get_user_available_equipment
from .workout_service import create_workout_instance
from .planning_service import generate_weekly_schedule, generate_weekly_plan

__all__ = [
    # user_service.py
    "get_user_details",
    "get_user_1rm_stats",
    "get_user_available_equipment",
    "infer_workout_schedule",
    # exercise_service.py
    "search_exercises",
    # workout_service.py
    "create_workout_instance",
    # fatigue_service.py
    "get_latest_user_fatigue",
    "calculate_workout_fatigue",
    "apply_workout_to_fatigue_model",
    "simulate_rest_day_recovery",
    "get_projected_central_recovery",
    # activity_service.py
    "create_activity_for_workout",
    "schedule_activity",
    "create_cardio_activity",
    "generate_activity_description",
    # planning_service.py
    "generate_weekly_schedule",
    "generate_weekly_plan",
] 