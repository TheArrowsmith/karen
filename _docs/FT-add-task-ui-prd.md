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

1.  **Trigger Button:** A circular "+" button **must** be added to the `TaskListView` header, to the left of the "Tasks" title.
2.  **Popover Form:** Clicking the "+" button **must** open a `popover` view attached to the button. This popover will contain the form for adding a new task.
3.  **Form Fields:** The popover **must** contain the following input fields:
    *   **Title:** A text field. This field is **required**.
    *   **Description:** A larger text area. This field is **optional**.
    *   **Priority:** A dropdown menu (`Picker`) with options "Low", "Medium", "High", and a "None" default.
    *   **Predicted Duration:** A combination of a text field for a number and a dropdown (`Picker`) to select "minutes" or "hours". The input number must be a positive integer.
    *   **Deadline:** A date and time picker (`DatePicker`). The picker **must** be configured to prevent the user from selecting any date/time in the past.
4.  **Form Behavior:**
    *   The "Add Task" button inside the popover **must** be disabled if the "Title" field is empty (after trimming leading/trailing whitespace).
    *   Pressing the `Enter` key while any form field is focused **must** submit the form.
    *   Pressing the `Escape` key **must** close the popover without creating a task.
    *   After the popover is closed (either by submitting or canceling), all form fields **must** be reset to their default empty/initial state for the next time it is opened.
5.  **Task Creation Logic:**
    *   When the form is submitted, a new `Task` object **must** be created.
    *   User-provided text (Title, Description) **must** have leading and trailing whitespace removed.
    *   The new task **must** have `is_completed` set to `false` by default.
    *   An `AppAction.addTask(task: ..., index: 0)` action **must** be dispatched to the `AppStore`. The `index` will always be `0` to add the task to the top of the list.

#### **Part B: Delete Task**

1.  **Delete Trigger:** When a user hovers their mouse over a task item in the `TaskListView`, a trash can icon **must** appear in the top-right corner of that item.
2.  **Confirmation:** Clicking the trash can icon **must** display a system confirmation dialog (an `alert`). The dialog should ask the user "Are you sure you want to delete this task? This action can be undone."
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

*   The add task popover should be clean and simple. Use standard SwiftUI controls for the form fields.
*   The hover effect for the delete icon should be subtle. The icon should fade in and out smoothly.
*   Refer to `TaskItemView.swift` for existing styles to ensure the delete icon feels like a natural part of the UI.
*   Use a standard system `alert` for the delete confirmation to maintain consistency with the operating system.

### **7. Technical Considerations**

*   **Local State for Form:** The state of the add task form (e.g., the text being typed into the title field) should be managed locally within the `TaskListView` or its new popover subview using `@State` properties. It should **not** be part of the global `AppState` in the `AppStore`.
*   **Relevant Files:** The primary files to be modified will be:
    *   `TaskListView.swift` (for the UI)
    *   `AppAction.swift` (to define the new actions)
    *   `AppStore.swift` (to implement the logic for the new actions and their undo behavior)
*   **Undo/Redo is Critical:** Pay close attention to the implementation in `AppStore.swift` to ensure the `index` is correctly captured and used, preserving the list order perfectly when undoing/redoing actions.
