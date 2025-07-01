import Foundation
import Combine

@MainActor
class AppStore: ObservableObject {
    @Published private(set) var state: AppState
    
    // Properties for Undo/Redo
    private var undoStack: [AppAction] = []
    private var redoStack: [AppAction] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // Properties for showing alerts on inconsistency
    @Published var showAlert: Bool = false
    @Published var alertMessage: String?

    init(initialState: AppState) {
        self.state = initialState
    }
    
    // The main entry point now takes an Intent
    func dispatch(_ intent: AppIntent) {
        // Translate the Intent into a fully-hydrated Action
        switch intent {
        // --- Task Intents ---
        case .createTask(let task):
            // For add, the index is usually 0 (prepended)
            let action = AppAction.addTask(task: task, index: 0)
            applyAndRecord(action)

        case .deleteTask(let id):
            guard let index = state.tasks.firstIndex(where: { $0.id == id }) else {
                triggerInconsistencyAlert(for: "task with ID \(id)")
                return
            }
            let taskToDelete = state.tasks[index]
            let action = AppAction.deleteTask(task: taskToDelete, index: index)
            applyAndRecord(action)

        case .toggleTaskCompletion(let id):
            guard let index = state.tasks.firstIndex(where: { $0.id == id }) else {
                triggerInconsistencyAlert(for: "task with ID \(id)")
                return
            }
            let oldTask = state.tasks[index]
            var newTask = oldTask
            newTask.is_completed.toggle()
            let action = AppAction.updateTask(oldValue: oldTask, newValue: newTask)
            applyAndRecord(action)
            
        case .updateTask(let id, let updatedTask):
             guard let oldTask = state.tasks.first(where: { $0.id == id }) else {
                triggerInconsistencyAlert(for: "task with ID \(id)")
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
                triggerInconsistencyAlert(for: "time block with ID \(id)")
                return
            }
            var newBlock = oldBlock
            newBlock.start_time = newStartTime
            newBlock.actual_duration_in_minutes = newDuration
            let action = AppAction.updateTimeBlock(oldValue: oldBlock, newValue: newBlock)
            applyAndRecord(action)

        // --- Chat Intents ---
        case .sendChatMessage(let text):
            // Non-undoable actions are applied directly
            let message = ChatMessage(text: text, sender: .user)
            apply(.sendChatMessage(message))
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

    // `apply` performs the action
    private func apply(_ action: AppAction) {
        switch action {
        case .addTask(let task, let index):
            state.tasks.insert(task, at: index)
            
        case .deleteTask(_, let index):
            // Ensure the index is valid before trying to remove
            guard state.tasks.indices.contains(index) else {
                triggerInconsistencyAlert(for: "task")
                return
            }
            state.tasks.remove(at: index)
            
        case .updateTask(_, let newValue):
            guard let index = state.tasks.firstIndex(where: { $0.id == newValue.id }) else {
                triggerInconsistencyAlert(for: "task")
                return
            }
            state.tasks[index] = newValue
            
        case .reorderTasks(let from, let to):
            state.tasks.move(fromOffsets: from, toOffset: to)
        
        case .updateTimeBlock(_, let newValue):
            guard let index = state.timeBlocks.firstIndex(where: { $0.id == newValue.id }) else {
                triggerInconsistencyAlert(for: "time block")
                return
            }
            state.timeBlocks[index] = newValue
        
        // --- Non-undoable Chat Actions ---
        case .sendChatMessage(let message):
            state.chatHistory.append(message)
            let loadingMessage = ChatMessage(text: "", sender: .bot, isLoading: true)
            apply(.receiveChatMessage(loadingMessage))
            
            // Simulate network delay and chatbot logic
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.state.chatHistory.removeAll { $0.isLoading }
                let response = ChatMessage(text: "I've received your message: '\(message.text)'. My logic is not fully implemented yet.", sender: .bot)
                self.apply(.receiveChatMessage(response))
            }
            
        case .receiveChatMessage(let message):
            state.chatHistory.append(message)
            
        case .showChatbotError(let errorMessage):
            state.chatHistory.append(ChatMessage(text: errorMessage, sender: .bot))
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
        default:
            return action // Should not happen for undoable actions
        }
    }
    
    private func isUndoable(_ action: AppAction) -> Bool {
        switch action {
        case .sendChatMessage, .receiveChatMessage, .showChatbotError:
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