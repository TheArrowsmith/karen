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
            
            CommandGroup(after: .newItem) {
                Divider()
                Button("Clear Chat History...") {
                    store.dispatch(.requestClearChatHistory)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .newItem) {
                Button("Next Day/Week", action: {
                    NotificationCenter.default.post(name: .navigateCalendar, object: CalendarNavigationDirection.next)
                })
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Button("Previous Day/Week", action: {
                    NotificationCenter.default.post(name: .navigateCalendar, object: CalendarNavigationDirection.previous)
                })
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button("Go to Today", action: {
                    NotificationCenter.default.post(name: .navigateCalendar, object: CalendarNavigationDirection.today)
                })
                .keyboardShortcut("t", modifiers: .command)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                store.save()
            }
        }
    }
}
