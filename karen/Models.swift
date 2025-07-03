import Foundation

// Represents the "what" - the core to-do item
struct Task: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String?
    var is_completed: Bool = false
    var priority: Priority?
    var creation_date: Date = Date()
    var deadline: Date?
    
    // Custom initializer that accepts an optional ID
    init(
        id: String? = nil,
        title: String,
        description: String? = nil,
        is_completed: Bool = false,
        priority: Priority? = nil,
        creation_date: Date = Date(),
        deadline: Date? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.title = title
        self.description = description
        self.is_completed = is_completed
        self.priority = priority
        self.creation_date = creation_date
        self.deadline = deadline
    }
    
    // Custom coding keys to match Python field names
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case is_completed
        case priority
        case creation_date
        case deadline
    }
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
    
    // Custom coding keys to match Python field names (already using snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case task_id
        case start_time
        case actual_duration_in_minutes
    }
}

// Represents the full state of the application for the UI to render
struct AppState: Codable {
    var tasks: [Task]
    var timeBlocks: [TimeBlock]
    var chatHistory: [ChatMessage]
}

// Represents a single message in the chat history
struct ChatMessage: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let sender: Sender
    var isLoading: Bool = false

    enum Sender: String, Codable {
        case user, bot
    }
    
    init(text: String, sender: Sender, isLoading: Bool = false) {
        self.id = UUID().uuidString
        self.text = text
        self.sender = sender
        self.isLoading = isLoading
    }
    
    // Custom encoding to exclude isLoading from API requests
    enum CodingKeys: String, CodingKey {
        case id, text, sender
    }
}

extension AppState {
    static func sampleData() -> AppState {
        let tasks = [
             Task(id: "1", title: "Review quarterly reports", description: "Analyze Q3 performance metrics.", is_completed: false, priority: .high, deadline: Date().addingTimeInterval(86400*2)),
             Task(id: "2", title: "Update project documentation", is_completed: false, priority: .medium, deadline: Date().addingTimeInterval(86400*5)),
             Task(id: "3", title: "Code review for new feature", description: "Review pull request #247.", is_completed: false, priority: .high, deadline: Date().addingTimeInterval(-86400))
        ]
        
        let today = Calendar.current.startOfDay(for: Date())
        let timeBlocks = [
            TimeBlock(task_id: tasks[0].id, start_time: today.addingTimeInterval(3600*9), actual_duration_in_minutes: 90),
            TimeBlock(task_id: tasks[1].id, start_time: today.addingTimeInterval(3600*11), actual_duration_in_minutes: 45),
            TimeBlock(task_id: tasks[2].id, start_time: today.addingTimeInterval(3600*14), actual_duration_in_minutes: 60)
        ]
        
        return AppState(
            tasks: tasks,
            timeBlocks: timeBlocks,
            chatHistory: [ChatMessage(text: "Hello! How can I help you plan your day?", sender: .bot)]
        )
    }
} 