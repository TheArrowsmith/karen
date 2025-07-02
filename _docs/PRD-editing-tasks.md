# PRD: Edit Task Functionality

## Introduction/Overview

Currently, users can create, delete, and mark tasks as complete, but there is no way to modify a task's details (like its title, description, or priority) after it has been created. This is a significant gap in the application's core functionality.

This feature introduces the ability for users to edit an existing task. It will reuse the existing "Add Task" form components to maintain a consistent user experience and speed up development. The goal is to provide a simple and intuitive way for users to modify tasks directly from the task list.

## Goals

*   To allow users to edit all attributes of an existing task.
*   To seamlessly integrate the editing flow into the existing UI without introducing new, complex patterns.
*   To reuse the existing `AddTaskView` component to minimize implementation effort.
*   To prevent users from accidentally losing their changes when canceling an edit.

## User Stories

*   **As a user, I want to** correct a typo in a task's title **so that** my task list is accurate.
*   **As a user, I want to** change the priority and deadline of a task **so that** I can adjust my plan as circumstances change.
*   **As a user, I want to** be able to start editing a task but then cancel my changes without saving them **so that** I don't commit to a change I'm unsure about.

## Functional Requirements

1.  **Triggering the Edit View:**
    *   FR1.1: A user must be able to open the edit view by performing a single click on a `TaskItemView` in the `TaskListView`.
    *   FR1.2: The clickable area must be the entire task item's background area.
    *   FR1.3: Clicking on the "completion" checkbox or the "delete" trash icon must **not** trigger the edit view; it must only perform its original action.

2.  **Displaying the Edit View:**
    *   FR2.1: The edit view must be presented in a popover, anchored to the task item that was clicked. This should reuse the same presentation style as the "Add Task" button.

3.  **Refactoring `AddTaskView` into a Reusable `TaskFormView`:**
    *   FR3.1: The existing `AddTaskView` must be modified to operate in two modes: "Add" and "Edit".
    *   FR3.2: It must accept an optional `Task` object during initialization. If a `Task` is provided, the view enters "Edit Mode". If no `Task` is provided, it remains in "Add Mode".
    *   FR3.3: In "Edit Mode", the form fields (Title, Description, Priority, Duration, Deadline) must be pre-populated with the data from the provided `Task` object.

4.  **UI Changes in Edit Mode:**
    *   FR4.1: The title of the form must change from "Add New Task" to "Edit Task".
    *   FR4.2: The primary action button's text must change from "Add Task" to "Save Changes".

5.  **Saving Changes:**
    *   FR5.1: The "Save Changes" button must be disabled by default when the form first opens. It should only become enabled if the user modifies any of the form's data fields.
    *   FR5.2: Upon clicking "Save Changes", the application must dispatch the `.updateTask` `AppIntent` to the `AppStore`, providing the task's original ID and the new, updated task data from the form.
    *   FR5.3: After a successful save, the popover must be dismissed.

6.  **Canceling Changes:**
    *   FR6.1: The user can click the "Cancel" button to dismiss the popover.
    *   FR6.2: **If the user has not made any changes to the form data**, clicking "Cancel" must immediately dismiss the popover without any confirmation.
    *   FR6.3: **If the user has made changes to the form data**, clicking "Cancel" must first display a confirmation dialog (`.alert`).
    *   FR6.4: The confirmation dialog must have a title like "Discard Changes?" and a message like "You have unsaved changes. Are you sure you want to discard them?".
    *   FR6.5: The dialog must have two options: "Discard" (which dismisses the popover) and "Cancel" (which closes the dialog and leaves the edit popover open).

## Non-Goals (Out of Scope)

*   **Inline Editing:** This feature will not include editing tasks directly within the `TaskListView` (e.g., clicking the text and typing in the list itself). All edits will happen in the popover form.
*   **Bulk Editing:** There will be no functionality to edit multiple tasks at once.
*   **A separate, dedicated "Edit Task" screen:** We are explicitly reusing the existing popover component and not creating a new full-screen view for this.

## Design Considerations

*   **Click Target:** The main `HStack` within `TaskItemView` should be used to define the clickable area for opening the editor.
*   **Popover:** The existing `.popover` modifier used for adding a task should be reused for editing a task. The system will need a state variable in `TaskListView` to track which task is currently being edited.
*   **Confirmation Dialog:** Use the standard SwiftUI `.alert` modifier for the "discard changes" confirmation.

## Technical Considerations

*   **`TaskListView.swift`:**
    *   This view will need a new `@State` variable to hold the task that is currently being edited, for example: `@State private var taskToEdit: Task?`.
    *   The `.popover` will be controlled by this state variable. It will be presented when `taskToEdit` is not `nil`.

*   **`TaskItemView.swift`:**
    *   An `.onTapGesture` should be added to the view's main content area to set the `taskToEdit` state in the parent `TaskListView`.

*   **`AddTaskView.swift`:**
    *   This file will see the most changes. It should be refactored to handle both adding and editing.
    *   It will need a new `init` that takes the `Task` to be edited.
    *   It will need an internal `@State` variable to hold a copy of the original task so it can be compared against the user's current input to determine if any changes have been made (for FR5.1 and FR6.2).
    *   The `onAddTask: (Task) -> Void` callback should be made more generic, e.g., `onSave: (Task) -> Void`, as it will now be used for both creating and updating.

*   **`AppStore.swift`:**
    *   No changes are expected here. The existing `dispatch(.updateTask(...))` intent is sufficient and already handles state updates and the undo/redo stack.
