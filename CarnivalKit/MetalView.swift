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

            let view = MTKView()
            view.device = device
            view.delegate = renderer
            view.clearColor = MTLClearColor(red: 0.33, green: 0.67, blue: 1.0, alpha: 1.0)
            view.depthStencilPixelFormat = .depth32Float
            return view
        }
    }
}
