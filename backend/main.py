# main.py

from fastapi import FastAPI, HTTPException
import uvicorn
import os
import sys
import atexit

from models import AppState, ApiResponse
from graph import run_graph

# Initialize the FastAPI app
app = FastAPI(
    title="Task Management Chatbot Backend",
    description="API for processing user chat messages and returning actions.",
    version="1.0.0"
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

# To run the server using Unix domain sockets:
# python main.py

if __name__ == "__main__":
    # Use the exact same path as the sandboxed Swift app
    import os
    home = os.path.expanduser("~")
    # This is the containerized cache directory for the sandboxed app
    SOCKET_PATH = os.path.join(home, "Library/Containers/com.arrowsmithlabs.karen/Data/Library/Caches/karen_dev.sock")
    
    # Ensure the directory exists
    socket_dir = os.path.dirname(SOCKET_PATH)
    os.makedirs(socket_dir, exist_ok=True)
    
    # 2. Define a cleanup function to remove the socket file when the server stops.
    #    This is critical to prevent errors on the next launch if the server crashes.
    def cleanup():
        print(f"\nCleaning up socket file at {SOCKET_PATH}")
        if os.path.exists(SOCKET_PATH):
            os.remove(SOCKET_PATH)
    
    # 3. Register the cleanup function to run automatically on process exit.
    atexit.register(cleanup)
    
    print(f"🚀 Starting server on UNIX Domain Socket: {SOCKET_PATH}")
    print("   Press CTRL+C to stop.")

    # 4. Run the Uvicorn server, telling it to listen on the socket path (`uds`)
    #    instead of a host and port.
    uvicorn.run(app, uds=SOCKET_PATH) 
