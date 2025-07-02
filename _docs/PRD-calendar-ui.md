# PRD: Visual Calendar (Phase 1 - Read-Only View)

## 1. Introduction/Overview

This document outlines the requirements for the first phase of the "Calendar" feature. The primary problem we are solving is the lack of a visual, time-based representation of a user's scheduled tasks. Users can create tasks, but cannot currently see them laid out on a calendar grid.

The goal of this phase is to build the foundational, **read-only** user interface for the calendar. This includes the main calendar view, the ability to switch between daily and weekly layouts, and navigation controls to change the visible date range. This feature will occupy a new panel on the right side of the main application window.

## 2. Goals

*   To successfully integrate a new, resizable calendar panel into the main application view.
*   To provide users with two distinct calendar layouts: a single-day view and a 7-day weekly view.
*   To implement intuitive date navigation controls, including next/previous buttons and a "Today" button, with corresponding keyboard shortcuts.
*   To accurately display existing scheduled tasks (`TimeBlock`s) from the application's state on the calendar grid.

## 3. User Stories

*   **As a user,** I want to see my scheduled tasks laid out on a daily calendar so I can understand my plan for the day at a glance.
*   **As a user,** I want to switch to a weekly view so I can get a high-level overview of my commitments for the entire week.
*   **As a user,** I want to easily navigate to past or future days and weeks to review what I've done or plan ahead.
*   **As a user,** I want to quickly jump back to the current day's or week's schedule with a single click.

## 4. Functional Requirements

### Panel and Layout
| ID  | Requirement                                                                                                                                                                                                                                                         |
|-----|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| FR-1| The application's `ContentView` must be updated to display a new calendar panel to the right of the Chat panel. The existing `DailyScheduleView` can be used as a starting point and should be renamed to a more generic name like `CalendarView`.                 |
| FR-2| The three main panels (Task List, Chat, Calendar) must be horizontally resizable. When the user hovers the mouse over the vertical divider between panels, the cursor must change to a resize cursor (`NSCursor.resizeLeftRight`).                                       |
| FR-3| All three panels must have a minimum width to ensure they remain usable when resized. A minimum width of 200px is suggested for each.                                                                                                                                 |
| FR-4| By default, the app should launch with the Calendar panel visible in "Daily" mode, with a width of `320px`.                                                                                                                                                         |

### Calendar Controls and Navigation
| ID  | Requirement                                                                                                                                                                                                                                                         |
|-----|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| FR-5| The calendar panel must contain a header with navigation controls.                                                                                                                                                                                                  |
| FR-6| The header must include a view mode toggle button. When in Daily mode, it shows "Weekly". When in Weekly mode, it shows "Daily". Clicking it switches between the two calendar layouts. The default view is **Daily**.                                               |
| FR-7| The header must include a "Previous" (`<`) button and a "Next" (`>`) button.                                                                                                                                                                                         |
| FR-8| In **Daily View**, the "Previous" and "Next" buttons must navigate backward and forward by one day at a time.                                                                                                                                                         |
| FR-9| In **Weekly View**, the "Previous" and "Next" buttons must navigate backward and forward by one week at a time (7 days).                                                                                                                                               |
| FR-10| The header must include a "Today" button between the "Previous" and "Next" buttons. Clicking "Today" must navigate the view to the current day (in Daily view) or the current week (in Weekly view).                                                               |
| FR-11| The following keyboard shortcuts must be implemented: `Cmd+Right` for "Next", `Cmd+Left` for "Previous", and `Cmd+T` for "Today".                                                                                                                                    |

### Visual Display
| ID  | Requirement                                                                                                                                                                                                                                                         |
|-----|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| FR-12| The **Daily View** must display a single column representing the selected day. The header for this column should display the full date (e.g., "Wednesday, July 3, 2025").                                                                                            |
| FR-13| The **Weekly View** must display seven columns, representing Monday to Sunday of the selected week. The header for each column must display the abbreviated day and date number (e.g., "Mon 1", "Tue 2").                                                          |
| FR-14| In the **Weekly View**, the column representing the current day ("today") must be highlighted. The date number in its header must have a solid, colored circular background, as seen in the provided screenshot.                                                     |
| FR-15| Both views must display a 24-hour grid, with horizontal lines and hour labels (e.g., "9 AM", "10 AM") running down the side. The existing `HourlyGridView` can be reused and adapted.                                                                                |
| FR-16| The view must render all `TimeBlock`s from the `store.state.timeBlocks` that fall within the visible date range. The vertical position and height of a block must correspond to its `start_time` and `actual_duration_in_minutes`. The `TimeBlockView` should be used. |
| FR-17| **Events Spanning Midnight:** An event that starts on one day and ends on the next (e.g., Mon 10 PM - Tue 2 AM) must be rendered as two distinct visual blocks: <br> 1. A block in the Monday column from 10 PM to 11:59 PM. <br> 2. A block in the Tuesday column from 12:00 AM to 2 AM. <br> Both visual pieces represent the same underlying `TimeBlock` data. |

## 5. Non-Goals (Out of Scope for this Phase)

*   **No Creating Events:** Users will **not** be able to create new `TimeBlock`s by dragging from the task list or clicking on the calendar.
*   **No Editing Events:** Users will **not** be able to move or resize existing `TimeBlock`s on the calendar. The view is strictly read-only.
*   **No Deleting Events:** Users will **not** be able to delete `TimeBlock`s from the calendar.
*   **No Chatbot Integration:** The chatbot will have no awareness of the calendar or its state.

## 6. Design Considerations

*   **"Today" Highlighting:** The current day in the weekly view should be highlighted as shown in the provided reference image. The date number should have a red circle background, and the text for that day may be a different color (e.g., white) to stand out.
*   **Component Reuse:** The existing `DailyScheduleView.swift` contains the `HourlyGridView` and `TimeBlockView` which should be reused and adapted for this new, more powerful calendar component.

## 7. Technical Considerations

*   **View State Management:** The state for the currently displayed date (`currentDate`) and the current view mode (`daily`/`weekly`) is transient UI state. It should be managed within the new `CalendarView` using `@State` variables, **not** in the global `AppStore`. No `AppIntent`s are needed for navigation.
*   **Panel Resizing:** Standard SwiftUI split views may not provide the desired resizing behavior and cursor-change functionality. A custom `HSplitView` implementation or a third-party library might be necessary to achieve the desired UX.
*   **Midnight-Spanning Logic:** The logic to calculate the layout for events that span midnight will be complex. It will involve calculating the geometry for two separate views from a single `TimeBlock` data model and placing them in different columns.
