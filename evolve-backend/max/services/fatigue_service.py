import math
from typing import Dict, Optional, List

# Central Django bootstrap
from max.utils.django_setup import ensure as _django_setup

_django_setup()

from django.db import models

from api.models import AppUser, AppUserFatigueModel, UserExerciseMax
from fitness.models import Workout
from max.core.fatigue import TwoCompartmentFatigueModel

def get_latest_user_fatigue(user_id: str) -> Dict[str, float]:
    """
    Retrieves the latest fatigue levels for each muscle group for a specific user.
    """
    try:
        user = AppUser.objects.get(id=user_id)
        latest_fatigue = AppUserFatigueModel.objects.filter(user=user).latest('date_recorded')
        
        return {
            field.name.replace('_', ' '): getattr(latest_fatigue, field.name)
            for field in AppUserFatigueModel._meta.get_fields()
            if isinstance(field, models.FloatField)
        }
    except AppUser.DoesNotExist:
        return {"error": f"AppUser with ID '{user_id}' not found."}
    except AppUserFatigueModel.DoesNotExist:
        return {
            field.name.replace('_', ' '): 0.0
            for field in AppUserFatigueModel._meta.get_fields()
            if isinstance(field, models.FloatField)
        }
    except Exception as e:
        return {"error": f"An unexpected error occurred: {str(e)}"}

def calculate_workout_fatigue(
    user_id: str,
    workout_id: str,
    initial_fatigue_levels: Optional[Dict[str, float]] = None,
    delta_t_hours_since_last_update: float = 0.0,
    secondary_muscle_impulse_factor: float = 0.5,
    default_difficulty_multiplier: float = 1.0
) -> Dict[str, float]:
    """
    Calculates the fatigue for each muscle group after a given workout,
    without persisting the new state. This is for projection.
    """
    try:
        user = AppUser.objects.get(id=user_id)
        workout = Workout.objects.get(id=workout_id)
    except AppUser.DoesNotExist:
        raise ValueError(f"AppUser with ID '{user_id}' not found.")
    except Workout.DoesNotExist:
        raise ValueError(f"Workout with ID '{workout_id}' not found.")

    model = TwoCompartmentFatigueModel()

    if initial_fatigue_levels:
        model.F_cen.update(initial_fatigue_levels)

    workout_exercises_details = []
    for we in workout.workoutexercise_set.all().order_by('order'):
        exercise = we.exercise
        r1 = None
        try:
            r1 = UserExerciseMax.objects.get(user=user, exercise=exercise).one_rep_max
        except UserExerciseMax.DoesNotExist:
            continue
        if r1 is None or r1 <= 0 or we.weight is None or we.sets is None or we.reps is None:
            continue
        
        details = {
            'name': exercise.name,
            'sets': we.sets,
            'reps': we.reps,
            'weight': float(we.weight),
            'R1': float(r1),
            'primary_muscles': exercise.primary_muscles or [],
            'secondary_muscles': exercise.secondary_muscles or [],
            'difficulty_multiplier': default_difficulty_multiplier
        }
        workout_exercises_details.append(details)

    # Use the public method, which correctly calculates and updates F_cen in memory
    updated_fatigue = model.update_central_fatigue_from_workout(
        workout_exercises_details,
        delta_t_hours_session=delta_t_hours_since_last_update,
        secondary_muscle_impulse_factor=secondary_muscle_impulse_factor,
    )
    
    return updated_fatigue

def apply_workout_to_fatigue_model(
    user_id: str,
    workout_exercises_details: List[Dict],
    delta_t_hours_since_last_central_update: float,
    secondary_muscle_impulse_factor: float = 0.5,
) -> Dict[str, float]:
    """
    Applies a hypothetical workout to the user's central-fatigue state and persists it.
    """
    try:
        user = AppUser.objects.get(id=user_id)
    except AppUser.DoesNotExist:
        return {"error": f"AppUser with ID '{user_id}' not found."}

    model = TwoCompartmentFatigueModel()
    try:
        latest_fatigue = AppUserFatigueModel.objects.filter(user=user).latest("date_recorded")
        for field in AppUserFatigueModel._meta.get_fields():
            if isinstance(field, models.FloatField):
                model.F_cen[field.name] = getattr(latest_fatigue, field.name)
    except AppUserFatigueModel.DoesNotExist:
        pass

    updated_f_cen = model.update_central_fatigue_from_workout(
        workout_exercises_details,
        delta_t_hours_session=delta_t_hours_since_last_central_update,
        secondary_muscle_impulse_factor=secondary_muscle_impulse_factor,
    )

    db_fatigue_data = _get_db_serializable_fatigue(updated_f_cen)
    AppUserFatigueModel.objects.create(user=user, **db_fatigue_data)
    return updated_f_cen

def simulate_rest_day_recovery(
    user_id: str,
    hours: float = 24.0,
) -> Dict[str, float]:
    """
    Simulates passive recovery for a user and persists the new fatigue state.
    """
    try:
        user = AppUser.objects.get(id=user_id)
    except AppUser.DoesNotExist:
        return {"error": f"AppUser with ID '{user_id}' not found."}

    model = TwoCompartmentFatigueModel()
    try:
        latest_fatigue = AppUserFatigueModel.objects.filter(user=user).latest("date_recorded")
        for field in AppUserFatigueModel._meta.get_fields():
            if isinstance(field, models.FloatField):
                model.F_cen[field.name] = getattr(latest_fatigue, field.name)
    except AppUserFatigueModel.DoesNotExist:
        pass

    for muscle in model.F_cen:
        tau = model.config.TAU_CEN_HOURS.get(muscle, 0)
        if tau > 0:
            model.F_cen[muscle] *= math.exp(-hours / tau)

    db_fatigue_data = _get_db_serializable_fatigue(model.F_cen)
    AppUserFatigueModel.objects.create(user=user, **db_fatigue_data)
    return model.F_cen

# ---------------------------------------------------------------------------
# Projection helper (tool wrapper for LLM)
# ---------------------------------------------------------------------------

def get_projected_central_recovery(
    workout_exercises_details: List[Dict],
    F_target_cen: float,
    use_current_fatigue: bool,
    initial_F_cen_override: Optional[Dict[str, float]] = None,
) -> Dict[str, float]:
    """Wrapper around TwoCompartmentFatigueModel.get_projected_central_recovery_times.

    This does *not* persist any fatigue changes; it merely returns the projected
    recovery times in hours for each muscle given a hypothetical workout.
    """

    model = TwoCompartmentFatigueModel()

    if use_current_fatigue and initial_F_cen_override is None:
        # Try to seed from latest snapshot of any user, but since we don't have
        # user context here, default to zeros. The LLM can pass override dict.
        pass

    recovery_dict = model.get_projected_central_recovery_times(
        workout_exercises_details,
        F_target_cen=F_target_cen,
        assume_fresh_start=not use_current_fatigue,
        initial_F_cen_override=initial_F_cen_override,
    )
    return recovery_dict

def _get_db_serializable_fatigue(fatigue_dict: Dict[str, float]) -> Dict[str, float]:
    """
    Converts space-case keys from the fatigue model (e.g., 'full body') to
    snake_case field names for the AppUserFatigueModel (e.g., 'full_body').
    It filters for keys that correspond to actual model fields.
    """
    valid_fields = {f.name for f in AppUserFatigueModel._meta.get_fields() if isinstance(f, models.FloatField)}
    return {
        key.replace(' ', '_'): value
        for key, value in fatigue_dict.items()
        if key.replace(' ', '_') in valid_fields
    } 