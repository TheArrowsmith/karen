# PRD: Interactive Calendar Task Scheduling

## Introduction/Overview

This document outlines the requirements for adding interactive task scheduling to the calendar view. Currently, users can see tasks and a calendar, but they cannot directly schedule tasks on the calendar. This feature will bridge that gap by allowing users to drag tasks from their list onto the calendar to create "Time Blocks," which represent scheduled work sessions. Users will also be able to directly manipulate these blocks on the calendar to adjust their schedule dynamically.

The goal is to make the calendar a fully interactive and intuitive planning tool, moving beyond a simple read-only display.

## Goals

*   **Enable direct manipulation:** Allow users to schedule tasks by dragging them onto the calendar.
*   **Improve planning workflow:** Provide tools to easily create, modify, and delete scheduled time blocks.
*   **Provide intuitive feedback:** Ensure the UI gives clear, real-time feedback for all user interactions (dragging, resizing, etc.).
*   **Maintain state integrity:** Ensure all calendar operations are robust, reversible, and correctly managed through the central app state.

## User Stories

*   **As a user, I want to** drag a task from my task list and drop it onto a specific time in my calendar **so that** I can quickly schedule a work session for that task.
*   **As a user, I want to** see a preview of where my task will be scheduled as I drag it over the calendar **so that** I know exactly what will happen when I release the mouse button.
*   **As a user, I want to** easily adjust the start and end time of a scheduled block by dragging its edges **so that** I can fine-tune my schedule without having to edit a form.
*   **As a user, I want to** quickly remove a scheduled block from my calendar by clicking a delete button on it **so that** I can clear up my schedule with minimal effort.
*   **As a user, I want to** undo any accidental changes I make to my calendar (like creating, deleting, or resizing a block) **so that** I can confidently manage my schedule without fear of making irreversible mistakes.

## Functional Requirements

### FR1: Drag and Drop Task Scheduling

1.  **Drag Initiation:** The user must be able to click and drag any `TaskItemView` from the `TaskListView`.
2.  **Drag Feedback:** While a task is being dragged, the original `TaskItemView` in the list must become semi-transparent to indicate it is the source of the drag operation.
3.  **Drop Target:** The user must be able to drop a dragged task onto both the `DailyView` and the `WeeklyView` of the calendar.
    *   In the `WeeklyView`, the system must correctly identify the target day based on the horizontal position (`x` coordinate) of the drop.
4.  **Time Block Creation:** Upon dropping a task, the system must create a new `TimeBlock` object associated with that task's ID.
5.  **Default Duration:** By default, a newly created `TimeBlock` must have a duration of 60 minutes.
6.  **Time Snapping:** The `start_time` of the new `TimeBlock` must snap to the nearest 15-minute interval (e.g., 9:00, 9:15, 9:30, 9:45) based on the vertical position (`y` coordinate) of the drop.

### FR2: "Smart Drop" Logic & Ghost Preview

1.  **Live Preview:** While dragging a task over the calendar, the system must display a semi-transparent "ghost" `TimeBlockView` that shows where the block will be placed and what its size will be upon dropping. This preview must update in real-time.
2.  **Scenario A (Perfect Fit):** If the user drags over an empty time slot that can accommodate the full 60-minute default duration, the ghost preview must show a 60-minute block. On drop, a 60-minute `TimeBlock` is created.
3.  **Scenario B (Shrink to Fit):** If the user drags over an empty time slot that is shorter than 60 minutes (i.e., between two existing blocks), the ghost preview must shrink to fit perfectly inside that gap.
    *   On drop, the created `TimeBlock`'s duration will be the size of the gap, rounded **down** to the nearest 15-minute increment.
    *   *Example:* Dropping into a 40-minute gap creates a 30-minute `TimeBlock`.
4.  **Scenario C (Find Next Available Slot):** If the user drags directly over an existing `TimeBlock`, the ghost preview must appear in the next available open time slot immediately following the conflicting block.
    *   On drop, the `TimeBlock` is created in that next available slot with the default 60-minute duration.
    *   If there are no subsequent available slots on that same day, the ghost preview must not appear, and the drop action must be ignored for that day.

### FR3: Resizing Time Blocks

1.  **Resize Cursor:** When the user hovers the cursor over the top or bottom edge of a `TimeBlockView`, the cursor must change to a resize cursor (`NSCursor.resizeUpDown`).
2.  **Start Time Adjustment:** Dragging the top edge of a `TimeBlock` must change its `start_time`.
3.  **End Time Adjustment:** Dragging the bottom edge of a `TimeBlock` must change its `actual_duration_in_minutes`.
4.  **Resize Snapping:** All resize operations (for both start and end times) must snap to 15-minute increments.
5.  **Collision Detection:** A `TimeBlock` cannot be resized to overlap with any other `TimeBlock`. The drag interaction must be constrained by the boundaries of adjacent blocks.
6.  **Minimum Duration:** The system must enforce a minimum `TimeBlock` duration of 15 minutes. It should not be possible to resize a block to be smaller than this.
7.  **Multi-Day Spanning:** A `TimeBlock` can be resized to extend past midnight. The system must continue to render it as a single block that visually spans two days.

### FR4: Deleting Time Blocks

1.  **Delete Control:** When the user hovers over a `TimeBlockView`, an 'X' icon must appear on the block.
2.  **Deletion:** Clicking the 'X' icon must immediately delete the `TimeBlock`.
3.  **No Confirmation:** No confirmation dialog is required for deletion.

### FR5: State Management

1.  **Centralized State:** All operations (creating, updating/resizing, and deleting `TimeBlock`s) must be handled by dispatching an `AppIntent` to the `AppStore`.
2.  **Undo/Redo:** All three operations (Create, Update, Delete) must be fully reversible via the application's existing Undo (Cmd+Z) and Redo (Cmd+Shift+Z) functionality. This requires creating and registering the appropriate inverse `AppAction`s on the undo stack.

## Non-Goals (Out of Scope)

*   **Directly creating a block on the calendar:** Users cannot click an empty time slot to create a new block. Creation only happens by dragging a task from the list.
*   **Moving an existing block:** This phase only includes resizing. Dragging the body of an existing `TimeBlock` to move it to a different time/day is not part of this implementation.
*   **Assigning a block to a different task:** It is not possible to change the `task_id` of an existing `TimeBlock`.
*   **Multi-task selection:** Users cannot drag multiple tasks at once.

## Design Considerations

*   **Ghost Preview:** The "ghost" block should use the standard `TimeBlockView` style but with reduced opacity (e.g., 50%) and a dashed border to distinguish it from existing, committed blocks.
*   **Delete Icon:** The 'X' icon for deletion should be placed in the top-right or top-left corner of the `TimeBlockView`, be clearly visible, and have a sufficiently large click target.
*   **Cursor States:** Use appropriate system cursors to provide feedback: `NSCursor.pointingHand` on the 'X' icon, `NSCursor.resizeUpDown` on the top/bottom edges of a block.

## Technical Considerations

*   **Drag and Drop:** Use SwiftUI's native `onDrag` modifier for the `TaskItemView` and a custom `DropDelegate` on the calendar day/week views to handle the drop logic.
*   **State for Ghost Preview:** The calendar view (`DailyView`/`WeeklyView`) will need a `@State` variable to hold the geometry and properties of the ghost block, which gets updated continuously by the `DropDelegate`'s `dropUpdated()` method.
*   **State Management:**
    *   New `AppIntent`s will be needed: `.createTimeBlock(TimeBlock)`, `.updateTimeBlock(id: String, updatedBlock: TimeBlock)`, `.deleteTimeBlock(id: String)`.
    *   New `AppAction`s for the `TimeBlock` model will need to be created to be stored on the undo/redo stack.
*   **Date and Geometry Calculations:** The logic for converting cursor coordinates to a snapped `Date` and for calculating collisions will be complex and should be encapsulated in helper functions. The existing `CalendarLayoutViews.swift` is a good place for this logic.
