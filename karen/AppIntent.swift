import Foundation

// Defines all possible user-initiated commands, dispatched from the UI.
enum AppIntent {
    // Task Intents
    case createTask(Task)
    case deleteTask(id: String)
    case toggleTaskCompletion(id: String)
    case updateTask(id: String, updatedTask: Task) // Simplified for now
    case reorderTasks(from: IndexSet, to: Int)

    // TimeBlock Intents
    case updateTimeBlock(id: String, newStartTime: Date, newDuration: Int)
    case deleteTimeBlock(id: String)
    case createTimeBlock(taskID: String, startTime: Date, duration: Int) // NEW
    
    // Chat Intents
    case sendChatMessage(text: String)
    case retryLastChatMessage // NEW
    case requestClearChatHistory
    case confirmClearChatHistory
} 