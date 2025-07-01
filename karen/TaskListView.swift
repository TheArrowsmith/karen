import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var store: AppStore
    let onReorderTasks: (IndexSet, Int) -> Void
    
    @State private var isShowingAddTaskPopover = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tasks")
                    .font(.system(size: 20, weight: .semibold))
                
                Button(action: { isShowingAddTaskPopover = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $isShowingAddTaskPopover, arrowEdge: .bottom) {
                    AddTaskView(onAddTask: { newTask in
                        store.dispatch(.createTask(newTask))
                    }, isPresented: $isShowingAddTaskPopover)
                }
                
                Spacer()
                Text("\(store.state.tasks.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            List {
                ForEach(store.state.tasks) { task in
                    TaskItemView(
                        task: task,
                        onToggleComplete: { taskId in
                            store.dispatch(.toggleTaskCompletion(id: taskId))
                        },
                        onDeleteTask: { taskToDeleteId in
                            store.dispatch(.deleteTask(id: taskToDeleteId))
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: onReorderTasks)
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TaskItemView: View {
    let task: Task
    let onToggleComplete: (String) -> Void
    let onDeleteTask: (String) -> Void
    
    @State private var isHovering = false
    @State private var showDeleteConfirm = false
    
    var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .gray
        }
    }
    
    var deadlineText: String? {
        guard let deadline = task.deadline else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: deadline, relativeTo: Date())
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: { onToggleComplete(task.id) }) {
                    Image(systemName: task.is_completed ? "checkmark.square.fill" : "square")
                        .foregroundColor(task.is_completed ? .blue : .gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(task.is_completed ? .secondary : .primary)
                        .strikethrough(task.is_completed)
                    
                    if let description = task.description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        if task.priority != nil {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(priorityColor)
                                    .frame(width: 6, height: 6)
                                Text(task.priority!.rawValue.capitalized)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let deadlineText = deadlineText {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(deadlineText)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(task.deadline! < Date() ? .red : .secondary)
                        }
                        
                        if let duration = task.predicted_duration_in_minutes {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("\(duration) min")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
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
        .onHover { hovering in
            self.isHovering = hovering
        }
        .alert("Delete Task?", isPresented: $showDeleteConfirm, presenting: task) { _ in
            Button("Delete", role: .destructive) {
                onDeleteTask(task.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("Are you sure you want to delete this task?")
        }
    }
} 