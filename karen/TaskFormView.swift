import SwiftUI

struct TaskFormView: View {
    // MARK: - Properties
    
    // The mode determines if the form is for adding or editing a task.
    private var mode: Mode
    
    // Callback to pass the created or updated task up to the parent view.
    let onSave: (Task) -> Void
    
    // Binding to control the popover's visibility.
    @Binding var isPresented: Bool

    // A copy of the original task in edit mode, used to detect changes.
    @State private var originalTask: Task?
    
    // Local state for all form fields.
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: Priority? = nil
    @State private var deadline: Date = Date().addingTimeInterval(3600)

    // State to manage the "discard changes" confirmation alert.
    @State private var showCancelConfirm = false
    
    enum Mode {
        case add, edit
    }


    
    init(taskToEdit: Task? = nil, onSave: @escaping (Task) -> Void, isPresented: Binding<Bool>) {
        self.mode = (taskToEdit == nil) ? .add : .edit
        self.onSave = onSave
        self._isPresented = isPresented
        
        // If a task is passed, we are in "edit" mode.
        if let task = taskToEdit {
            // Store the original task to compare against for changes.
            _originalTask = State(initialValue: task)
            
            // Pre-populate the form fields with the task's data.
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.description ?? "")
            _priority = State(initialValue: task.priority)
            _deadline = State(initialValue: task.deadline ?? Date().addingTimeInterval(3600))
        }
    }
    
    // Computed property to check if the form is valid for submission.
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Computed property to check if any data has been changed in edit mode.
    private var hasChanges: Bool {
        guard mode == .edit, let original = originalTask else { return false }
        
        return title != original.title ||
               description != (original.description ?? "") ||
               priority != original.priority ||
               !Calendar.current.isDate(deadline, inSameDayAs: original.deadline ?? Date.distantPast)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(mode == .add ? "Add New Task" : "Edit Task")
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
                    Text("Deadline")
                        .font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: $deadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            
            HStack {
                Button("Cancel") {
                    handleCancel()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(mode == .add ? "Add Task" : "Save Changes", action: submitTask)
                    .disabled(!isFormValid || (mode == .edit && !hasChanges))
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 350)
        .alert("Discard Changes?", isPresented: $showCancelConfirm, actions: {
            Button("Discard", role: .destructive) {
                isPresented = false
            }
            Button("Cancel", role: .cancel) { }
        }, message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        })
    }
    
    private func handleCancel() {
        if mode == .edit && hasChanges {
            showCancelConfirm = true
        } else {
            isPresented = false
        }
    }
    
    private func submitTask() {
        guard isFormValid else { return }
        
        let task = Task(
            // If editing, use the original ID. If adding, a new ID is generated by the initializer.
            id: originalTask?.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            is_completed: originalTask?.is_completed ?? false, // Preserve completion state
            priority: priority,
            // Preserve original creation date when editing
            creation_date: originalTask?.creation_date ?? Date(),
            deadline: deadline
        )
        
        onSave(task)
        isPresented = false
    }
} 