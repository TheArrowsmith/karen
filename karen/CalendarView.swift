import SwiftUI

enum CalendarViewMode {
    case daily, weekly
}

struct CalendarView: View {
    // These are transient UI states, not part of the global AppState
    @State private var viewMode: CalendarViewMode = .daily
    @State private var currentDate: Date = Date()
    
    // Passed in from ContentView
    let timeBlocks: [TimeBlock]
    let tasks: [Task]

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                viewMode: $viewMode,
                currentDate: $currentDate
            )
            
            // The main grid area
            if viewMode == .daily {
                DailyView(date: currentDate, timeBlocks: timeBlocks, tasks: tasks)
            } else {
                WeeklyView(date: currentDate, timeBlocks: timeBlocks, tasks: tasks)
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
}

// Custom Notification for keyboard shortcuts
extension Notification.Name {
    static let navigateCalendar = Notification.Name("navigateCalendar")
}

enum CalendarNavigationDirection {
    case next, previous, today
}

