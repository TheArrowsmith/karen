import Foundation

// The request body we send to the server
struct ChatRequest: Codable {
    let tasks: [Task]
    let timeBlocks: [TimeBlock]
    let chatHistory: [ChatMessage]
    
    // Python server expects camelCase, not snake_case
    private enum CodingKeys: String, CodingKey {
        case tasks
        case timeBlocks
        case chatHistory  // Keep as camelCase to match Python
    }
}

// The response body we receive from the server
struct ChatResponse: Decodable {
    let chat_response: String
    let actions: [APIAction]
}

// Represents a single action from the API.
// We need custom decoding to handle different payload types.
struct APIAction: Decodable {
    let type: ActionType
    let payload: ActionPayload

    enum ActionType: String, Decodable {
        case createTask
        case deleteTask
        case updateTask
        case toggleTaskCompletion
        case createTimeBlock
        case updateTimeBlock
        case deleteTimeBlock
    }

    // We use a custom initializer to decode the correct payload based on the `type`
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ActionType.self, forKey: .type)

        switch self.type {
        case .createTask:
            // The API wraps the task in a "task" object
            let taskContainer = try container.nestedContainer(keyedBy: TaskCodingKeys.self, forKey: .payload)
            let task = try taskContainer.decode(Task.self, forKey: .task)
            self.payload = .create(task)
        case .deleteTask:
            self.payload = .delete(try container.decode(IDPayload.self, forKey: .payload))
        case .updateTask:
            self.payload = .update(try container.decode(UpdateTaskPayload.self, forKey: .payload))
        case .toggleTaskCompletion:
            self.payload = .toggle(try container.decode(IDPayload.self, forKey: .payload))
        case .createTimeBlock:
            self.payload = .createTimeBlock(try container.decode(CreateTimeBlockPayload.self, forKey: .payload))
        case .updateTimeBlock:
            self.payload = .updateTimeBlock(try container.decode(UpdateTimeBlockPayload.self, forKey: .payload))
        case .deleteTimeBlock:
            self.payload = .deleteTimeBlock(try container.decode(IDPayload.self, forKey: .payload))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "action_type"  // API uses "action_type" not "type"
        case payload
    }
    
    private enum TaskCodingKeys: String, CodingKey {
        case task
    }
}

// An enum to hold the different payload structures in a type-safe way
enum ActionPayload {
    case create(Task)
    case delete(IDPayload)
    case update(UpdateTaskPayload)
    case toggle(IDPayload)
    case createTimeBlock(CreateTimeBlockPayload)
    case updateTimeBlock(UpdateTimeBlockPayload)
    case deleteTimeBlock(IDPayload)
}

// Payloads for actions that only need an ID
struct IDPayload: Decodable {
    let id: String
}

// Payload for the updateTask action
struct UpdateTaskPayload: Decodable {
    let id: String
    let updatedTask: Task
}

// Payload for the createTimeBlock action
struct CreateTimeBlockPayload: Decodable {
    let task_id: String
    let start_time: Date
    let duration_in_minutes: Int
}

// Payload for the updateTimeBlock action
struct UpdateTimeBlockPayload: Decodable {
    let id: String
    let new_start_time: Date
    let new_duration_in_minutes: Int
} 