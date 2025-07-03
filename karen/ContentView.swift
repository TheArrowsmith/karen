//
//  ContentView.swift
//  karen
//
//  Created by George Millo on 01/07/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settingsManager: SettingsManager // Get the settings manager
    
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
                    // Center Panel (Chat) - THIS IS THE MODIFIED PART
                    if settingsManager.apiKey.isEmpty {
                        ApiKeyPromptView()
                    } else {
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
                    }
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
                    .environmentObject(store)
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

// Add this new View at the bottom of ContentView.swift
struct ApiKeyPromptView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("OpenAI API Key Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please add your OpenAI API key in the settings to enable chat.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 280)
            
            Button("Open Settings") {
                // This is the standard way to open the Settings scene on macOS
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore(initialState: AppState.sampleData()))
}
