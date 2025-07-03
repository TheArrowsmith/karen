### LLM IMPLEMENTATION INSTRUCTIONS

**High-Level Goal:**

Your primary objective is to refactor the application's state management from a direct mutation model to a modern, event-driven architecture. The current approach, where views directly call methods on `StubBackend` to change data, is inflexible. We are replacing this with a central `AppStore` that manages all application state. Views will no longer modify state directly; instead, they will dispatch descriptive `AppAction`s (events) to the store. The store will then process these actions, update the state, and maintain a history.

This architectural change will achieve three key goals:
1.  Enable a global undo/redo system for most user actions.
2.  Create a single, predictable source of truth for the application's data.
3.  Handle potential race conditions between user actions and asynchronous operations (like chatbot responses) in a safe and predictable manner.

---

### Step-by-Step Implementation Plan:

#### **Step 1: Create the `AppAction` Enum**

This is the foundation of our event-driven system. It defines every possible change that can occur.

1.  Create a new file named `karen/AppAction.swift`.
2.  Add the following code to this new file. Note how `update` and `delete` actions store the `oldValue` or original object, which is essential for the undo functionality.

```swift
// In karen/AppAction.swift

import Foundation

// Defines all possible state-mutating actions in the app.
enum AppAction {
    // Task Actions
    case updateTask(oldValue: Task, newValue: Task)
    case reorderTasks(from: IndexSet, to: Int)

    // TimeBlock Actions
    case updateTimeBlock(oldValue: TimeBlock, newValue: TimeBlock)
    
    // Chat Actions (Non-undoable)
    case sendChatMessage(ChatMessage)
    case receiveChatMessage(ChatMessage)
    case showChatbotError(String)
}
```

#### **Step 2: Create the `AppStore` and Replace `StubBackend`**

The `AppStore` is the new brain of the application. It will hold the state, process actions, and manage the undo/redo history.

1.  Rename the file `karen/StubBackend.swift` to `karen/AppStore.swift`.
2.  Replace the entire content of the newly renamed `AppStore.swift` with the following code. This new class is comprehensive and includes all logic for state management, undo/redo, saving/loading, and handling inconsistencies.

```swift
// In karen/AppStore.swift

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
    
    // The main entry point for all state changes
    func dispatch(_ action: AppAction) {
        // For undoable actions, add to undo stack and clear redo stack
        if isUndoable(action) {
            // Before applying, capture the inverse for reordering
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
            self.dispatch(.receiveChatMessage(loadingMessage))
            
            // Simulate network delay and chatbot logic
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.state.chatHistory.removeAll { $0.isLoading }
                let response = ChatMessage(text: "I've received your message: '\(message.text)'. My logic is not fully implemented yet.", sender: .bot)
                self.dispatch(.receiveChatMessage(response))
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
```

#### **Step 3: Update Data Models with Sample Data**

To make initialization easier, add a static function to `AppState` to generate sample data.

1.  Open `karen/Models.swift`.
2.  At the end of the file, add the following extension to the `AppState` struct:

```swift
// In karen/Models.swift

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
```

#### **Step 4: Refactor `ContentView` to Use the `AppStore`**

This is where we connect our new architecture to the main UI.

1.  Open `karen/ContentView.swift`.
2.  Replace the entire contents of the file with the following. This code initializes the `AppStore`, passes dispatch closures to the child views, adds the undo/redo commands, and adds the alert modifier.

```swift
// In karen/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var store: AppStore

    init() {
        // Initialize the store by loading previous state or sample data
        _store = StateObject(wrappedValue: AppStore(initialState: AppStore.load()))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Panel 1: Task List (Left)
            TaskListView(
                tasks: store.state.tasks,
                onToggleComplete: { taskId in
                    guard let task = store.state.tasks.first(where: { $0.id == taskId }) else { return }
                    var updatedTask = task
                    updatedTask.is_completed.toggle()
                    store.dispatch(.updateTask(oldValue: task, newValue: updatedTask))
                },
                onReorderTasks: { from, to in
                    store.dispatch(.reorderTasks(from: from, to: to))
                }
            )
            .frame(width: 320)
            
            Divider()

            // Panel 2: Chat (Center)
            ChatView(
                messages: store.state.chatHistory, // Pass read-only array
                onSendMessage: { text in
                    store.dispatch(.sendChatMessage(ChatMessage(text: text, sender: .user)))
                }
            )
            .frame(minWidth: 400)
            
            Divider()

            // Panel 3: Daily Schedule (Right)
            DailyScheduleView(
                timeBlocks: store.state.timeBlocks, // Pass read-only array
                tasks: store.state.tasks,
                onUpdateBlock: { blockId, newStartTime, newDuration in
                    guard let block = store.state.timeBlocks.first(where: { $0.id == blockId }) else { return }
                    var updatedBlock = block
                    updatedBlock.start_time = newStartTime
                    updatedBlock.actual_duration_in_minutes = newDuration
                    store.dispatch(.updateTimeBlock(oldValue: block, newValue: updatedBlock))
                }
            )
            .frame(width: 320)
        }
        .frame(minHeight: 600)
        .commands {
            UndoCommands(
                undo: store.canUndo ? store.undo : nil,
                redo: store.canRedo ? store.redo : nil
            )
        }
        .alert("Action Incomplete", isPresented: $store.showAlert, presenting: store.alertMessage) { _ in
            // Default "OK" button is fine
        } message: { message in
            Text(message)
        }
    }
}

// Helper for Undo/Redo menu items and keyboard shortcuts
struct UndoCommands: View {
    let undo: (() -> Void)?
    let redo: (() -> Void)?
    
    var body: some View {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo", action: undo ?? {})
                .keyboardShortcut("z", modifiers: .command)
                .disabled(undo == nil)
            
            Button("Redo", action: redo ?? {})
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(redo == nil)
        }
    }
}


#Preview {
    ContentView()
}
```
**Important Correction:** Because the `init()` of `ContentView` now loads data, the `#Preview` macro will fail. Replace `#Preview { ContentView() }` with a version that works with the new `AppStore`.
```swift
#Preview {
    ContentView()
        .environmentObject(AppStore(initialState: AppState.sampleData()))
}
```
And modify the `ContentView` `init` to be injectable for the preview.
Replace:
```swift
init() {
    // Initialize the store by loading previous state or sample data
    _store = StateObject(wrappedValue: AppStore(initialState: AppStore.load()))
}
```
With:
```swift
@EnvironmentObject var store: AppStore
// The init() is no longer needed
```
And modify the `karenApp.swift` to inject the store.

#### **Step 5: Refactor `ChatView` and `DailyScheduleView`**

These views need to be updated to no longer use Bindings for their data source, as the state is now read-only from their perspective.

1.  **In `karen/ChatView.swift`:**
    *   Change the `messages` property from a `@Binding` to a `let` constant.
    *   Replace `@Binding var messages: [ChatMessage]` with `let messages: [ChatMessage]`.

2.  **In `karen/DailyScheduleView.swift`:**
    *   Change the `timeBlocks` property in `DailyScheduleView` from a `@Binding` to a `let` constant.
    *   Replace `@Binding var timeBlocks: [TimeBlock]` with `let timeBlocks: [TimeBlock]`.
    *   Now, update `TimeBlockView` to manage drag state locally. Replace its properties section with the following. This adds local `@State` for drag/resize feedback and removes the bindings.
    ```swift
    // In TimeBlockView struct
    let block: TimeBlock // No longer a binding
    let allBlocks: [TimeBlock] // No longer a binding
    let taskTitle: String
    let hourHeight: CGFloat
    let onUpdate: (String, Date, Int) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var resizeOffset: CGFloat = 0
    @State private var isResizing = false
    @State private var resizingEdge: ResizeEdge? = nil
    @State private var hoveredEdge: ResizeEdge? = nil
    ```
    *   In `DailyScheduleView`, update the `ForEach` loop to pass the non-binding `block` to `TimeBlockView`.
    *   Change `ForEach($timeBlocks)` to `ForEach(timeBlocks)`.
    *   Change `TimeBlockView(block: $block, ...)` to `TimeBlockView(block: block, ...)`.

#### **Step 6: Update the App Entry Point for State Persistence**

Finally, modify the main app file to handle saving state when the app goes into the background and to provide the `AppStore` to the `ContentView`.

1.  Open `karen/karenApp.swift`.
2.  Replace the entire content of the file with the following:

```swift
// In karen/karenApp.swift

import SwiftUI

@main
struct karenApp: App {
    @StateObject private var store = AppStore(initialState: AppStore.load())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                store.save()
            }
        }
    }
}
```

---

### Summary of Modified Files

The following existing files will be modified:

*   `karen/ContentView.swift`
*   `karen/ChatView.swift`
*   `karen/DailyScheduleView.swift`
*   `karen/karenApp.swift`
*   `karen/Models.swift`

The following file will be renamed and its contents replaced:

*   `karen/StubBackend.swift` will become `karen/AppStore.swift`.
