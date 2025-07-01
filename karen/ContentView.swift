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
                messages: store.state.chatHistory,
                loadingState: store.chatLoadingState, // NEW
                onRetry: { // NEW
                    store.dispatch(.retryLastChatMessage)
                },
                onSendMessage: { text in
                    store.dispatch(.sendChatMessage(text: text))
                }
            )
            .frame(minWidth: 400)
            
            // Commenting out the Daily Schedule panel temporarily
            // Divider()

            // // Panel 3: Daily Schedule (Right)
            // DailyScheduleView(
            //     timeBlocks: store.state.timeBlocks, // Pass read-only array
            //     tasks: store.state.tasks,
            //     onUpdateBlock: { blockId, newStartTime, newDuration in
            //         store.dispatch(.updateTimeBlock(id: blockId, newStartTime: newStartTime, newDuration: newDuration))
            //     }
            // )
            // .frame(width: 320)
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
