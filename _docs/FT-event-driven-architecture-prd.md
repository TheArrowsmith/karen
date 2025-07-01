# PRD: Undo/Redo and Event-Driven Architecture

## 1. Introduction/Overview

### The Problem

Our application currently lacks an undo/redo feature. If a user makes an accidental change, such as marking the wrong task as complete or incorrectly moving a time block, there is no way to reverse the action. This can be frustrating and makes the application feel less polished and forgiving than standard desktop software.

### The Solution

We will implement a global undo/redo system that allows users to reverse and re-apply most data-changing actions. To achieve this, we will build the core data management logic of the app using a robust **event-driven architecture**.

This architecture works in two stages:
1.  Instead of directly changing data, views will dispatch lightweight **"Intents"** that describe the desired change with minimal information (e.g., "delete the task with this ID").
2.  A central **"Store"** will receive this intent, look up the current state to gather all necessary details, and translate it into a fully-detailed **"Action"** (e.g., the complete task object and its position). This detailed action is then used to update the state and is recorded in a history that we can traverse for undo and redo operations.

### Goal

The primary goal is to enhance user experience by providing a reliable and familiar undo/redo capability, making the application more robust and user-friendly through a clean, decoupled architecture.

## 2. Goals

*   Implement an "undo stack" to record and reverse user actions.
*   Implement a "redo stack" to re-apply actions that have been undone.
*   Integrate undo/redo with standard macOS menu bar items and keyboard shortcuts (`Cmd+Z`, `Cmd+Shift+Z`).
*   Implement the application's data flow using a central `AppStore` and a two-layer system of lightweight `AppIntent`s that are translated into detailed, undoable `AppAction`s.
*   Ensure the user's core data (tasks, schedule) is saved when the app closes and restored on launch.

## 3. User Stories

*   **As a user,** I want to undo marking a task as complete so that I can easily correct my mistake if I clicked the wrong one.
*   **As a user,** I want to undo moving a task in my to-do list so I can instantly return it to its previous position.
*   **As a user,** I want to undo a change I made to a time block on my schedule (moving or resizing it) so that I can revert to the previous schedule if I'm not happy with the change.
*   **As a user,** after undoing an action, I want to be able to redo it so that I can re-apply the change if I decide I wanted it after all.

## 4. Functional Requirements

### 4.1. Core Architecture Components

1.  **`AppIntent` Enum:** Create a Swift file containing an `enum` named `AppIntent`. This enum defines all possible user-initiated commands.
    *   **Purpose:** To express *intent* from the UI with the *minimum information required*.
    *   Examples: `deleteTask(id: String)`, `toggleTaskCompletion(id: String)`, `updateTimeBlock(id: String, newStartTime: Date, newDuration: Int)`.
    *   The UI layer will exclusively dispatch these lightweight intents.

2.  **`AppAction` Enum:** Create a Swift file containing an `enum` named `AppAction`. This enum defines the detailed, hydrated representation of a state mutation.
    *   **Purpose:** To be the internal, fully-detailed "fact" of what changed. This is what gets recorded on the undo/redo stacks.
    *   For actions that modify existing data (e.g., `updateTask(oldValue: Task, newValue: Task)`), the action case **must** store both the old and new versions of the object. This is critical for the `undo` logic to work.
    *   Chat-related actions (`sendChatMessage`, `receiveChatMessage`, `showChatbotError`) should also be included but marked as non-undoable.

3.  **`AppStore` Class:** Create a Swift `class` named `AppStore`.
    *   This class will be the **single source of truth** for the application's state (`AppState`).
    *   It must be an `@MainActor @ObservableObject` to be used by SwiftUI views.
    *   It must contain the state as a `@Published private(set) var state: AppState` property.
    *   The store must be provided via `@EnvironmentObject` from the app's main entry point.

### 4.2. Intent Dispatch and Translation

4.  **Intent Dispatching:** The `AppStore` must have a public `dispatch(_ intent: AppIntent)` method. This is the only way for views to request a state change.

5.  **Intent-to-Action Translation:** Inside the `dispatch` method, the `AppStore` is responsible for:
    *   Receiving the `AppIntent`.
    *   Using the information from the intent (e.g., an object's `id`) to find the full object and its context (e.g., its index) from the current `AppState`.
    *   Constructing the corresponding detailed `AppAction` (e.g., `.deleteTask(task: foundTask, index: foundIndex)`).
    *   Passing this new `AppAction` to internal methods for recording and state mutation.

6.  **View Refactoring:**
    *   All SwiftUI views (`TaskListView`, `DailyScheduleView`, etc.) must be refactored to call `store.dispatch(...)` with the appropriate `AppIntent`.
    *   Views should receive the store via `@EnvironmentObject var store: AppStore`.
    *   Data properties in views should be `let` constants, not `@Binding`, since views do not directly modify state.
    *   Example: A delete button will call `store.dispatch(.deleteTask(id: task.id))`.

### 4.3. Undo/Redo Logic

7.  **Undo/Redo Stacks:** The `AppStore` must maintain two private arrays: `undoStack: [AppAction]` and `redoStack: [AppAction]`. These stacks store the detailed `AppAction`s, not the `AppIntent`s.

8.  **Action Recording Logic:** When an undoable `AppAction` is generated by the store:
    *   Create the inverse `AppAction` **before** applying the original action.
    *   Append the inverse action to the `undoStack`.
    *   Clear the `redoStack` completely.
    *   Apply the `AppAction`'s change to the `AppState`.

9.  **`undo()` Method:** The `AppStore` must provide an `undo()` method. When called, it must:
    *   Pop the last action from `undoStack`.
    *   Create its inverse and push it to `redoStack`.
    *   Apply the action from the undo stack to the `AppState`.

10. **`redo()` Method:** The `AppStore` must provide a `redo()` method. When called, it must:
    *   Pop the last action from `redoStack`.
    *   Create its inverse and push it to `undoStack`.
    *   Apply the action from the redo stack to the `AppState`.

11. **macOS Integration:**
    *   The undo/redo commands must be added at the app level using the `.commands` modifier.
    *   Use `CommandGroup(replacing: .undoRedo)` to replace the default menu items.
    *   The menu items must use `store.canUndo` and `store.canRedo` for their disabled state.
    *   The keyboard shortcuts (`Cmd+Z` and `Cmd+Shift+Z`) must be explicitly set.

### 4.4. Feature-Specific Requirements

12. **Atomic Gestures:**
    *   Continuous user gestures (`TimeBlockView` drag/resize) must use local `@State` variables.
    *   The `AppIntent` should only be dispatched when the gesture is completed (`onEnded`).

13. **State Persistence:**
    *   `AppState` must be saved to a JSON file in the Application Support directory when the app enters the background (`.onChange(of: scenePhase)`).
    *   On launch, `AppStore.load()` should load the saved state, falling back to sample data if loading fails.
    *   Add a `sampleData()` static method to `AppState`.

14. **Inconsistent State Handling:**
    *   During intent-to-action translation, the `dispatch` method must safely handle cases where an ID is not found (e.g., an action targets a deleted item).
    *   If an object doesn't exist, call `triggerInconsistencyAlert()` and return early.
    *   Use `@Published` properties in `AppStore` for alert state and show it in `ContentView` with `.alert()`.

## 5. Non-Goals (Out of Scope)

*   **Chat Input Undo:** The undo/redo for typing text in the chat input field will be handled by the native text field component, not the global undo system.
*   **Chat History Undo:** `AppIntent`s related to chat history (sending/receiving messages) will be translated to non-undoable `AppAction`s. Once a message appears, it is permanent for that session.
*   **UI State Undo:** Changes to UI that don't affect core data (resizing panels, scrolling) will not be undoable.
*   **No In-App Buttons:** We will not add any new Undo or Redo buttons to the application's UI. The menu bar is the only entry point.

## 6. Design Considerations

*   **UI:** The only required UI change is connecting the logic to the macOS `Edit` menu. The `Undo` and `Redo` menu items will be enabled or disabled based on `store.canUndo` and `store.canRedo`.
*   **Alerts:** The pop-up alert for inconsistent state should be a standard, native macOS alert dialog with a title like "Action Incomplete" and an "OK" button.

## 7. Technical Considerations

*   **`AppStore`:** This is the central hub for state. It will be an `@MainActor @ObservableObject` class instantiated as a `@StateObject` in `karenApp.swift`.
*   **State Persistence:** Use Swift's `Codable` protocol to serialize `AppState` to a JSON file named `karen_appstate.json`.
*   **Chat Simulation:** The `sendChatMessage` intent should trigger a simulated bot response after a delay, which in turn dispatches a `receiveChatMessage` action internally.
