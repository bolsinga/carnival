//
//  CarnivalAppApp.swift
//  CarnivalApp
//
//  Created by Greg Bolsinga on 9/26/26.
//

import CarnivalKit
import SwiftUI

@main
struct CarnivalAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS) || os(iOS)
        .commands {
            // macOS: shows up as a real menu bar item. iPadOS: not
            // visible on its own, but discoverable (and usable) as a
            // hardware keyboard shortcut, same as the Mac's.
            // `commands(content:)`/`CommandMenu`/`keyboardShortcut(_:
            // modifiers:)` are all unavailable on tvOS (confirmed by
            // trying — its docs mention key commands here, but the SDK
            // disagrees), which already has its own Siri Remote input
            // anyway.
            CommandMenu("Carnival") {
                Button("Toggle Camera") {
                    NotificationCenter.default.post(name: .carnivalToggleCamera, object: nil)
                }
                .keyboardShortcut("t", modifiers: [])
            }
        }
        #endif
    }
}
