# Acceptance Tests: Visual Calendar (Phase 1)

## 1. Purpose

This document provides a set of test cases to verify that the "Phase 1 - Read-Only Calendar" feature has been implemented correctly according to the Product Requirements Document (PRD).

## 2. Prerequisites

*   The application must be launched with the default sample data loaded (`AppState.sampleData()`). This data includes pre-existing tasks and scheduled `TimeBlock`s.
*   For Test Case `AT-12`, the tester will need to temporarily modify the sample data.

## 3. Test Cases

### 3.1. Main Layout and Resizing

| Test Case ID | Feature | Test Steps | Expected Result | Status (Pass/Fail) |
| :--- | :--- | :--- | :--- | :--- |
| **AT-01** | Panel Integration | 1. Launch the application. | The main window displays three vertical panels: Task List (left), Chat (center), and a new Calendar panel (right). | |
| **AT-02** | Panel Resizing | 1. Move the mouse cursor over the vertical divider between the Chat and Calendar panels. <br> 2. Click and drag the divider to the left and right. <br> 3. Repeat for the divider between the Task List and Chat panels. | 1. The cursor changes to a horizontal resize cursor (`↔`). <br> 2. The panels change width smoothly as the divider is dragged. | |
| **AT-03** | Minimum Panel Width | 1. Drag the divider between the Chat and Calendar panel as far left as it will go. <br> 2. Drag the divider between the Task List and Chat panel as far right as it will go. | The panels stop resizing when they reach a minimum width (approx. 200px) and cannot be made any smaller, ensuring content remains readable. | |

### 3.2. Calendar Navigation and Controls

| Test Case ID | Feature | Test Steps | Expected Result | Status (Pass/Fail) |
| :--- | :--- | :--- | :--- | :--- |
| **AT-04** | View Mode Toggle | 1. Launch the app. The calendar is in Daily view. <br> 2. In the calendar header, click the "Weekly" button in the segmented control. <br> 3. Click the "Daily" button. | 1. The calendar view switches from a single-day column to a 7-day (Mon-Sun) layout. <br> 2. The calendar view switches back to the single-day column layout. | |
| **AT-05** | Daily Navigation | 1. Ensure the calendar is in **Daily View**. <br> 2. Click the `>` (Next) button twice. <br> 3. Click the `<` (Previous) button twice. <br> 4. Click the "Today" button. | 1. The calendar moves forward by one day for each click, and the header date updates accordingly. <br> 2. The calendar moves backward to the original date. <br> 3. The calendar view returns to the current date. | |
| **AT-06** | Weekly Navigation | 1. Switch to **Weekly View**. <br> 2. Click the `>` (Next) button. <br> 3. Click the `<` (Previous) button. <br> 4. Click the "Today" button. | 1. The calendar moves forward by one full week (7 days), and the header date range updates. <br> 2. The calendar moves backward to the original week. <br> 3. The calendar view returns to the current week. | |
| **AT-07** | Keyboard Shortcuts | 1. In either Daily or Weekly view, press `Cmd + Right Arrow`. <br> 2. Press `Cmd + Left Arrow`. <br> 3. Press `Cmd + T`. | 1. The calendar navigates to the next day/week, identical to clicking the `>` button. <br> 2. The calendar navigates to the previous day/week, identical to clicking the `<` button. <br> 3. The calendar navigates to the current day/week, identical to clicking the "Today" button. | |

### 3.3. Visual Display and Data Rendering

| Test Case ID | Feature | Test Steps | Expected Result | Status (Pass/Fail) |
| :--- | :--- | :--- | :--- | :--- |
| **AT-08** | "Today" Highlighting | 1. Switch to **Weekly View**. <br> 2. Ensure the view is on the current week. | The column for the current day is visually distinct. The date number in its header has a solid red circular background, and the day's text (e.g., "WED") is red. | |
| **AT-09** | Hourly Grid | 1. Inspect any column in either Daily or Weekly view. | The column has a 24-hour vertical grid with horizontal lines and hour labels (e.g., "9 AM", "10 AM") on the left-hand side. | |
| **AT-10** | `TimeBlock` Display | 1. Launch the app and observe the calendar. The sample data contains tasks scheduled for today. | The `TimeBlock`s from the sample data are displayed as blue, rounded rectangles in the correct time slots. The block's title and time range are visible inside the rectangle. | |
| **AT-11** | `TimeBlock` Filtering | 1. Navigate to a day or week in the future where no tasks are scheduled. | The calendar grid for that date range is empty, with no blue `TimeBlock`s displayed. | |
| **AT-12** | Event Spanning Midnight | **Setup:** <br> 1. In the codebase, open `karen/Models.swift`. <br> 2. In `AppState.sampleData()`, add a new `TimeBlock` that starts at 10 PM tonight and lasts 240 minutes (4 hours). <br> `TimeBlock(task_id: tasks[0].id, start_time: Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600*22), actual_duration_in_minutes: 240)` <br> 3. Relaunch the app. <br><br> **Test:** <br> 1. Switch to **Weekly View**. <br> 2. Observe the columns for today and tomorrow. | 1. In today's column, a `TimeBlock` is rendered starting at 10 PM and extending to the bottom of the column (11:59 PM). <br> 2. In tomorrow's column, another `TimeBlock` is rendered starting at the top (12:00 AM) and extending to 2:00 AM. <br> 3. Both visual blocks display the same task title. | |
