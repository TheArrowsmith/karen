import Foundation
import Combine

// Type alias to avoid conflict with our custom Task model
typealias AsyncTask = _Concurrency.Task

@MainActor
class AppStore: ObservableObject {
    @Published private(set) var state: AppState
    @Published var chatLoadingState: ChatLoadingState = .idle // NEW
    @Published var showClearChatConfirm = false
    
    // Properties for Undo/Redo
    private var undoStack: [AppAction] = []
    private var redoStack: [AppAction] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // Properties for showing alerts on inconsistency
    @Published var showAlert: Bool = false
    @Published var alertMessage: String?
    
    private let apiService = APIService() // NEW
    
    // NEW enum to manage UI state for chat
    enum ChatLoadingState {
        case idle
        case loading
        case error(error: APIError, onRetry: () async -> Void)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }

    init(initialState: AppState) {
        self.state = initialState
    }
    
    // The main entry point now takes an Intent
    func dispatch(_ intent: AppIntent, isFromAPI: Bool = false) {
        // Translate the Intent into a fully-hydrated Action
        switch intent {
        // --- Task Intents ---
        case .createTask(let task):
            // For add, the index is usually 0 (prepended)
            if isFromAPI {
                print("Creating task from API with ID: \(task.id), title: \(task.title)")
            }
            let action = AppAction.addTask(task: task, index: 0)
            applyAndRecord(action)

        case .deleteTask(let id):
            guard let index = state.tasks.firstIndex(where: { $0.id == id }) else {
                if isFromAPI {
                    print("Failed to find task with ID: \(id)")
                    print("Current task IDs: \(state.tasks.map { $0.id })")
                    let errorMessage = "Sorry, I couldn't find the task you mentioned. It might have been changed or deleted."
                    apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                } else {
                    triggerInconsistencyAlert(for: "task with ID \(id)")
                }
                return
            }
            let taskToDelete = state.tasks[index]
            let action = AppAction.deleteTask(task: taskToDelete, index: index)
            applyAndRecord(action)

        case .toggleTaskCompletion(let id):
            guard let index = state.tasks.firstIndex(where: { $0.id == id }) else {
                if isFromAPI {
                    let errorMessage = "Sorry, I couldn't find the task you mentioned. It might have been changed or deleted."
                    apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                } else {
                    triggerInconsistencyAlert(for: "task with ID \(id)")
                }
                return
            }
            let oldTask = state.tasks[index]
            var newTask = oldTask
            newTask.is_completed.toggle()
            let action = AppAction.updateTask(oldValue: oldTask, newValue: newTask)
            applyAndRecord(action)
            
        case .updateTask(let id, let updatedTask):
             guard let oldTask = state.tasks.first(where: { $0.id == id }) else {
                if isFromAPI {
                    let errorMessage = "Sorry, I couldn't find the task you mentioned. It might have been changed or deleted."
                    apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                } else {
                    triggerInconsistencyAlert(for: "task with ID \(id)")
                }
                return
            }
            let action = AppAction.updateTask(oldValue: oldTask, newValue: updatedTask)
            applyAndRecord(action)

        case .reorderTasks(let from, let to):
            let action = AppAction.reorderTasks(from: from, to: to)
            applyAndRecord(action)

        // --- TimeBlock Intents ---
        case .updateTimeBlock(let id, let newStartTime, let newDuration):
            guard let oldBlock = state.timeBlocks.first(where: { $0.id == id }) else {
                if isFromAPI {
                    let errorMessage = "Sorry, I couldn't find the time block you mentioned."
                    apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                } else {
                    triggerInconsistencyAlert(for: "time block with ID \(id)")
                }
                return
            }
            var newBlock = oldBlock
            newBlock.start_time = newStartTime
            newBlock.actual_duration_in_minutes = newDuration
            let action = AppAction.updateTimeBlock(oldValue: oldBlock, newValue: newBlock)
            applyAndRecord(action)

        case .deleteTimeBlock(let id):
            guard let index = state.timeBlocks.firstIndex(where: { $0.id == id }) else {
                if isFromAPI {
                    let errorMessage = "Sorry, I couldn't find the time block you mentioned."
                    apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                } else {
                    triggerInconsistencyAlert(for: "time block with ID \(id)")
                }
                return
            }
            let blockToDelete = state.timeBlocks[index]
            let action = AppAction.deleteTimeBlock(timeBlock: blockToDelete, index: index)
            applyAndRecord(action)
            
        case .createTimeBlock(let taskID, let startTime, let duration):
            // Find the associated task to ensure it exists
            guard state.tasks.contains(where: { $0.id == taskID }) else {
                triggerInconsistencyAlert(for: "task with ID \(taskID)")
                return
            }
            
            let newBlock = TimeBlock(
                task_id: taskID,
                start_time: startTime,
                actual_duration_in_minutes: duration
            )
            
            // Add to the end of the timeblocks array
            let action = AppAction.addTimeBlock(timeBlock: newBlock, index: state.timeBlocks.count)
            applyAndRecord(action)

        // --- Chat Intents ---
        case .sendChatMessage(let text):
            // Get the key from UserDefaults
            guard let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !apiKey.isEmpty else {
                // This case should ideally be prevented by the UI, but as a fallback:
                let errorMessage = "API Key is not set. Please add it in Settings."
                apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                return
            }

            // Add the user's message to the history immediately
            let message = ChatMessage(text: text, sender: .user)
            apply(.sendChatMessage(message))

            // Create the request body *before* the async task
            let requestBody = ChatRequest(
                tasks: state.tasks,
                timeBlocks: state.timeBlocks,
                chatHistory: state.chatHistory
            )

            // Define the task to be executed
            let task = { [weak self] in
                guard let self else { return }
                await self.handleSend(requestBody: requestBody, apiKey: apiKey)
            }

            // Set loading state and kick off the task
            chatLoadingState = .loading
            AsyncTask {
                await task()
            }
            
        case .retryLastChatMessage:
            if case .error(_, let onRetry) = chatLoadingState {
                chatLoadingState = .loading
                AsyncTask {
                    await onRetry()
                }
            }
            
        case .requestClearChatHistory:
            showClearChatConfirm = true
            
        case .confirmClearChatHistory:
            apply(.clearChatHistory)
            showClearChatConfirm = false
        }
    }
    
    private func applyAndRecord(_ action: AppAction) {
        if isUndoable(action) {
            let undoAction = createUndoAction(for: action)
            undoStack.append(undoAction)
            redoStack.removeAll()
        }
        apply(action)
    }
    
    func undo() {
        guard let action = undoStack.popLast() else { return }
        redoStack.append(createUndoAction(for: action))
        apply(action) // Apply the inverse action
    }
    
    func redo() {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(createUndoAction(for: action))
        apply(action) // Re-apply the original action
    }
    
    // Add this new private method to AppStore
    private func handleSend(requestBody: ChatRequest, apiKey: String) async {
        let result = await apiService.send(requestBody: requestBody, apiKey: apiKey)
        
        switch result {
        case .success(let response):
            self.chatLoadingState = .idle
            
            print("API Response received with \(response.actions.count) actions")
            
            // Add the bot's response message
            let botMessage = ChatMessage(text: response.chat_response, sender: .bot)
            self.apply(.receiveChatMessage(botMessage))
            
            // Sequentially apply all actions from the server
            for apiAction in response.actions {
                print("Processing API action: \(apiAction.type)")
                if let intent = mapToAction(apiAction) {
                    print("Mapped to intent: \(intent)")
                    self.dispatch(intent, isFromAPI: true)
                } else {
                    let errorMessage = "Sorry, I received an action I couldn't understand."
                    self.apply(.receiveChatMessage(ChatMessage(text: errorMessage, sender: .bot)))
                }
            }
            
        case .failure(let error):
            // On failure, set the error state and provide a retry closure
            self.chatLoadingState = .error(error: error) {
                // The retry action re-triggers this same function, passing the key again
                await self.handleSend(requestBody: requestBody, apiKey: apiKey)
            }
        }
    }
    
    // Add this new private method to AppStore
    private func mapToAction(_ apiAction: APIAction) -> AppIntent? {
        switch apiAction.payload {
        case .create(let task):
            return .createTask(task)
        case .delete(let payload):
            return .deleteTask(id: payload.id)
        case .toggle(let payload):
            return .toggleTaskCompletion(id: payload.id)
        case .update(let payload):
            return .updateTask(id: payload.id, updatedTask: payload.updatedTask)
        case .createTimeBlock(let payload):
            return .createTimeBlock(taskID: payload.task_id, startTime: payload.start_time, duration: payload.duration_in_minutes)
        case .updateTimeBlock(let payload):
            return .updateTimeBlock(id: payload.id, newStartTime: payload.new_start_time, newDuration: payload.new_duration_in_minutes)
        case .deleteTimeBlock(let payload):
            return .deleteTimeBlock(id: payload.id)
        }
    }

    // `apply` performs the action
    private func apply(_ action: AppAction) {
        switch action {
        case .addTask(let task, let index):
            state.tasks.insert(task, at: index)
            
        case .deleteTask(_, let index):
            // Ensure the index is valid before trying to remove
            guard state.tasks.indices.contains(index) else {
                // This shouldn't happen if dispatch is working correctly
                print("Warning: Attempted to delete task at invalid index \(index)")
                return
            }
            state.tasks.remove(at: index)
            
        case .updateTask(_, let newValue):
            guard let index = state.tasks.firstIndex(where: { $0.id == newValue.id }) else {
                // This shouldn't happen if dispatch is working correctly
                print("Warning: Attempted to update non-existent task with ID \(newValue.id)")
                return
            }
            state.tasks[index] = newValue
            
        case .reorderTasks(let from, let to):
            state.tasks.move(fromOffsets: from, toOffset: to)
        
        case .updateTimeBlock(_, let newValue):
            guard let index = state.timeBlocks.firstIndex(where: { $0.id == newValue.id }) else {
                // This shouldn't happen if dispatch is working correctly
                print("Warning: Attempted to update non-existent time block with ID \(newValue.id)")
                return
            }
            state.timeBlocks[index] = newValue
        
        case .deleteTimeBlock(_, let index):
            // Ensure the index is valid before trying to remove
            guard state.timeBlocks.indices.contains(index) else {
                // This shouldn't happen if dispatch is working correctly
                print("Warning: Attempted to delete time block at invalid index \(index)")
                return
            }
            state.timeBlocks.remove(at: index)
        
        case .addTimeBlock(let timeBlock, let index):
            state.timeBlocks.insert(timeBlock, at: index)
        
        // --- Non-undoable Chat Actions ---
        case .sendChatMessage(let message):
            state.chatHistory.append(message)
            
        case .receiveChatMessage(let message):
            state.chatHistory.append(message)
            
        case .showChatbotError(let errorMessage):
            state.chatHistory.append(ChatMessage(text: errorMessage, sender: .bot))
            
        case .clearChatHistory:
            state.chatHistory.removeAll()
            // Add the initial welcome message back so the UI isn't empty
            state.chatHistory.append(ChatMessage(text: "Hello! How can I help you plan your day?", sender: .bot))
        }
    }
    
    // --- Helpers ---
    private func createUndoAction(for action: AppAction) -> AppAction {
        switch action {
        case .addTask(let task, let index):
            return .deleteTask(task: task, index: index)
            
        case .deleteTask(let task, let index):
            return .addTask(task: task, index: index)
            
        case .updateTask(let oldValue, let newValue):
            return .updateTask(oldValue: newValue, newValue: oldValue)
        case .reorderTasks(let from, let to):
            // The inverse of a move
            var source = IndexSet()
            if to > from.first! {
                 source.insert(to - 1)
                 return .reorderTasks(from: source, to: from.first!)
            } else {
                 source.insert(to)
                 return .reorderTasks(from: source, to: from.first! + 1)
            }
        case .updateTimeBlock(let oldValue, let newValue):
            return .updateTimeBlock(oldValue: newValue, newValue: oldValue)
        case .deleteTimeBlock(let timeBlock, let index):
            return .addTimeBlock(timeBlock: timeBlock, index: index)
        case .addTimeBlock(let timeBlock, let index):
            return .deleteTimeBlock(timeBlock: timeBlock, index: index)
        default:
            return action // Should not happen for undoable actions
        }
    }
    
    private func isUndoable(_ action: AppAction) -> Bool {
        switch action {
        case .sendChatMessage, .receiveChatMessage, .showChatbotError, .clearChatHistory:
            return false
        default:
            return true
        }
    }
    
    private func triggerInconsistencyAlert(for objectType: String) {
        self.alertMessage = "An automated action could not be completed because the related \(objectType) was modified or deleted."
        self.showAlert = true
    }
    
    // --- State Persistence ---
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("karen_appstate.json")
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(state)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        } catch {
            print("Error saving state: \(error.localizedDescription)")
        }
    }

    static func load() -> AppState {
        do {
            let fileURL = try fileURL()
            let data = try Data(contentsOf: fileURL)
            let appState = try JSONDecoder().decode(AppState.self, from: data)
            return appState
        } catch {
            print("Could not load state, using sample data. Error: \(error.localizedDescription)")
            return AppState.sampleData()
        }
    }
} 
