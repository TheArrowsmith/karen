import SwiftUI

// --- Daily View ---
struct DailyView: View {
    let date: Date
    let timeBlocks: [TimeBlock]
    let tasks: [Task]

    var body: some View {
        HStack(spacing: 0) {
            // A single column for the selected day
            DayColumnView(day: date, timeBlocks: timeBlocks, tasks: tasks, isToday: Calendar.current.isDateInToday(date))
        }
    }
}

// --- Weekly View ---
struct WeeklyView: View {
    let date: Date
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    
    private let hourHeight: CGFloat = 60.0
    
    private var weekDays: [Date] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }
        var days: [Date] = []
        for i in 0..<7 {
            if let day = Calendar.current.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(day)
            }
        }
        return days
    }
    
    private func hourText(for hour: Int) -> String {
        if hour == 0 { return "" } // Hide 12 AM to not clutter
        else if hour < 12 { return "\(hour) AM" }
        else if hour == 12 { return "12 PM" }
        else { return "\(hour - 12) PM" }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Headers for each day
            HStack(spacing: 0) {
                // Empty space above hour labels
                Color.clear
                    .frame(width: 50)
                
                ForEach(weekDays, id: \.self) { day in
                    DayHeaderView(day: day, isToday: Calendar.current.isDateInToday(day))
                    Divider()
                }
            }
            .padding(.trailing, 15) // Account for scrollbar width
            .fixedSize(horizontal: false, vertical: true) // Prevent vertical expansion
            
            Divider()
            
            // Single scrollable area for all days
            ScrollView {
                HStack(spacing: 0) {
                    // FIX: Replace the hour labels VStack to give it a fixed width
                    // and correctly align its content. This aligns the columns.
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            HStack {
                                Spacer()
                                Text(hourText(for: hour))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 5) // Keep text from hitting the divider
                            .frame(height: hourHeight)
                        }
                    }
                    .frame(width: 50) // Fix the column width to match the header spacer
                    
                    // Day columns
                    ForEach(weekDays, id: \.self) { day in
                        WeeklyDayColumnView(day: day, timeBlocks: timeBlocks, tasks: tasks, hourHeight: hourHeight)
                        Divider()
                    }
                }
            }
        }
    }
}

// --- A Single Day's Column ---
struct DayColumnView: View {
    let day: Date
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    let isToday: Bool
    
    private let hourHeight: CGFloat = 60.0

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // e.g., "Mon"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d" // e.g., "1"
        return formatter
    }

    // This computes the geometry for each block for this specific day
    private var timeBlockGeometries: [(block: TimeBlock, geometry: BlockGeometry)] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        return timeBlocks.compactMap { block -> (TimeBlock, BlockGeometry)? in
            let blockEnd = block.start_time.addingTimeInterval(TimeInterval(block.actual_duration_in_minutes * 60))
            
            // Must overlap with the current day's interval to be visible
            guard block.start_time < dayEnd && blockEnd > dayStart else {
                return nil
            }
            
            // Calculate the visible portion for *this* day
            let visibleStartTime = max(block.start_time, dayStart)
            let visibleEndTime = min(blockEnd, dayEnd)
            
            // Calculate Y position
            let minutesFromDayStart = calendar.dateComponents([.minute], from: dayStart, to: visibleStartTime).minute ?? 0
            let yOffset = CGFloat(minutesFromDayStart) / 60.0 * hourHeight

            // Calculate height
            let durationInSeconds = visibleEndTime.timeIntervalSince(visibleStartTime)
            let height = CGFloat(durationInSeconds) / 3600.0 * hourHeight
            
            // Don't render if height is negligible
            guard height > 1 else { return nil }

            let geometry = BlockGeometry(yOffset: yOffset, height: height)
            return (block, geometry)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Column Header
            HStack {
                Text(dayFormatter.string(from: day).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isToday ? .red : .secondary)

                Text(dateFormatter.string(from: day))
                    .font(.system(size: 13, weight: .medium))
                    .padding(4)
                    .background(isToday ? Color.red : Color.clear)
                    .clipShape(Circle())
                    .foregroundColor(isToday ? .white : .primary)
            }
            .padding(.vertical, 8)

            Divider()
            
            ScrollView {
                ZStack(alignment: .topLeading) {
                    HourlyGridView(hourHeight: hourHeight)
                    
                    // FIX: Wrap blocks in a container and pad it to align with the grid.
                    // This prevents the blocks from overflowing the view.
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(timeBlockGeometries, id: \.block.id) { item in
                            TimeBlockView(
                                block: item.block,
                                geometry: item.geometry,
                                taskTitle: tasks.first(where: { $0.id == item.block.task_id })?.title ?? "Untitled",
                                hourHeight: hourHeight
                            )
                        }
                    }
                    .padding(.leading, 50) // Indent to align right of hour labels.
                    .padding(.trailing, 10) // Prevent touching the scrollbar/edge.
                }
                .frame(minHeight: hourHeight * 24)
            }
        }
    }
}

// A helper struct to pass geometry information
struct BlockGeometry {
    let yOffset: CGFloat
    let height: CGFloat
}

// --- Day Header View (for weekly view) ---
struct DayHeaderView: View {
    let day: Date
    let isToday: Bool
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // e.g., "Mon"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d" // e.g., "1"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(dayFormatter.string(from: day).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isToday ? .red : .secondary)

            Text(dateFormatter.string(from: day))
                .font(.system(size: 13, weight: .medium))
                .padding(4)
                .background(isToday ? Color.red : Color.clear)
                .clipShape(Circle())
                .foregroundColor(isToday ? .white : .primary)
        }
        // FIX: Use adaptive padding for height and let it expand horizontally.
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

// --- Weekly Day Column View (without ScrollView) ---
struct WeeklyDayColumnView: View {
    let day: Date
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    let hourHeight: CGFloat
    
    // This computes the geometry for each block for this specific day
    private var timeBlockGeometries: [(block: TimeBlock, geometry: BlockGeometry)] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        return timeBlocks.compactMap { block -> (TimeBlock, BlockGeometry)? in
            let blockEnd = block.start_time.addingTimeInterval(TimeInterval(block.actual_duration_in_minutes * 60))
            
            // Must overlap with the current day's interval to be visible
            guard block.start_time < dayEnd && blockEnd > dayStart else {
                return nil
            }
            
            // Calculate the visible portion for *this* day
            let visibleStartTime = max(block.start_time, dayStart)
            let visibleEndTime = min(blockEnd, dayEnd)
            
            // Calculate Y position
            let minutesFromDayStart = calendar.dateComponents([.minute], from: dayStart, to: visibleStartTime).minute ?? 0
            let yOffset = CGFloat(minutesFromDayStart) / 60.0 * hourHeight

            // Calculate height
            let durationInSeconds = visibleEndTime.timeIntervalSince(visibleStartTime)
            let height = CGFloat(durationInSeconds) / 3600.0 * hourHeight
            
            // Don't render if height is negligible
            guard height > 1 else { return nil }

            let geometry = BlockGeometry(yOffset: yOffset, height: height)
            return (block, geometry)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Just the horizontal divider lines, no hour labels
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { _ in
                    VStack {
                        Divider()
                        Spacer()
                    }
                    .frame(height: hourHeight)
                }
            }
            
            // FIX: The internal padding of TimeBlockView now handles alignment.
            // No offset is needed.
            ForEach(timeBlockGeometries, id: \.block.id) { item in
                TimeBlockView(
                    block: item.block,
                    geometry: item.geometry,
                    taskTitle: tasks.first(where: { $0.id == item.block.task_id })?.title ?? "Untitled",
                    hourHeight: hourHeight
                )
            }
        }
        .frame(minHeight: hourHeight * 24)
    }
}

// --- Existing Hourly Grid View ---
// (No changes needed, but keep it in this file for organization)
struct HourlyGridView: View {
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top) {
                    Text(hourText(for: hour))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                        .offset(y: -6) // Nudge text to align with the line
                    
                    VStack {
                        Divider()
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
        .padding(.leading, 5)
    }
    
    private func hourText(for hour: Int) -> String {
        if hour == 0 { return "" } // Hide 12 AM to not clutter
        else if hour < 12 { return "\(hour) AM" }
        else if hour == 12 { return "12 PM" }
        else { return "\(hour - 12) PM" }
    }
} 