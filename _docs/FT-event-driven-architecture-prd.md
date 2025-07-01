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

1.  **`AppAction` Enum:** Create a new Swift file `karen/AppAction.swift` containing an `enum` named `AppAction`. This enum will define all possible data-modifying operations.
    *   Examples: `updateTask`, `reorderTasks`, `updateTimeBlock`.
    *   For actions that modify existing data (e.g., `updateTask(oldValue: Task, newValue: Task)`), the action case **must** store both the old and new versions of the object. This is critical for the `undo` logic to work.
    *   Chat-related actions (`sendChatMessage`, `receiveChatMessage`, `showChatbotError`) should also be included but marked as non-undoable.

2.  **`AppStore` Class:** Create a new Swift `class` named `AppStore` by renaming the existing `StubBackend.swift` file to `AppStore.swift` and replacing its contents.
    *   This class will be the **single source of truth** for the application's state (`AppState`).
    *   It must be an `@MainActor @ObservableObject` to be used by SwiftUI views.
    *   It must contain the state as a `@Published private(set) var state: AppState` property to ensure all modifications go through the dispatch method.
    *   The store must be provided via `@EnvironmentObject` from the app's main entry point.

3.  **Action Dispatching:** The `AppStore` must have a `dispatch(_ action: AppAction)` method. This will be the only way to modify the application state.

4.  **View Refactoring:** 
    *   All SwiftUI views (`TaskListView`, `DailyScheduleView`, etc.) must be refactored to call `store.dispatch(...)` instead of directly modifying data.
    *   Views should receive the store via `@EnvironmentObject var store: AppStore`.
    *   Data properties in views should be changed from `@Binding` to `let` constants since views can no longer directly modify state.
    *   Views should pass closures down to child views for handling actions.

### Undo/Redo Logic

5.  **Undo/Redo Stacks:** The `AppStore` must maintain two private arrays: `undoStack: [AppAction]` and `redoStack: [AppAction]`.

6.  **Dispatch Logic:** When an undoable action is dispatched:
    *   Create the inverse action **before** applying the original action.
    *   Append the inverse action to the `undoStack`.
    *   Clear the `redoStack` completely.
    *   Apply the action's change to the `AppState`.

7.  **`undo()` Method:** The `AppStore` must provide an `undo()` method. When called, it must:
    *   Check if the `undoStack` is not empty.
    *   Remove the last action from the `undoStack`.
    *   Create the inverse of that action and append it to the `redoStack`.
    *   Apply the action from the undo stack to the `AppState`.

8.  **`redo()` Method:** The `AppStore` must provide a `redo()` method. When called, it must:
    *   Check if the `redoStack` is not empty.
    *   Remove the last action from the `redoStack`.
    *   Create the inverse of that action and append it to the `undoStack`.
    *   Apply the action from the redo stack to the `AppState`.

9.  **macOS Integration:** 
    *   The undo/redo commands must be added at the **app level** in `karenApp.swift` using the `.commands` modifier on the `WindowGroup`.
    *   Use `CommandGroup(replacing: .undoRedo)` to replace the default undo/redo menu items.
    *   The menu items must check `store.canUndo` and `store.canRedo` for their disabled state.
    *   The keyboard shortcuts (`Cmd+Z` and `Cmd+Shift+Z`) must be explicitly set.

### Feature-Specific Requirements

10. **Atomic Gestures:** 
    *   Continuous user gestures in `TimeBlockView` must use local `@State` variables to track drag/resize state during the gesture.
    *   The `TimeBlock` and `allBlocks` properties in `TimeBlockView` must be `let` constants, not bindings.
    *   The `AppAction` should only be dispatched when the gesture is completed (in `onEnded`).

11. **State Persistence:** 
    *   The `AppState` must be saved using the `.onChange(of: scenePhase)` modifier in `karenApp.swift`.
    *   Save when `scenePhase` becomes `.background`.
    *   The state must be saved to the Application Support directory as a JSON file.
    *   On app launch, `AppStore.load()` should attempt to load the saved state, falling back to sample data if none exists.
    *   Add a `sampleData()` static method to `AppState` as an extension in `Models.swift`.

12. **Inconsistent State Handling:** 
    *   In the `apply` method, use guard statements to check if objects exist before modification.
    *   If an object doesn't exist, call `triggerInconsistencyAlert()` and return early.
    *   Use `@Published` properties in `AppStore` for alert state: `showAlert: Bool` and `alertMessage: String?`.
    *   The alert should be attached to `ContentView` using the `.alert()` modifier.

### Implementation Details

13. **Inverse Action Calculation:** The `createUndoAction` method must handle:
    *   For `updateTask`: swap old and new values.
    *   For `reorderTasks`: calculate the reverse move considering the index shift.
    *   For `updateTimeBlock`: swap old and new values.
    *   Non-undoable actions should return themselves (though they won't be added to undo stack).

14. **Preview Support:** The `#Preview` macro in `ContentView` must provide the store via `.environmentObject(AppStore(initialState: AppState.sampleData()))`.

## 5. Non-Goals (Out of Scope)

*   **Chat Input Undo:** The undo/redo for typing text in the chat input field will be handled by the native text field component, not the global undo system.
*   **Chat History Undo:** Actions related to the chat history itself (sending or receiving messages) will **not** be undoable. Once a message appears in the chat, it is permanent for that session.
*   **UI State Undo:** Changes to the UI that don't affect core data, such as resizing panels, changing the window size, or scrolling, will not be undoable.
*   **No In-App Buttons:** We will not add any new Undo or Redo buttons to the application's UI. The menu bar is the only entry point.

## 6. Design Considerations

*   **UI:** The only required UI change is connecting the logic to the existing macOS `Edit` menu. The `Undo` and `Redo` menu items will be enabled or disabled based on whether the `undoStack` or `redoStack` are empty.
*   **Alerts:** The pop-up alert for inconsistent state should be a standard, native macOS alert dialog with a title (e.g., "Action Incomplete") and an "OK" button to dismiss.

## 7. Technical Considerations

*   **`AppStore`:** This will be the new central hub for state. It should be an `@MainActor @ObservableObject` class with a `@StateObject` instance created in `karenApp.swift`.
*   **`DailyScheduleView`:** The `ForEach` loop must iterate over the non-binding array: `ForEach(timeBlocks)` not `ForEach($timeBlocks)`.
*   **State Persistence:** Use Swift's `Codable` protocol to easily serialize `AppState` to a JSON file and deserialize it on launch. The file should be named `karen_appstate.json`.
*   **Chat Simulation:** The `sendChatMessage` action should trigger a simulated bot response after a delay, dispatching a `receiveChatMessage` action.
