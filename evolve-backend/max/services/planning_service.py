"""Weekly workout schedule generator – canonical implementation.

Moved from `max.core.workout_planner` to this module for clearer package
structure.  Imports updated to use the new `max.services` façade instead of the
older `max.tools` path.
"""
from __future__ import annotations

import json
from datetime import date, timedelta
from typing import Dict, List

from max.ai import GroqClient
from .user_service import (
    get_user_details,
    get_user_1rm_stats,
    get_user_available_equipment,
)
from .fatigue_service import get_latest_user_fatigue, simulate_rest_day_recovery
from .exercise_service import search_exercises
from .workout_service import create_workout_instance
from .activity_service import (
    create_activity_for_workout,
    schedule_activity,
    create_cardio_activity,
)

from max.core.fatigue import TwoCompartmentFatigueModel

__all__ = ["generate_weekly_schedule", "generate_weekly_plan"]


def generate_weekly_schedule(
    user_id: str,
    active_days: int | None = None,
    start_date: date | None = None,
) -> Dict:
    """Generate a 7-day schedule and persist `UserScheduledActivity` rows."""

    if start_date is None:
        start_date = date.today()

    # 1. gather context -------------------------------------------------
    user_details = get_user_details(user_id)
    fatigue_snapshot = get_latest_user_fatigue(user_id)
    one_rm_stats_dict = get_user_1rm_stats(user_id)
    one_rm_lookup = {}
    if isinstance(one_rm_stats_dict, dict) and "one_rep_maxes" in one_rm_stats_dict:
        for item in one_rm_stats_dict["one_rep_maxes"]:
            one_rm_lookup[item["exercise_name"].lower()] = item["one_rep_max"]
    include_cardio = user_details.get("info", {}).get("include_cardio", True)
    equipment_list = get_user_available_equipment(user_id) or []

    system_prompt = (
        "You are a world-class certified fitness coach. Your task is to generate a 7-day workout plan. "
        "The output MUST be a single JSON object. The keys of this object must be 'Day 1', 'Day 2', ..., 'Day 7'. "
        "The value for each day key must be another JSON object containing two keys: 'type' and 'focus'. "
        "The 'type' must be one of: 'gym', 'cardio', or 'rest'. "
        "The 'focus' for 'gym' days should be a logical muscle group or training cluster (e.g., 'Upper Body Push', 'Legs'). "
        "Structure the plan logically, considering muscle recovery (e.g., avoid consecutive intense leg days). A good split is Push, Pull, Legs. "
        "Return ONLY this single JSON object and nothing else."
    )

    user_blob = {
        "user_details": user_details,
        "current_fatigue": fatigue_snapshot,
        "one_rm": one_rm_stats_dict,
        "include_cardio": include_cardio,
        "active_days_constraint": active_days,
    }

    client = GroqClient()

    def _call_llm() -> Dict:
        try:
            resp = client.send_message(
                user_prompt=json.dumps(user_blob),
                system_prompt=system_prompt.replace("{active_days}", str(active_days) if active_days else ""),
                use_tools=False
            )
            if resp.strip().startswith("```json"):
                resp = resp.strip()[7:-4].strip()
            
            parsed_json = json.loads(resp)
            # Attempt to repair if LLM returns a list instead of a dict
            if isinstance(parsed_json, list) and len(parsed_json) == 7:
                print("Info: LLM returned a list, converting to Day-keyed dictionary.")
                return {f"Day {i+1}": parsed_json[i] for i in range(7)}
            
            return parsed_json
        except Exception as e:
            print(f"LLM call for blueprint failed: {e}")
            return {} # Return empty dict to trigger validation failure

    blueprint = _call_llm()
    if not _validate_blueprint(blueprint, include_cardio, active_days):
        # Second attempt with clarification
        user_blob["validation_feedback"] = "Last response failed validation. Ensure 7 days, correct types, and active day constraints."
        blueprint = _call_llm()
        if not _validate_blueprint(blueprint, include_cardio, active_days):
            raise RuntimeError("LLM blueprint invalid after second attempt")

    # 2. materialise days ----------------------------------------------
    scheduled_ids: List[str] = []
    cur_date = start_date

    allowed_focuses = {
        'quadriceps','abdominals','abductors','adductors','biceps','calves',
        'cardiovascular','chest','forearms','full body','glutes','hamstrings',
        'lats','lower back','middle back','neck','shoulders','traps','triceps'
    }

    fatigue_model = TwoCompartmentFatigueModel()
    if isinstance(fatigue_snapshot, dict):
        for k, v in fatigue_snapshot.items():
            if k in fatigue_model.F_cen:
                fatigue_model.F_cen[k] = v

    last_focus_muscle: str | None = None
    FATIGUE_THRESHOLD = 0.5  # if muscle fatigue above this, skip gym day

    search_cache: Dict[str, str] = {}

    for idx in range(1, 8):
        day_key = f"Day {idx}"
        meta = blueprint.get(day_key) or blueprint.get(day_key.replace(" ", ""), {"type": "rest"})
        day_type = meta.get("type", "rest").lower()

        if day_type == "rest":
            simulate_rest_day_recovery(user_id=user_id, hours=24)
        elif day_type == "cardio":
            cardio_resp = create_cardio_activity(user_id=user_id, cardio_type="run", duration_minutes=30)
            act_id = cardio_resp.get("activity_id")
            if act_id:
                sched = schedule_activity(
                    user_id=user_id,
                    activity_id=act_id,
                    scheduled_date_iso=cur_date.isoformat(),
                )
                if sid := sched.get("scheduled_activity_id"):
                    scheduled_ids.append(sid)
            cur_date += timedelta(days=1)
            continue
        else:
            focus = meta.get("focus", "full body").lower()
            if focus not in allowed_focuses:
                focus = "full body"

            # Choose muscle with lowest fatigue not equal to last focus
            sorted_by_fatigue = sorted(fatigue_model.F_cen.items(), key=lambda kv: kv[1])
            primary_choice = None
            for m_name, _val in sorted_by_fatigue:
                if m_name != last_focus_muscle:
                    primary_choice = m_name
                    break
            if primary_choice is None:
                primary_choice = sorted_by_fatigue[0][0]

            focus_muscle = focus if focus != "full body" else primary_choice

            # If chosen muscle fatigue too high, convert to rest day automatically
            if fatigue_model.F_cen.get(focus_muscle, 0) > FATIGUE_THRESHOLD:
                simulate_rest_day_recovery(user_id=user_id, hours=24)
                cur_date += timedelta(days=1)
                continue

            # Step A: Get all available exercises for the focus
            search_resp = search_exercises(primary_muscles=[focus_muscle], equipment=equipment_list)

            if "No exercises found" in search_resp:
                print(f"Warning: No exercises found for focus '{focus_muscle}' with available equipment. Converting to rest day.")
                simulate_rest_day_recovery(user_id=user_id, hours=24)
                last_focus_muscle = None # Reset since it's now a rest day
                cur_date += timedelta(days=1)
                continue

            # Step B: Use a second LLM call to select and order exercises
            selection_client = GroqClient()
            selection_system_prompt = (
                "You are an expert workout designer. Your task is to select and order exercises from the provided list "
                "to create a logical and effective workout. Prioritize compound movements before isolation exercises. "
                "Avoid selecting redundant exercises; for example, do not include multiple variations of a bench press in the same workout. Aim for variety in movement patterns. "
                "Return ONLY a valid JSON array of the selected exercise IDs, in the optimal order. Do not include any other text or markdown."
            )
            selection_user_prompt = (
                f"From the following list of available exercises for a '{focus.replace('_', ' ').title()}' workout, "
                f"please select 5 to 7 exercises and provide their IDs in a JSON array, ordered for an optimal workout session.\n\n"
                f"Available Exercises:\n{search_resp}"
            )

            ordered_ids_json = selection_client.send_message(
                user_prompt=selection_user_prompt,
                system_prompt=selection_system_prompt,
                use_tools=False
            )

            try:
                raw_ids = json.loads(ordered_ids_json)
                if not isinstance(raw_ids, list):
                    raise ValueError("LLM did not return a list.")

                # Validate each ID is a valid UUID before proceeding
                import uuid
                selected_ids = []
                for item_id in raw_ids:
                    try:
                        uuid.UUID(str(item_id))
                        selected_ids.append(str(item_id))
                    except ValueError:
                        print(f"Warning: LLM returned an invalid UUID '{item_id}'. Discarding it.")

            except (json.JSONDecodeError, ValueError) as e:
                print(f"Error processing LLM exercise selection: {e}. Skipping day.")
                last_focus_muscle = None
                simulate_rest_day_recovery(user_id=user_id, hours=24)
                cur_date += timedelta(days=1)
                continue

            # If, after validation, no valid IDs are left, convert to rest day.
            if not selected_ids:
                print(f"Warning: No valid exercise IDs were returned by the LLM for focus '{focus_muscle}'. Converting to rest day.")
                simulate_rest_day_recovery(user_id=user_id, hours=24)
                last_focus_muscle = None
                cur_date += timedelta(days=1)
                continue

            exercises_details = []
            for ex_id in selected_ids:
                try:
                    # Lazy import inside loop to avoid heavy models at top
                    from fitness.models import Exercise as _Ex
                    ex_obj = _Ex.objects.get(id=ex_id)
                    name_lower = ex_obj.name.lower()
                    r1_val = one_rm_lookup.get(name_lower)
                except Exception:
                    ex_obj = None
                    r1_val = None

                weight_val = 0
                reps_val = 10
                sets_val = 3

                if r1_val and r1_val > 0:
                    weight_val = round(0.65 * r1_val)
                    reps_val = 8  # Hypertrophy rep range
                    sets_val = 4

                exercises_details.append({
                    "exercise_id": ex_id,
                    "sets": sets_val,
                    "reps": reps_val,
                    "weight": weight_val,
                })

            wk_resp = create_workout_instance(
                user_id=user_id,
                workout_name=f"{focus.replace('_', ' ').title()} Workout",
                exercises_details=exercises_details,
            )
            workout_id = wk_resp.get("workout_id")
            if not workout_id:
                continue
            act_resp = create_activity_for_workout(workout_id=workout_id)
            act_id = act_resp.get("activity_id")
            if not act_id:
                continue
            sched_resp = schedule_activity(
                user_id=user_id,
                activity_id=act_id,
                scheduled_date_iso=cur_date.isoformat(),
            )
            if sid := sched_resp.get("scheduled_activity_id"):
                scheduled_ids.append(sid)

            # Build detailed list for fatigue model impulse
            detailed_for_fatigue = []
            for ex_detail in exercises_details:
                try:
                    from fitness.models import Exercise as _Ex
                    ex_obj = _Ex.objects.get(id=ex_detail["exercise_id"])
                    r1_val = one_rm_lookup.get(ex_obj.name.lower(), 1)
                    detailed_for_fatigue.append({
                        'name': ex_obj.name,
                        'sets': ex_detail['sets'],
                        'reps': ex_detail['reps'],
                        'weight': ex_detail['weight'],
                        'R1': r1_val,
                        'primary_muscles': ex_obj.primary_muscles or [],
                        'secondary_muscles': ex_obj.secondary_muscles or [],
                        'difficulty_multiplier': 1.0,
                    })
                except Exception:
                    continue

            fatigue_model.update_central_fatigue_from_workout(detailed_for_fatigue, 0)
            last_focus_muscle = focus_muscle
        cur_date += timedelta(days=1)

    return {"scheduled_activity_ids": scheduled_ids, "llm_draft": blueprint}


generate_weekly_plan = generate_weekly_schedule 

# ---------------------------------------------------------------------------
# Local helpers
# ---------------------------------------------------------------------------


ALLOWED_DAY_TYPES = {"gym", "cardio", "rest"}


def _validate_blueprint(bp: Dict, include_cardio: bool, active_days_constraint: int | None) -> bool:
    """Return True if blueprint passes basic validation rules."""
    # Must have 7 keys
    for i in range(1, 8):
        if f"Day {i}" not in bp and f"Day{i}" not in bp:
            return False

    active_day_count = 0
    for meta in bp.values():
        if not isinstance(meta, dict):
            return False
        d_type = meta.get("type", "rest").lower()
        if d_type == "workout":  # Treat 'workout' as an alias for 'gym'
            d_type = "gym"
        if d_type not in ALLOWED_DAY_TYPES:
            return False
        if d_type != "rest":
            active_day_count += 1
        if d_type == "cardio" and not include_cardio:
            return False

    if active_days_constraint and active_day_count != active_days_constraint:
        return False

    return True 