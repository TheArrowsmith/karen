import Foundation

// Defines all possible state-mutating actions in the app.
enum AppAction {
    // Task Actions
    case addTask(task: Task, index: Int)
    case deleteTask(task: Task, index: Int)
    case updateTask(oldValue: Task, newValue: Task)
    case reorderTasks(from: IndexSet, to: Int)

    // TimeBlock Actions
    case updateTimeBlock(oldValue: TimeBlock, newValue: TimeBlock)
    
    // Chat Actions (Non-undoable)
    case sendChatMessage(ChatMessage)
    case receiveChatMessage(ChatMessage)
    case showChatbotError(String)
} 