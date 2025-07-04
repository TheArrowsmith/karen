# Karen - AI-Powered Task Management for macOS

Karen is a native macOS task management app that combines a clean, intuitive interface with an AI assistant to help you organize your tasks and schedule through natural conversation.

## How to use

For the app to work you need to create an env file at `backend/.env` with an OpenAI key:

```bash
# backend/.env
OPENAI_API_KEY=sk-proj-<key>
```

Then start the Python server:

```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
python -m spacy download en_core_web_sm
python main.py
```

Then open the main app in Xcode and click 'Run'


## Features

### 🎯 Smart Task Management
- **Natural Language Processing**: Create, update, and manage tasks by simply chatting with Karen
- **Intelligent Understanding**: Karen uses advanced NLP to understand context and intent from your messages
- **Drag & Drop**: Easily reorder tasks or drag them onto the calendar to schedule time blocks
- **Priority Levels**: Organize tasks with low, medium, and high priority settings
- **Deadlines**: Set due dates and times for important tasks

### 📅 Interactive Calendar
- **Daily & Weekly Views**: Switch between detailed daily and overview weekly calendar layouts
- **Time Blocking**: Schedule specific time slots for your tasks
- **Visual Scheduling**: Drag tasks from your list directly onto calendar time slots
- **Conflict Detection**: Prevents overlapping time blocks
- **Keyboard Navigation**: Use Cmd+← and Cmd+→ to navigate dates, Cmd+T to jump to today

### 🤖 AI Assistant Capabilities
Karen can understand and execute commands like:
- "Add a task to review the quarterly report"
- "Schedule the meeting prep for tomorrow at 2pm"
- "Mark the budget review as complete"
- "Delete the flight booking task"
- "Move my 3pm meeting to 4:30pm"
- "What's on my calendar today?"
- "Clear my afternoon schedule"

### 💾 Persistent & Reliable
- **Auto-save**: Your tasks and schedule are automatically saved
- **Undo/Redo**: Full support for undoing and redoing actions (Cmd+Z / Cmd+Shift+Z)
- **Stateless Backend**: The entire app state is managed locally for privacy and reliability

## Architecture

Karen uses a modern, event-driven architecture:

- **Frontend**: Native SwiftUI app with reactive state management
- **Backend**: Python FastAPI server with LangGraph for AI orchestration
- **AI Pipeline**: Multi-stage processing with intent detection, semantic search, and contextual understanding
- **Communication**: Unix domain sockets for secure, sandboxed IPC

## Usage Guide

### Getting Started
When you first launch Karen, you'll see three panels:
- **Left**: Your task list
- **Center**: Chat with Karen
- **Right**: Calendar view

### Managing Tasks
**Via Chat:**
- Type naturally to Karen about what you want to do
- Examples: "Add a task to call mom", "Delete the grocery shopping task"

**Via UI:**
- Click the "+" button to add a task manually
- Click on any task to edit its details
- Drag tasks to reorder them
- Check the checkbox to mark tasks as complete

### Scheduling Time
**Via Chat:**
- "Schedule the report writing for 2pm today"
- "Book 90 minutes tomorrow morning for deep work"

**Via Drag & Drop:**
- Drag any task from the list onto a time slot in the calendar
- Adjust time blocks by dragging their edges

### Keyboard Shortcuts
- `Cmd+Z` - Undo
- `Cmd+Shift+Z` - Redo
- `Cmd+←` - Previous day/week
- `Cmd+→` - Next day/week
- `Cmd+T` - Go to today
- `Cmd+Shift+K` - Clear chat history

## How It Works

### AI Processing Pipeline

1. **Intent Detection**: When you send a message, Karen first uses spaCy NLP to quickly identify your intent (create, delete, update, etc.)

2. **Smart Routing**: Based on the intent, your request is routed through different processing paths:
   - **Fast Track**: Simple create commands are handled locally without AI calls
   - **Semi-Fast Track**: Delete/toggle commands use semantic search + lightweight AI
   - **Full AI Track**: Complex requests go through the complete LangGraph pipeline

3. **Semantic Search**: For commands referencing existing items, Karen uses embeddings to find the most relevant tasks or calendar events

4. **Contextual Understanding**: The AI considers your full chat history and current state to provide accurate, contextual responses

### Privacy & Security
- All data is stored locally on your Mac
- The app runs in a sandbox with limited permissions
- Communication between frontend and backend uses Unix domain sockets (no network exposure)
- Your tasks and conversations never leave your machine (except for OpenAI API calls)

## Troubleshooting

### Backend won't start
- Ensure your virtual environment is activated
- Check that the OpenAI API key is correctly set in `.env`
- Verify Python 3.11+ is installed

### "Socket error" in the app
- Make sure the backend server is running
- The app and backend must be run by the same user
- Check Console.app for detailed error logs

### AI responses seem off
- Try clearing the chat history (Cmd+Shift+K) to reset context
- Ensure your OpenAI API key has sufficient credits
- Check the backend logs for any API errors

## Development

### Running Tests
```bash
cd backend
python -m pytest
```

### Project Structure
```
karen/
├── karen/              # Swift/SwiftUI frontend
│   ├── Models.swift    # Data models
│   ├── AppStore.swift  # State management
│   ├── ContentView.swift # Main UI
│   └── ...            # UI components
├── backend/           # Python backend
│   ├── main.py        # FastAPI server
│   ├── graph.py       # LangGraph workflow
│   ├── intent_router.py # NLP intent detection
│   └── models.py      # Pydantic models
└── _docs/             # Documentation
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

[Add your license information here]

## Acknowledgments

Built with:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Apple's declarative UI framework
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [LangGraph](https://github.com/langchain-ai/langgraph) - LLM application orchestration
- [OpenAI](https://openai.com/) - Language model API
- [spaCy](https://spacy.io/) - Industrial-strength NLP
