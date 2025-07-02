#!/usr/bin/env python3
"""
Test script to demonstrate the Intent Router functionality.
Run this after installing spacy and downloading the model:
    pip install -r requirements.txt
    python -m spacy download en_core_web_sm
"""

from intent_router import run_intent_router

def test_intent_router():
    """Test various user messages to see how the router classifies them."""
    
    test_messages = [
        # CREATE_TASK examples (should be fully handled by router)
        "add task to buy milk",
        "create a reminder to call mom",
        "make a task for cleaning the garage",
        
        # DELETE_TASK examples (should be identified for partial shortcut)
        "delete the meeting task",
        "remove buy groceries from my list",
        "get rid of the gym task",
        
        # TOGGLE_TASK examples (should be identified for partial shortcut)
        "mark the shopping task as done",
        "complete the laundry task",
        "I finished the homework",
        
        # Complex examples (should fallback to full LLM)
        "I need to call my dentist tomorrow at 3pm",
        "add a high priority task to submit the report by Friday",
        "I should probably start working on the presentation",
        "what tasks do I have for today?",
    ]
    
    print("Testing Intent Router\n" + "="*50 + "\n")
    
    for message in test_messages:
        result = run_intent_router(message)
        intent = result["intent"]
        
        print(f"Message: '{message}'")
        print(f"Intent: {intent}")
        
        if intent == "CREATE_TASK":
            print(f"Response: {result['response']}")
            print(f"Action: {result['payload'][0]['action_type']}")
            print(f"Task Title: {result['payload'][0]['payload']['task']['title']}")
        elif intent in ["DELETE_TASK", "TOGGLE_TASK"]:
            print("→ Will use specialized agent to find and act on the task")
        else:
            print("→ Will use full LLM agent")
        
        print("-" * 50 + "\n")

if __name__ == "__main__":
    test_intent_router() 