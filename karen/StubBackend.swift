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
    
    // Function to reorder tasks
    func reorderTasks(from source: IndexSet, to destination: Int) {
        appState.tasks.move(fromOffsets: source, toOffset: destination)
    }
    
    // --- Sample Data Generation ---
    static func generateSampleTasks() -> [Task] {
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