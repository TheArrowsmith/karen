### **High-Level Goal**

The goal is to implement a core feature in the "karen" task management app: allowing users to add and delete tasks. This involves creating a new task via a popover form and deleting existing tasks via a hover-button and confirmation dialog. Both actions must be fully integrated into the existing undo/redo system for a seamless user experience.

---

### **Step-by-Step Implementation Instructions**

#### **Step 1: Update State Management for New Actions**

First, we must teach the application's state management system about adding and deleting tasks.

1.  **Modify `karen/AppAction.swift`:**
    Add `addTask` and `deleteTask` cases to the `AppAction` enum. These actions need to include not just the task itself, but also its position (index) in the list to support undo/redo correctly.

    ```swift
    // In karen/AppAction.swift
    
    enum AppAction {
        // Task Actions
        case addTask(task: Task, index: Int) // ADD THIS LINE
        case deleteTask(task: Task, index: Int) // ADD THIS LINE
        case updateTask(oldValue: Task, newValue: Task)
        case reorderTasks(from: IndexSet, to: Int)
    
        // ... rest of the enum
    }
    ```

2.  **Modify `karen/AppStore.swift`:**
    Update the `AppStore` to handle the logic for the new actions and their inverses for undo/redo.

    a. **Update the `apply` method** to execute the state changes for `addTask` and `deleteTask`.

    ```swift
    // In karen/AppStore.swift, inside the apply(_:) method's switch statement
    
    private func apply(_ action: AppAction) {
        switch action {
        case .addTask(let task, let index): // ADD THIS CASE
            state.tasks.insert(task, at: index)
            
        case .deleteTask(_, let index): // ADD THIS CASE
            // Ensure the index is valid before trying to remove
            guard state.tasks.indices.contains(index) else {
                triggerInconsistencyAlert(for: "task")
                return
            }
            state.tasks.remove(at: index)

        case .updateTask(_, let newValue):
            // ... existing code
    ```

    b. **Update the `createUndoAction` method** to define the inverse of each new action. The inverse of adding is deleting at the same index, and vice versa.

    ```swift
    // In karen/AppStore.swift, inside the createUndoAction(for:) method's switch statement

    private func createUndoAction(for action: AppAction) -> AppAction {
        switch action {
        case .addTask(let task, let index): // ADD THIS CASE
            return .deleteTask(task: task, index: index)
            
        case .deleteTask(let task, let index): // ADD THIS CASE
            return .addTask(task: task, index: index)

        case .updateTask(let oldValue, let newValue):
            // ... existing code
    ```

    c. **Confirm `isUndoable` logic:** No code change is needed in the `isUndoable` method. The `default: return true` case will correctly handle `addTask` and `deleteTask`, making them undoable.

---

#### **Step 2: Create the "Add Task" Popover View**

We need a dedicated SwiftUI view for the form that will appear in the popover.

1.  **Create a new file named `karen/AddTaskView.swift`**.
2.  **Add the following code to the new file.** This view manages its own local state for the form inputs and provides a callback when a valid task is ready to be created.

    ```swift
    // In new file karen/AddTaskView.swift

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
                
                Form {
                    TextField("Title (required)", text: $title)
                    TextField("Description (optional)", text: $description)
                    
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(Priority?(nil))
                        Text("Low").tag(Priority?.low)
                        Text("Medium").tag(Priority?.medium)
                        Text("High").tag(Priority?.high)
                    }
                    
                    HStack {
                        TextField("Duration", text: $durationAmount)
                            .keyboardType(.numberPad)
                            .frame(width: 50)
                        
                        Picker("Unit", selection: $durationUnit) {
                            ForEach(DurationUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    DatePicker("Deadline", selection: $deadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
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
    ```

---

#### **Step 3: Integrate Add & Delete Functionality into `TaskListView`**

Now, update `TaskListView.swift` to use the new `AddTaskView` and to add the delete functionality to `TaskItemView`.

1.  **Modify `karen/TaskListView.swift`:**

    a. **Add state and the "Add Task" button with its popover.**

    ```swift
    // In karen/TaskListView.swift

    struct TaskListView: View {
        @EnvironmentObject var store: AppStore // ADD THIS LINE TO ACCESS THE STORE
        let onReorderTasks: (IndexSet, Int) -> Void
        
        @State private var isShowingAddTaskPopover = false // ADD THIS STATE

        var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    // ADD THE BUTTON AND POPOVER
                    Button(action: { isShowingAddTaskPopover = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $isShowingAddTaskPopover, arrowEdge: .bottom) {
                        AddTaskView(onAddTask: { newTask in
                            store.dispatch(.addTask(task: newTask, index: 0))
                        }, isPresented: $isShowingAddTaskPopover)
                    }

                    Text("Tasks")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Text("\(store.state.tasks.count)") // UPDATE TO USE STORE
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                // ... existing HStack code

                List {
                    ForEach(store.state.tasks) { task in // UPDATE TO USE STORE
                        TaskItemView(
                            task: task,
                            onToggleComplete: { taskId in
                                guard let task = store.state.tasks.first(where: { $0.id == taskId }) else { return }
                                var updatedTask = task
                                updatedTask.is_completed.toggle()
                                store.dispatch(.updateTask(oldValue: task, newValue: updatedTask))
                            },
                            // ADD THE onDeleteTask CALLBACK
                            onDeleteTask: { taskToDelete in
                                if let index = store.state.tasks.firstIndex(where: { $0.id == taskToDelete.id }) {
                                    store.dispatch(.deleteTask(task: taskToDelete, index: index))
                                }
                            }
                        )
                        // ... existing list row modifiers
                    }
                    .onMove(perform: onReorderTasks)
                }
                // ... existing list modifiers
            }
            // ... existing background
        }
    }
    ```

    b. **Update `TaskItemView` to include the delete button and confirmation alert.**

    ```swift
    // In karen/TaskListView.swift, inside TaskItemView

    struct TaskItemView: View {
        let task: Task
        let onToggleComplete: (String) -> Void
        let onDeleteTask: (Task) -> Void // ADD THIS CALLBACK
        
        @State private var isHovering = false // ADD THIS STATE
        @State private var showDeleteConfirm = false // ADD THIS STATE

        // ... existing computed properties (priorityColor, deadlineText) ...

        var body: some View {
            // WRAP THE EXISTING HSTACK IN A ZSTACK
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 12) {
                    // ... This is the entire existing HStack for the task item content ...
                    Button(action: { onToggleComplete(task.id) }) {
                        // ...
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // ...
                    }
                    
                    Spacer()
                }
                
                // ADD THE DELETE BUTTON
                if isHovering {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .contentShape(Rectangle())
            // ADD ONHOVER AND ALERT MODIFIERS
            .onHover { hovering in
                self.isHovering = hovering
            }
            .alert("Delete Task?", isPresented: $showDeleteConfirm, presenting: task) { _ in
                Button("Delete", role: .destructive) {
                    onDeleteTask(task)
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("Are you sure you want to delete \"\(task.title)\"? This can be undone.")
            }
        }
    }
    ```

#### **Step 4: Update the Main `ContentView`**

The `ContentView` passes data down to `TaskListView`. We need to adjust its initializers to match the changes we made.

1.  **Modify `karen/ContentView.swift`:**
    Remove the `tasks` and `onToggleComplete` parameters from the `TaskListView` initializer, as it now gets this data directly from the environment store.

    ```swift
    // In karen/ContentView.swift
    
    struct ContentView: View {
        @EnvironmentObject var store: AppStore
        
        var body: some View {
            HStack(spacing: 0) {
                // Panel 1: Task List (Left)
                // UPDATE THIS INITIALIZER
                TaskListView(
                    onReorderTasks: { from, to in
                        store.dispatch(.reorderTasks(from: from, to: to))
                    }
                )
                .frame(width: 320)
                
                // ... rest of the body is unchanged
            }
            // ... rest of the view is unchanged
        }
    }
    ```

---

### **Summary of Modified Files**

The following existing files need to be modified to complete this implementation:

*   `karen/AppAction.swift`
*   `karen/AppStore.swift`
*   `karen/TaskListView.swift`
*   `karen/ContentView.swift`
