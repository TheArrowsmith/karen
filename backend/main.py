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
