# PRD: Chatbot Backend Integration

## 1. Introduction/Overview

### The Problem
The current chatbot in the "Karen" macOS app is a non-functional placeholder. It provides hard-coded, generic responses and cannot perform any real actions. This prevents users from interacting with the app in a natural, conversational way.

### The Goal
This feature will replace the placeholder logic with a live integration to a backend AI service. The goal is to make the chatbot intelligent, allowing it to understand user requests (like "add a new task" or "mark this as complete") and translate them into actions within the app, making the application truly interactive and conversational.

## 2. Goals

*   Connect the Swift application to the existing backend API endpoint.
*   Send the current app state (tasks and chat history) to the API with each new user message.
*   Process the API's response to update the chat history and execute state changes (e.g., creating, updating, or deleting tasks).
*   Implement a clear loading state in the UI so the user knows their request is being processed.
*   Implement robust error handling for network failures (e.g., no internet connection) and logical failures (e.g., the API returns an invalid action).

## 3. User Stories

*   **As a user,** I want to type "add a task to call the dentist" into the chat and see a new task "Call the dentist" appear in my task list, so I can manage my to-do list through conversation.
*   **As a user,** when I send a message to the chatbot, I want to see a loading indicator so I know the app is working on my request, and I want to be able to type my next message while I wait.
*   **As a user,** if I send a message while I'm offline, I want to see a clear error message in the chat area and be given a button to try sending the message again once I'm back online.
*   **As a user,** if I ask the chatbot to do something impossible, like "delete the task that I already deleted," I want the bot to respond with a message explaining it couldn't perform the action, so I'm not left confused.

## 4. Functional Requirements

### FR1: Triggering the API Call
When the user sends a message in the `ChatView`, the system must trigger a network request instead of the current hard-coded logic. This will be managed within the `AppStore`'s `dispatch` function for the `.sendChatMessage` intent.

### FR2: Constructing the Request
The system must send a `POST` request to `http://127.0.0.1:8000/api/chat` with a JSON body.
*   The JSON body must contain two top-level keys:
    *   `tasks`: An array of all current `Task` objects in the app's state. All fields of the Swift `Task` model should be included.
    *   `chatHistory`: An array of all current `ChatMessage` objects.

### FR3: Handling the Loading UI State
While the network request is in-flight:
*   An existing `LoadingIndicator` view must appear in the chat history immediately after the user's message.
*   The chat input field in `ChatInputView` must remain enabled, allowing the user to type their next message.
*   The "Send" button must be **disabled** to prevent sending a new message while one is already being processed.

### FR4: Parsing the API Response
The system must be ableto parse a successful JSON response from the API. The expected structure is:
*   `chat_response`: A string containing the bot's text response.
*   `actions`: An array of action objects. Each action object will have:
    *   `type`: A string identifying the action (e.g., `"createTask"`, `"deleteTask"`).
    *   `payload`: An object containing the data for that action.

    *Example `actions` array:*
    ```json
    "actions": [
      {
        "type": "createTask",
        "payload": { "id": "uuid-123", "title": "Call the plumber", ... }
      },
      {
        "type": "deleteTask",
        "payload": { "id": "uuid-456" }
      }
    ]
    ```

### FR5: Handling a Successful Response
Upon receiving a successful response (HTTP 200):
1.  The `LoadingIndicator` must be removed from the UI.
2.  The "Send" button must be re-enabled.
3.  A new `ChatMessage` from the `bot` must be added to the chat history, using the text from the `chat_response` field.
4.  The system must iterate through the `actions` array **sequentially** and dispatch the corresponding `AppIntent` for each action. The mapping should be:
    *   `"createTask"` -> `.createTask(Task)`
    *   `"deleteTask"` -> `.deleteTask(id: String)`
    *   `"updateTask"` -> `.updateTask(id: String, updatedTask: Task)`
    *   `"toggleTaskCompletion"` -> `.toggleTaskCompletion(id: String)`

### FR6: Handling Network Errors
If the network request fails (e.g., no internet, server is down, HTTP 500 error):
1.  The `LoadingIndicator` must be removed from the UI.
2.  The "Send" button must be re-enabled.
3.  A custom error view must be displayed in the chat area where the bot's response would have been. This view is **not a standard chat bubble** and must contain:
    *   An error message in red text (e.g., "Connection Error. Please try again.").
    *   A "Tap to Retry" button.

### FR7: Implementing Retry Logic
When the user taps the "Tap to Retry" button, the system must re-send the exact same network request that previously failed.

### FR8: Handling Client-Side Action Failures
If the API returns a valid action that the app cannot execute (e.g., an instruction to delete a task with an ID that doesn't exist in the client's state), the system must **not** show a system alert. Instead, it must programmatically add a new `ChatMessage` from the bot to the chat history, explaining the issue (e.g., "Sorry, I couldn't find the task you mentioned. It might have been changed or deleted.").

## 5. Non-Goals (Out of Scope)

*   **No Backend Development:** This task only involves the Swift client. The backend server is considered complete and functional as-is.
*   **No Time Block Actions:** The system will not be required to process any actions related to `TimeBlock`s, even if the API were to send them.
*   **No Concurrent Requests:** The UI will prevent the user from sending a new message until the previous one has finished (either with success or failure).
*   **No Changes to Undo/Redo:** The new actions dispatched via the API should integrate with the existing `UndoManager`-based system without requiring changes to it.

## 6. Design Considerations

*   The `LoadingIndicator` component already exists in `ChatView.swift` and should be reused.
*   A new SwiftUI view needs to be created for the network error state (red text + retry button). This view will be dynamically inserted into the `ChatView`'s message list.
*   All new UI elements (loading indicator, error view, bot responses) should appear within the main scrollable chat area.

## 7. Technical Considerations

*   **Networking Layer:** A dedicated `APIService` class should be created to encapsulate all `URLSession` logic. This keeps the `AppStore` clean and focused on state management.
*   **Data Modeling:** Use Swift's `Codable` protocol to define structs that match the JSON request and response bodies for type-safe parsing.
*   **State Management:** All networking triggers and state updates should be orchestrated from the `AppStore` class to maintain a single source of truth.
*   **URL:** The backend URL can be hard-coded for now: `http://127.0.0.1:8000/api/chat`.
