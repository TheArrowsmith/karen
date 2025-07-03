import SwiftUI
import UniformTypeIdentifiers

// --- Daily View ---
struct DailyView: View {
    let date: Date
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    let onToggleComplete: (String) -> Void
    let onUpdateTimeBlock: (String, Date, Int) -> Void
    let onDeleteTimeBlock: (String) -> Void
    let onDropTask: (String, Date, Int) -> Void // NEW

    @State private var dragInfo: DragInfo? = nil // NEW state to manage drag

    var body: some View {
        HStack(spacing: 0) {
            // A single column for the selected day
            DayColumnView(
                day: date, 
                timeBlocks: timeBlocks, 
                tasks: tasks, 
                isToday: Calendar.current.isDateInToday(date), 
                onToggleComplete: onToggleComplete, 
                onUpdateDate: onUpdateTimeBlock,
                onDeleteTimeBlock: onDeleteTimeBlock,
                dragInfo: $dragInfo, // Pass binding
                onDropTask: onDropTask // Pass closure
            )
        }
    }
}

// --- Weekly View ---
struct WeeklyView: View {
    let date: Date
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    let onToggleComplete: (String) -> Void
    let onUpdateTimeBlock: (String, Date, Int) -> Void
    let onDeleteTimeBlock: (String) -> Void
    let onDropTask: (String, Date, Int) -> Void // NEW
    
    @State private var dragInfo: DragInfo? = nil // NEW state to manage drag
    
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
                        WeeklyDayColumnView(
                            day: day, 
                            timeBlocks: timeBlocks, 
                            tasks: tasks, 
                            hourHeight: hourHeight, 
                            onToggleComplete: onToggleComplete, 
                            onUpdateDate: onUpdateTimeBlock,
                            onDeleteTimeBlock: onDeleteTimeBlock,
                            dragInfo: $dragInfo, // Pass binding
                            onDropTask: onDropTask // Pass closure
                        )
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
    let onToggleComplete: (String) -> Void
    let onUpdateDate: (String, Date, Int) -> Void
    let onDeleteTimeBlock: (String) -> Void
    @Binding var dragInfo: DragInfo? // NEW: To receive drag state
    let onDropTask: (String, Date, Int) -> Void // NEW: Callback for when drop completes
    
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
        // WRAP the entire VStack in a GeometryReader to get its size for coordinate conversion
        GeometryReader { geometry in
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
                        ZStack(alignment: .topLeading) {
                            ForEach(timeBlockGeometries, id: \.block.id) { item in
                                let task = tasks.first(where: { $0.id == item.block.task_id })
                                TimeBlockView(
                                    block: item.block,
                                    geometry: item.geometry,
                                    task: task,
                                    allTimeBlocks: timeBlocks,
                                    hourHeight: hourHeight,
                                    onToggleComplete: onToggleComplete,
                                    onUpdate: onUpdateDate,
                                    onDelete: onDeleteTimeBlock
                                )
                            }
                            
                            // NEW: Display the ghost block if a drag is active on this day
                            if let info = dragInfo, info.isDropPossible, Calendar.current.isDate(info.targetDay, inSameDayAs: day) {
                                GhostBlockView(geometry: BlockGeometry(
                                    yOffset: CGFloat(Calendar.current.dateComponents([.minute], from: Calendar.current.startOfDay(for: day), to: info.startTime).minute ?? 0) / 60.0 * hourHeight,
                                    height: CGFloat(info.duration) / 60.0 * hourHeight
                                ))
                                .allowsHitTesting(false) // Make sure it doesn't interfere with drop detection
                            }
                        }
                        .padding(.leading, 50) // Indent to align right of hour labels.
                        .padding(.trailing, 10) // Prevent touching the scrollbar/edge.
                        // ADD a .onDrop modifier to this ZStack
                        .onDrop(of: [.plainText], delegate: SimpleDayDropDelegate(
                            day: day,
                            timeBlocks: timeBlocks,
                            dragInfo: $dragInfo,
                            onDropTask: onDropTask,
                            geometry: geometry
                        ))
                    }
                    .frame(minHeight: hourHeight * 24)
                }
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
    let onToggleComplete: (String) -> Void
    let onUpdateDate: (String, Date, Int) -> Void
    let onDeleteTimeBlock: (String) -> Void
    @Binding var dragInfo: DragInfo? // NEW
    let onDropTask: (String, Date, Int) -> Void // NEW
    
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
        // WRAP in GeometryReader
        GeometryReader { geometry in
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
                
                // NEW: Display the ghost block
                if let info = dragInfo, info.isDropPossible, Calendar.current.isDate(info.targetDay, inSameDayAs: day) {
                    GhostBlockView(geometry: BlockGeometry(
                        yOffset: CGFloat(Calendar.current.dateComponents([.minute], from: Calendar.current.startOfDay(for: day), to: info.startTime).minute ?? 0) / 60.0 * hourHeight,
                        height: CGFloat(info.duration) / 60.0 * hourHeight
                    ))
                    .allowsHitTesting(false)
                }
                
                // FIX: The internal padding of TimeBlockView now handles alignment.
                // No offset is needed.
                ForEach(timeBlockGeometries, id: \.block.id) { item in
                    let task = tasks.first(where: { $0.id == item.block.task_id })
                    TimeBlockView(
                        block: item.block,
                        geometry: item.geometry,
                        task: task,
                        allTimeBlocks: timeBlocks,
                        hourHeight: hourHeight,
                        onToggleComplete: onToggleComplete,
                        onUpdate: onUpdateDate,
                        onDelete: onDeleteTimeBlock
                    )
                }
            }
            .frame(minHeight: hourHeight * 24)
            // ADD .onDrop modifier to the ZStack
            .onDrop(of: [.plainText], delegate: SimpleDayDropDelegate(
                day: day,
                timeBlocks: timeBlocks,
                dragInfo: $dragInfo,
                onDropTask: onDropTask,
                geometry: geometry
            ))
        }
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

// Simple drop delegate that tracks cursor position
struct SimpleDayDropDelegate: DropDelegate {
    let day: Date
    let timeBlocks: [TimeBlock]
    @Binding var dragInfo: DragInfo?
    let onDropTask: (String, Date, Int) -> Void
    let geometry: GeometryProxy
    
    func dropEntered(info: DropInfo) {
        // Initialize drag info when entering
        dragInfo = DragInfo(
            taskID: "",
            targetDay: day,
            startTime: day,
            duration: CalendarHelpers.defaultDuration
        )
        
        // Try to get task duration from the drag data
        if let provider = info.itemProviders(for: [.plainText]).first {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
                if let data = data {
                    // Try to parse as JSON first
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let duration = json["duration"] as? Int {
                        DispatchQueue.main.async {
                            self.dragInfo?.duration = duration
                        }
                    }
                }
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard dragInfo != nil else { return DropProposal(operation: .forbidden) }
        
        // Calculate drop position relative to the scroll view content
        let dropY = info.location.y
        let dropTime = CalendarHelpers.timeFor(y: max(0, dropY), in: day)
        
        // Calculate smart placement
        let placement = CalendarHelpers.calculateSmartPlacement(
            for: dropTime,
            on: day,
            existingTimeBlocks: timeBlocks
        )
        
        // Update drag info
        dragInfo?.targetDay = day
        dragInfo?.startTime = placement.startTime
        dragInfo?.duration = placement.duration
        dragInfo?.isDropPossible = placement.isPossible
        
        return DropProposal(operation: placement.isPossible ? .copy : .forbidden)
    }
    
    func dropExited(info: DropInfo) {
        dragInfo = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        print("performDrop called on day: \(day)")
        guard let currentDragInfo = dragInfo else {
            print("No dragInfo available")
            dragInfo = nil
            return false
        }
        
        guard currentDragInfo.isDropPossible else {
            print("Drop not possible - no available slot")
            dragInfo = nil
            return false
        }
        
        // Load the task ID and perform the drop
        guard let provider = info.itemProviders(for: [.plainText]).first else {
            print("No provider found in drop")
            dragInfo = nil
            return false
        }
        
        provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
            if let data = data {
                // Try to parse as JSON first
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let taskID = json["id"] as? String {
                    DispatchQueue.main.async {
                        print("Dropping task \(taskID) at \(currentDragInfo.startTime) for \(currentDragInfo.duration) minutes")
                        self.onDropTask(taskID, currentDragInfo.startTime, currentDragInfo.duration)
                        self.dragInfo = nil
                    }
                } else if let taskID = String(data: data, encoding: .utf8) {
                    // Fallback to plain string
                    DispatchQueue.main.async {
                        print("Dropping task \(taskID) at \(currentDragInfo.startTime) for \(currentDragInfo.duration) minutes")
                        self.onDropTask(taskID, currentDragInfo.startTime, currentDragInfo.duration)
                        self.dragInfo = nil
                    }
                } else {
                    print("Failed to load task ID from drop data")
                    DispatchQueue.main.async {
                        self.dragInfo = nil
                    }
                }
            } else {
                print("Failed to load drop data")
                DispatchQueue.main.async {
                    self.dragInfo = nil
                }
            }
        }
        
        return true
    }
} 