# graph.py

import os
from typing import List, TypedDict, Optional, Dict, Any

import numpy as np
from langchain_core.messages import HumanMessage, BaseMessage, SystemMessage
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langgraph.graph import StateGraph, END
from sklearn.metrics.pairwise import cosine_similarity

from models import AppState, Task, ApiResponse, ChatMessage, TimeBlock
from intent_router import run_intent_router

# --- 1. Define the State for our Graph ---
# This dictionary will be passed between nodes.

class GraphState(TypedDict):
    app_state: AppState
    # The list of messages that will be sent to the LLM
    messages: List[BaseMessage]
    # A list of candidate tasks found by our search tool
    candidate_tasks: Optional[List[Task]]
    # A list of candidate time blocks found by our search tool
    candidate_time_blocks: Optional[List[TimeBlock]]
    # The final response for the user
    chat_response: str
    # The list of actions for the frontend
    actions: List[Dict[str, Any]]
    # The intent detected by the local NLP router
    detected_intent: str
    # Add the models to the state
    llm: ChatOpenAI
    llm_json: ChatOpenAI
    embeddings_model: OpenAIEmbeddings


# --- 2. Define the Tools and the Agent ---

def get_system_prompt(tasks: List[Task], time_blocks: List[TimeBlock], candidate_tasks: Optional[List[Task]], candidate_time_blocks: Optional[List[TimeBlock]]) -> str:
    """Dynamically generates the system prompt for the LLM."""

    task_list_str = "\n".join([
        f"- ID: {t.id}, Title: '{t.title}', Completed: {t.is_completed}, "
        f"Priority: {t.priority}, Deadline: {t.deadline}, "
        f"Created: {t.creation_date}"
        for t in tasks
    ])

    time_block_list_str = "No events are scheduled on the calendar."
    if time_blocks:
        time_block_list_str = "Here is the current list of all scheduled time blocks on the calendar:\n" + "\n".join([
            f"- Block ID: {tb.id}, Task: '{next((t.title for t in tasks if t.id == tb.task_id), 'Unknown Task')}', Start: {tb.start_time.strftime('%Y-%m-%d %H:%M')}, Duration: {tb.actual_duration_in_minutes} mins"
            for tb in time_blocks
        ])

    candidate_task_str = "No specific tasks identified as candidates."
    if candidate_tasks:
        candidate_task_str = "Based on a semantic search, these are the most likely tasks the user is referring to:\n" + \
                             "\n".join([f"- ID: {t.id}, Title: '{t.title}'" for t in candidate_tasks])

    candidate_time_block_str = "No specific calendar events identified as candidates."
    if candidate_time_blocks:
        candidate_time_block_str = "Based on a semantic search, these are the most likely calendar events the user is referring to:\n" + \
                                 "\n".join([f"- Block ID: {tb.id}, Task Title: '{next((t.title for t in tasks if t.id == tb.task_id), 'Unknown')}', Start: {tb.start_time.strftime('%H:%M')}" for tb in candidate_time_blocks])

    return f"""
You are a helpful and efficient task management assistant. Your goal is to help the user manage their to-do list and calendar via conversation.
You are part of a system that is stateless. You will receive the entire list of tasks, time blocks, and chat history in every request.
The user's most recent message is the last one in the chat history. You must respond to it.

Here is the current list of all tasks:
{task_list_str}

{time_block_list_str}

{candidate_task_str}

{candidate_time_block_str}

Based on the user's latest message, you MUST decide what to do. You MUST respond with a valid JSON object with this exact structure:
{{
  "response_message": "Your conversational response here",
  "actions": [ /* Array of action objects, can be empty */ ]
}}

Available actions and their exact formats:

For tasks:
- createTask: {{"action_type": "createTask", "payload": {{"task": {{ ...task object... }} }} }}
- updateTask: {{"action_type": "updateTask", "payload": {{"id": "task-id", "updatedTask": {{ ...task object... }} }} }}
- deleteTask: {{"action_type": "deleteTask", "payload": {{"id": "task-id"}} }}
- toggleTaskCompletion: {{"action_type": "toggleTaskCompletion", "payload": {{"id": "task-id"}} }}

For calendar time blocks:
- createTimeBlock: {{"action_type": "createTimeBlock", "payload": {{"task_id": "existing-task-id", "start_time": "YYYY-MM-DDTHH:MM:SSZ", "duration_in_minutes": 60}} }}
- updateTimeBlock: {{"action_type": "updateTimeBlock", "payload": {{"id": "existing-block-id", "new_start_time": "YYYY-MM-DDTHH:MM:SSZ", "new_duration_in_minutes": 45}} }}
- deleteTimeBlock: {{"action_type": "deleteTimeBlock", "payload": {{"id": "existing-block-id"}} }}

--- IMPORTANT RULES ---
1. To schedule a task on the calendar (`createTimeBlock`), you MUST use the ID of an existing task. If the user asks to schedule something that is not yet a task, you MUST create the task first, then create the time block for it in the same `actions` array.
2. When a user wants to move or reschedule an event, use `updateTimeBlock`.
3. When a user wants to cancel or remove an event from the calendar, use `deleteTimeBlock`.
4. NEVER guess an ID. If a request is ambiguous, ask for clarification.
5. If the user's request is out of scope, just provide a friendly conversational response with an empty actions array.
6. Always generate a `response_message` that confirms what you've done or asks for clarification.
"""

def find_similar_tasks(query: str, tasks: List[Task], embeddings_model: OpenAIEmbeddings, top_k: int = 5) -> List[Task]:
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

def find_similar_time_blocks(query: str, time_blocks: List[TimeBlock], tasks: List[Task], embeddings_model: OpenAIEmbeddings, top_k: int = 3) -> List[TimeBlock]:
    """Finds the most semantically similar time blocks to a query."""
    if not time_blocks or not tasks:
        return []
    
    task_map = {task.id: task.title for task in tasks}
    
    block_descriptions = []
    for tb in time_blocks:
        task_title = task_map.get(tb.task_id, "a scheduled event")
        block_descriptions.append(f"{task_title} at {tb.start_time.strftime('%I:%M %p on %A')}")

    if not block_descriptions:
        return []

    query_embedding = embeddings_model.embed_query(query)
    block_embeddings = embeddings_model.embed_documents(block_descriptions)

    similarities = cosine_similarity([query_embedding], block_embeddings)[0]
    
    top_k_indices = np.argsort(similarities)[-top_k:][::-1]
    
    return [time_blocks[i] for i in top_k_indices]

# --- 3. Define the Nodes of the Graph ---

def prepare_initial_messages(state: GraphState) -> GraphState:
    """Prepares the initial list of messages for the LLM, including chat history."""
    chat_history_str = "\n".join([f"{msg.sender}: {msg.text}" for msg in state["app_state"].chatHistory])
    latest_message = state["app_state"].chatHistory[-1].text
    state["messages"] = [HumanMessage(content=f"Chat History:\n{chat_history_str}\n\nUser's latest message: '{latest_message}'")]
    return state

def find_candidate_tasks_node(state: GraphState) -> GraphState:
    """Node that runs semantic search to find relevant tasks and time blocks."""
    user_query = state["app_state"].chatHistory[-1].text
    all_tasks = state["app_state"].tasks
    all_time_blocks = state["app_state"].timeBlocks
    embeddings_model = state["embeddings_model"] # Get model from state

    # We only run this if the query isn't obviously a creation command
    if "add" not in user_query.lower() and "create" not in user_query.lower():
        candidate_tasks = find_similar_tasks(user_query, all_tasks, embeddings_model)
        state["candidate_tasks"] = candidate_tasks
    else:
        state["candidate_tasks"] = []
        
    # Also find candidate time blocks
    candidate_time_blocks = find_similar_time_blocks(user_query, all_time_blocks, all_tasks, embeddings_model)
    state["candidate_time_blocks"] = candidate_time_blocks

    return state

def agent_node(state: GraphState) -> GraphState:
    """The main agent node. It invokes the LLM to decide on actions and a response."""
    import json
    llm_json = state["llm_json"] # Get model from state
    
    system_prompt = get_system_prompt(
        state["app_state"].tasks, 
        state["app_state"].timeBlocks,
        state.get("candidate_tasks"),
        state.get("candidate_time_blocks")
    )
    messages = [SystemMessage(content=system_prompt)] + state["messages"]

    # Get JSON response from LLM
    response = llm_json.invoke(messages)
    
    try:
        # Parse the JSON response
        bot_response = json.loads(response.content)
        
        # For complex actions, we will trust the LLM's output structure as defined in the prompt.
        actions = bot_response.get("actions", [])
        
        state["chat_response"] = bot_response.get("response_message", "I processed your request.")
        state["actions"] = actions
        return state
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error parsing LLM response: {e}")
        state["chat_response"] = "I'm sorry, I encountered an error processing your request. Please try again."
        state["actions"] = []
        return state

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
    llm_json = state["llm_json"] # Get model from state
    
    intent = state["detected_intent"]
    user_query = state["app_state"].chatHistory[-1].text
    all_tasks = state["app_state"].tasks
    
    # Prepare a generic failure response
    def get_failure_response():
        state["chat_response"] = "I couldn't find an item matching your request. Could you be more specific?"
        state["actions"] = []
        return state
    
    prompt = ""
    # Generate a focused prompt based on the intent
    if intent in ["DELETE_TASK", "TOGGLE_TASK"]:
        candidate_items = state.get("candidate_tasks", [])
        if not candidate_items: return get_failure_response()
        
        item_list = "\n".join([f"- ID: {t.id}, Title: '{t.title}'" for t in candidate_items])
        action_word = "delete" if intent == "DELETE_TASK" else "toggle"
        prompt = f"""User wants to {action_word} a task with this query: "{user_query}"
These are the candidate tasks:
{item_list}
Return JSON with the ID of the task to {action_word}: {{"item_id": "the-correct-id"}}
If none match, return: {{"item_id": null}}"""

    elif intent == "DELETE_TIME_BLOCK":
        candidate_items = state.get("candidate_time_blocks", [])
        if not candidate_items: return get_failure_response()
        
        task_map = {task.id: task.title for task in all_tasks}
        item_list = "\n".join([f"- ID: {tb.id}, Title: '{task_map.get(tb.task_id, 'Unknown Task')}' at {tb.start_time.strftime('%H:%M')}" for tb in candidate_items])
        prompt = f"""User wants to delete a calendar event with this query: "{user_query}"
These are the candidate events:
{item_list}
Return JSON with the ID of the event to delete: {{"item_id": "the-correct-id"}}
If none match, return: {{"item_id": null}}"""
    else:
        return get_failure_response()

    # Make a lightweight LLM call
    response = llm_json.invoke([HumanMessage(content=prompt)])
    
    try:
        result = json.loads(response.content)
        item_id = result.get("item_id")
        
        if item_id:
            if intent == "DELETE_TASK":
                candidate_tasks = state.get("candidate_tasks") or []
                title = next((t.title for t in candidate_tasks if t.id == item_id), "the task")
                state["chat_response"] = f"OK, I've deleted '{title}' from your list."
                state["actions"] = [{"action_type": "deleteTask", "payload": {"id": item_id}}]
            elif intent == "TOGGLE_TASK":
                candidate_tasks = state.get("candidate_tasks") or []
                title = next((t.title for t in candidate_tasks if t.id == item_id), "the task")
                state["chat_response"] = f"OK, I've toggled the completion status of '{title}'."
                state["actions"] = [{"action_type": "toggleTaskCompletion", "payload": {"id": item_id}}]
            elif intent == "DELETE_TIME_BLOCK":
                # For response message, find the original block and its task title
                candidate_time_blocks = state.get("candidate_time_blocks") or []
                block = next((b for b in candidate_time_blocks if b.id == item_id), None)
                task_title = next((t.title for t in all_tasks if t.id == block.task_id), "the event") if block else "the event"
                state["chat_response"] = f"OK, I've removed '{task_title}' from your calendar."
                state["actions"] = [{"action_type": "deleteTimeBlock", "payload": {"id": item_id}}]
        else:
            state["chat_response"] = "I couldn't find a task matching your request. Could you be more specific?"
            state["actions"] = []
            
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error in specialized agent: {e}")
        state["chat_response"] = "I had trouble understanding which item you meant. Could you be more specific?"
        state["actions"] = []
    
    return state


# --- 4. Wire up the graph ---

# Define the routing logic
def route_after_intent(state: GraphState) -> str:
    """Decides which node to go to after the intent router."""
    intent = state.get("detected_intent", "AGENT_FALLBACK")
    
    if intent == "CREATE_TASK":
        return "final_response"
    elif intent in ["DELETE_TASK", "TOGGLE_TASK", "DELETE_TIME_BLOCK"]:
        return "find_candidate_tasks"
    else:
        return "prepare_initial_messages"

def route_after_find_candidates(state: GraphState) -> str:
    """Decides which agent to use after finding candidates."""
    intent = state.get("detected_intent", "AGENT_FALLBACK")
    
    if intent in ["DELETE_TASK", "TOGGLE_TASK", "DELETE_TIME_BLOCK"]:
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
def run_graph(app_state: AppState, api_key: str) -> ApiResponse:
    """Runs the graph and returns the final API response."""

    # Create model instances here, using the provided key
    llm = ChatOpenAI(model="gpt-4-0125-preview", temperature=0.7, api_key=api_key)
    llm_json = ChatOpenAI(
        model="gpt-4-0125-preview", 
        temperature=0,
        model_kwargs={"response_format": {"type": "json_object"}},
        api_key=api_key
    )
    embeddings_model = OpenAIEmbeddings(model="text-embedding-3-small", api_key=api_key)

    initial_state: GraphState = {
        "app_state": app_state,
        "messages": [],
        "candidate_tasks": None,
        "candidate_time_blocks": None,
        "chat_response": "",
        "actions": [],
        "detected_intent": "",
        # Pass model instances in the state
        "llm": llm,
        "llm_json": llm_json,
        "embeddings_model": embeddings_model,
    }
    final_state = app.invoke(initial_state)
    return ApiResponse(
        chat_response=final_state["chat_response"],
        actions=final_state["actions"]
    ) 
