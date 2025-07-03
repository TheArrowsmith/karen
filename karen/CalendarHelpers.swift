import Foundation
import SwiftUI

class CalendarHelpers {
    static let hourHeight: CGFloat = 60.0
    static let defaultDuration: Int = 60 // minutes
    static let minimumDuration: Int = 15 // minutes

    // Converts a Y-coordinate within a day's grid to a Date, snapped to 15 mins.
    static func timeFor(y: CGFloat, in day: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)

        // Calculate minutes from the top of the view
        let minutesFromStart = Int((y / hourHeight) * 60)

        // Snap to the nearest 15-minute interval
        let snappedMinutes = (minutesFromStart / 15) * 15

        return calendar.date(byAdding: .minute, value: snappedMinutes, to: startOfDay)!
    }

    // This is the core "Smart Drop" logic.
    static func calculateSmartPlacement(for targetTime: Date, on day: Date, existingTimeBlocks: [TimeBlock]) -> (startTime: Date, duration: Int, isPossible: Bool) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        var sortedBlocks = existingTimeBlocks
            .filter { calendar.isDate($0.start_time, inSameDayAs: day) }
            .sorted { $0.start_time < $1.start_time }

        // Function to find the next available slot starting from a given time
        func findNextAvailableSlot(from time: Date) -> (startTime: Date, duration: Int)? {
            var searchTime = time

            // Find the block that our searchTime falls into or comes just after
            if let conflictingBlock = sortedBlocks.first(where: {
                let blockEnd = $0.start_time.addingTimeInterval(TimeInterval($0.actual_duration_in_minutes * 60))
                return searchTime >= $0.start_time && searchTime < blockEnd
            }) {
                // If we land inside a block, the next available time is after it ends
                searchTime = conflictingBlock.start_time.addingTimeInterval(TimeInterval(conflictingBlock.actual_duration_in_minutes * 60))
            }

            // Now, check for gaps from our (potentially updated) searchTime
            let nextBlock = sortedBlocks.first { $0.start_time >= searchTime }

            let availableEnd = nextBlock?.start_time ?? endOfDay
            let gapDuration = Int(availableEnd.timeIntervalSince(searchTime) / 60)

            if gapDuration >= minimumDuration {
                // We found a valid slot
                return (searchTime, min(gapDuration, defaultDuration))
            } else if let nextBlock = nextBlock {
                // The immediate gap is too small, so try again after the next block
                let nextSearchTime = nextBlock.start_time.addingTimeInterval(TimeInterval(nextBlock.actual_duration_in_minutes * 60))
                return findNextAvailableSlot(from: nextSearchTime)
            }
            
            // No suitable slot found for the rest of the day
            return nil
        }
        
        let initialGap = findNextAvailableSlot(from: targetTime)

        if let placement = initialGap {
            // Scenario A or B: The initial target time works, or fits in a smaller gap
            return (placement.startTime, placement.duration, true)
        } else {
            // Scenario C or impossible: No slot found at or after the target time.
            return (targetTime, defaultDuration, false)
        }
    }
} 