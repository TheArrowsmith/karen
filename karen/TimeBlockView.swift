import SwiftUI

struct TimeBlockView: View {
    let block: TimeBlock
    let geometry: BlockGeometry // New property to accept pre-calculated geometry
    let taskTitle: String
    let hourHeight: CGFloat
    let xOffset: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(taskTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(timeRangeText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(height: geometry.height)
        .offset(x: xOffset, y: geometry.yOffset) // Use the passed-in geometry
        .padding(.trailing, 10) // Give it some breathing room from the next column
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