class AgentTools {
  static final List<Map<String, dynamic>> definitions = [
    {
      "type": "function",
      "function": {
        "name": "log_food",
        "description": "Log a food item to the user's daily nutrition log. Use this when the user says they ate something.",
        "parameters": {
          "type": "object",
          "properties": {
            "food_name": {
              "type": "string",
              "description": "The name of the food item, e.g., 'Apple', 'Chicken Salad'."
            },
            "calories": {
              "type": "integer",
              "description": "Estimated calories."
            },
            "protein": {
              "type": "integer",
              "description": "Estimated protein in grams."
            },
            "fat": {
              "type": "integer",
              "description": "Estimated fat in grams."
            },
            "carbs": {
              "type": "integer",
              "description": "Estimated carbohydrates in grams."
            }
          },
          "required": ["food_name", "calories"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "update_rhythm",
        "description": "Update the user's daily rhythm (schedule/tasks). Use this to add, remove, or complete tasks.",
        "parameters": {
          "type": "object",
          "properties": {
            "action": {
              "type": "string",
              "enum": ["add", "remove", "complete"],
              "description": "The action to perform."
            },
            "task_title": {
              "type": "string",
              "description": "The title of the task, e.g., 'Morning Meditation', 'Drink Water'."
            },
            "time_of_day": {
              "type": "string",
              "description": "The time of day for the task (e.g., '08:00 AM', 'Evening'). Optional for remove/complete."
            }
          },
          "required": ["action", "task_title"]
        }
      }
    },
    {
        "type": "function",
        "function": {
            "name": "read_health_context",
            "description": "Read the user's current health context, including daily rhythm progress and recent logs.",
            "parameters": {
                "type": "object",
                "properties": {},
            }
        }
    }
  ];
}
