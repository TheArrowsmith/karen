# Run the tests with:
# python -m unittest test_graph.py

import unittest
import os
from dotenv import load_dotenv

# Import the models and the function to be tested
from models import AppState, Task, ChatMessage, Priority
from graph import run_graph

# Load environment variables from .env file
load_dotenv()

# Check for OpenAI API key. The tests will be skipped if the key is not found.
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
IS_API_KEY_PRESENT = OPENAI_API_KEY is not None and OPENAI_API_KEY != ""

@unittest.skipIf(not IS_API_KEY_PRESENT, "OpenAI API key not found in .env, skipping integration tests.")
class TestGraphE2E(unittest.TestCase):
    """
    End-to-end tests for the graph.run_graph function.
    These tests make real calls to the OpenAI API and do not use mocks.
    """

    def test_1_create_simple_task(self):
        """Tests creating a single task from a simple user request."""
        print("\n--- Running Test 1: Create Simple Task ---")
        app_state = AppState(
            tasks=[],
            chatHistory=[
                ChatMessage(id="msg-1", text="add a task to buy groceries", sender="user")
            ]
        )

        # Run the graph
        response = run_graph(app_state)

        # Assertions
        self.assertEqual(len(response.actions), 1, "Expected exactly one action to be created.")
        self.assertEqual(response.actions[0]['action_type'], 'createTask', "Expected a 'createTask' action.")
        print("--- Test 1 Passed ---")

    def test_2_toggle_task_completion(self):
        """Tests marking an existing task as complete."""
        print("\n--- Running Test 2: Toggle Task Completion ---")
        task_id = "task-abc-123"
        app_state = AppState(
            tasks=[
                Task(
                    id=task_id,
                    title="Submit quarterly report",
                    is_completed=False,
                    priority=Priority.high,
                    creation_date="2023-10-27T10:00:00Z"
                )
            ],
            chatHistory=[
                ChatMessage(id="msg-1", text="I just finished the quarterly report", sender="user")
            ]
        )
        
        # Run the graph
        response = run_graph(app_state)
        
        # Assertions
        self.assertEqual(len(response.actions), 1, "Expected exactly one action.")
        self.assertEqual(response.actions[0]['action_type'], 'toggleTaskCompletion', "Expected a 'toggleTaskCompletion' action.")
        self.assertEqual(response.actions[0]['payload']['id'], task_id, "Action payload should reference the correct task ID.")
        print("--- Test 2 Passed ---")

    def test_3_delete_existing_task(self):
        """Tests deleting a task by referencing its title."""
        print("\n--- Running Test 3: Delete Existing Task ---")
        task_to_delete_id = "task-def-456"
        app_state = AppState(
            tasks=[
                Task(id="task-abc-123", title="Submit quarterly report", is_completed=True),
                Task(id=task_to_delete_id, title="Book flight to conference", is_completed=False)
            ],
            chatHistory=[
                ChatMessage(id="msg-1", text="get rid of the flight booking task", sender="user")
            ]
        )

        # Run the graph
        response = run_graph(app_state)

        # Assertions
        self.assertEqual(len(response.actions), 1, "Expected exactly one action.")
        self.assertEqual(response.actions[0]['action_type'], 'deleteTask', "Expected a 'deleteTask' action.")
        self.assertEqual(response.actions[0]['payload']['id'], task_to_delete_id, "Action payload should reference the correct task ID.")
        print("--- Test 3 Passed ---")

    def test_4_update_existing_task(self):
        """Tests updating a task's property (e.g., priority)."""
        print("\n--- Running Test 4: Update Existing Task ---")
        task_id = "task-xyz-789"
        app_state = AppState(
            tasks=[
                Task(
                    id=task_id,
                    title="Draft the project proposal",
                    is_completed=False,
                    priority=Priority.medium,
                    creation_date="2023-10-27T11:00:00Z"
                )
            ],
            chatHistory=[
                ChatMessage(id="msg-1", text="make the project proposal high priority", sender="user")
            ]
        )

        # Run the graph
        response = run_graph(app_state)
        
        # Assertions
        self.assertEqual(len(response.actions), 1, "Expected exactly one action.")
        action = response.actions[0]
        self.assertEqual(action['action_type'], 'updateTask', "Expected an 'updateTask' action.")
        self.assertEqual(action['payload']['id'], task_id, "Action payload should reference the correct task ID.")
        self.assertEqual(action['payload']['updatedTask']['priority'], 'high', "Task priority should be updated to 'high'.")
        print("--- Test 4 Passed ---")


    def test_5_ambiguous_request(self):
        """Tests that an ambiguous request results in a clarification and no actions."""
        print("\n--- Running Test 5: Ambiguous Request ---")
        app_state = AppState(
            tasks=[
                Task(id="task-meet-1", title="Weekly team meeting", is_completed=False),
                Task(id="task-meet-2", title="1-on-1 meeting with Sarah", is_completed=False)
            ],
            chatHistory=[
                ChatMessage(id="msg-1", text="mark the meeting as done", sender="user")
            ]
        )

        # Run the graph
        response = run_graph(app_state)

        # Assertions
        self.assertEqual(len(response.actions), 0, "Expected zero actions for an ambiguous request.")
        print("--- Test 5 Passed ---")

    def test_6_out_of_scope_request(self):
        """Tests that a nonsense or out-of-scope request results in no actions."""
        print("\n--- Running Test 6: Out-of-Scope Request ---")
        app_state = AppState(
            tasks=[],
            chatHistory=[
                ChatMessage(id="msg-1", text="what is the capital of nebraska?", sender="user")
            ]
        )

        # Run the graph
        response = run_graph(app_state)

        # Assertions
        self.assertEqual(len(response.actions), 0, "Expected zero actions for an out-of-scope request.")
        print("--- Test 6 Passed ---")

    def test_7_create_multiple_tasks(self):
        """Tests creating multiple tasks from a single user prompt."""
        print("\n--- Running Test 7: Create Multiple Tasks ---")
        app_state = AppState(
            tasks=[],
            chatHistory=[
                ChatMessage(
                    id="msg-1",
                    text="I need to add two tasks: first, call the plumber, and second, buy a new filter",
                    sender="user"
                )
            ]
        )

        # Run the graph
        response = run_graph(app_state)
        
        # Assertions
        self.assertEqual(len(response.actions), 2, "Expected exactly two actions to be created.")
        action_types = [action['action_type'] for action in response.actions]
        self.assertTrue(all(at == 'createTask' for at in action_types), "All actions should be of type 'createTask'.")
        print("--- Test 7 Passed ---")


if __name__ == '__main__':
    unittest.main()
