import json
from datetime import date, timedelta
from typing import Dict, Optional, List

# Central Django bootstrap
from max.utils.django_setup import ensure as _django_setup

_django_setup()

from api.models import AppUser, AppUserInfo, AppUserGoals, UserCompletedLog, UserExerciseMax

def get_user_details(user_id: str) -> Dict:
    """
    Fetches and returns details for a given AppUser ID (UUID string) as a dictionary.
    Details include User Info (Height, Age, Weight, Sex), Goals,
    and a summary of recent workouts and muscle groups worked.
    """
    try:
        user = AppUser.objects.get(id=user_id)
    except AppUser.DoesNotExist:
        return {"error": f"AppUser with ID '{user_id}' not found."}

    output = {
        "user_id": str(user.id),
        "name": f"{user.first_name} {user.last_name}",
        "phone": user.phone,
        "info": {},
        "goals": {},
        "recent_workouts_summary": {}
    }

    # Get AppUserInfo
    try:
        user_info = AppUserInfo.objects.get(user=user)
        output["info"]["height_inches"] = user_info.height
        if user_info.birthday:
            today = date.today()
            age = today.year - user_info.birthday.year - ((today.month, today.day) < (user_info.birthday.month, user_info.birthday.day))
            output["info"]["age"] = age
            output["info"]["birthday"] = user_info.birthday.isoformat()
        output["info"]["weight_lbs"] = user_info.weight
        output["info"]["sex"] = user_info.get_sex_display()
        output["info"]["include_cardio"] = user_info.include_cardio
    except AppUserInfo.DoesNotExist:
        output["info"] = "No AppUserInfo found for this user."

    # Get AppUserGoals
    try:
        user_goals = AppUserGoals.objects.get(user=user)
        output["goals"]["general_goals"] = user_goals.goals_general
        details = [
            {
                "categories": detail.get_goal_categories_display_names(),
                "text": detail.text
            } 
            for detail in user_goals.details.all()
        ]
        output["goals"]["detailed_goals"] = details
    except AppUserGoals.DoesNotExist:
        output["goals"] = "No AppUserGoals found for this user."

    # Get UserCompletedLog (last 7 days) for workout summary
    today = date.today()
    seven_days_ago = today - timedelta(days=7)
    completed_logs = UserCompletedLog.objects.filter(
        user=user,
        completed_at__date__gte=seven_days_ago
    ).order_by('-completed_at')

    daily_muscle_summary = {}
    for log in completed_logs:
        if log.activity and log.activity.associated_workout:
            workout = log.activity.associated_workout
            effective_date = log.completed_at.date()

            if effective_date.isoformat() not in daily_muscle_summary:
                daily_muscle_summary[effective_date.isoformat()] = {
                    "muscles_worked": set(),
                    "workout_names": set()
                }
            
            daily_muscle_summary[effective_date.isoformat()]["workout_names"].add(workout.name)
            
            for exercise_obj in workout.exercises.all():
                if hasattr(exercise_obj, 'primary_muscles') and exercise_obj.primary_muscles:
                    daily_muscle_summary[effective_date.isoformat()]["muscles_worked"].update(exercise_obj.primary_muscles)

    for day, data in daily_muscle_summary.items():
        data["muscles_worked"] = sorted(list(data["muscles_worked"]))
        data["workout_names"] = sorted(list(data["workout_names"]))

    output["recent_workouts_summary"] = daily_muscle_summary if daily_muscle_summary else "No workouts with primary muscle groups found in the last 7 days."
    
    return output

def get_user_1rm_stats(user_id: str) -> Dict:
    """
    Fetches all of a user's 1-rep max (1RM) stats.
    """
    try:
        user = AppUser.objects.get(id=user_id)
        maxes = UserExerciseMax.objects.filter(user=user).order_by('exercise__name')
        
        if not maxes.exists():
            return {"message": "No 1-rep max records found for this user."}
            
        return {
            "user_id": str(user_id),
            "one_rep_maxes": [
                {
                    "exercise_name": user_max.exercise.name,
                    "one_rep_max": user_max.one_rep_max,
                    "unit": user_max.unit,
                    "date_recorded": user_max.date_recorded.isoformat()
                }
                for user_max in maxes
            ]
        }
    except AppUser.DoesNotExist:
        return {"error": f"AppUser with ID '{user_id}' not found."}
    except Exception as e:
        return {"error": f"An unexpected error occurred: {str(e)}"}

def _safe_get_user_info(user: AppUser) -> Optional[AppUserInfo]:
    try:
        return user.info
    except AppUserInfo.DoesNotExist:
        return None

def _safe_get_user_goals(user: AppUser) -> Optional[AppUserGoals]:
    try:
        return user.goals
    except AppUserGoals.DoesNotExist:
        return None

def _infer_schedule_logic(user: AppUser) -> Dict[str, any]:
    DEFAULT_GYM_DAYS = 2
    DEFAULT_CARDIO_DAYS = 1
    DEFAULT_REST_DAYS = 4

    info = _safe_get_user_info(user)
    goals = _safe_get_user_goals(user)

    if info is None or goals is None:
        message = f"User {user.id} is missing {'info' if info is None else 'goals'} – using baseline recommendation."
        return {
            "user_id": str(user.id),
            "inferred_gym_days": DEFAULT_GYM_DAYS,
            "inferred_cardio_days": DEFAULT_CARDIO_DAYS,
            "inferred_rest_days": DEFAULT_REST_DAYS,
            "message": message
        }

    age_adjustment = 0
    if info.birthday:
        today = date.today()
        age_years = today.year - info.birthday.year - ((today.month, today.day) < (info.birthday.month, info.birthday.day))
        if age_years < 25:
            age_adjustment = 1
        elif age_years > 50:
            age_adjustment = -1

    goal_set = set(goals.goals_general or [])
    goal_adjustment = 0
    if "build_muscle" in goal_set or "get_stronger" in goal_set:
        goal_adjustment += 1
    if "lose_weight" in goal_set or "regulate_energy" in goal_set:
        goal_adjustment -= 1

    inferred_gym_days = max(1, DEFAULT_GYM_DAYS + age_adjustment + goal_adjustment)
    inferred_cardio_days = DEFAULT_CARDIO_DAYS + max(0, -goal_adjustment)

    total_active = inferred_gym_days + inferred_cardio_days
    if total_active >= 7:
        scale = 6 / total_active
        inferred_gym_days = round(inferred_gym_days * scale)
        inferred_cardio_days = 6 - inferred_gym_days

    inferred_rest_days = 7 - (inferred_gym_days + inferred_cardio_days)
    inferred_rest_days = max(1, inferred_rest_days)

    return {
        "user_id": str(user.id),
        "inferred_gym_days": inferred_gym_days,
        "inferred_cardio_days": inferred_cardio_days,
        "inferred_rest_days": inferred_rest_days,
    }

def infer_workout_schedule(user_id: str) -> str:
    """
    Infers a weekly workout schedule for a user and returns it as a JSON string.
    """
    try:
        user = AppUser.objects.get(id=user_id)
        schedule = _infer_schedule_logic(user)
        return json.dumps(schedule, indent=2)
    except AppUser.DoesNotExist:
        return json.dumps({"error": f"AppUser with ID '{user_id}' not found."}, indent=2)
    except Exception as e:
        return json.dumps({"error": f"An error occurred: {e}"}, indent=2)

# ---------------------------------------------------------------------------
# Equipment helper
# ---------------------------------------------------------------------------

def get_user_available_equipment(user_id: str) -> Optional[List[str]]:
    """Return a list of equipment strings the user owns (from AppUserEquipment)."""
    try:
        user = AppUser.objects.get(id=user_id)
        if hasattr(user, "equipment") and user.equipment:
            return user.equipment.available_equipment or []
        return []
    except AppUser.DoesNotExist:
        return None 