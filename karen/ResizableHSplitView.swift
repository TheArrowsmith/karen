import SwiftUI

struct ResizableHSplitView<Left: View, Right: View>: View {
    private let left: Left
    private let right: Right
    private let totalWidth: CGFloat?
    private let rightMinWidth: CGFloat
    
    // The width of the left panel
    @State private var leftWidth: CGFloat
    
    // Initializer to set default widths
    init(leftInitialWidth: CGFloat, totalWidth: CGFloat? = nil, rightMinWidth: CGFloat = 400, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self._leftWidth = State(initialValue: leftInitialWidth)
        self.totalWidth = totalWidth
        self.rightMinWidth = rightMinWidth
        self.left = left()
        self.right = right()
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                left
                    .frame(width: leftWidth)
                
                Divider()
                    .frame(width: 4)
                    .background(Color.gray.opacity(0.2))
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                // Prevent resizing smaller than 400 for left panel
                                // Also ensure right panel doesn't get smaller than rightMinWidth
                                let proposedWidth = self.leftWidth + value.translation.width
                                let minLeft: CGFloat = 400
                                let containerWidth = totalWidth ?? geometry.size.width
                                let maxLeft = containerWidth - rightMinWidth - 4 // 4 is divider width
                                
                                let newWidth = min(max(minLeft, proposedWidth), maxLeft)
                                self.leftWidth = newWidth
                            }
                    )

                right
                    .frame(maxWidth: .infinity)
            }
        }
    }
} 