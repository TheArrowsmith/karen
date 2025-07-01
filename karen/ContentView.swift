//
//  ContentView.swift
//  karen
//
//  Created by George Millo on 01/07/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack(spacing: 0) {
            // Panel 1: Task List (Left)
            TaskListView(
                onReorderTasks: { from, to in
                    store.dispatch(.reorderTasks(from: from, to: to))
                }
            )
            .frame(width: 320)
            
            Divider()

            // Panel 2: Chat (Center)
            ChatView(
                messages: store.state.chatHistory, // Pass read-only array
                onSendMessage: { text in
                    store.dispatch(.sendChatMessage(ChatMessage(text: text, sender: .user)))
                }
            )
            .frame(minWidth: 400)
            
            Divider()

            // Panel 3: Daily Schedule (Right)
            DailyScheduleView(
                timeBlocks: store.state.timeBlocks, // Pass read-only array
                tasks: store.state.tasks,
                onUpdateBlock: { blockId, newStartTime, newDuration in
                    guard let block = store.state.timeBlocks.first(where: { $0.id == blockId }) else { return }
                    var updatedBlock = block
                    updatedBlock.start_time = newStartTime
                    updatedBlock.actual_duration_in_minutes = newDuration
                    store.dispatch(.updateTimeBlock(oldValue: block, newValue: updatedBlock))
                }
            )
            .frame(width: 320)
        }
        .frame(minHeight: 600)
        .alert("Action Incomplete", isPresented: $store.showAlert, presenting: store.alertMessage) { _ in
            // Default "OK" button is fine
        } message: { message in
            Text(message)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore(initialState: AppState.sampleData()))
}
