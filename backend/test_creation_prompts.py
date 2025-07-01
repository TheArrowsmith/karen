# Run the tests with:
# python -m unittest test_creation_prompts.py

import unittest
import os
from datetime import datetime
from dotenv import load_dotenv

from models import AppState, ChatMessage
from graph import run_graph

# Load environment variables from .env file
load_dotenv()

# Check for OpenAI API key.
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
IS_API_KEY_PRESENT = OPENAI_API_KEY is not None and OPENAI_API_KEY != ""

# --- List of Prompts to Test ---

# Each entry is a tuple: (test_name, prompt_text)
# This allows us to generate tests dynamically.
CREATION_PROMPTS = [
    # Category 1: Explicit & Direct Commands
    ('explicit_call_dentist', "add a new task: call the dentist"),
    ('explicit_buy_milk', "Create a task to buy milk and eggs"),
    ('explicit_report', "New task: Finish the quarterly report"),
    ('explicit_dry_cleaning', "add: pick up dry cleaning"),
    ('explicit_book_flight', "create task - Book flight to New York"),

    # Category 2: Implicit & Conversational Commands
    ('implicit_team_meeting', "I need to schedule a team meeting for next week"),
    ('implicit_water_plants', "I have to remember to water the plants tomorrow"),
    ('implicit_follow_up_email', "oh, I can't forget to send that follow-up email"),
    ('implicit_draft_proposal', "on my to-do list: draft the project proposal"),
    ('implicit_oil_change', "I should probably get the car's oil changed soon"),
    ('implicit_pay_bill', "got to pay the electricity bill"),

    # Category 3: Question-Based Commands
    ('question_call_mom', "Could you remind me to call Mom on Sunday?"),
    ('question_research_crm', "Can you make a task to research new CRM software?"),
    ('question_update_resume', "Will you add 'update resume' to my list?"),

    # Category 4: Prompts with Deadlines
    ('deadline_trash_tonight', "Remind me to take out the trash tonight at 9pm"),
    ('deadline_rent_next_month', "add a task to pay rent by the 1st of next month"),
    ('deadline_taxes_april', "File taxes before April 15th"),
    ('deadline_bday_december', "Create a task to send birthday card to David, his birthday is 2024-12-25"),

    # Category 5: Prompts with Priority
    ('priority_high_bug', "add a high priority task to fix the production bug"),
    ('priority_implicit_high', "It's really important that I finish the client mockup today"),
    ('priority_low_organize', "Create a low priority task: organize my desktop files"),
    ('priority_implicit_low', "It's not urgent, but add a task to clean the garage"),

    # Category 6: Prompts with Descriptions
    ('description_plan_vacation', "Add a task to plan the vacation. I need to look up flights, hotels, and things to do."),
    ('description_fix_bug', "I need to fix the login bug. The bug happens when a user types a password longer than 25 characters."),
    ('description_blog_post', "Create a task called 'Write Blog Post'. The topic should be 'The Future of AI Assistants'."),
]


@unittest.skipIf(not IS_API_KEY_PRESENT, "OpenAI API key not found, skipping integration tests.")
class TestGraphCreationPrompts(unittest.TestCase):
    """
    Tests a wide variety of user prompts that should result in a 'createTask' action.
    This test class dynamically creates a test method for each prompt in the list.
    """
    pass

def create_test_method(prompt_text):
    """A closure that creates a test function for a given prompt."""
    def test_prompt(self):
        print(f"\n--- Running Test for Prompt: '{prompt_text}' ---")
        
        # Setup the state for this specific test
        app_state = AppState(
            tasks=[],
            chatHistory=[
                ChatMessage(id="msg-1", text=prompt_text, sender="user")
            ]
        )

        # Run the graph
        response = run_graph(app_state)
        
        # Primary Assertion: at least one action was created
        self.assertGreaterEqual(len(response.actions), 1, 
            f"Expected at least one action for prompt: '{prompt_text}'")
        
        # Secondary Assertion: the first action is a 'createTask' action
        action = response.actions[0]
        self.assertEqual(action['action_type'], 'createTask',
            f"Expected a 'createTask' action for prompt: '{prompt_text}'")

        # Optional: Log the created task's title for manual review
        created_task = action['payload']['task']
        print(f"  -> SUCCESS: Created task with title: '{created_task.get('title')}'")
        if created_task.get('description'):
            print(f"  -> Description: '{created_task.get('description')}'")
        if created_task.get('deadline'):
            print(f"  -> Deadline: '{created_task.get('deadline')}'")
        if created_task.get('priority'):
            print(f"  -> Priority: '{created_task.get('priority')}'")

    return test_prompt

# Dynamically add a test method to the class for each prompt
for name, prompt in CREATION_PROMPTS:
    test_method = create_test_method(prompt)
    setattr(TestGraphCreationPrompts, f'test_{name}', test_method)


if __name__ == '__main__':
    unittest.main()
