# PRD: Edit Time Blocks

## Introduction/Overview

This document outlines the requirements for implementing an "Edit Time Block" feature in the calendar view. Currently, users can create and delete tasks and time blocks, but they cannot modify a time block's start time or duration after it has been created. This feature will introduce a popover form, allowing users to adjust the start and end times of a scheduled block.

The goal is to give users more flexibility in managing their schedule directly from the calendar, ensuring that any changes they make do not create scheduling conflicts.

## Goals

*   **Enable Modification:** Allow users to edit the start and end time of any existing time block.
*   **Prevent Conflicts:** Implement validation to prevent a time block from being saved if it overlaps with another existing block.
*   **Intuitive UX:** Integrate the editing workflow seamlessly into the existing calendar interface using a popover form.
*   **Maintain State Integrity:** Ensure that edits are integrated into the app's undo/redo system.

## User Stories

*   **As a user,** I want to change the start and end time of a scheduled time block so I can easily adjust my schedule when plans change.
*   **As a user,** I want to be prevented from scheduling two time blocks at the same time so that I don't accidentally create an invalid or conflicting schedule.
*   **As a user,** I want to be able to cancel my edits without saving them, in case I open the form by mistake or change my mind.

## Functional Requirements

1.  **Triggering the Edit Form:**
    *   1.1. When a user hovers their mouse over a `TimeBlockView` in the calendar, an "Edit" icon (a pencil) must appear in the top-right corner, next to the existing "Delete" icon.
    *   1.2. Clicking this "Edit" icon must open a popover containing the `TimeBlockFormView`.

2.  **Time Block Edit Form (`TimeBlockFormView`):**
    *   2.1. A new SwiftUI view named `TimeBlockFormView.swift` must be created. It can be modeled after the existing `TaskFormView.swift`.
    *   2.2. The form must display the title of the task associated with the time block. This title must be non-editable.
    *   2.3. The form must contain a `DatePicker` for the user to select the **Start Time**.
    *   2.4. The form must contain a `DatePicker` for the user to select the **End Time**.
    *   2.5. The form must include a "Save" button and a "Cancel" button.

3.  **Form Validation Logic:**
    *   3.1. The "Save" button must be disabled by default and only become enabled when the user has made valid changes.
    *   3.2. **Time Range Validity:** The "Save" button must be disabled if the selected End Time is not at least one minute after the selected Start Time.
    *   3.3. **Overlap Detection:** The "Save" button must be disabled if the time range `[start_time, end_time)` overlaps with any *other* existing time block in the `AppState`.
    *   3.4. **User Feedback:** If the "Save" button is disabled due to an overlap, a visible text hint (e.g., "Time conflicts with another block.") must be displayed within the form.

4.  **Saving and Cancelling:**
    *   4.1. **Saving:** When the "Save" button is clicked:
        *   The system must calculate the new duration in minutes from the selected Start Time and End Time.
        *   The system must dispatch the existing `AppIntent.updateTimeBlock(id: newStartTime: newDuration:)`.
        *   The popover must be dismissed.
    *   4.2. **Cancelling:** No changes should be saved if the user clicks the "Cancel" button, presses the `Escape` key, or clicks outside the popover to dismiss it.
    *   4.3. **No Confirmation on Cancel:** The form must close immediately upon cancellation without showing a "Discard Changes?" confirmation dialog.

## Non-Goals (Out of Scope)

*   The ability to change which `Task` is associated with the `TimeBlock`.
*   Drag-and-drop functionality to move or resize time blocks directly on the calendar grid.
*   Support for editing recurring time blocks (as they do not exist in the app yet).

## Design Considerations

*   **Iconography:** Use a standard SF Symbol for the edit icon, such as `pencil` or `pencil.circle.fill`.
*   **Form Layout:** The `TimeBlockFormView` should have a clean layout, with clear labels for "Start Time" and "End Time". Refer to `TaskFormView` for style consistency.
*   **Popover Behavior:** The popover should anchor to the edit icon that was clicked to open it.

## Technical Considerations

*   **File Creation:** A new file, `karen/TimeBlockFormView.swift`, will need to be created.
*   **File Modification:** The file `karen/TimeBlockView.swift` must be modified to add the hover state, edit icon, and the popover presentation logic.
*   **State Management:**
    *   No changes are required for the `TimeBlock` model in `karen/Models.swift`. The form will calculate the `actual_duration_in_minutes` from the user-provided end time.
    *   The form will need access to the `TimeBlock` being edited and the entire `store.state.timeBlocks` array to perform its overlap validation.
    *   The `AppIntent.updateTimeBlock` is already implemented in `AppStore.swift` and supports undo/redo. This existing intent should be reused.
*   **Validation Location:** All validation logic (time range validity, overlap detection) should be contained within the `TimeBlockFormView` to provide real-time feedback to the user.
