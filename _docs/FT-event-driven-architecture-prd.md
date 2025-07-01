# PRD: Undo/Redo and Event-Driven Architecture

## 1. Introduction/Overview

### The Problem

Our application currently lacks an undo/redo feature. If a user makes an accidental change, such as marking the wrong task as complete or incorrectly moving a time block, there is no way to reverse the action. This can be frustrating and makes the application feel less polished and forgiving than standard desktop software.

### The Solution

We will implement a global undo/redo system that allows users to reverse and re-apply most data-changing actions. To achieve this, we will refactor the core data management logic of the app from a direct mutation model to an **event-driven architecture**. This means that instead of views directly changing the application's data, they will dispatch "actions" describing the intended change. A central "store" will process these actions, update the data, and maintain a history that we can traverse for undo and redo operations.

### Goal

The primary goal is to enhance user experience by providing a reliable and familiar undo/redo capability, making the application more robust and user-friendly.

## 2. Goals

*   Implement an "undo stack" to record and reverse user actions.
*   Implement a "redo stack" to re-apply actions that have been undone.
*   Integrate undo/redo with standard macOS menu bar items and keyboard shortcuts (`Cmd+Z`, `Cmd+Shift+Z`).
*   Refactor the application's data flow to use a central `AppStore` and a system of `AppAction`s.
*   Ensure the user's core data (tasks, schedule) is saved when the app closes and restored on launch.

## 3. User Stories

*   **As a user,** I want to undo marking a task as complete so that I can easily correct my mistake if I clicked the wrong one.
*   **As a user,** I want to undo moving a task in my to-do list so I can instantly return it to its previous position.
*   **As a user,** I want to undo a change I made to a time block on my schedule (moving or resizing it) so that I can revert to the previous schedule if I'm not happy with the change.
*   **As a user,** after undoing an action, I want to be able to redo it so that I can re-apply the change if I decide I wanted it after all.

## 4. Functional Requirements

### Core Architecture Refactor

1.  **`AppAction` Enum:** Create a new Swift `enum` named `AppAction`. This enum will define all possible data-modifying operations.
    *   Examples: `updateTask`, `reorderTasks`, `updateTimeBlock`.
    *   For actions that modify existing data (e.g., `updateTask(oldValue: Task, newValue: Task)`), the action case **must** store both the old and new versions of the object. This is critical for the `undo` logic to work.

2.  **`AppStore` Class:** Create a new Swift `class` named `AppStore` that will replace the current `StubBackend`.
    *   This class will be the **single source of truth** for the application's state (`AppState`).
    *   It must be an `@ObservableObject` to be used by SwiftUI views.
    *   It must contain the `AppState` as a `@Published` property that is `private(set)` to ensure all modifications go through the dispatch method.

3.  **Action Dispatching:** The `AppStore` must have a `dispatch(_ action: AppAction)` method. This will be the only way to modify the application state.

4.  **View Refactoring:** All SwiftUI views (`TaskListView`, `DailyScheduleView`, etc.) must be refactored to call `store.dispatch(...)` instead of directly modifying data.

### Undo/Redo Logic

5.  **Undo/Redo Stacks:** The `AppStore` must maintain two private arrays: `undoStack: [AppAction]` and `redoStack: [AppAction]`.

6.  **Dispatch Logic:** When an undoable action is dispatched:
    *   Apply the action's change to the `AppState`.
    *   Append the action to the `undoStack`.
    *   Clear the `redoStack` completely.

7.  **`undo()` Method:** The `AppStore` must provide an `undo()` method. When called, it must:
    *   Check if the `undoStack` is not empty.
    *   Remove the last action from the `undoStack`.
    *   Apply the **inverse** of that action to the `AppState`. (e.g., for `updateTask`, it restores the `oldValue`).
    *   Append the action to the `redoStack`.

8.  **`redo()` Method:** The `AppStore` must provide a `redo()` method. When called, it must:
    *   Check if the `redoStack` is not empty.
    *   Remove the last action from the `redoStack`.
    *   Re-apply the action to the `AppState`.
    *   Append the action back to the `undoStack`.

9.  **macOS Integration:** The `undo()` and `redo()` methods must be connected to the standard macOS menu bar (`Edit > Undo`/`Redo`).
    *   The associated keyboard shortcuts (`Cmd+Z` and `Cmd+Shift+Z`) must work.
    *   The menu items must be automatically disabled when their respective stacks are empty.

### Feature-Specific Requirements

10. **Atomic Gestures:** Continuous user gestures, such as dragging or resizing a `TimeBlock` in the `DailyScheduleView`, must be treated as a single, atomic action. The `AppAction` should only be dispatched when the gesture is completed (e.g., on mouse-up).

11. **State Persistence:** The `AppState` (tasks and time blocks) must be saved to a file on disk when the app is about to close. This state must be reloaded when the app launches. The undo/redo history does **not** need to be saved.

12. **Inconsistent State Handling:** The system must gracefully handle cases where a background action (from the chatbot) tries to modify data that no longer exists (e.g., updating a task that the user just deleted).
    *   In the `AppStore`'s `apply` method, check if the target object exists before attempting a modification.
    *   If the object does not exist, **drop the action** (do not apply it).
    *   Present a standard pop-up alert to the user with a message like: "An automated action could not be completed because the related item was modified or deleted."

## 5. Non-Goals (Out of Scope)

*   **Chat Input Undo:** The undo/redo for typing text in the chat input field will be handled by the native text field component, not the global undo system.
*   **Chat History Undo:** Actions related to the chat history itself (sending or receiving messages) will **not** be undoable. Once a message appears in the chat, it is permanent for that session.
*   **UI State Undo:** Changes to the UI that don't affect core data, such as resizing panels, changing the window size, or scrolling, will not be undoable.
*   **No In-App Buttons:** We will not add any new Undo or Redo buttons to the application's UI. The menu bar is the only entry point.

## 6. Design Considerations

*   **UI:** The only required UI change is connecting the logic to the existing macOS `Edit` menu. The `Undo` and `Redo` menu items will be enabled or disabled based on whether the `undoStack` or `redoStack` are empty.
*   **Alerts:** The pop-up alert for inconsistent state should be a standard, native macOS alert dialog with a title (e.g., "Action Incomplete") and an "OK" button to dismiss.

## 7. Technical Considerations

*   **`AppStore`:** This will be the new central hub for state. It should be an `@MainActor @ObservableObject`.
*   **`DailyScheduleView`:** This view's drag-and-drop logic will need to be updated. Use local `@State` variables within its subviews to manage the visual position/size of a `TimeBlock` *during* a drag, and only dispatch the final `updateTimeBlock` action on gesture completion.
*   **State Persistence:** Use Swift's `Codable` protocol to easily serialize `AppState` to a JSON file and deserialize it on launch. A good location for this file is the app's Application Support directory.
*   **Alerts:** The alert mechanism can be implemented by adding `@Published` properties to the `AppStore` (e.g., `showAlert: Bool`, `alertMessage: String?`) and using the `.alert()` view modifier in the main `ContentView`.
