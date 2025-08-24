"""
Client for interacting with Groq models, including tool use.
"""
import json
import os
from dotenv import load_dotenv
from groq import Groq
from pathlib import Path

from .tool_definitions import GROQ_MODEL_TOOLS

BASE_DIR = Path(__file__).resolve().parent.parent.parent


# Define the default model name here, can be overridden in constructor
DEFAULT_GROQ_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

class GroqClient:
    def __init__(self, model_name=None):
        # Load environment variables from .env file
        load_dotenv(os.path.join(BASE_DIR, '.env'))
        self.api_key = os.getenv("GROQ_API_KEY")
        self.model_name = model_name or DEFAULT_GROQ_MODEL
        
        if not self.api_key:
            raise ValueError("GROQ_API_KEY not found in .env file or environment variables. Please ensure it's set in " + str(dotenv_path))
        
        self.client = Groq(api_key=self.api_key)
        self.conversation_history = []
        self.tool_definitions = GROQ_MODEL_TOOLS

    def _execute_tool_call(self, tool_call):
        """Dynamically executes a tool call based on its name and arguments."""
        # Defer import to break circular dependency: planning_service -> GroqClient -> services
        try:
            from max import services as user_tools
        except ImportError:
            print(
                "Warning: Could not import the 'services' package from 'max'. "
                "Ensure the package and its __init__.py are correct."
            )
            user_tools = None

        function_name = tool_call.function.name
        try:
            function_args_dict = json.loads(tool_call.function.arguments)
        except json.JSONDecodeError as e:
            print(f"Error decoding JSON arguments for tool {function_name}: {e}")
            return f"Error: Invalid JSON arguments provided for {function_name}."

        if not user_tools:
            print(f"Error: user_tools module not loaded. Cannot execute tool: {function_name}")
            return f"Error: Tool module not available for {function_name}."

        if hasattr(user_tools, function_name):
            print(f"Executing tool: {function_name} with args: {function_args_dict}")
            try:
                function_to_call = getattr(user_tools, function_name)
                result = function_to_call(**function_args_dict)
                return result
            except Exception as e:
                print(f"Error executing tool {function_name}: {e}")
                return f"Error during execution of {function_name}: {str(e)}"
        else:
            print(f"Error: Tool '{function_name}' not found in user_tools module.")
            return f"Error: Tool '{function_name}' is not defined."

    def send_message(self, user_prompt=None, system_prompt=None, use_tools: bool = True):
        """
        Sends a message to the configured Groq model, handles tool calls, 
        and returns the LLM's textual response.
        """
        if not self.conversation_history and system_prompt:
            self.conversation_history.append({"role": "system", "content": system_prompt})
        
        if user_prompt:
            self.conversation_history.append({"role": "user", "content": user_prompt})
        elif not self.conversation_history:
            raise ValueError("A user_prompt or system_prompt must be provided for the first message.")

        if not use_tools:
            print("\n--- Groq Model Request (No Tools) ---")
            try:
                chat_completion = self.client.chat.completions.create(
                    messages=self.conversation_history,
                    model=self.model_name,
                )
                response_message = chat_completion.choices[0].message
                print(f"Model Response: {response_message.content}")
                return response_message.content
            except Exception as e:
                print(f"Groq API request failed: {e}")
                raise

        # Tool-use enabled execution loop
        max_tool_iterations = 5
        for i in range(max_tool_iterations):
            print(f"\n--- Groq Model Request Iteration {i+1} ---")

            try:
                chat_completion = self.client.chat.completions.create(
                    messages=self.conversation_history,
                    model=self.model_name,
                    tools=self.tool_definitions,
                    tool_choice="auto",
                )
            except Exception as e:
                print(f"Groq API request failed: {e}")
                raise

            response = chat_completion.choices[0].message
            self.conversation_history.append(response)

            if response.tool_calls:
                print(f"Model requested tool call(s): {[tc.function.name for tc in response.tool_calls]}")
                tool_results = []
                for tool_call in response.tool_calls:
                    tool_call_id = tool_call.id
                    tool_output = self._execute_tool_call(tool_call)
                    tool_results.append({
                        "tool_call_id": tool_call_id,
                        "role": "tool",
                        "name": tool_call.function.name,
                        "content": json.dumps(tool_output)
                    })
                
                self.conversation_history.extend(tool_results)
            else:
                print(f"Model Response: {response.content}")
                return response.content 

        print("Warning: Exceeded maximum tool iterations.")
        last_assistant_response = self.conversation_history[-1]
        return last_assistant_response.content if last_assistant_response.content else "Max tool iterations reached without a final text response."

    def reset_conversation(self):
        """Clears the conversation history."""
        self.conversation_history = []
        print("Conversation history reset.")

# Example Usage (you can move this to a main script or test file)
if __name__ == '__main__':
    # Ensure your .env file is at /Users/marcussypher/dev/evolve/evolve-backend/.env
    # and contains GROQ_API_KEY=your_actual_key
    print("Attempting to initialize GroqClient...")
    try:
        # You can specify a different .env path if needed:
        # planner_client = GroqClient(dotenv_path="/path/to/your/.env")
        planner_client = GroqClient()
        print("Client initialized.")

        planner_client.reset_conversation()
        system_message = (
            "You are a world-class certified fitness coach with expertise in tailoring plans to individual goals and constraints."
            "Use the available tools to search for exercises and manage fatigue based on the user's needs."
        )
        user_query = "Please generate a 7-day workout plan for muscle hypertrophy. Focus on chest and triceps for Day 1. User has dumbbells and barbells."
        
        print(f"\nSending initial prompt to Groq model: {user_query}")
        response = planner_client.send_message(user_prompt=user_query, system_prompt=system_message)
        
        print(f"\n--- Final Response from Groq Model ---")
        print(response)

    except ValueError as ve:
        print(f"Configuration Error: {ve}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        import traceback
        traceback.print_exc() 