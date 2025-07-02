# intent_router.py

import spacy
from spacy.matcher import Matcher
import uuid
from datetime import datetime

# --- Load Models and Initialize Matcher (runs only once on server start) ---
try:
    nlp = spacy.load("en_core_web_sm")
except OSError:
    print("Spacy model 'en_core_web_sm' not found. Please run 'python -m spacy download en_core_web_sm'")
    nlp = None

matcher = Matcher(nlp.vocab) if nlp else None

# --- Define Patterns for Intent Matching ---
# The patterns are ordered from more specific to more general.

# Pattern for creating a task. Looks for a verb like "add/create" followed by content.
create_pattern = [
    {"LOWER": {"IN": ["add", "create", "make"]}, "POS": "VERB"},
    {"LOWER": {"IN": ["a", "an", "the"]}, "OP": "?"},
    {"LOWER": {"IN": ["task", "reminder", "item", "entry"]}, "OP": "?"},
    {"LOWER": {"IN": ["to", "for"]}, "OP": "?"},
    {"POS": {"IN": ["VERB", "NOUN"]}, "OP": "+"},
    {"IS_PUNCT": False, "OP": "*"}
]

# Pattern for deleting a task.
delete_pattern = [
    {"LOWER": {"IN": ["delete", "remove", "get rid of", "cancel"]}, "POS": "VERB"},
    {"IS_PUNCT": False, "OP": "*"}
]

# Pattern for toggling a task's completion status.
toggle_pattern = [
    {"LOWER": {"IN": ["mark", "toggle", "finish", "finished", "complete", "completed", "did"]}, "POS": {"IN": ["VERB", "AUX"]}},
    {"IS_PUNCT": False, "OP": "*"}
]

if matcher:
    matcher.add("CREATE_TASK", [create_pattern])
    matcher.add("DELETE_TASK", [delete_pattern])
    matcher.add("TOGGLE_TASK", [toggle_pattern])

# --- Main Router Function ---

def run_intent_router(user_message: str):
    """
    Uses spaCy to detect simple intents and returns the detected intent and a payload.
    - For CREATE_TASK, it can fully handle the request.
    - For others, it just identifies the intent for further routing.
    """
    if not nlp or not matcher:
        return {"intent": "AGENT_FALLBACK", "payload": None, "response": None}

    doc = nlp(user_message)
    matches = matcher(doc, as_spans=True)

    # Filter out matches that are just sub-matches of longer ones
    # and prefer longer, more specific matches.
    matches = spacy.util.filter_spans(matches)
    
    if not matches:
        return {"intent": "AGENT_FALLBACK", "payload": None, "response": None}

    # The first match is the longest, best one.
    best_match = matches[0]
    rule_id = best_match.label_
    
    # --- Tier 1: Full Shortcut for CREATE_TASK ---
    if rule_id == "CREATE_TASK":
        # Check for complex entities that the LLM should handle instead
        for ent in doc.ents:
            if ent.label_ in ["DATE", "TIME", "CARDINAL", "ORDINAL"]:
                return {"intent": "AGENT_FALLBACK", "payload": None, "response": None}
        if any(token.lower_ in ["priority", "deadline", "urgent"] for token in doc):
            return {"intent": "AGENT_FALLBACK", "payload": None, "response": None}

        # Extract the title
        title_start_index = 0
        for i, token in enumerate(best_match):
             if token.pos_ in ["VERB", "NOUN"] and i > 0:
                title_start_index = token.i
                break
        
        task_title = doc[title_start_index:].text.strip()

        # Create the action and response directly
        new_task = {
            "id": str(uuid.uuid4()),
            "title": task_title,
            "description": None,
            "is_completed": False,
            "priority": None,
            "creation_date": datetime.utcnow().isoformat() + "Z",
            "deadline": None,
            "predicted_duration_in_minutes": None,
        }
        return {
            "intent": "CREATE_TASK",
            "payload": [{"action_type": "createTask", "payload": {"task": new_task}}],
            "response": f"OK, I've added '{task_title}' to your list."
        }
    
    # --- Tier 2: Partial Shortcut for Other Intents ---
    if rule_id in ["DELETE_TASK", "TOGGLE_TASK"]:
        return {"intent": rule_id, "payload": None, "response": None}

    # --- Tier 3: Fallback ---
    return {"intent": "AGENT_FALLBACK", "payload": None, "response": None} 