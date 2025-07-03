# PRD: Task Management Chatbot Backend API

## 1. Introduction/Overview

### Problem
Users manage their to-do lists by manually clicking buttons and filling out forms, which can be slow and interrupt their workflow. Additionally, processing every user request through a powerful but expensive Large Language Model (LLM) is inefficient for simple, direct commands.

### Solution
A conversational backend API that serves as the "brain" of the task management chatbot. The system uses an intelligent routing mechanism to optimize both cost and response time:
- Simple, direct commands (like "add task to buy milk") are handled locally using fast NLP processing
- Complex or ambiguous requests are processed by a sophisticated LLM
- The API translates natural language into specific actions the frontend application can execute

### Goal
To provide a single, stateless API endpoint that:
1. Receives the current app state (tasks and chat history)
2. Intelligently routes requests based on complexity
3. Processes the user's latest message efficiently
4. Returns a conversational response along with structured commands for the frontend

## 2. Goals

*   **Efficient Processing:** Use local NLP for simple commands to reduce latency by at least 50% and eliminate API costs for ~20% of requests
*   **Accurate Intent Recognition:** Accurately interpret user requests to create, update, delete, and toggle task completion
*   **Contextual Conversations:** Provide helpful, context-aware responses with clarification requests when needed
*   **Structured Responses:** Ensure predictable JSON responses for reliable frontend parsing
*   **High Reliability:** Maintain deterministic responses for simple commands with <1% false positive rate

## 3. User Stories

*   **As a busy user,** I want to quickly add a task by typing "add a task to follow up with the design team tomorrow morning", so I can capture my to-dos without navigating through multiple screens.
*   **As a user,** I want to mark a task complete by saying "I'm done with the 'submit expense report' task", so I can easily update my list by referencing the task naturally.
*   **As a user,** I want simple commands like "add task to buy milk" to be processed instantly, so the app feels fast and responsive.
*   **As a user,** when I say "delete the meeting task" and have multiple similar tasks, I want the bot to ask me which one I mean, so I don't accidentally modify the wrong task.
*   **As a developer,** I want to see clear logs showing which processing path was used for each request, so I can measure the system's effectiveness.

## 4. Functional Requirements

### FR1: API Endpoint
The system exposes a single HTTP API endpoint:
*   **Method:** `POST`
*   **Path:** `/api/chat`
*   **Server:** Runs on Unix domain socket for secure local communication

### FR2: Request Body Structure
The endpoint accepts a JSON object representing the application's state:

```json
{
  "tasks": [
    {
      "id": "uuid-string-1",
      "title": "Submit expense report",
      "description": "Q3 expenses for client meetings",
      "is_completed": false,
      "priority": "medium",
      "creation_date": "2023-10-26T10:00:00Z",
      "deadline": "2023-10-29T17:00:00Z",
      "predicted_duration_in_minutes": 30
    }
  ],
  "chatHistory": [
    { "id": "uuid-string-2", "text": "Hello!", "sender": "bot" },
    { "id": "uuid-string-3", "text": "Mark the expense report as done", "sender": "user" }
  ]
}
```

### FR3: Response Body Structure
The endpoint returns a JSON object with:
*   `chat_response` (string): The bot's conversational response
*   `actions` (array): List of commands for the frontend to execute

```json
{
  "chat_response": "OK, I've marked 'Submit expense report' as completed.",
  "actions": [
    {
      "action_type": "toggleTaskCompletion",
      "payload": { "id": "uuid-string-1" }
    }
  ]
}
```

### FR4: Supported Actions

1. **Create Task**
   ```json
   {
     "action_type": "createTask",
     "payload": {
       "task": {
         "id": "backend-generated-uuid",
         "title": "New Task",
         "description": null,
         "is_completed": false,
         "priority": null,
         "creation_date": "2023-10-26T10:00:00Z",
         "deadline": null,
         "predicted_duration_in_minutes": null
       }
     }
   }
   ```

2. **Update Task**
   ```json
   {
     "action_type": "updateTask",
     "payload": {
       "id": "task-uuid",
       "updatedTask": { /* complete task object with all fields */ }
     }
   }
   ```

3. **Delete Task**
   ```json
   {
     "action_type": "deleteTask",
     "payload": { "id": "task-uuid" }
   }
   ```

4. **Toggle Task Completion**
   ```json
   {
     "action_type": "toggleTaskCompletion",
     "payload": { "id": "task-uuid" }
   }
   ```

### FR5: Intent Routing System

The system uses a three-tier routing approach:

#### Tier 1: Full Shortcut (CREATE_TASK)
*   Uses spaCy's pattern matching to detect simple creation commands
*   Patterns include verbs like "add", "create", "make" followed by task content
*   Bypasses all API calls if no complex entities (dates, priorities) are detected
*   Generates complete action payload locally with UUID and timestamp
*   Returns simple confirmation message

#### Tier 2: Partial Shortcut (DELETE_TASK, TOGGLE_TASK)
*   Detects deletion patterns ("delete", "remove", "get rid of")
*   Detects completion patterns ("mark", "complete", "finish", "toggle")
*   Uses semantic search to find top 5 candidate tasks
*   Makes focused LLM call to select the correct task from candidates
*   Generates appropriate action and confirmation message

#### Tier 3: Full LLM Processing
*   Handles all complex, ambiguous, or conversational requests
*   Uses full context including task list and chat history
*   Can handle multiple actions, complex parsing, and clarification requests

### FR6: Task Identification System

For update/delete/toggle operations:
1. **Semantic Search:** Uses OpenAI's `text-embedding-3-small` model to find semantically similar tasks
2. **Candidate Selection:** Returns top 5 most relevant tasks based on cosine similarity
3. **LLM Decision:** Passes candidates to appropriate agent for final selection

### FR7: Ambiguity Handling
*   System never guesses when uncertain
*   Returns empty actions list with clarification request
*   Examples: "I found multiple tasks matching 'meeting'. Which one did you mean: 1. 'Team Meeting' or 2. 'Client Meeting'?"

### FR8: Error Handling
*   Network errors return HTTP 503 with informative message
*   Invalid requests return HTTP 400
*   Internal errors are logged and return HTTP 500
*   Malformed LLM responses fail gracefully with user-friendly error message

### FR9: Logging
*   Every request logs the routing path taken:
  - `Router: Create` - for shortcut creations
  - `Router: Delete` - for delete intent
  - `Router: Toggle` - for completion toggle intent  
  - `Router: AGENT_FALLBACK` - for full LLM processing
*   Matched patterns are logged for router paths

## 5. Non-Goals (Out of Scope)

*   User authentication or authorization
*   Persistent storage or database (fully stateless)
*   Reordering tasks or managing time blocks
*   Handling multiple actions in a single command
*   Processing implicit/conversational task creation (e.g., "I should probably call my mom")
*   Extracting complex entities (deadlines, priorities) in router shortcuts

## 6. Design Considerations

*   **Tone:** The AI maintains a helpful, concise, and professional tone
*   **Confirmations:** All actions receive clear confirmation messages
*   **Efficiency:** Router patterns are ordered from specific to general for optimal matching

## 7. Technical Considerations

### Architecture
*   **Language:** Python 3
*   **Framework:** FastAPI with automatic data validation
*   **State Machine:** LangGraph for orchestrating the multi-path workflow
*   **NLP:** spaCy with English small model (`en_core_web_sm`)

### Dependencies
*   `fastapi`, `uvicorn` - Web server
*   `langgraph`, `langchain-openai` - LLM orchestration
*   `openai` - API integration
*   `spacy` - Local NLP processing
*   `scikit-learn`, `numpy` - Semantic similarity calculations
*   `pydantic`, `pydantic-settings` - Data validation and environment management
*   `python-dotenv` - Environment variable loading

### AI Models
*   **Main LLM:** `gpt-4.1-nano` (for complex requests and specialized agents)
*   **Embeddings:** `text-embedding-3-small` (for semantic search)
*   **Local NLP:** spaCy `en_core_web_sm` (for intent routing)

### Configuration
*   `OPENAI_API_KEY` stored in `.env` file (gitignored)
*   Server runs on Unix domain socket at `~/Library/Containers/com.arrowsmithlabs.karen/Data/Library/Caches/karen_dev.sock`

### Graph Workflow
The system implements a state machine with the following nodes:
1. **intent_router** - Entry point, determines processing path
2. **prepare_initial_messages** - Formats chat history for LLM
3. **find_candidate_tasks** - Semantic search for relevant tasks
4. **agent** - Full LLM processing for complex requests
5. **specialized_agent** - Lightweight LLM for delete/toggle operations
6. **final_response** - Assembles the API response

Conditional routing ensures requests follow the most efficient path based on detected intent.

## 8. Performance Characteristics

*   **Simple Creation Commands:** <100ms response time (no API calls)
*   **Delete/Toggle Commands:** ~200-500ms (one embedding + one LLM call)
*   **Complex Requests:** ~500-2000ms (full LLM processing)
*   **Cost Reduction:** ~20-30% of requests handled without OpenAI API calls 