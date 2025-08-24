"""
Defines the tool schemas for Groq models based on functions available in `max.tools`.
Each tool definition is a dictionary that the model will use to understand
how and when to call your Python functions.
"""

# This is a list of tool definitions. Each item in the list is a dictionary
# that describes a function the model can call.
# You need to ensure these definitions accurately reflect the functions in `max.tools.py`

GROQ_MODEL_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_user_details",
            "description": "Fetches and returns details for a given AppUser ID as a JSON object. Details include User Info (Height, Age, Weight, Sex), Goals, and a summary of recent workouts.",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "The UUID of the user to fetch details for."
                    }
                },
                "required": ["user_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_latest_user_fatigue",
            "description": "Retrieves the latest fatigue levels for each muscle group for a specific user from the database. Returns a dictionary of muscle names to fatigue values (0.0 to 1.0).",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "The UUID of the user to fetch fatigue levels for."
                    }
                },
                "required": ["user_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_user_1rm_stats",
            "description": "Fetches all of a user's 1-rep max (1RM) stats from the database.",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "The UUID of the user to fetch 1RM stats for."
                    }
                },
                "required": ["user_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_exercises",
            "description": "Searches the exercise database for exercises based on various criteria. Use this to find exercises for a workout plan.",
            "parameters": {
                "type": "object",
                "properties": {
                    "level": {
                        "type": "string",
                        "description": "Optional. Exercise difficulty level (e.g., 'Beginner', 'Intermediate', 'Expert')."
                    },
                    "equipment": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional. List of available equipment (e.g., ['Dumbbell', 'Body Only'])."
                    },
                    "primary_muscles": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional. List of primary muscle groups to target."
                    },
                    "secondary_muscles": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional. List of secondary muscle groups to target."
                    },
                    "category": {
                        "type": "string",
                        "description": "Optional. Exercise category (e.g., 'Strength', 'Cardio')."
                    },
                    "force": {
                        "type": "string",
                        "description": "Optional. The force type of the exercise (e.g., 'Push', 'Pull')."
                    },
                    "mechanic": {
                        "type": "string",
                        "description": "Optional. The mechanic type (e.g., 'Compound', 'Isolation')."
                    },
                    "is_cardio": {
                        "type": "boolean",
                        "description": "Optional. Filter for cardio exercises."
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_projected_central_recovery", # Corresponds to `max.tools.get_projected_central_recovery`
            "description": "Calculates projected central recovery times for each muscle group after a given workout. Does NOT change the model's actual fatigue state.",
            "parameters": {
                "type": "object",
                "properties": {
                    "workout_exercises_details": {
                        "type": "array",
                        "items": { "type": "object" }, # Each object is an exercise detail
                        "description": "List of exercise dictionaries for the workout. Each dict should contain 'name', 'sets', 'reps', 'weight', 'R1', 'primary_muscles', 'secondary_muscles', 'difficulty_multiplier'."
                    },
                    "F_target_cen": {
                        "type": "number",
                        "description": "Target central fatigue level for recovery calculation (e.g., 0.2)."
                    },
                    "use_current_fatigue": {
                        "type": "boolean",
                        "description": "If true, projects recovery from the model's current fatigue state (from fatigue model instance). If false, assumes a fresh start (F_cen=0 for projection)."
                    },
                     "initial_F_cen_override": {
                        "type": "object",
                        "description": "Optional. If use_current_fatigue is False and this is provided, this dictionary (muscle: fatigue_level) will be used as the starting F_cen for the projection."
                    }
                },
                "required": ["workout_exercises_details", "F_target_cen", "use_current_fatigue"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "apply_workout_to_fatigue_model", # Corresponds to `max.tools.apply_workout_to_fatigue_model`
            "description": "Updates the fatigue model's central fatigue state based on a completed workout and the time elapsed since the last central update.",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "workout_exercises_details": {
                        "type": "array",
                        "items": { "type": "object" },
                        "description": "List of exercise dictionaries detailing the workout."
                    },
                    "delta_t_hours_since_last_central_update": {
                        "type": "number",
                        "description": "Time in hours since the last central fatigue update (e.g., time since the end of the previous workout or last rest day simulation)."
                    }
                },
                "required": ["user_id", "workout_exercises_details", "delta_t_hours_since_last_central_update"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "simulate_rest_day_recovery", # Corresponds to `max.tools.simulate_rest_day_recovery`
            "description": "Simulates a 24-hour rest period, updating the central fatigue levels in the fatigue model instance accordingly due to natural decay.",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "hours": {"type": "number"}
                },
                "required": ["user_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_workout_instance",
            "description": "Creates a Workout and associated WorkoutExercise rows given a list of exercise details and returns the new workout_id.",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "UUID of the user for whom this workout is being generated."
                    },
                    "workout_name": {
                        "type": "string",
                        "description": "Name for the new workout (e.g., 'Push Day A')."
                    },
                    "exercises_details": {
                        "type": "array",
                        "items": {"type": "object"},
                        "description": "List of exercise dictionaries. Each must contain exercise_id or exercise_name, sets, reps, weight, and optional equipment, order, time (seconds)."
                    }
                },
                "required": ["user_id", "workout_name", "exercises_details"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_activity_for_workout",
            "description": "Creates an Activity linked to a Workout and returns the activity_id.",
            "parameters": {
                "type": "object",
                "properties": {
                    "workout_id": {"type": "string"},
                    "name": {"type": "string"},
                    "description": {"type": "string"},
                    "default_point_value": {"type": "number"},
                    "category": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["workout_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "schedule_activity",
            "description": "Schedules an Activity for a user on a given date.",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"},
                    "activity_id": {"type": "string"},
                    "scheduled_date_iso": {"type": "string"},
                    "order_in_day": {"type": "number"},
                    "is_generated": {"type": "boolean"}
                },
                "required": ["user_id", "activity_id", "scheduled_date_iso"]
            }
        }
    }
]