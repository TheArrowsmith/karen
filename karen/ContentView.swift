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
        GeometryReader { geometry in
            ResizableHSplitView(
                leftInitialWidth: 400,
                totalWidth: geometry.size.width,
                rightMinWidth: 850 // Chat (450) + Calendar (400)
            ) {
                // Left Panel (Task List)
                TaskListView(
                    onReorderTasks: { from, to in
                        store.dispatch(.reorderTasks(from: from, to: to))
                    }
                )
            } right: {
                ResizableHSplitView(
                    leftInitialWidth: 450,
                    totalWidth: geometry.size.width > 400 ? geometry.size.width - 400 : 850,
                    rightMinWidth: 400
                ) {
                     // Center Panel (Chat)
                     ChatView(
                         messages: store.state.chatHistory,
                         loadingState: store.chatLoadingState,
                         onRetry: {
                             store.dispatch(.retryLastChatMessage)
                         },
                         onSendMessage: { text in
                             store.dispatch(.sendChatMessage(text: text))
                         }
                     )
                } right: {
                    // Right Panel (New Calendar)
                    CalendarView(
                        timeBlocks: store.state.timeBlocks,
                        tasks: store.state.tasks,
                        onToggleComplete: { taskId in
                            store.dispatch(.toggleTaskCompletion(id: taskId))
                        },
                        onUpdateTimeBlock: { blockId, newStartTime, newDuration in
                            store.dispatch(.updateTimeBlock(id: blockId, newStartTime: newStartTime, newDuration: newDuration))
                        },
                        onDeleteTimeBlock: { blockId in
                            store.dispatch(.deleteTimeBlock(id: blockId))
                        }
                    )
                }
            }
        }
        .frame(minWidth: 1250, minHeight: 600)
        .alert("Action Incomplete", isPresented: $store.showAlert, presenting: store.alertMessage) { _ in
            // Default "OK" button is fine
        } message: { message in
            Text(message)
        }
        .alert("Are you sure?", isPresented: $store.showClearChatConfirm, actions: {
            Button("Clear History", role: .destructive) {
                store.dispatch(.confirmClearChatHistory)
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("This will permanently delete your entire chat history. This action cannot be undone.")
        })
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore(initialState: AppState.sampleData()))
}
