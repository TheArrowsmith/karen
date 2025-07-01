import Foundation

// Represents the "what" - the core to-do item
struct Task: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var description: String?
    var is_completed: Bool = false
    var priority: Priority?
    var creation_date: Date = Date()
    var deadline: Date?
    var predicted_duration_in_minutes: Int?
}

// The Priority Enum for Tasks
enum Priority: String, Codable, Hashable {
    case low, medium, high
}

// Represents the "when" - a scheduled work session for a Task
struct TimeBlock: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var task_id: String
    var start_time: Date
    var actual_duration_in_minutes: Int
}

// Represents the full state of the application for the UI to render
struct AppState: Codable {
    var tasks: [Task]
    var timeBlocks: [TimeBlock]
    var chatHistory: [ChatMessage]
}

// Represents a single message in the chat history
struct ChatMessage: Identifiable, Codable, Hashable {
    let id = UUID()
    let text: String
    let sender: Sender
    var isLoading: Bool = false

    enum Sender: String, Codable {
        case user, bot
    }
} 