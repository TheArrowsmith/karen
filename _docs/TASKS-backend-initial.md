### High-Level Goal

Our objective is to build a stateless Python backend server for a task management chatbot. This server will expose a single API endpoint that receives the current list of tasks and chat history from a client application. It will use the OpenAI API (specifically GPT-4.1-nano and an embedding model) via a LangGraph workflow to understand the user's latest message, determine the necessary actions (like creating, updating, or deleting tasks), and return a conversational response along with a structured list of these actions for the client to execute.

### Step-by-Step Implementation Instructions

#### Step 1: Initialize the Python Environment and Install Dependencies

First, we need to create a virtual environment and install all the necessary libraries. Execute these commands in your terminal one by one.

1.  Activate the virtual environment:
    ```bash
    source venv/bin/activate
    ```

2.  Install all required packages using pip. We need libraries for the web server (FastAPI), running the server (Uvicorn), data validation (Pydantic), managing environment variables, and interacting with OpenAI and LangGraph.
    ```bash
    pip install fastapi uvicorn python-dotenv pydantic pydantic-settings openai langgraph langchain-openai scikit-learn numpy
    ```
    *Note: `scikit-learn` and `numpy` are used for a simple and effective cosine similarity calculation for our semantic search tool.*

#### Step 2: Define the Data Models

We need to translate the Swift data models into Python Pydantic models. This ensures our API is type-safe and that data serialization/deserialization is handled automatically.

Create a new file named `models.py` and add the following code to it. This file will define all the data structures for our application.

```python
# models.py

import uuid
from datetime import datetime
from enum import Enum
from typing import List, Optional, Literal, Union, Annotated

from pydantic import BaseModel, Field

# --- Core Data Models (mirroring Swift) ---

class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"

class Task(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    description: Optional[str] = None
    is_completed: bool = False
    priority: Optional[Priority] = None
    creation_date: datetime = Field(default_factory=datetime.utcnow)
    deadline: Optional[datetime] = None
    

class Sender(str, Enum):
    user = "user"
    bot = "bot"

class ChatMessage(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    text: str
    sender: Sender

# --- API Request Body Model ---

class AppState(BaseModel):
    tasks: List[Task]
    chatHistory: List[ChatMessage]

# --- Action (AppIntent) Models for the API Response ---
# These represent the commands the frontend will execute.

class CreateTaskPayload(BaseModel):
    task: Task

class UpdateTaskPayload(BaseModel):
    id: str
    updatedTask: Task

class DeleteTaskPayload(BaseModel):
    id: str

class ToggleTaskCompletionPayload(BaseModel):
    id: str

# Use Annotated and Field to create a tagged union for the actions
# This makes it easy for Pydantic to parse the correct action type
class CreateTaskAction(BaseModel):
    action_type: Literal["createTask"]
    payload: CreateTaskPayload

class UpdateTaskAction(BaseModel):
    action_type: Literal["updateTask"]
    payload: UpdateTaskPayload

class DeleteTaskAction(BaseModel):
    action_type: Literal["deleteTask"]
    payload: DeleteTaskPayload

class ToggleTaskAction(BaseModel):
    action_type: Literal["toggleTaskCompletion"]
    payload: ToggleTaskCompletionPayload

Action = Annotated[
    Union[CreateTaskAction, UpdateTaskAction, DeleteTaskAction, ToggleTaskAction],
    Field(discriminator="action_type"),
]

# --- API Response Body Model ---

class ApiResponse(BaseModel):
    chat_response: str
    actions: List[Action]

```

#### Step 3: Create the LangGraph Workflow

This is the core logic of our application. We will define a graph that processes the user's request. It will have nodes for analyzing intent, finding tasks, and generating the final response.

Create a new file named `graph.py` and add the following code. I have added extensive comments to explain each part of the process.

```python
# graph.py

import os
from typing import List, TypedDict, Optional

import numpy as np
from dotenv import load_dotenv
from langchain_core.messages import HumanMessage, BaseMessage, SystemMessage
from langchain_core.pydantic_v1 import BaseModel, Field
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langgraph.graph import StateGraph, END
from sklearn.metrics.pairwise import cosine_similarity

from models import AppState, Task, Action, ApiResponse

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
    actions: List[Action]


# --- 2. Define the Tools and the Agent ---

# Initialize the OpenAI models we'll be using
# gpt-4.1-nano is a fast and capable model for this structured task
llm = ChatOpenAI(model="gpt-4.1-nano", temperature=0, openai_api_key=os.getenv("OPENAI_API_KEY"))
# text-embedding-3-small is a cheap and powerful model for semantic search
embeddings_model = OpenAIEmbeddings(model="text-embedding-3-small", openai_api_key=os.getenv("OPENAI_API_KEY"))

# Define the structured output the LLM should produce
class BotResponse(BaseModel):
    """The bot's response, containing a conversational message and a list of actions."""
    response_message: str = Field(description="A conversational, helpful message to display to the user.")
    actions: List[Action] = Field(description="A list of actions for the frontend to execute. Can be empty.")

# Bind the desired output structure to the LLM
structured_llm = llm.with_structured_output(BotResponse)

def get_system_prompt(tasks: List[Task], candidate_tasks: Optional[List[Task]]) -> str:
    """Dynamically generates the system prompt for the LLM."""
    
    task_list_str = "\n".join([f"- ID: {t.id}, Title: '{t.title}', Completed: {t.is_completed}" for t in tasks])
    
    candidate_task_str = "No specific candidates identified. The user might be creating a new task or the query is ambiguous."
    if candidate_tasks:
        candidate_task_str = "Based on a semantic search, these are the most likely tasks the user is referring to:\n" + \
                             "\n".join([f"- ID: {t.id}, Title: '{t.title}', Completed: {t.is_completed}" for t in candidate_tasks])

    return f"""
You are a helpful and efficient task management assistant. Your goal is to help the user manage their to-do list via conversation.
You are part of a system that is stateless. You will receive the entire list of tasks and chat history in every request.
The user's most recent message is the last one in the chat history. You must respond to it.

Here is the current list of all tasks:
{task_list_str}

{candidate_task_str}

Based on the user's latest message and the chat history, determine what to do.
You can perform the following actions by generating the corresponding JSON objects:
- createTask: To add a new task.
- updateTask: To modify an existing task. You must provide the full updated task object.
- deleteTask: To remove a task.
- toggleTaskCompletion: To mark a task as complete or incomplete.

IMPORTANT RULES:
1.  **NEVER** guess a task ID. If the user's request is ambiguous (e.g., "delete the meeting task" when multiple exist), ask for clarification instead of acting.
2.  When creating a task, you MUST generate a new UUID for the task's 'id' field.
3.  For updates, you MUST provide the complete, updated task object in the 'updatedTask' field of the payload.
4.  If the user's request is nonsensical, out of scope, or just small talk, do not generate any actions. Just provide a friendly conversational response.
5.  Always generate a `response_message` that confirms what you've done or asks for clarification.
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
    messages = [ChatMessage(text=msg.text, sender=msg.sender) for msg in state["app_state"].chatHistory]
    state["messages"] = [HumanMessage(content=f"Chat History:\n{messages}\n\nUser's latest message: '{messages[-1].text}'")]
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
    system_prompt = get_system_prompt(state["app_state"].tasks, state.get("candidate_tasks"))
    messages = [SystemMessage(content=system_prompt)] + state["messages"]

    bot_response = structured_llm.invoke(messages)
    
    return {
        **state,
        "chat_response": bot_response.response_message,
        "actions": bot_response.actions
    }

def final_response_node(state: GraphState) -> GraphState:
    """Assembles the final API response. This is the last step."""
    # This node doesn't do much now, but is a good placeholder for future final logic.
    return state


# --- 4. Wire up the graph ---

workflow = StateGraph(GraphState)

workflow.add_node("prepare_initial_messages", prepare_initial_messages)
workflow.add_node("find_candidate_tasks", find_candidate_tasks_node)
workflow.add_node("agent", agent_node)
workflow.add_node("final_response", final_response_node)

workflow.set_entry_point("prepare_initial_messages")
workflow.add_edge("prepare_initial_messages", "find_candidate_tasks")
workflow.add_edge("find_candidate_tasks", "agent")
workflow.add_edge("agent", "final_response")
workflow.add_edge("final_response", END)

# Compile the graph into a runnable object
app = workflow.compile()


# --- 5. Create a simple runner function ---
def run_graph(app_state: AppState) -> ApiResponse:
    """Runs the graph and returns the final API response."""
    initial_state = {"app_state": app_state}
    final_state = app.invoke(initial_state)
    return ApiResponse(
        chat_response=final_state["chat_response"],
        actions=final_state["actions"]
    )

```

#### Step 4: Create the FastAPI Server

Finally, we'll create the web server that exposes our API endpoint. This script will tie everything together.

Create a new file named `main.py` and add the following code:

```python
# main.py

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from models import AppState, ApiResponse
from graph import run_graph

# Initialize the FastAPI app
app = FastAPI(
    title="Task Management Chatbot Backend",
    description="API for processing user chat messages and returning actions.",
    version="1.0.0"
)

# Configure CORS (Cross-Origin Resource Sharing)
# This allows our frontend (on a different domain) to communicate with this backend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this to your frontend's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", tags=["Health Check"])
def read_root():
    """A simple health check endpoint to confirm the server is running."""
    return {"status": "ok"}


@app.post("/api/chat", response_model=ApiResponse, tags=["Chat"])
def process_chat_message(app_state: AppState):
    """
    Receives the full application state (tasks and chat history),
    processes the latest user message through the LangGraph workflow,
    and returns a conversational response and a list of actions.
    """
    if not app_state.chatHistory:
        raise HTTPException(status_code=400, detail="Chat history cannot be empty.")
    
    try:
        # Run the main logic graph
        api_response = run_graph(app_state)
        return api_response
    except Exception as e:
        # Basic error handling for any unexpected issues in the graph
        print(f"An error occurred: {e}")
        raise HTTPException(status_code=500, detail="An internal error occurred while processing the request.")

# To run the server, execute the following command in your terminal:
# uvicorn main:app --reload
```

#### Step 5: Run the Server

You are now ready to run the application. Make sure your virtual environment is still active and your `.env` file with the `OPENAI_API_KEY` is present.

Execute this command in your terminal:
```bash
uvicorn main:app --reload
```

The server will start, and you can access the automatically generated API documentation at `http://127.0.0.1:8000/docs`. You can use this documentation to test the `/api/chat` endpoint by providing it with JSON that matches the `AppState` model.

---

### Summary of Created Files

The following new files were created. No existing files were modified.

*   `models.py`
*   `graph.py`
*   `main.py`
