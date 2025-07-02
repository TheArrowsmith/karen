//
//  karenApp.swift
//  karen
//
//  Created by George Millo on 01/07/2025.
//

import SwiftUI

@main
struct karenApp: App {
    @StateObject private var store = AppStore(initialState: AppStore.load())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo", action: {
                    store.undo()
                })
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!store.canUndo)
                
                Button("Redo", action: {
                    store.redo()
                })
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!store.canRedo)
            }
            
            CommandMenu("File") {
                Button("Clear Chat History...") {
                    store.dispatch(.requestClearChatHistory)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                store.save()
            }
        }
    }
}
