### **PRD: Task App UI with Interactive Daily Schedule**

**1. Introduction/Overview**
This document outlines the requirements for building the front-end user interface (UI) for a new desktop productivity application. The application will be built and tested against a temporary, local, stubbed backend to enable focused UI development.

The application's layout will feature a central chat interface, flanked by a master task list on the left and an interactive daily schedule on the right. The daily schedule will be a visual, calendar-style view where users can directly manipulate scheduled time blocks via drag-and-drop.

**Goal:** To build a responsive and functional desktop application with a three-panel layout, an interactive daily schedule, and full integration with a predictable, local stub backend.

**2. Goals**
*   Implement the three-panel UI layout: Master Task List (left), Chat View (center), and Daily Schedule (right).
*   Develop a chat component where messages can be sent via a button or the Enter key, with full text editing capabilities.
*   Build a visual, hourly timeline for the Daily Schedule view with minimal left margin.
*   Enable users to drag-and-drop and resize `TimeBlock`s within the Daily Schedule to intuitively manage their day.
*   Ensure all drag operations snap to 15-minute intervals and prevent overlapping blocks.
*   Enable drag-and-drop reordering of tasks in the Master Task List.
*   Integrate all UI components with a local stub backend that simulates application state changes.

**3. User Stories**
*   As a user, I want to see my master list of all tasks on the left, my chat conversation in the center, and my scheduled plan for the day on the right, so I have a complete overview at all times.
*   As a user, I want to type a message in the chat and press Enter to send it, for a faster workflow.
*   As a user, I want to use standard text editing shortcuts (Cmd+A, Cmd+C, Cmd+V, Cmd+Z, etc.) in the chat input field.
*   As a user, I want to see my day's schedule laid out visually against an hourly timeline, so I can easily understand my availability.
*   As a user, I want to drag a scheduled block from 10:00 AM to 2:00 PM to easily reschedule it.
*   As a user, I want to make a 1-hour appointment longer by dragging its bottom edge downwards, extending its duration.
*   As a user, when I resize a time block from 40 minutes to an hour, I want its new end time to snap cleanly to the nearest 15-minute mark.
*   As a user, I want to reorder tasks in my task list by dragging them to new positions.

**4. Functional Requirements**

**Layout & General**
1.  The application window must be divided into three persistent, visible panels in the following order:
    *   Panel 1: **Master Task List View** (Left)
    *   Panel 2: **Chat View** (Center)
    *   Panel 3: **Daily Schedule View** (Right)

**Master Task List View**
2.  Tasks must be displayed in a list format with completion checkboxes, titles, descriptions, priorities, deadlines, and estimated durations.
3.  Users must be able to click anywhere on a task item to drag and reorder it within the list.
4.  The drag-and-drop operation must provide visual feedback during the drag.
5.  No separate drag handle icon should be shown - the entire task item must be draggable.

**Chat View**
6.  The Chat View must contain only a scrollable message area and an input area at the bottom. No header should be displayed.
7.  The Chat View must contain a text input field and a "Send" button.
8.  The text input field must support all standard macOS text editing shortcuts (Cmd+A for select all, Cmd+C/V for copy/paste, Cmd+Z for undo, etc.).
9.  The user must be able to send the message by pressing the Enter key while the input field is focused.
10. The UI must send the user's text to the local `stubBackend.processUserMessage()` function.

**Daily Schedule View**
11. The view must have minimal left margin (approximately 5px padding) to maximize usable space.
12. The view must display a vertical timeline with 24 clearly marked, evenly-spaced hourly indicators (e.g., "8 AM", "9 AM", "10 AM").
13. Each `TimeBlock` received from the backend must be rendered as a visual block/rectangle on this timeline. The block's vertical position and height must directly correspond to its `start_time` and `duration`.
14. The user must be able to click and drag a `TimeBlock` based on the click location:
    *   Clicking within 10 pixels of the top edge must allow dragging to change the `start_time` while keeping the end time fixed.
    *   Clicking within 10 pixels of the bottom edge must allow dragging to change the end time (and thus duration) while keeping the start time fixed.
    *   Clicking anywhere else on the block must allow dragging the entire block to a new time slot, preserving its duration.
15. When hovering over the top or bottom edge of a `TimeBlock`, the cursor must change to a vertical resize cursor (↕).
16. All drag and resize operations must snap the resulting `start_time` and `end_time` to the nearest 15-minute increment (e.g., HH:00, HH:15, HH:30, HH:45).
17. `TimeBlock`s have no minimum duration.
18. The UI must prevent the user from dropping or resizing a `TimeBlock` in a way that would cause it to overlap with another existing `TimeBlock`.
19. Upon successful completion of a drag or resize operation, the UI must call a backend function, passing the `id` of the modified `TimeBlock` and its new `start_time` and `duration`.

**5. Non-Goals (Out of Scope)**
*   Implementing the real LangGraph AI logic.
*   Persisting tasks, time blocks, or timer state between application launches.
*   User authentication or cloud synchronization.
*   Horizontal scrolling in the Daily Schedule to view other days.

**6. Design Considerations**
*   **Daily Schedule Interactivity:** The cursor changes and edge detection must be precise. A 10-pixel threshold for edge detection provides a good balance between ease of use and avoiding accidental resize operations.
*   **Visual Feedback:** During a drag operation, the UI should show a semi-transparent "ghost" of the block being moved. If the target position is invalid (i.e., would cause an overlap), the ghost block could turn red to provide immediate feedback.
*   **Task List Reordering:** The drag-and-drop in the task list should use native SwiftUI list reordering animations for smooth visual feedback.

**7. Technical Considerations**
*   The application must be built as a native macOS desktop application using **Swift** and **SwiftUI**.
*   The UI must be built to handle the two core data models: `Task` and `TimeBlock`.
*   A **stub backend function** must be created locally. In addition to the `processUserMessage` function, it must expose functions to handle updates from the UI's drag-and-drop operations.

    ```swift
    // Pseudo-code for the stub backend
    class StubBackend: ObservableObject {
        var tasks: [Task]
        var timeBlocks: [TimeBlock]

        // Existing function for chat commands
        func processUserMessage(text: String) -> AppState { ... }

        // Function for UI-driven time block updates
        func updateTimeBlock(id: String, newStartTime: Date, newDuration: Int) -> AppState {
            // Find the TimeBlock by ID and update its properties.
            // Return the new, complete AppState.
        }

        // Function for reordering tasks
        func reorderTasks(from: IndexSet, to: Int) {
            // Reorder tasks in the array
        }
    }
    ```
*   The Daily Schedule view will need to contain complex gesture-handling logic to manage the state of drag operations, calculate snapping, perform edge detection, and handle collision detection before calling the backend.
*   The time labels in the Daily Schedule should be compact (40px width) and right-aligned to minimize space usage.
