import SwiftUI

struct TimeBlockView: View {
    let block: TimeBlock
    let geometry: BlockGeometry // Pre-calculated geometry
    let taskTitle: String
    let hourHeight: CGFloat
    let isCompleted: Bool
    let onToggleComplete: (String) -> Void
    let onDelete: (String) -> Void

    @State private var isHovering = false
    
    // Minimum height needed to show both title and time range
    private let minHeightForTimeRange: CGFloat = 40

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(taskTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .strikethrough(isCompleted)
                
                // Only show time range if there's enough vertical space
                if geometry.height >= minHeightForTimeRange {
                    Text(timeRangeText)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .padding(.leading, 20)
            .allowsHitTesting(false) // Let clicks pass through to buttons
            
            // Checkbox overlay in top left
            Button(action: { onToggleComplete(block.task_id) }) {
                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 4)
            .padding(.leading, 6)
            
            // Delete button in top right (only show when hovering)
            if isHovering {
                HStack {
                    Spacer()
                    Button(action: { onDelete(block.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.9))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete time block")
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.trailing, 6)
            }
        }
        .frame(height: geometry.height)
        .padding(.horizontal, 5)
        .offset(y: geometry.yOffset)
        .onHover { hovering in
            isHovering = hovering
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