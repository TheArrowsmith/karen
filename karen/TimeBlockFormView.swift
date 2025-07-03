import SwiftUI

struct TimeBlockFormView: View {
    // MARK: - Properties
    
    // Inputs from the parent view
    let timeBlock: TimeBlock
    let associatedTask: Task?
    let allOtherTimeBlocks: [TimeBlock]
    let onSave: (String, Date, Int) -> Void
    @Binding var isPresented: Bool

    // Local state for the form fields
    @State private var startTime: Date
    @State private var endTime: Date
    
    // MARK: - Initializer
    
    init(timeBlock: TimeBlock, associatedTask: Task?, allOtherTimeBlocks: [TimeBlock], onSave: @escaping (String, Date, Int) -> Void, isPresented: Binding<Bool>) {
        self.timeBlock = timeBlock
        self.associatedTask = associatedTask
        self.allOtherTimeBlocks = allOtherTimeBlocks
        self.onSave = onSave
        self._isPresented = isPresented
        
        // Initialize local state from the passed-in timeBlock
        _startTime = State(initialValue: timeBlock.start_time)
        let end = timeBlock.start_time.addingTimeInterval(TimeInterval(timeBlock.actual_duration_in_minutes * 60))
        _endTime = State(initialValue: end)
    }
    
    // MARK: - Computed Properties for Validation
    
    // Checks if the end time is at least 1 minute after the start time
    private var isTimeRangeValid: Bool {
        endTime > startTime.addingTimeInterval(59) // 59 seconds to ensure at least 1 full minute
    }
    
    // Checks if the current start/end time overlaps with any other block
    private var isOverlapping: Bool {
        let proposedInterval = DateInterval(start: startTime, end: endTime)
        
        for otherBlock in allOtherTimeBlocks {
            let otherBlockEnd = otherBlock.start_time.addingTimeInterval(TimeInterval(otherBlock.actual_duration_in_minutes * 60))
            let otherInterval = DateInterval(start: otherBlock.start_time, end: otherBlockEnd)
            
            if proposedInterval.intersects(otherInterval) {
                return true
            }
        }
        return false
    }

    // Checks if any changes have been made
    private var hasChanges: Bool {
        let originalEndTime = timeBlock.start_time.addingTimeInterval(TimeInterval(timeBlock.actual_duration_in_minutes * 60))
        return startTime != timeBlock.start_time || endTime != originalEndTime
    }
    
    // The save button is enabled only if all conditions are met
    private var isFormValid: Bool {
        hasChanges && isTimeRangeValid && !isOverlapping
    }

    // MARK: - View Body

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Time Block")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                // Non-editable Task Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task")
                        .font(.system(size: 12, weight: .medium))
                    Text(associatedTask?.title ?? "Untitled Task")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.unemphasizedSelectedContentBackgroundColor))
                        .cornerRadius(6)
                }

                // Start Time Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                // End Time Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                
                // Validation Error Message
                if isOverlapping {
                    Text("Time conflicts with another block.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save Changes", action: submit)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    // MARK: - Actions
    
    private func submit() {
        guard isFormValid else { return }
        
        // Calculate duration in minutes from the start and end times
        let durationInSeconds = endTime.timeIntervalSince(startTime)
        let durationInMinutes = Int(round(durationInSeconds / 60))
        
        onSave(timeBlock.id, startTime, durationInMinutes)
        isPresented = false
    }
} 