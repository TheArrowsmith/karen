import SwiftUI

struct DailyScheduleView: View {
    let timeBlocks: [TimeBlock]
    let tasks: [Task]
    let onUpdateBlock: (String, Date, Int) -> Void
    
    private let hourHeight: CGFloat = 60.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text("Today's Schedule")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Text(Date(), style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Background hourly grid
                        HourlyGridView(hourHeight: hourHeight)
                        
                        // Render the interactive TimeBlock views
                        ForEach(timeBlocks) { block in
                            TimeBlockView(
                                block: block,
                                allBlocks: timeBlocks,
                                taskTitle: tasks.first(where: { $0.id == block.task_id })?.title ?? "Untitled",
                                hourHeight: hourHeight,
                                onUpdate: onUpdateBlock
                            )
                        }
                    }
                    .frame(minHeight: hourHeight * 24)
                }
                .onAppear { 
                    withAnimation {
                        proxy.scrollTo(8, anchor: .top) 
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct HourlyGridView: View {
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack {
                    Text(hourText(for: hour))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                    
                    Spacer()
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
        .padding(.leading, 5)
    }
    
    private func hourText(for hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        else if hour < 12 { return "\(hour) AM" }
        else if hour == 12 { return "12 PM" }
        else { return "\(hour - 12) PM" }
    }
}

struct TimeBlockView: View {
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
    
    enum ResizeEdge {
        case top, bottom
    }
    
    private var yPosition: CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: block.start_time)
        let minutesFromMidnight = calendar.dateComponents([.minute], from: startOfDay, to: block.start_time).minute ?? 0
        return CGFloat(minutesFromMidnight) / 60.0 * hourHeight
    }
    
    private var blockHeight: CGFloat {
        CGFloat(block.actual_duration_in_minutes) / 60.0 * hourHeight
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(isDragging || isResizing ? 0.6 : 0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(taskTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(timeRangeText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(8)
        }
        .frame(width: 250, height: blockHeight + (isResizing ? resizeOffset : 0))
        .offset(x: 50, y: yPosition + (isDragging ? dragOffset.height : 0))
        .onHover { hovering in
            if hovering {
                NSCursor.arrow.push()
            } else {
                NSCursor.pop()
                hoveredEdge = nil
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let edgeThreshold: CGFloat = 10
                if location.y < edgeThreshold {
                    if hoveredEdge != .top {
                        hoveredEdge = .top
                        NSCursor.resizeUpDown.push()
                    }
                } else if location.y > blockHeight - edgeThreshold {
                    if hoveredEdge != .bottom {
                        hoveredEdge = .bottom
                        NSCursor.resizeUpDown.push()
                    }
                } else {
                    if hoveredEdge != nil {
                        NSCursor.pop()
                        hoveredEdge = nil
                        NSCursor.arrow.push()
                    }
                }
            case .ended:
                if hoveredEdge != nil {
                    NSCursor.pop()
                    hoveredEdge = nil
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let location = value.startLocation
                    let edgeThreshold: CGFloat = 10
                    
                    if !isDragging && !isResizing {
                        // Determine if we're dragging the whole block or resizing
                        if location.y < edgeThreshold {
                            isResizing = true
                            resizingEdge = .top
                        } else if location.y > blockHeight - edgeThreshold {
                            isResizing = true
                            resizingEdge = .bottom
                        } else {
                            isDragging = true
                        }
                    }
                    
                    if isDragging {
                        dragOffset = value.translation
                    } else if isResizing {
                        resizeOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if isDragging {
                        handleDragEnd(translation: value.translation.height)
                    } else if isResizing {
                        handleResizeEnd(offset: value.translation.height)
                    }
                    
                    isDragging = false
                    isResizing = false
                    resizingEdge = nil
                    dragOffset = .zero
                    resizeOffset = 0
                }
        )
    }
    
    private func handleDragEnd(translation: CGFloat) {
        let minuteOffset = Int(translation / hourHeight * 60)
        let calendar = Calendar.current
        
        // Calculate new start time
        guard let newStartTime = calendar.date(byAdding: .minute, value: minuteOffset, to: block.start_time) else { return }
        
        // Snap to 15-minute intervals
        let components = calendar.dateComponents([.hour, .minute], from: newStartTime)
        let snappedMinute = Int(round(Double(components.minute ?? 0) / 15.0) * 15.0) % 60
        let hourAdjustment = (components.minute ?? 0) + minuteOffset >= 60 ? 1 : 0
        
        guard let snappedStartTime = calendar.date(bySettingHour: (components.hour ?? 0) + hourAdjustment,
                                                   minute: snappedMinute,
                                                   second: 0,
                                                   of: newStartTime) else { return }
        
        // Check for collisions
        if !hasCollision(startTime: snappedStartTime, duration: block.actual_duration_in_minutes) {
            onUpdate(block.id, snappedStartTime, block.actual_duration_in_minutes)
        }
    }
    
    private func handleResizeEnd(offset: CGFloat) {
        let minuteChange = Int(offset / hourHeight * 60)
        let calendar = Calendar.current
        
        if resizingEdge == .top {
            // Changing start time
            guard let newStartTime = calendar.date(byAdding: .minute, value: minuteChange, to: block.start_time) else { return }
            
            // Snap to 15-minute intervals
            let components = calendar.dateComponents([.hour, .minute], from: newStartTime)
            let snappedMinute = Int(round(Double(components.minute ?? 0) / 15.0) * 15.0) % 60
            
            guard let snappedStartTime = calendar.date(bySettingHour: components.hour ?? 0,
                                                       minute: snappedMinute,
                                                       second: 0,
                                                       of: newStartTime) else { return }
            
            let newDuration = block.actual_duration_in_minutes - minuteChange
            
            if newDuration > 0 && !hasCollision(startTime: snappedStartTime, duration: newDuration) {
                onUpdate(block.id, snappedStartTime, newDuration)
            }
        } else if resizingEdge == .bottom {
            // Changing duration
            let newDuration = block.actual_duration_in_minutes + minuteChange
            let snappedDuration = Int(round(Double(newDuration) / 15.0) * 15.0)
            
            if snappedDuration > 0 && !hasCollision(startTime: block.start_time, duration: snappedDuration) {
                onUpdate(block.id, block.start_time, snappedDuration)
            }
        }
    }
    
    private func hasCollision(startTime: Date, duration: Int) -> Bool {
        let endTime = startTime.addingTimeInterval(TimeInterval(duration * 60))
        
        return allBlocks.contains { otherBlock in
            if otherBlock.id == block.id { return false }
            
            let otherEndTime = otherBlock.start_time.addingTimeInterval(TimeInterval(otherBlock.actual_duration_in_minutes * 60))
            
            // Check for overlap
            return startTime < otherEndTime && endTime > otherBlock.start_time
        }
    }
    
    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let startText = formatter.string(from: block.start_time)
        let endTime = block.start_time.addingTimeInterval(TimeInterval(block.actual_duration_in_minutes * 60))
        let endText = formatter.string(from: endTime)
        
        return "\(startText) - \(endText)"
    }
} 