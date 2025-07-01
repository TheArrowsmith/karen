import SwiftUI

struct AddTaskView: View {
    // Callback to pass the created task up to the parent view
    let onAddTask: (Task) -> Void
    // Binding to control the popover's visibility
    @Binding var isPresented: Bool

    // Local state for all form fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: Priority? = nil
    @State private var durationAmount: String = "30"
    @State private var durationUnit: DurationUnit = .minutes
    @State private var deadline: Date = Date().addingTimeInterval(3600) // Default to 1 hour from now

    enum DurationUnit: String, CaseIterable {
        case minutes, hours
    }
    
    // Computed property to check if the form is valid for submission
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Task")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.system(size: 12, weight: .medium))
                    TextField("", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.system(size: 12, weight: .medium))
                    TextEditor(text: $description)
                        .font(.system(size: 13))
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Priority")
                        .font(.system(size: 12, weight: .medium))
                    Picker("", selection: $priority) {
                        Text("None").tag(Priority?(nil))
                        Text("Low").tag(Priority.low as Priority?)
                        Text("Medium").tag(Priority.medium as Priority?)
                        Text("High").tag(Priority.high as Priority?)
                    }
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Duration")
                        .font(.system(size: 12, weight: .medium))
                    HStack {
                        TextField("", text: $durationAmount)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                        
                        Picker("", selection: $durationUnit) {
                            ForEach(DurationUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deadline")
                        .font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: $deadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add Task", action: submitTask)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 350)
    }
    
    private func submitTask() {
        guard isFormValid, let durationValue = Int(durationAmount), durationValue > 0 else { return }
        
        let totalMinutes: Int
        switch durationUnit {
        case .minutes:
            totalMinutes = durationValue
        case .hours:
            totalMinutes = durationValue * 60
        }
        
        let newTask = Task(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            is_completed: false,
            priority: priority,
            deadline: deadline,
            predicted_duration_in_minutes: totalMinutes
        )
        
        onAddTask(newTask)
        isPresented = false
    }
} 