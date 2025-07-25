import SwiftUI

enum CalendarViewMode {
    case daily, weekly
}

struct CalendarView: View {
    @EnvironmentObject var store: AppStore // NEW
    // These are transient UI states, not part of the global AppState
    @State private var viewMode: CalendarViewMode = .weekly
    @State private var currentDate: Date = Date()
    
    // Passed in from ContentView
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    let onToggleComplete: (String) -> Void
    let onUpdateTimeBlock: (String, Date, Int) -> Void
    let onDeleteTimeBlock: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                viewMode: $viewMode,
                currentDate: $currentDate
            )
            
            // The main grid area
            if viewMode == .daily {
                DailyView(
                    date: currentDate, 
                    timeBlocks: timeBlocks, 
                    tasks: tasks, 
                    onToggleComplete: onToggleComplete, 
                    onUpdateTimeBlock: onUpdateTimeBlock,
                    onDeleteTimeBlock: onDeleteTimeBlock,
                    onDropTask: handleDrop // NEW
                )
            } else {
                WeeklyView(
                    date: currentDate, 
                    timeBlocks: timeBlocks, 
                    tasks: tasks, 
                    onToggleComplete: onToggleComplete, 
                    onUpdateTimeBlock: onUpdateTimeBlock,
                    onDeleteTimeBlock: onDeleteTimeBlock,
                    onDropTask: handleDrop // NEW
                )
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        // Listen for keyboard shortcut commands from the main app
        .onReceive(NotificationCenter.default.publisher(for: .navigateCalendar)) { notification in
            guard let direction = notification.object as? CalendarNavigationDirection else { return }
            handleNavigation(direction)
        }
    }
    
    private func handleNavigation(_ direction: CalendarNavigationDirection) {
        let calendar = Calendar.current
        let component: Calendar.Component = (viewMode == .daily) ? .day : .weekOfYear
        
        switch direction {
        case .next:
            if let newDate = calendar.date(byAdding: component, value: 1, to: currentDate) {
                currentDate = newDate
            }
        case .previous:
            if let newDate = calendar.date(byAdding: component, value: -1, to: currentDate) {
                currentDate = newDate
            }
        case .today:
            currentDate = Date()
        }
    }
    
    // NEW: Function to handle the drop action
    private func handleDrop(taskID: String, startTime: Date, duration: Int) {
        print("Handling drop for task: \(taskID), startTime: \(startTime), duration: \(duration)")
        store.dispatch(.createTimeBlock(
            taskID: taskID,
            startTime: startTime,
            duration: duration
        ))
    }
}

// Custom Notification for keyboard shortcuts
extension Notification.Name {
    static let navigateCalendar = Notification.Name("navigateCalendar")
}

enum CalendarNavigationDirection {
    case next, previous, today
}

