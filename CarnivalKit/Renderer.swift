import MetalKit
import simd

/// `MTKViewDelegate` that clears the frame to the carnival's sky-blue
/// background (matching the original `glClearColor(0.33, 0.67, 1.0, 1.0)`)
/// and draws the static ground/mountains mesh from `StaticScene`, ported
/// from `drawScene`/`mountains` in the original carnival.c.
final class Renderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    private let indexCount: Int

    private var clock = AnimationClock()

    /// Seconds elapsed since the previous frame. Exposed now so the
    /// coaster and ferris wheel can later advance in world-units-per-
    /// second instead of being tied to how often `draw(in:)` happens to
    /// be called.
    private(set) var deltaTime: TimeInterval = 0

    /// Total elapsed time, used only to orbit the placeholder camera
    /// below. Once the real coaster/ferris camera-follow logic exists
    /// (driven by `deltaTime` directly, per `main.c`'s `Idle`), this
    /// placeholder — and the orbit — goes away.
    private var elapsedTime: Float = 0

    private var aspectRatio: Float = 1

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue

        // The pixel format here must match the MTKView's own
        // colorPixelFormat. MetalView.swift doesn't set one explicitly,
        // so this relies on MTKView's default of .bgra8Unorm.
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle(for: Renderer.self)),
            let vertexFunction = library.makeFunction(name: "carnival_vertex"),
            let fragmentFunction = library.makeFunction(name: "carnival_fragment")
        else { return nil }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        else { return nil }
        self.pipelineState = pipelineState

        // Equivalent of the original's glEnable(GL_DEPTH_TEST).
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        else { return nil }
        self.depthStencilState = depthStencilState

        let mesh = StaticScene.groundAndMountains()
        guard
            let vertexBuffer = device.makeBuffer(
                bytes: mesh.vertices,
                length: MemoryLayout<Vertex>.stride * mesh.vertices.count,
                options: []
            ),
            let indexBuffer = device.makeBuffer(
                bytes: mesh.indices,
                length: MemoryLayout<UInt16>.stride * mesh.indices.count,
                options: []
            )
        else { return nil }
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        self.indexCount = mesh.indices.count

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard size.height > 0 else { return }
        aspectRatio = Float(size.width / size.height)
    }

    func draw(in view: MTKView) {
        deltaTime = clock.tick()
        elapsedTime += Float(deltaTime)

        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        // Placeholder sightseeing camera: slowly orbits above the scene so
        // the ground and all three mountains (which span roughly
        // x/z in [-100, 100], y in [-1, 50]) are visible at once. Replaced
        // once the real coaster/ferris ride-follow camera exists.
        let radius: Float = 150
        let height: Float = 60
        let center = SIMD3<Float>(0, 10, 0)
        let angle = elapsedTime * 0.2
        let eye = SIMD3<Float>(radius * sin(angle), height, radius * cos(angle))
        let viewMatrix = float4x4.lookAt(eye: eye, center: center, up: SIMD3<Float>(0, 1, 0))
        let projectionMatrix = float4x4.perspective(
            fovyRadians: .pi / 3, aspect: aspectRatio, near: 0.1, far: 500)

        var uniforms = Uniforms(modelViewProjectionMatrix: projectionMatrix * viewMatrix)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthStencilState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )

        encoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
