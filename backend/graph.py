# graph.py

import os
from typing import List, TypedDict, Optional, Dict, Any

import numpy as np
from dotenv import load_dotenv
from langchain_core.messages import HumanMessage, BaseMessage, SystemMessage
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langgraph.graph import StateGraph, END
from sklearn.metrics.pairwise import cosine_similarity

from models import AppState, Task, ApiResponse, ChatMessage
from intent_router import run_intent_router

# Load environment variables from .env file
load_dotenv()

# --- 1. Define the State for our Graph ---
# This dictionary will be passed between nodes.

class GraphState(TypedDict):
    app_state: AppState
    # The list of messages that will be sent to the LLM
    messages: List[BaseMessage]
    # A list of candidate tasks found by our search tool
    candidate_tasks: Optional[List[Task]]
    # The final response for the user
    chat_response: str
    # The list of actions for the frontend
    actions: List[Dict[str, Any]]
    # The intent detected by the local NLP router
    detected_intent: str


# --- 2. Define the Tools and the Agent ---

# Initialize the OpenAI models we'll be using
# gpt-4.1-nano is a fast and capable model for this structured task
llm = ChatOpenAI(model="gpt-4.1-nano", temperature=0, openai_api_key=os.getenv("OPENAI_API_KEY"))
# text-embedding-3-small is a cheap and powerful model for semantic search
embeddings_model = OpenAIEmbeddings(model="text-embedding-3-small", openai_api_key=os.getenv("OPENAI_API_KEY"))

# We'll use JSON mode instead of structured output to avoid Pydantic version conflicts
llm_json = ChatOpenAI(model="gpt-4.1-nano", temperature=0, openai_api_key=os.getenv("OPENAI_API_KEY"), model_kwargs={"response_format": {"type": "json_object"}})

def get_system_prompt(tasks: List[Task], candidate_tasks: Optional[List[Task]]) -> str:
    """Dynamically generates the system prompt for the LLM."""
    
    # Show full task details for better context
    task_list_str = "\n".join([
        f"- ID: {t.id}, Title: '{t.title}', Completed: {t.is_completed}, "
        f"Priority: {t.priority}, Deadline: {t.deadline}, "
        f"Created: {t.creation_date}" 
        for t in tasks
    ])
    
    candidate_task_str = "No specific candidates identified. The user might be creating a new task or the query is ambiguous."
    if candidate_tasks:
        candidate_task_str = "Based on a semantic search, these are the most likely tasks the user is referring to:\n" + \
                             "\n".join([
                                 f"- ID: {t.id}, Title: '{t.title}', Completed: {t.is_completed}, "
                                 f"Priority: {t.priority}, Deadline: {t.deadline}"
                                 for t in candidate_tasks
                             ])

    return f"""
You are a helpful and efficient task management assistant. Your goal is to help the user manage their to-do list via conversation.
You are part of a system that is stateless. You will receive the entire list of tasks and chat history in every request.
The user's most recent message is the last one in the chat history. You must respond to it.

Here is the current list of all tasks:
{task_list_str}

{candidate_task_str}

Based on the user's latest message, you MUST decide whether to create, update, or delete a task, or simply chat.

You MUST respond with a valid JSON object with this exact structure:
{{
  "response_message": "Your conversational response here",
  "actions": [
    // Array of action objects, can be empty
  ]
}}

--- EXAMPLES ---

1.  **Implicit Task Creation:**
    *   User Message: "today I have to water my plants"
    *   Your JSON Response:
        {{
          "response_message": "OK, I've added 'water my plants' to your list for today.",
          "actions": [
            {{
              "action_type": "createTask",
              "payload": {{
                "task": {{
                  "id": "a-new-uuid-you-generate",
                  "title": "Water the plants",
                  "is_completed": false,
                  "deadline": "YYYY-MM-DD" // Set to today's date
                }}
              }}
            }}
          ]
        }}

2.  **Ambiguous Request (Requires Clarification):**
    *   User Message: "delete the meeting task"
    *   (Assume there are two tasks: 'Plan team meeting' and 'Book meeting room')
    *   Your JSON Response:
        {{
          "response_message": "You have a couple of tasks related to meetings: 'Plan team meeting' and 'Book meeting room'. Which one would you like to delete?",
          "actions": []
        }}

3.  **Creation with Title and Description:**
    *   User Message: "Add a task to plan the vacation. I need to look up flights, hotels, and things to do."
    *   Your JSON Response:
        {{
          "response_message": "Right, I've added 'Plan the vacation' to your list with the details you provided.",
          "actions": [
            {{
              "action_type": "createTask",
              "payload": {{
                "task": {{
                  "id": "a-new-uuid-you-generate",
                  "title": "Plan the vacation",
                  "description": "Need to look up flights, hotels, and things to do.",
                  "is_completed": false
                }}
              }}
            }}
          ]
        }}

Available actions and their exact formats:

For creating a task:
{{
  "action_type": "createTask",
  "payload": {{
    "task": {{
      "id": "generate-a-uuid-here",
      "title": "A short, clear title for the task",
      "description": "Any additional details, context, or notes from the user's request can go here. Can be null.",
      "is_completed": false,
      "priority": null, // or "low", "medium", "high"
      "creation_date": "YYYY-MM-DDTHH:MM:SSZ", // Current UTC time
      "deadline": null, // or "YYYY-MM-DDTHH:MM:SSZ"
      "predicted_duration_in_minutes": null
    }}
  }}
}}

For other actions:
- updateTask: {{"action_type": "updateTask", "payload": {{"id": "existing-task-id", "updatedTask": {{complete task object with ALL original fields preserved, only changing what the user requested}}}}}}
- deleteTask: {{"action_type": "deleteTask", "payload": {{"id": "existing-task-id"}}}}
- toggleTaskCompletion: {{"action_type": "toggleTaskCompletion", "payload": {{"id": "existing-task-id"}}}}

--- IMPORTANT RULES & JSON FORMAT ---

1.  **NEVER** guess a task ID. If the user's request is ambiguous (e.g., "delete the meeting task" when multiple exist), ask for clarification instead of acting.
2.  When creating a task, you MUST generate a new UUID for the task's 'id' field (format: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx").
3.  For updates, you MUST provide the complete, updated task object in the 'updatedTask' field of the payload.
4.  For the 'priority' field in any task object, you MUST use one of these exact string values: "low", "medium", or "high". DO NOT use "Priority.high" or other object representations.
5.  If the user's request is nonsensical, out of scope, or just small talk, do not generate any actions. Just provide a friendly conversational response with an empty actions array.
6.  Always generate a response_message that confirms what you've done or asks for clarification.
"""

def find_similar_tasks(query: str, tasks: List[Task], top_k: int = 5) -> List[Task]:
    """Finds the most semantically similar tasks to a given query."""
    if not tasks:
        return []
    
    task_titles = [task.title for task in tasks]
    query_embedding = embeddings_model.embed_query(query)
    task_embeddings = embeddings_model.embed_documents(task_titles)

    similarities = cosine_similarity([query_embedding], task_embeddings)[0]
    
    # Get the indices of the top_k most similar tasks
    top_k_indices = np.argsort(similarities)[-top_k:][::-1]
    
    return [tasks[i] for i in top_k_indices]

# --- 3. Define the Nodes of the Graph ---

def prepare_initial_messages(state: GraphState) -> GraphState:
    """Prepares the initial list of messages for the LLM, including chat history."""
    chat_history_str = "\n".join([f"{msg.sender}: {msg.text}" for msg in state["app_state"].chatHistory])
    latest_message = state["app_state"].chatHistory[-1].text
    state["messages"] = [HumanMessage(content=f"Chat History:\n{chat_history_str}\n\nUser's latest message: '{latest_message}'")]
    return state

def find_candidate_tasks_node(state: GraphState) -> GraphState:
    """Node that runs semantic search to find relevant tasks."""
    user_query = state["app_state"].chatHistory[-1].text
    all_tasks = state["app_state"].tasks
    # We only run this if the query isn't obviously a creation command
    if "add" not in user_query.lower() and "create" not in user_query.lower():
        candidate_tasks = find_similar_tasks(user_query, all_tasks)
        state["candidate_tasks"] = candidate_tasks
    else:
        state["candidate_tasks"] = []
    return state

def agent_node(state: GraphState) -> GraphState:
    """The main agent node. It invokes the LLM to decide on actions and a response."""
    import json
    import uuid
    
    system_prompt = get_system_prompt(state["app_state"].tasks, state.get("candidate_tasks"))
    messages = [SystemMessage(content=system_prompt)] + state["messages"]

    # Get JSON response from LLM
    response = llm_json.invoke(messages)
    
    try:
        # Parse the JSON response
        bot_response = json.loads(response.content)
        
        # Process actions to ensure they match our model structure
        actions = []
        for action_data in bot_response.get("actions", []):
            action_type = action_data.get("action_type")
            payload = action_data.get("payload", {})
            
            if action_type == "createTask":
                # Ensure the task has all required fields
                task_data = payload.get("task", {})
                if "id" not in task_data:
                    task_data["id"] = str(uuid.uuid4())
                if "title" in task_data:  # Only create if title exists
                    actions.append({
                        "action_type": "createTask",
                        "payload": {"task": task_data}
                    })
            elif action_type == "updateTask":
                actions.append({
                    "action_type": "updateTask",
                    "payload": payload
                })
            elif action_type == "deleteTask":
                actions.append({
                    "action_type": "deleteTask",
                    "payload": payload
                })
            elif action_type == "toggleTaskCompletion":
                actions.append({
                    "action_type": "toggleTaskCompletion",
                    "payload": payload
                })
        
        return {
            **state,
            "chat_response": bot_response.get("response_message", "I processed your request."),
            "actions": actions
        }
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error parsing LLM response: {e}")
        return {
            **state,
            "chat_response": "I'm sorry, I encountered an error processing your request. Please try again.",
            "actions": []
        }

def final_response_node(state: GraphState) -> GraphState:
    """Assembles the final API response. This is the last step."""
    # This node doesn't do much now, but is a good placeholder for future final logic.
    return state

def intent_router_node(state: GraphState) -> GraphState:
    """The new router node. It runs first to see if it can handle the request locally."""
    user_query = state["app_state"].chatHistory[-1].text
    router_result = run_intent_router(user_query)
    
    intent = router_result["intent"]
    state['detected_intent'] = intent
    
    if intent == "CREATE_TASK":
        # Tier 1: Full shortcut. The router handled everything.
        print(f"Router: Create - Pattern matched for '{user_query}'")
        state["chat_response"] = router_result["response"]
        state["actions"] = router_result["payload"]
    else:
        # Log the routing decision
        print(f"Router: {intent} - For query '{user_query}'")
    
    return state

def specialized_agent_node(state: GraphState) -> GraphState:
    """A specialized, lightweight agent for DELETE and TOGGLE intents."""
    import json
    
    intent = state["detected_intent"]
    user_query = state["app_state"].chatHistory[-1].text
    candidate_tasks = state.get("candidate_tasks", [])
    
    if not candidate_tasks:
        state["chat_response"] = "I couldn't find any tasks matching your request."
        state["actions"] = []
        return state
    
    # Create a focused prompt for the specific intent
    if intent == "DELETE_TASK":
        task_list = "\n".join([f"- ID: {t.id}, Title: '{t.title}'" for t in candidate_tasks])
        prompt = f"""
User wants to delete a task with this query: "{user_query}"

These are the candidate tasks:
{task_list}

Return JSON with the ID of the task to delete:
{{"task_id": "the-correct-task-id"}}

If none match, return: {{"task_id": null}}
"""
    else:  # TOGGLE_TASK
        task_list = "\n".join([f"- ID: {t.id}, Title: '{t.title}', Completed: {t.is_completed}" for t in candidate_tasks])
        prompt = f"""
User wants to toggle completion of a task with this query: "{user_query}"

These are the candidate tasks:
{task_list}

Return JSON with the ID of the task to toggle:
{{"task_id": "the-correct-task-id"}}

If none match, return: {{"task_id": null}}
"""
    
    # Make a lightweight LLM call
    response = llm_json.invoke([HumanMessage(content=prompt)])
    
    try:
        result = json.loads(response.content)
        task_id = result.get("task_id")
        
        if task_id:
            # Find the task title for the response message
            task_title = next((t.title for t in candidate_tasks if t.id == task_id), "the task")
            
            if intent == "DELETE_TASK":
                state["chat_response"] = f"OK, I've deleted '{task_title}' from your list."
                state["actions"] = [{"action_type": "deleteTask", "payload": {"id": task_id}}]
            else:  # TOGGLE_TASK
                state["chat_response"] = f"OK, I've toggled the completion status of '{task_title}'."
                state["actions"] = [{"action_type": "toggleTaskCompletion", "payload": {"id": task_id}}]
        else:
            state["chat_response"] = "I couldn't find a task matching your request. Could you be more specific?"
            state["actions"] = []
            
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error in specialized agent: {e}")
        state["chat_response"] = "I had trouble understanding which task you meant. Could you be more specific?"
        state["actions"] = []
    
    return state


# --- 4. Wire up the graph ---

# Define the routing logic
def route_after_intent(state: GraphState) -> str:
    """Decides which node to go to after the intent router."""
    intent = state.get("detected_intent", "AGENT_FALLBACK")
    
    if intent == "CREATE_TASK":
        # Full shortcut - go straight to final response
        return "final_response"
    elif intent in ["DELETE_TASK", "TOGGLE_TASK"]:
        # Partial shortcut - find candidates then use specialized agent
        return "find_candidate_tasks"
    else:
        # Fallback - use the full agent path
        return "prepare_initial_messages"

def route_after_find_candidates(state: GraphState) -> str:
    """Decides which agent to use after finding candidates."""
    intent = state.get("detected_intent", "AGENT_FALLBACK")
    
    if intent in ["DELETE_TASK", "TOGGLE_TASK"]:
        return "specialized_agent"
    else:
        return "agent"

workflow = StateGraph(GraphState)

# Add all nodes
workflow.add_node("intent_router", intent_router_node)
workflow.add_node("prepare_initial_messages", prepare_initial_messages)
workflow.add_node("find_candidate_tasks", find_candidate_tasks_node)
workflow.add_node("agent", agent_node)
workflow.add_node("specialized_agent", specialized_agent_node)
workflow.add_node("final_response", final_response_node)

# Set the router as the entry point
workflow.set_entry_point("intent_router")

# Add conditional routing after the intent router
workflow.add_conditional_edges(
    "intent_router",
    route_after_intent,
    {
        "final_response": "final_response",
        "find_candidate_tasks": "find_candidate_tasks",
        "prepare_initial_messages": "prepare_initial_messages"
    }
)

# Add conditional routing after finding candidates
workflow.add_conditional_edges(
    "find_candidate_tasks",
    route_after_find_candidates,
    {
        "specialized_agent": "specialized_agent",
        "agent": "agent"
    }
)

# Add regular edges
workflow.add_edge("prepare_initial_messages", "find_candidate_tasks")
workflow.add_edge("agent", "final_response")
workflow.add_edge("specialized_agent", "final_response")
workflow.add_edge("final_response", END)

# Compile the graph into a runnable object
app = workflow.compile()


# --- 5. Create a simple runner function ---
def run_graph(app_state: AppState) -> ApiResponse:
    """Runs the graph and returns the final API response."""
    initial_state: GraphState = {
        "app_state": app_state,
        "messages": [],
        "candidate_tasks": None,
        "chat_response": "",
        "actions": [],
        "detected_intent": ""
    }
    final_state = app.invoke(initial_state)
    return ApiResponse(
        chat_response=final_state["chat_response"],
        actions=final_state["actions"]
    ) 
