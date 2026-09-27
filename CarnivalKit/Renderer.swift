import MetalKit
import simd

/// A mesh's vertex/index buffers on the GPU, ready to draw.
private struct MeshBuffers {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int

    init?(device: MTLDevice, mesh: StaticScene.Mesh) {
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
    }
}

/// `MTKViewDelegate` that clears the frame to the carnival's sky-blue
/// background (matching the original `glClearColor(0.33, 0.67, 1.0, 1.0)`)
/// and draws the static parts of the scene ported so far: the ground/
/// mountains from `StaticScene`, and two tent instances from `Tent` —
/// all from `drawScene` in the original carnival.c.
final class Renderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let groundAndMountains: MeshBuffers
    private let tent: MeshBuffers

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

        guard
            let groundAndMountains = MeshBuffers(
                device: device, mesh: StaticScene.groundAndMountains()),
            let tent = MeshBuffers(device: device, mesh: Tent.mesh())
        else { return nil }
        self.groundAndMountains = groundAndMountains
        self.tent = tent

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard size.height > 0 else { return }
        aspectRatio = Float(size.width / size.height)
    }

    private func draw(
        _ mesh: MeshBuffers, modelMatrix: float4x4, viewProjectionMatrix: float4x4,
        encoder: MTLRenderCommandEncoder
    ) {
        var uniforms = Uniforms(modelViewProjectionMatrix: viewProjectionMatrix * modelMatrix)
        encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: mesh.indexCount,
            indexType: .uint16,
            indexBuffer: mesh.indexBuffer,
            indexBufferOffset: 0
        )
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
        let viewProjectionMatrix = projectionMatrix * viewMatrix

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthStencilState)

        draw(
            groundAndMountains, modelMatrix: float4x4(1), viewProjectionMatrix: viewProjectionMatrix,
            encoder: encoder)

        // The two tent placements from drawScene:
        //   glPushMatrix(); glTranslatef(17, -1.0, -8); glRotatef(-90, 0, 1, 0); tent(); glPopMatrix();
        //   glPushMatrix(); glTranslatef(-22, -1, -11); tent(); glPopMatrix();
        // OpenGL post-multiplies each new matrix, so the rotation (applied
        // second) affects the tent's own local vertices first, then the
        // translation moves the already-rotated tent into place.
        let tent1Model =
            float4x4.translation(SIMD3<Float>(17, -1.0, -8)) * float4x4.rotationY(radians: -.pi / 2)
        draw(tent, modelMatrix: tent1Model, viewProjectionMatrix: viewProjectionMatrix, encoder: encoder)

        let tent2Model = float4x4.translation(SIMD3<Float>(-22, -1, -11))
        draw(tent, modelMatrix: tent2Model, viewProjectionMatrix: viewProjectionMatrix, encoder: encoder)

        encoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
