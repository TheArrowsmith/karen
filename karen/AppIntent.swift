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
    
    // Chat Intents
    case sendChatMessage(text: String)
} 