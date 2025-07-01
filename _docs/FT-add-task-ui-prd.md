### **PRD: Add and Delete Task Functionality**

### **1. Introduction/Overview**

Currently, the "karen" application displays a predefined list of tasks, but users have no way to add their own tasks or remove completed/unwanted ones. This makes the core task management functionality incomplete.

This feature will introduce the ability for users to create new tasks via a user-friendly form and delete existing tasks from their list. These actions will be fully integrated with the application's existing undo/redo system to provide a robust and forgiving user experience.

### **2. Goals**

*   Enable users to create new tasks with a title and optional details (description, priority, deadline, duration).
*   Enable users to delete existing tasks with a confirmation step.
*   Ensure both "add" and "delete" operations are fully supported by the app's undo/redo functionality.
*   Maintain a consistent UI and UX with the existing application.

### **3. User Stories**

*   **As a user, I want to quickly add a new task to my list so I can capture what I need to do.**
*   **As a user, I want to add details like a priority and deadline to a new task so I can organize and plan my work effectively.**
*   **As a user, I want to remove tasks I no longer need so I can keep my task list clean and focused.**
*   **As a user, if I accidentally add or delete a task, I want to be able to undo my action so I don't lose my work or have to re-enter information.**

### **4. Functional Requirements**

The implementation is broken into three parts: Adding Tasks, Deleting Tasks, and the underlying State Management.

#### **Part A: Add Task**

1.  **Trigger Button:** A circular "+" button **must** be added to the `TaskListView` header, positioned immediately to the right of the "Tasks" title.
2.  **Popover Form:** Clicking the "+" button **must** open a `popover` view attached to the button. This popover will contain the form for adding a new task.
3.  **Form Layout:** The form **must** use a vertical layout where each label appears above its corresponding input field. Labels should be styled with a smaller font size and medium weight.
4.  **Form Fields:** The popover **must** contain the following input fields:
    *   **Title:** A text field with the label "Title" above it. This field is **required**. Do not include "(required)" in the label text.
    *   **Description:** A multi-line text editor (`TextEditor`) with the label "Description" above it. This field is **optional**. Do not include "(optional)" in the label text. The text editor should have a visible border and be approximately 60 points in height.
    *   **Priority:** A dropdown menu (`Picker`) with the label "Priority" above it. Options are "None" (default), "Low", "Medium", and "High". The picker itself should not show any label text.
    *   **Estimated Duration:** The label "Estimated Duration" **must** appear above a horizontal stack containing:
        *   A text field for entering a number (width approximately 60 points). Default value should be "30".
        *   A dropdown menu (`Picker`) to select "minutes" or "hours" (width approximately 100 points). Default to "minutes". Do not include a "Unit" label.
    *   **Deadline:** A date and time picker (`DatePicker`) with the label "Deadline" above it. The picker **must** be configured to prevent the user from selecting any date/time in the past. Default value should be 1 hour from the current time. The picker itself should not show any label text.
5.  **Form Behavior:**
    *   The "Add Task" button inside the popover **must** be disabled if the "Title" field is empty (after trimming leading/trailing whitespace).
    *   When submitting, the duration field **must** contain a valid positive integer. If not, the form should not submit.
    *   Pressing the `Enter` key while any form field is focused **must** submit the form.
    *   Pressing the `Escape` key **must** close the popover without creating a task.
    *   After the popover is closed (either by submitting or canceling), all form fields **must** be reset to their default empty/initial state for the next time it is opened.
6.  **Task Creation Logic:**
    *   When the form is submitted, a new `Task` object **must** be created.
    *   User-provided text (Title, Description) **must** have leading and trailing whitespace removed.
    *   If the Description field is empty after trimming whitespace, it should be stored as `nil` rather than an empty string.
    *   The new task **must** have `is_completed` set to `false` by default.
    *   Duration values **must** be converted to minutes (multiply hours by 60).
    *   An `AppAction.addTask(task: ..., index: 0)` action **must** be dispatched to the `AppStore`. The `index` will always be `0` to add the task to the top of the list.

#### **Part B: Delete Task**

1.  **Delete Trigger:** When a user hovers their mouse over a task item in the `TaskListView`, a trash can icon **must** appear in the top-right corner of that item.
2.  **Confirmation:** Clicking the trash can icon **must** display a system confirmation dialog (an `alert`) with:
    *   **Title:** "Delete Task?"
    *   **Message:** "Are you sure you want to delete this task?"
    *   **Buttons:** "Delete" (destructive style) and "Cancel"
3.  **Deletion Logic:** If the user confirms the deletion, the application **must** determine the current index of that task in the `state.tasks` array. It then **must** dispatch an `AppAction.deleteTask(task: ..., index: ...)` action to the store, passing the task object and its original index.

#### **Part C: State Management & Undo/Redo**

1.  **New App Actions:** The `AppAction` enum **must** be updated with two new cases:
    *   `case addTask(task: Task, index: Int)`
    *   `case deleteTask(task: Task, index: Int)`
2.  **`AppStore` Reducer Logic:** The `apply(_:)` method in `AppStore.swift` **must** be updated to handle these new actions:
    *   `addTask`: Inserts the new task into the `state.tasks` array at the specified `index`.
    *   `deleteTask`: Removes the task from the `state.tasks` array at the specified `index`.
3.  **Undo Logic:** The `createUndoAction(for:)` method in `AppStore.swift` **must** be updated to make these actions reversible:
    *   The inverse of `addTask(task: T, index: I)` **must** be `deleteTask(task: T, index: I)`.
    *   The inverse of `deleteTask(task: T, index: I)` **must** be `addTask(task: T, index: I)`. This will correctly restore a deleted task to its original position.

### **5. Non-Goals (Out of Scope)**

*   **Editing existing tasks.** Clicking on a task will not do anything new.
*   **Adding tasks at a specific position** in the list (e.g., via drag-and-drop). All new tasks are added to the top.
*   **Batch-deleting** multiple tasks at once.
*   **Any changes to the Chat or Daily Schedule views.** This work is confined to the `TaskListView` and the `AppStore`.

### **6. Design Considerations**

*   **Form Design:**
    *   The add task popover should have a clean vertical layout with consistent spacing (16 points between field groups).
    *   Each form field should have its label above the input with 4 points spacing.
    *   Labels should use `.system(size: 12, weight: .medium)` font styling.
    *   The popover should be 350 points wide with 20 points padding.
    *   Text fields should use `RoundedBorderTextFieldStyle()`.
    *   The description TextEditor should have a custom border using `RoundedRectangle` with `NSColor.separatorColor`.
*   **Delete Icon:**
    *   The trash icon should use `systemName: "trash.fill"` in red color.
    *   Font size should be 14 points.
    *   The icon should have 8 points padding.
    *   Use `.transition(.opacity.animation(.easeInOut(duration: 0.2)))` for smooth fade in/out.
*   **Alert Dialog:**
    *   Keep the alert simple with no app logo or extra information.
    *   Use destructive style for the Delete button.

### **7. Technical Considerations**

*   **Local State for Form:** The state of the add task form (e.g., the text being typed into the title field) should be managed locally within the `TaskListView` or its new popover subview using `@State` properties. It should **not** be part of the global `AppState` in the `AppStore`.
*   **Form Implementation:** Use `VStack` with proper alignment and spacing instead of `Form` to achieve the required vertical layout with labels above inputs.
*   **Platform Considerations:** This is a macOS app, so avoid iOS-specific modifiers like `.keyboardType()`.
*   **Store Access:** `TaskListView` should access the store directly via `@EnvironmentObject` instead of receiving tasks as a parameter. This simplifies the component hierarchy.
*   **Relevant Files:** The primary files to be modified will be:
    *   `TaskListView.swift` (for the UI and delete functionality)
    *   `AddTaskView.swift` (new file for the add task form)
    *   `AppAction.swift` (to define the new actions)
    *   `AppStore.swift` (to implement the logic for the new actions and their undo behavior)
    *   `ContentView.swift` (to update TaskListView initialization)
*   **Undo/Redo is Critical:** Pay close attention to the implementation in `AppStore.swift` to ensure the `index` is correctly captured and used, preserving the list order perfectly when undoing/redoing actions.
