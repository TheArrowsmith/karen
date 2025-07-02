import SwiftUI

struct CalendarHeaderView: View {
    @Binding var viewMode: CalendarViewMode
    @Binding var currentDate: Date

    var body: some View {
        HStack {
            // View Mode Toggle (no label)
            Picker("", selection: $viewMode) {
                Text("Daily").tag(CalendarViewMode.daily)
                Text("Weekly").tag(CalendarViewMode.weekly)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 120)

            Spacer()
            
            // Navigation Buttons
            HStack(spacing: 4) {
                Button(action: { navigate(.previous) }) { Image(systemName: "chevron.left") }
                Button(action: { navigate(.today) }) { Text("Today") }
                Button(action: { navigate(.next) }) { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func navigate(_ direction: CalendarNavigationDirection) {
        // This is a "trick" to use the same logic as the keyboard shortcuts
        NotificationCenter.default.post(name: .navigateCalendar, object: direction)
    }
} 