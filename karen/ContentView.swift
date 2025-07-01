//
//  ContentView.swift
//  karen
//
//  Created by George Millo on 01/07/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var backend = StubBackend()

    var body: some View {
        HStack(spacing: 0) {
            // Panel 1: Task List (Left)
            TaskListView(
                tasks: backend.appState.tasks,
                onToggleComplete: backend.toggleTaskCompleted,
                onReorderTasks: backend.reorderTasks
            )
            .frame(width: 320)
            
            Divider()

            // Panel 2: Chat (Center)
            ChatView(
                messages: $backend.appState.chatHistory,
                onSendMessage: backend.processUserMessage
            )
            .frame(minWidth: 400)
            
            Divider()

            // Panel 3: Daily Schedule (Right)
            DailyScheduleView(
                timeBlocks: $backend.appState.timeBlocks,
                tasks: backend.appState.tasks,
                onUpdateBlock: backend.updateTimeBlock
            )
            .frame(width: 320)
        }
        .frame(minHeight: 600)
    }
}

#Preview {
    ContentView()
}
