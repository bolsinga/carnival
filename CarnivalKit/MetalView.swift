import SwiftUI
import MetalKit

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
    final class Coordinator {
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
            #endif
            view.device = device
            view.delegate = renderer
            view.clearColor = MTLClearColor(red: 0.33, green: 0.67, blue: 1.0, alpha: 1.0)
            view.depthStencilPixelFormat = .depth32Float
            return view
        }
    }
}
