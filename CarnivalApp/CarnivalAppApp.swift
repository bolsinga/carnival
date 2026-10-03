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
          CarnivalView()
        }
        #if os(macOS) || os(iOS)
        .commands {
            // Added to the existing View menu (`CommandGroupPlacement
            // .toolbar` is one of its built-in anchors) rather than a
            // new top-level menu — macOS: shows up as a real menu bar
            // item there. iPadOS: not visible on its own, but
            // discoverable (and usable) as a hardware keyboard
            // shortcut, same as the Mac's.
            // `commands(content:)`/`CommandGroup`/`keyboardShortcut(_:
            // modifiers:)` are all unavailable on tvOS (confirmed by
            // trying — its docs mention key commands here, but the SDK
            // disagrees), which already has its own Siri Remote input
            // anyway.
            CommandGroup(after: .toolbar) {
                Button("Toggle Ride") {
                    NotificationCenter.default.post(name: .carnivalToggleCamera, object: nil)
                }
                .keyboardShortcut("t")  // defaults to the Command modifier: ⌘T
            }
        }
        #endif
    }
}
