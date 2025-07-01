### **LLM Implementation Instructions: Interactive Desktop Task App UI**

**High-Level Goal**

Your primary goal is to build the complete user interface for a native macOS desktop application using SwiftUI. The application's UI must adhere to the style and structure provided in the example components.

The layout will consist of three main panels: a **Task List** on the left, the main **Chat View** in the center, and an **interactive Daily Schedule** on the right. The Daily Schedule must be a dynamic, calendar-style view where users can visually rearrange and resize their scheduled work sessions using drag-and-drop gestures.

To facilitate this, you will create and integrate a local **stubbed backend**. This stub will manage the application's state (tasks and scheduled time blocks) in memory and provide functions for the UI to call after user interactions, such as sending a chat message or rescheduling a time block.

**Step-by-Step Instructions**

**Step 1: Define the Core Data Models**

First, define the data structures that the entire application will use. These models are the source of truth for all data displayed in the UI.

Create a new Swift file named `Models.swift`. Add the following code:

```swift
// In Models.swift

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
```

**Step 2: Create the Enhanced Stub Backend**

Next, create the temporary backend. It will now manage both tasks and time blocks and expose a new function to handle updates from the interactive schedule.

Create a new Swift file named `StubBackend.swift`. Add the following code. This class will contain sample data so the UI looks populated on launch.

```swift
// In StubBackend.swift

import Foundation
import Combine

@MainActor
class StubBackend: ObservableObject {
    @Published var appState: AppState

    init() {
        // Initialize with sample data
        let sampleTasks = StubBackend.generateSampleTasks()
        self.appState = AppState(
            tasks: sampleTasks,
            timeBlocks: StubBackend.generateSampleTimeBlocks(for: sampleTasks),
            chatHistory: [ChatMessage(text: "Hello! How can I help you plan your day?", sender: .bot)]
        )
    }

    // Function for chat commands
    func processUserMessage(text: String) {
        let userMessage = ChatMessage(text: text, sender: .user)
        appState.chatHistory.append(userMessage)

        let loadingMessage = ChatMessage(text: "", sender: .bot, isLoading: true)
        appState.chatHistory.append(loadingMessage)

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.appState.chatHistory.removeAll { $0.isLoading }
            let botResponse = ChatMessage(text: "I've received your message: '\(text)'. My logic is not fully implemented yet.", sender: .bot)
            self.appState.chatHistory.append(botResponse)
        }
    }

    // NEW function for UI-driven updates from the schedule
    func updateTimeBlock(id: String, newStartTime: Date, newDuration: Int) {
        if let index = appState.timeBlocks.firstIndex(where: { $0.id == id }) {
            appState.timeBlocks[index].start_time = newStartTime
            appState.timeBlocks[index].actual_duration_in_minutes = newDuration
        }
    }
    
    // Function to toggle task completion status
    func toggleTaskCompleted(id: String) {
        if let index = appState.tasks.firstIndex(where: { $0.id == id }) {
            appState.tasks[index].is_completed.toggle()
        }
    }
    
    // --- Sample Data Generation ---
    static func generateSampleTasks() -> [Task] {
        // ... (Code to generate tasks similar to the TaskListView example)
        // For brevity, you can adapt the defaultTasks array from the example.
        // Ensure you use our `Task` model, not the example's.
        return [
             Task(id: "1", title: "Review quarterly reports", description: "Analyze Q3 performance metrics.", is_completed: false, priority: .high, deadline: Date().addingTimeInterval(86400*2), predicted_duration_in_minutes: 120),
             Task(id: "2", title: "Update project documentation", is_completed: false, priority: .medium, deadline: Date().addingTimeInterval(86400*5), predicted_duration_in_minutes: 45),
             Task(id: "3", title: "Code review for new feature", description: "Review pull request #247.", is_completed: false, priority: .high, deadline: Date().addingTimeInterval(-86400), predicted_duration_in_minutes: 60)
        ]
    }
    
    static func generateSampleTimeBlocks(for tasks: [Task]) -> [TimeBlock] {
        guard !tasks.isEmpty else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        return [
            TimeBlock(task_id: tasks[0].id, start_time: today.addingTimeInterval(3600*9), actual_duration_in_minutes: 90), // 9:00 AM for 1.5h
            TimeBlock(task_id: tasks[1].id, start_time: today.addingTimeInterval(3600*11), actual_duration_in_minutes: 45), // 11:00 AM for 45m
            TimeBlock(task_id: tasks[2].id, start_time: today.addingTimeInterval(3600*14), actual_duration_in_minutes: 60) // 2:00 PM for 1h
        ]
    }
}
```

**Step 3: Create the UI Panels**

Now, create the three main panels as separate SwiftUI View files. Use the provided examples as a strong visual and structural guide.

**3a. Task List Panel (Left)**

Create a new file `TaskListView.swift`. Base its design on the provided example, but connect it to our `StubBackend` and `Task` model.

```swift
// In TaskListView.swift

import SwiftUI

struct TaskListView: View {
    let tasks: [Task]
    let onToggleComplete: (String) -> Void // Use String for ID

    // Adapt the view logic to use our `Task` model.
    // The visual structure (header, item layout) should match the example.
    
    // ... body of the view ...
}

// Example for TaskItemView adaptation
struct TaskItemView: View {
    let task: Task
    let onToggleComplete: (String) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { onToggleComplete(task.id) }) {
                 Image(systemName: task.is_completed ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.is_completed ? .blue : .gray)
            }
            // ... Rest of the view structure from the example,
            // adapting fields like task.deadline, task.priority, etc.
        }
    }
}
```

**3b. Chat Panel (Center)**

Create a new file `ChatView.swift`. Use the provided chat example as a base, but remove its internal state management and connect it to the `StubBackend`.

```swift
// In ChatView.swift

import SwiftUI

struct ChatView: View {
    @Binding var messages: [ChatMessage]
    let onSendMessage: (String) -> Void

    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header from example
            // ...
            
            // Scrollable message area
            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(messages) { message in
                        ChatBubbleView(message: message)
                    }
                }
                // ... (add auto-scrolling logic from example)
            }

            // Input area
            ChatInputView(text: $inputText, onSend: sendMessage)
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSendMessage(inputText)
        inputText = ""
    }
}

// Sub-view for the text input field
struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack {
            TextField("Type your message...", text: $text)
                .onSubmit { // Use onSubmit for Enter key submission
                    onSend()
                }
            Button("Send", action: onSend)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}

// Sub-view for a single chat bubble (adapt from example)
struct ChatBubbleView: View {
    let message: ChatMessage
    // ... adapt the view to use our ChatMessage model
}
```

**3c. Daily Schedule Panel (Right)**

This is the most complex view. Create a new file named `DailyScheduleView.swift`.

```swift
// In DailyScheduleView.swift

import SwiftUI

struct DailyScheduleView: View {
    @Binding var timeBlocks: [TimeBlock]
    let tasks: [Task] // Needed to get task titles
    let onUpdateBlock: (String, Date, Int) -> Void
    
    private let hourHeight: CGFloat = 60.0

    var body: some View {
        VStack {
            // Header from example
            // ...
            
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .top) {
                        // Background hourly grid
                        HourlyGridView(hourHeight: hourHeight)

                        // Render the interactive TimeBlock views
                        ForEach($timeBlocks) { $block in
                            TimeBlockView(
                                block: $block,
                                allBlocks: $timeBlocks,
                                taskTitle: tasks.first(where: { $0.id == block.task_id })?.title ?? "Untitled",
                                hourHeight: hourHeight,
                                onUpdate: onUpdateBlock
                            )
                        }
                    }
                }
                .onAppear { proxy.scrollTo(8, anchor: .top) } // Scroll to 8 AM
            }
        }
    }
}

// A new view for a single, draggable, and resizable time block
struct TimeBlockView: View {
    @Binding var block: TimeBlock
    @Binding var allBlocks: [TimeBlock]
    let taskTitle: String
    let hourHeight: CGFloat
    let onUpdate: (String, Date, Int) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        // ... (visual styling from the EventCard example)
        // The core logic is the gesture:
        .gesture(DragGesture()
            .onChanged { value in
                self.isDragging = true
                self.dragOffset = value.translation
            }
            .onEnded { value in
                self.isDragging = false
                let verticalTranslation = value.translation.height
                let minuteOffset = Int(verticalTranslation / hourHeight * 60)
                
                // Calculate new start time, snapped to 15 mins
                let newStartOffset = Calendar.current.dateComponents([.minute], from: block.start_time).minute! + minuteOffset
                let snappedMinute = Int(round(Double(newStartOffset) / 15.0) * 15.0)
                var newStartTime = Calendar.current.date(bySetting: .minute, value: snappedMinute, of: block.start_time)!
                // Adjust for hour changes
                newStartTime = Calendar.current.date(byAdding: .hour, value: snappedMinute / 60, to: newStartTime)!
                
                // --- Collision Detection ---
                let newEndTime = newStartTime.addingTimeInterval(TimeInterval(block.actual_duration_in_minutes * 60))
                let hasCollision = allBlocks.first { otherBlock in
                    if otherBlock.id == block.id { return false } // Don't check against self
                    let otherEndTime = otherBlock.start_time.addingTimeInterval(TimeInterval(otherBlock.actual_duration_in_minutes * 60))
                    // Check for overlap: (StartA < EndB) and (EndA > StartB)
                    return newStartTime < otherEndTime && newEndTime > otherBlock.start_time
                } != nil
                
                if !hasCollision {
                    // If no collision, call the backend to update state
                    onUpdate(block.id, newStartTime, block.actual_duration_in_minutes)
                }
                
                self.dragOffset = .zero
            }
        )
    }
}
```

**Step 4: Assemble the Main Content View**

Finally, modify the main `ContentView.swift` to assemble the three panels in the correct order and connect them to the backend.

```swift
// In ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var backend = StubBackend()

    var body: some View {
        HStack(spacing: 0) {
            // Panel 1: Task List (Left)
            TaskListView(
                tasks: backend.appState.tasks,
                onToggleComplete: backend.toggleTaskCompleted
            )
            .frame(width: 320)
            
            Divider()

            // Panel 2: Chat (Center)
            ChatView(
                messages: $backend.appState.chatHistory,
                onSendMessage: backend.processUserMessage
            )
            .frame(minWidth: 400)
            
            Divider()

            // Panel 3: Daily Schedule (Right)
            DailyScheduleView(
                timeBlocks: $backend.appState.timeBlocks,
                tasks: backend.appState.tasks,
                onUpdateBlock: backend.updateTimeBlock
            )
            .frame(width: 320)
        }
        .frame(minHeight: 600)
    }
}
```

---

**Summary of File Changes:**

**New Files to Create:**
*   `Models.swift`
*   `StubBackend.swift`
*   `TaskListView.swift`
*   `ChatView.swift`
*   `DailyScheduleView.swift`

**Existing Files to Modify:**
*   `ContentView.swift`
