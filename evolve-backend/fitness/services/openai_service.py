import os
import json
import requests
from typing import Dict, List, Any, Optional
from decouple import config

class OpenAIService:
    """Service for interacting with OpenAI API to generate workout plans"""
    
    def __init__(self, api_key=None):
        """
        Initialize the OpenAI service
        
        Args:
            api_key: OpenAI API key (if None, will try to get from .env file or environment variables)
        """
        # Priority order: 
        # 1. Explicitly passed api_key
        # 2. OPENAI_API_KEY from .env file (via python-decouple)
        # 3. OPENAI_API_KEY from environment variables
        self.api_key = api_key or config('OPENAI_API_KEY', default=None) or os.environ.get('OPENAI_API_KEY')
        
        if not self.api_key:
            raise ValueError("OpenAI API key not provided and not found in .env file or environment variables")
        
        self.base_url = "https://api.openai.com/v1/chat/completions"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    def generate_workout_plan(
        self, 
        duration: int, 
        target_muscles: List[str], 
        experience_level: str, 
        workout_category: str,
        exercise_list: List[Dict[str, str]],
        available_equipment: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Generate a workout plan using OpenAI's o3-mini model
        
        Args:
            duration: Workout duration in minutes
            target_muscles: List of muscles to target
            experience_level: User experience level (beginner, intermediate, advanced)
            workout_category: Type of workout (strength, flexibility, cardio, etc.)
            exercise_list: List of exercises to include in the workout plan (required)
            available_equipment: Optional list of available equipment
            
        Returns:
            Dictionary containing the workout plan
        """
        if not exercise_list:
            return {"error": "Exercise list is required to generate a workout plan"}
            
        # Craft the prompt
        prompt = self._create_workout_prompt(
            duration, 
            target_muscles, 
            experience_level, 
            workout_category,
            exercise_list,
            available_equipment
        )
        
        # Prepare the API request payload
        payload = {
            "model": "gpt-4.1", 
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.7,
            "max_tokens": 1000
        }
        
        # Make the API call
        try:
            response = requests.post(
                self.base_url,
                headers=self.headers,
                json=payload
            )
            response.raise_for_status()  # Raise exception for HTTP errors
            
            result = response.json()
            
            # Extract and return the generated workout plan
            if 'choices' in result and len(result['choices']) > 0:
                workout_plan = result['choices'][0]['message']['content']
                
                # Try to parse as JSON if possible
                try:
                    return json.loads(workout_plan)
                except json.JSONDecodeError:
                    # Return as text if not valid JSON
                    return {"workout_plan": workout_plan}
            else:
                return {"error": "No response generated"}
                
        except requests.exceptions.RequestException as e:
            return {"error": f"API request failed: {str(e)}"}
    
    def _create_workout_prompt(
        self, 
        duration: int, 
        target_muscles: List[str], 
        experience_level: str, 
        workout_category: str,
        exercise_list: List[Dict[str, str]],
        available_equipment: Optional[List[str]] = None
    ) -> str:
        """
        Craft a prompt for the OpenAI model to generate a workout plan
        
        Returns:
            The prompt string
        """
        equipment_text = ""
        if available_equipment:
            equipment_text = f"The user has access to the following equipment: {', '.join(available_equipment)}."
        else:
            equipment_text = "The user doesn't have access to any equipment, so only include bodyweight exercises."
        
        # Format exercises as JSON string
        exercises_json = json.dumps(exercise_list, indent=2)
        
        return f"""
You are a professional fitness coach tasked with creating a personalized workout plan. Here are the requirements:

1. Duration: {duration} minutes
2. Target muscles: {', '.join(target_muscles)}
3. Experience level: {experience_level}
4. Workout category: {workout_category}
5. Equipment: {equipment_text}

IMPORTANT: You must ONLY use exercises from the following list:
{exercises_json}

Please generate a detailed workout plan that:
- Fits within the time constraint
- Focuses primarily on the target muscles listed
- Is appropriate for someone with {experience_level} experience
- Aligns with the {workout_category} workout category
- ONLY includes exercises from the provided list

For each exercise in the workout you generate, include:
- The exercise ID (exactly as provided in the list)
- Recommended number of sets
- Recommended number of reps
- Recommended weight (if applicable, can be specified as a percentage of 1RM or actual weight)

Return the workout plan as a structured JSON object with the following format:
{{
  "duration": "Total duration in minutes",
  "category": "The workout category",
  "target_muscles": ["list", "of", "targeted", "muscles"],
  "exercises": [
    {{
      "id": "exercise ID from the provided list",
      "sets": number,
      "reps": number,
      "weight": "recommended weight (e.g., '50 lbs', '70% 1RM', etc.)",
      "rest": "rest period in seconds"
    }}
  ]
}}

Ensure the workout plan is challenging but achievable for the specified experience level, and that the total time for all exercises, including rest periods, fits within the requested duration.
""" 