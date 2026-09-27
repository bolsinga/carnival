import SwiftUI
import MetalKit
#if os(iOS) || os(tvOS)
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

#if os(tvOS)
/// `MTKView` subclass so tvOS can receive Siri Remote presses — a plain
/// `MTKView` isn't part of the focus engine (`canBecomeFocused` defaults
/// to `false`), so it would never receive `pressesBegan`. There's only
/// this one focusable view in the whole app, so it's focused
/// automatically without any extra focus-engine plumbing.
private final class RemoteHandlingMTKView: MTKView {
    var onPress: ((UIPress.PressType) -> Void)?

    override var canBecomeFocused: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            switch press.type {
            case .leftArrow, .rightArrow, .upArrow, .downArrow, .playPause:
                onPress?(press.type)
                handled = true
            default:
                break
            }
        }
        // Anything not handled (e.g. Menu) still needs to reach `super`
        // so the system's own behavior (like backgrounding the app) works.
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }
}
#endif
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
            #if os(tvOS)
            // Siri Remote equivalent of the original's 't' (toggle
            // coaster/ferris camera) and ' ' (pause) keys, plus the iOS
            // pause/look-around feature (pan rotates gaze, pinch zooms)
            // — the remote has no touch surface to pan/pinch on here, so
            // arrow presses (the remote's touch-surface swipes, or a
            // game controller's d-pad) nudge yaw/pitch by a fixed step
            // instead, mirroring the original's own View_Point, which
            // nudged the eye by a fixed `gStep` per arrow key press
            // (main.c's SpecialKey) rather than anything continuous.
            // Meaning depends on whether the ride is paused, same
            // split as iOS's swipe-vs-pan gating: while riding,
            // left/right toggle the camera (matching iOS's "either
            // direction toggles" design, since there are only two
            // modes); while paused, left/right/up/down nudge the
            // look-around yaw/pitch instead — `adjustLookAround` is a
            // no-op while riding, so this couldn't double as a camera
            // toggle even if it fired then. The dedicated Play/Pause
            // button always pauses/resumes, rather than a tap/select
            // click, since that's exactly what it's for.
            let view = RemoteHandlingMTKView()
            let remoteLookStepRadians: Float = 5 * .pi / 180
            view.onPress = { [weak renderer] type in
                guard let renderer else { return }
                if renderer.isAnimating {
                    switch type {
                    case .leftArrow, .rightArrow:
                        renderer.toggleCameraMode()
                    case .playPause:
                        renderer.togglePause()
                    default:
                        break
                    }
                } else {
                    switch type {
                    case .leftArrow:
                        renderer.adjustLookAround(deltaYaw: -remoteLookStepRadians, deltaPitch: 0)
                    case .rightArrow:
                        renderer.adjustLookAround(deltaYaw: remoteLookStepRadians, deltaPitch: 0)
                    case .upArrow:
                        renderer.adjustLookAround(deltaYaw: 0, deltaPitch: remoteLookStepRadians)
                    case .downArrow:
                        renderer.adjustLookAround(deltaYaw: 0, deltaPitch: -remoteLookStepRadians)
                    case .playPause:
                        renderer.togglePause()
                    default:
                        break
                    }
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
            // Gated (via `self` as delegate, below) to only fire while
            // not paused — mirrors the original's own
            // `if (gStyle != View_Point)` guard on 't'.
            let swipeLeft = UISwipeGestureRecognizer(
                target: self, action: #selector(handleCameraSwipe))
            swipeLeft.direction = .left
            swipeLeft.delegate = self
            view.addGestureRecognizer(swipeLeft)

            let swipeRight = UISwipeGestureRecognizer(
                target: self, action: #selector(handleCameraSwipe))
            swipeRight.direction = .right
            swipeRight.delegate = self
            view.addGestureRecognizer(swipeRight)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handlePauseTap))
            view.addGestureRecognizer(tap)

            // Pause/look-around: only meaningful while paused (gated via
            // `self` as delegate, below), since that's when the ride
            // camera holds still. A one-finger drag rotates the gaze
            // direction; a pinch narrows/widens the field of view. See
            // `Renderer.adjustLookAround`/`adjustZoom`.
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleLookPan))
            pan.delegate = self
            view.addGestureRecognizer(pan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleLookPinch))
            pinch.delegate = self
            view.addGestureRecognizer(pinch)
            #endif
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

        @objc private func handleLookPan(_ recognizer: UIPanGestureRecognizer) {
            // Reset each call so `translation` is always just this
            // increment, not the accumulated drag since the gesture began.
            let translation = recognizer.translation(in: recognizer.view)
            recognizer.setTranslation(.zero, in: recognizer.view)

            // Arbitrary but reasonable feel: dragging across the whole
            // screen width/height is roughly a quarter turn.
            let radiansPerPoint: Float = 0.005
            renderer?.adjustLookAround(
                deltaYaw: -Float(translation.x) * radiansPerPoint,
                deltaPitch: -Float(translation.y) * radiansPerPoint)
        }

        @objc private func handleLookPinch(_ recognizer: UIPinchGestureRecognizer) {
            renderer?.adjustZoom(byFactor: Float(recognizer.scale))
            // Reset each call for the same reason as handleLookPan's
            // setTranslation(.zero...) — `scale` is otherwise cumulative
            // since the gesture began, not just this increment.
            recognizer.scale = 1
        }
        #endif
    }
}

#if os(iOS)
extension MetalView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Swipe (camera toggle) only while riding; pan/pinch
        // (look-around/zoom) only while paused — see togglePause()'s
        // doc comment for why these two input modes don't mix. The tap
        // (pause toggle itself) has no delegate set, so it isn't gated.
        guard let isAnimating = renderer?.isAnimating else { return true }
        switch gestureRecognizer {
        case is UISwipeGestureRecognizer:
            return isAnimating
        case is UIPanGestureRecognizer, is UIPinchGestureRecognizer:
            return !isAnimating
        default:
            return true
        }
    }

    // Lets a drag and a pinch drive the look-around/zoom together, like
    // Photos/Maps' simultaneous pan-and-zoom.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        (gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIPinchGestureRecognizer)
            && (otherGestureRecognizer is UIPanGestureRecognizer
                || otherGestureRecognizer is UIPinchGestureRecognizer)
    }
}
#endif
