# PRD: Drag-and-Drop Task Scheduling

## Introduction/Overview

This document outlines the requirements for a new "Drag-and-Drop Task Scheduling" feature. Currently, our application has a list of tasks and a separate calendar, but no direct, interactive way for a user to place a task onto the calendar.

This feature will allow users to click and drag a task from the "Tasks" list and drop it directly onto the calendar (in either Daily or Weekly view). This action will create a "Time Block" for that task, effectively scheduling it. The goal is to provide a fast, intuitive, and visual method for users to plan their time, significantly improving the application's core workflow.

## Goals

*   **Enhance User Workflow:** Provide a fluid, drag-and-drop interface for scheduling tasks, reducing clicks and manual data entry.
*   **Increase Interactivity:** Make the application more engaging by allowing direct manipulation of UI elements to plan the user's day/week.
*   **Implement "Smart" Scheduling:** Ensure the drop action is always predictable and helpful, intelligently handling cases where the desired time slot is occupied or too small. The user's drop action should never be rejected.

## User Stories

*   **As a user, I want to drag a task from my task list and drop it onto a specific time in my calendar,** so that I can quickly schedule a work session for that task.
*   **As a user, I want to see a live preview of where my task will be scheduled as I drag it over the calendar,** so that I know the outcome of my action before I release the mouse button.
*   **As a user, when I drop a task into a time slot that is too small or already occupied, I want the app to intelligently place the task for me,** so that I don't have to manually find a free spot.

## Functional Requirements

### FR1: Drag and Drop Foundation
1.1. **Drag Initiation:** Users must be able to initiate a drag operation on any task item in the `TaskListView`. The dragged item must carry the unique ID of the task (`Task.id`).
1.2. **Drop Target:** The main grid area of the calendar, in both `DailyView` and `WeeklyView`, must be configured as a valid drop target for tasks.
1.3. **State Update:** Upon a successful drop, a new `TimeBlock` object must be created and added to the application's state via the `AppStore`. The new `TimeBlock` must be linked to the dragged task via its `task_id`.

### FR2: Live "Ghost" Preview
2.1. While a task is being dragged over the calendar grid, a visual placeholder, or "ghost block," must be displayed in real-time to show the user where the `TimeBlock` will be created.
2.2. The ghost block's vertical position and height must update continuously as the user moves their cursor over the calendar.
2.3. **Time Snapping:** The ghost block's start time (its top edge) must "snap" to the nearest 15-minute interval on the calendar (e.g., 6:00, 6:15, 6:30, 6:45).

### FR3: "Smart Drop" Placement Logic
The system must determine where to place the `TimeBlock` based on the cursor's drop location and existing `TimeBlock`s. This logic is used for both the ghost preview and the final placement. The default duration for a new `TimeBlock` is **60 minutes**. The minimum allowed duration is **15 minutes**.

3.1. **Scenario A: The "Perfect Fit"**
    *   **Condition:** The user drops the task into an empty time slot that is large enough to accommodate the full 60-minute default duration.
    *   **Action:** A new `TimeBlock` is created at the snapped start time with a duration of 60 minutes.

3.2. **Scenario B: The "Shrink to Fit"**
    *   **Condition:** The user drops the task into an empty gap between two existing `TimeBlock`s that is smaller than 60 minutes but greater than or equal to the 15-minute minimum.
    *   **Action:** A new `TimeBlock` is created that perfectly fills the duration of the gap. For example, dropping into a 45-minute gap creates a 45-minute `TimeBlock`.

3.3. **Scenario C: The "Find Next Available Slot"**
    *   **Condition:** The user drops the task directly on top of an existing `TimeBlock`, or into a gap that is smaller than the 15-minute minimum.
    *   **Action:** The system will find the start time of the next available empty slot that is at least 15 minutes long, immediately following the conflicting `TimeBlock`. The new `TimeBlock` is created there with the full 60-minute default duration.

### FR4: Invalid Drop Handling
4.1. **No Available Slot:** If a user is dragging a task over a day that has no available time slots of at least 15 minutes remaining, the ghost block must disappear.
4.2. **"Not Allowed" Cursor:** When the ghost block is hidden per rule 4.1, the system cursor must change to the "not allowed" symbol (a circle with a slash) to indicate that a drop on this day is not possible. For all other valid drop scenarios, the standard system drag cursor will be used.

## Non-Goals (Out of Scope)

*   **Moving or Resizing Existing Blocks:** This feature only covers the creation of new `TimeBlock`s. Users will not be able to drag existing blocks to move or resize them.
*   **Dragging from Calendar to Task List:** This workflow is one-way: from the `TaskListView` to the `CalendarView`.
*   **Multi-Task Dragging:** Users can only drag and drop one task at a time.
*   **Visual Highlight for Target Day:** The day column in the `WeeklyView` will not change its appearance or background color when a task is dragged over it.

## Design Considerations

*   **Ghost Block Style:** The ghost preview block should be styled as a semi-transparent version of the standard blue `TimeBlock` and should have a dashed border to clearly distinguish it as a temporary placeholder.
*   **Existing Components:** This functionality will be built into the existing `CalendarView`, `DailyView`, and `WeeklyView` SwiftUI views.

## Technical Considerations

*   **SwiftUI Modifiers:** The implementation should leverage SwiftUI's `.onDrag` and `.onDrop` view modifiers.
*   **Passing Data:** The `Task.id` should be encoded and passed using an `NSItemProvider` during the drag operation.
*   **Transient State Management:** The real-time information about the drag operation (e.g., the task being dragged, the ghost block's calculated position and size) is temporary UI state. It should be managed locally within the `CalendarView` using `@State` variables, not stored in the global `AppStore`.
*   **Coordinate Space Logic:** A key task will be writing helper functions to convert a gesture's screen location (`CGPoint`) into a specific `Date` on the calendar grid. This logic must account for the view's scroll position, the `hourHeight` constant, and the specific day column (in weekly view).
*   **Future-Proofing:** While moving/resizing is out of scope, the code for collision detection and date calculation should be written in a modular and reusable way to make implementing those future features easier.

## Open Questions
*   None at this time. All clarifying questions have been resolved.
