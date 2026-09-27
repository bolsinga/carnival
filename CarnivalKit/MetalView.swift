import SwiftUI
import MetalKit
#if os(iOS)
import UIKit
#endif

/// Hosts an `MTKView` inside SwiftUI. `MTKView.delegate` is `weak`, so the
/// `Renderer` is retained by the `Coordinator` — without that, it would be
/// deallocated immediately after `make*View` returns and nothing would draw.
#if os(macOS)
struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        context.coordinator.makeConfiguredView()
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}

/// `MTKView` subclass so macOS can receive key events — plain `MTKView`
/// doesn't accept first responder by default. Equivalent of the
/// original's `glutKeyboardFunc(Key)`.
private final class KeyHandlingMTKView: MTKView {
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}
#else
struct MetalView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        context.coordinator.makeConfiguredView()
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
#endif

extension MetalView {
    // NSObject, so it can be a UIGestureRecognizer target on iOS (the
    // Objective-C target-action mechanism gesture recognizers use
    // requires it).
    final class Coordinator: NSObject {
        private var renderer: Renderer?

        func makeConfiguredView() -> MTKView {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }
            guard let renderer = Renderer(device: device) else {
                fatalError("Failed to create the Carnival renderer.")
            }
            self.renderer = renderer

            #if os(macOS)
            let view = KeyHandlingMTKView()
            view.onKeyDown = { [weak renderer] event in
                // Equivalent of the original's Key(unsigned char key, ...).
                // 's'/'z'/'x' (View_Point look-around) come with that
                // feature.
                switch event.charactersIgnoringModifiers {
                case "t":
                    renderer?.toggleCameraMode()
                case " ":
                    renderer?.togglePause()
                default:
                    break
                }
            }
            #else
            let view = MTKView()
            #if os(iOS)
            // Touch equivalent of the original's 't' (toggle coaster/
            // ferris camera) and ' ' (pause) keys — there's no keyboard
            // to assume on iOS/iPadOS. A swipe in either direction
            // toggles, same as 't' does: with exactly two camera modes,
            // "the other one" is the same regardless of swipe direction.
            let swipeLeft = UISwipeGestureRecognizer(
                target: self, action: #selector(handleCameraSwipe))
            swipeLeft.direction = .left
            view.addGestureRecognizer(swipeLeft)

            let swipeRight = UISwipeGestureRecognizer(
                target: self, action: #selector(handleCameraSwipe))
            swipeRight.direction = .right
            view.addGestureRecognizer(swipeRight)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handlePauseTap))
            view.addGestureRecognizer(tap)
            #endif
            #endif
            view.device = device
            view.delegate = renderer
            view.clearColor = MTLClearColor(red: 0.33, green: 0.67, blue: 1.0, alpha: 1.0)
            view.depthStencilPixelFormat = .depth32Float
            return view
        }

        #if os(iOS)
        @objc private func handleCameraSwipe(_ recognizer: UISwipeGestureRecognizer) {
            renderer?.toggleCameraMode()
        }

        @objc private func handlePauseTap(_ recognizer: UITapGestureRecognizer) {
            renderer?.togglePause()
        }
        #endif
    }
}
