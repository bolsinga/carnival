//
//  CarnivalAppApp.swift
//  CarnivalApp
//
//  Created by Greg Bolsinga on 9/26/26.
//

import CarnivalKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct CarnivalAppApp: App {
    @State private var carnival = Carnival()
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some Scene {
        WindowGroup {
            CarnivalView(carnival: carnival)
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
                    carnival.toggleCamera()
                }
                .keyboardShortcut("t")  // defaults to the Command modifier: ⌘T
            }

            #if os(macOS)
            // In the File menu, right after "New Window" (the `.newItem`
            // placement's own anchor) -- opens the "Original OpenGL"
            // window below: a fresh NSOpenGLView (CarnivalGLView) showing
            // the same scene as the original 1992 GLUT `carnival` app,
            // calling straight into its untouched drawing code. Not
            // main.c itself: GLUT's glutMainLoop() never returns and
            // would block this app's own run loop, and its Key() calls
            // exit(0) on Escape, which would quit this whole app rather
            // than just close a window -- see CarnivalGLView.h/.m.
            CommandGroup(after: .newItem) {
                Button("OpenGL") {
                    openWindow(id: "original-opengl")
                }

                // Hands the embedded CarnivalScreenSaver.saver (copied into
                // Contents/Resources by the Carnival target's Copy Files
                // build phase) to the system's own screen-saver installer
                // flow -- the same one that runs when someone double-clicks
                // a downloaded .saver in Finder. Opening it this way needs
                // no sandbox entitlement: the OS does the privileged copy
                // into ~/Library/Screen Savers/, not this (sandboxed) app.
                Button("Install Screen Saver…") {
                    guard let url = Bundle.main.url(forResource: "Carnival", withExtension: "saver")
                    else { return }
                    NSWorkspace.shared.open(url)
                }
            }
            #endif
        }
        #endif

        #if os(macOS)
        // A dedicated Window, not WindowGroup: CarnivalGLView's state
        // (and the rollerin/rollerout arrays it reads) are effectively
        // singleton in spirit, so only one instance of this window ever
        // makes sense.
        Window("Original OpenGL", id: "original-opengl") {
            CarnivalGLViewRepresentable()
        }
        .defaultSize(width: 640, height: 480)
        #endif
    }
}
