### **PRD: Task App UI with Interactive Daily Schedule**

**1. Introduction/Overview**
This document outlines the requirements for building the front-end user interface (UI) for a new desktop productivity application. The application will be built and tested against a temporary, local, stubbed backend to enable focused UI development.

The application’s layout will feature a central chat interface, flanked by a master task list on the left and an interactive daily schedule on the right. The daily schedule will be a visual, calendar-style view where users can directly manipulate scheduled time blocks via drag-and-drop.

**Goal:** To build a responsive and functional desktop application with a three-panel layout, an interactive daily schedule, and full integration with a predictable, local stub backend.

**2. Goals**
*   Implement the three-panel UI layout: Master Task List (left), Chat View (center), and Daily Schedule (right).
*   Develop a chat component where messages can be sent via a button or the Enter key.
*   Build a visual, hourly timeline for the Daily Schedule view.
*   Enable users to drag-and-drop and resize `TimeBlock`s within the Daily Schedule to intuitively manage their day.
*   Ensure all drag operations snap to 15-minute intervals and prevent overlapping blocks.
*   Integrate all UI components with a local stub backend that simulates application state changes.

**3. User Stories**
*   As a user, I want to see my master list of all tasks on the left, my chat conversation in the center, and my scheduled plan for the day on the right, so I have a complete overview at all times.
*   As a user, I want to type a message in the chat and press Enter to send it, for a faster workflow.
*   As a user, I want to see my day's schedule laid out visually against an hourly timeline, so I can easily understand my availability.
*   As a user, I want to drag a scheduled block from 10:00 AM to 2:00 PM to easily reschedule it.
*   As a user, I want to make a 1-hour appointment longer by dragging its bottom edge downwards, extending its duration.
*   As a user, when I resize a time block from 40 minutes to an hour, I want its new end time to snap cleanly to the nearest 15-minute mark.

**4. Functional Requirements**

**Layout & General**
1.  The application window must be divided into three persistent, visible panels in the following order:
    *   Panel 1: **Master Task List View** (Left)
    *   Panel 2: **Chat View** (Center)
    *   Panel 3: **Daily Schedule View** (Right)

**Chat View**
2.  The Chat View must contain a text input field and a "Send" button.
3.  The user must be able to send the message by pressing the Enter key while the input field is focused.
4.  The UI must send the user's text to the local `stubBackend.processUserMessage()` function.

**Daily Schedule View**
5.  The view must display a vertical timeline with 24 clearly marked, evenly-spaced hourly indicators (e.g., "8 AM", "9 AM", "10 AM").
6.  Each `TimeBlock` received from the backend must be rendered as a visual block/rectangle on this timeline. The block's vertical position and height must directly correspond to its `start_time` and `duration`.
7.  The user must be able to click and drag a `TimeBlock` to a new vertical position to change its `start_time`.
8.  The user must be able to click and drag the top edge of a `TimeBlock` to change its `start_time`.
9.  The user must be able to click and drag the bottom edge of a `TimeBlock` to change its end time (and thus, its duration).
10. All drag and resize operations must snap the resulting `start_time` and `end_time` to the nearest 15-minute increment (e.g., HH:00, HH:15, HH:30, HH:45).
11. `TimeBlock`s have no minimum duration.
12. The UI must prevent the user from dropping or resizing a `TimeBlock` in a way that would cause it to overlap with another existing `TimeBlock`.
13. Upon successful completion of a drag or resize operation, the UI must call a backend function, passing the `id` of the modified `TimeBlock` and its new `start_time` and `duration`.

**5. Non-Goals (Out of Scope)**
*   Implementing the real LangGraph AI logic.
*   Persisting tasks, time blocks, or timer state between application launches.
*   User authentication or cloud synchronization.
*   Horizontal scrolling in the Daily Schedule to view other days.

**6. Design Considerations**
*   **Daily Schedule Interactivity:** When the user hovers over a `TimeBlock`, the cursor should change to indicate it's movable. When hovering over the top or bottom edge, the cursor should change to a resize indicator (e.g., a vertical two-headed arrow).
*   **Visual Feedback:** During a drag operation, the UI should show a semi-transparent "ghost" of the block being moved. If the target position is invalid (i.e., would cause an overlap), the ghost block could turn red to provide immediate feedback.

**7. Technical Considerations**
*   The application must be built as a native macOS desktop application using **Swift** and **SwiftUI**.
*   The UI must be built to handle the two core data models: `Task` and `TimeBlock`.
*   A **stub backend function** must be created locally. In addition to the `processUserMessage` function, it must expose a new function to handle updates from the UI's drag-and-drop operations.

    ```swift
    // Pseudo-code for the stub backend
    class StubBackend: ObservableObject {
        var tasks: [Task]
        var timeBlocks: [TimeBlock]

        // Existing function for chat commands
        func processUserMessage(text: String) -> AppState { ... }

        // NEW function for UI-driven updates
        func updateTimeBlock(id: String, newStartTime: Date, newDuration: Int) -> AppState {
            // Find the TimeBlock by ID and update its properties.
            // ...
            // Return the new, complete AppState.
        }
    }
    ```
*   The Daily Schedule view will need to contain complex gesture-handling logic to manage the state of drag operations, calculate snapping, and perform collision detection before calling the backend.
