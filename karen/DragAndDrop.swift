import SwiftUI
import UniformTypeIdentifiers

// 1. A struct to hold all information about an active drag operation.
// This is transient UI state and does not belong in the AppStore.
struct DragInfo {
    let taskID: String
    var targetDay: Date
    var startTime: Date
    var duration: Int // in minutes
    var isDropPossible: Bool = true
}

// 2. A new view to render the "ghost" preview on the calendar.
struct GhostBlockView: View {
    let geometry: BlockGeometry // We will reuse the existing BlockGeometry

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            // Use a dashed stroke for the border
            .stroke(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            // Use a semi-transparent fill
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.2))
            )
            .frame(height: geometry.height)
            .offset(y: geometry.yOffset)
    }
}

// 3. Define a custom UTType for our task drag
extension UTType {
    static let taskDragItem = UTType(exportedAs: "com.karen.taskdragitem")
} 