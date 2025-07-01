Here are several `curl` commands you can use to test the various functionalities of your server. These commands simulate different user inputs and scenarios.

You'll need to run these from your terminal while the `uvicorn` server is running.

---

### 1. Test: Creating a Simple Task

This command simulates a user asking to add a new task. The `chatHistory` only contains this one message.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "add a task to buy groceries",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
The `chat_response` should be something like "Okay, I've added a task to buy groceries." The `actions` list should contain one `createTask` action with a newly generated UUID.

---

### 2. Test: Toggling an Existing Task to Complete

This command simulates a user asking to mark an existing task as complete. Notice the task already exists in the `tasks` list.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [
    {
      "id": "task-abc-123",
      "title": "Submit quarterly report",
      "is_completed": false,
      "priority": "high",
      "creation_date": "2023-10-27T10:00:00Z"
    }
  ],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "I just finished the quarterly report",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
A confirmation message and an `actions` list with one `toggleTaskCompletion` action, referencing `id: "task-abc-123"`.

---

### 3. Test: Deleting an Existing Task

This command simulates a user asking to delete a task by referencing its title.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [
    {
      "id": "task-abc-123",
      "title": "Submit quarterly report",
      "is_completed": true
    },
    {
      "id": "task-def-456",
      "title": "Book flight to conference",
      "is_completed": false
    }
  ],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "get rid of the flight booking task",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
A confirmation message and an `actions` list with one `deleteTask` action, referencing `id: "task-def-456"`.

---

### 4. Test: Updating an Existing Task

This command simulates a user changing the priority of a task.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [
    {
      "id": "task-xyz-789",
      "title": "Draft the project proposal",
      "is_completed": false,
      "priority": "medium",
      "creation_date": "2023-10-27T11:00:00Z"
    }
  ],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "make the project proposal high priority",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
A confirmation message and an `actions` list with one `updateTask` action. The payload will contain the `id` and a complete `updatedTask` object with the `priority` field changed to `"high"`.

---

### 5. Test: Ambiguous Request (Clarification)

This command simulates a situation where the user's request could apply to multiple tasks. The bot should ask for clarification.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [
    {
      "id": "task-meet-1",
      "title": "Weekly team meeting",
      "is_completed": false
    },
    {
      "id": "task-meet-2",
      "title": "1-on-1 meeting with Sarah",
      "is_completed": false
    }
  ],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "mark the meeting as done",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
The `chat_response` should be a clarifying question like "I found a couple of tasks that match. Which one did you mean?". The `actions` list should be **empty `[]`**.

---

### 6. Test: Out-of-Scope (Nonsense) Request

This command sends a message that has nothing to do with task management.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "what is the capital of nebraska?",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
The `chat_response` should be a polite refusal, explaining the bot's capabilities. The `actions` list should be **empty `[]`**.

---

### 7. Test: Creating Multiple Tasks from One Prompt

This tests the bot's ability to extract multiple actions from a single message.

```bash
curl -X POST "http://127.0.0.1:8000/api/chat" \
-H "Content-Type: application/json" \
-d '{
  "tasks": [],
  "chatHistory": [
    {
      "id": "msg-1",
      "text": "I need to add two tasks: first, call the plumber, and second, buy a new filter",
      "sender": "user"
    }
  ]
}'
```

**Expected Response:**
A confirmation message, and an `actions` list containing **two** `createTask` actions, one for each new task.
