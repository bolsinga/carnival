import MetalKit

/// Minimal `MTKViewDelegate` that clears the frame to the carnival's sky-blue
/// background (matching the original `glClearColor(0.33, 0.67, 1.0, 1.0)`).
/// This proves the Metal pipeline end-to-end before any scene geometry,
/// camera, or animation is ported over.
final class Renderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private var clock = AnimationClock()

    /// Seconds elapsed since the previous frame. Exposed now so the
    /// coaster and ferris wheel can later advance in world-units-per-
    /// second instead of being tied to how often `draw(in:)` happens to
    /// be called.
    private(set) var deltaTime: TimeInterval = 0

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No projection matrix yet — added once real scene geometry exists.
    }

    func draw(in view: MTKView) {
        deltaTime = clock.tick()

        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        encoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
