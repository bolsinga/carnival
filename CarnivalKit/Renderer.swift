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

/// A line list's vertex buffer on the GPU, ready to draw with
/// `.drawPrimitives(type: .line, ...)`. Unlike `MeshBuffers`, there's no
/// index buffer — the coaster track has too much point reuse across
/// disconnected segments (rails, cross-ties, struts) for a single index
/// list to help, so it's just a flat list of vertex pairs.
private struct LineBuffers {
    let vertexBuffer: MTLBuffer
    let vertexCount: Int

    init?(device: MTLDevice, vertices: [Vertex]) {
        guard
            let vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<Vertex>.stride * vertices.count,
                options: []
            )
        else { return nil }
        self.vertexBuffer = vertexBuffer
        self.vertexCount = vertices.count
    }
}

/// `MTKViewDelegate` that clears the frame to the carnival's sky-blue
/// background (matching the original `glClearColor(0.33, 0.67, 1.0, 1.0)`)
/// and draws the scene ported so far: the ground/mountains from
/// `StaticScene`, two tent instances from `Tent`, the roller coaster
/// track from `Coaster`, and the ferris wheel from `FerrisWheel` — all
/// from `drawScene` in the original carnival.c.
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let groundAndMountains: MeshBuffers
    private let tent: MeshBuffers
    private let coaster: LineBuffers
    private let coasterTrack: Coaster.Track

    /// The ferris wheel's angular velocity. Unlike everything ported so
    /// far, there's no faithful "original" rate to port: the original's
    /// `gRotation -= WHEELROT` only advanced once every `gThreshhold`
    /// (5000) raw idle callbacks, a frame-count-based throttle calibrated
    /// to whatever the 1992 hardware's incidental callback rate happened
    /// to be — not a real-world angular velocity. This is a freshly
    /// chosen, real-time rate (one revolution every 20 seconds) instead.
    private static let wheelAngularVelocity: Float = 2 * .pi / 20

    /// How fast the camera moves along the coaster track, in points per
    /// second. Same situation as `wheelAngularVelocity`: the original's
    /// `gCurrentCoaster++` per idle tick had no real-world rate to
    /// preserve, so this is a freshly chosen pace (a full 300-point lap
    /// every 20 seconds, matching the wheel's revolution time).
    private static let coasterPointsPerSecond: Float = 15

    private var clock = AnimationClock()

    /// Seconds elapsed since the previous frame.
    private(set) var deltaTime: TimeInterval = 0

    /// Total elapsed time. Currently only drives the ferris wheel's
    /// rotation.
    private var elapsedTime: Float = 0

    /// How far along the coaster track the camera currently is. Unlike
    /// the original's integer `gCurrentCoaster`, this accumulates
    /// continuously so it isn't tied to a fixed per-tick step — but
    /// `Int(coasterPosition)` is still used as a plain index below (no
    /// interpolation between points), matching the original's actual
    /// point-to-point jump motion, just paced by real time instead of a
    /// frame-count throttle.
    private var coasterPosition: Float = 0

    private var aspectRatio: Float = 1

    init?(device: MTLDevice) {
        self.device = device
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

        let coasterTrack = Coaster.computeTrack()
        guard
            let groundAndMountains = MeshBuffers(
                device: device, mesh: StaticScene.groundAndMountains()),
            let tent = MeshBuffers(device: device, mesh: Tent.mesh()),
            let coaster = LineBuffers(
                device: device, vertices: Coaster.lineVertices(track: coasterTrack))
        else { return nil }
        self.groundAndMountains = groundAndMountains
        self.tent = tent
        self.coaster = coaster
        self.coasterTrack = coasterTrack

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

    private func draw(
        _ lines: LineBuffers, modelMatrix: float4x4, viewProjectionMatrix: float4x4,
        encoder: MTLRenderCommandEncoder
    ) {
        var uniforms = Uniforms(modelViewProjectionMatrix: viewProjectionMatrix * modelMatrix)
        encoder.setVertexBuffer(lines.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lines.vertexCount)
    }

    func draw(in view: MTKView) {
        deltaTime = clock.tick()
        elapsedTime += Float(deltaTime)

        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        // The coaster ride-follow camera, equivalent of View_Coaster in
        // the original's Idle: eye sits at the rider's position (the
        // midpoint between the inner/outer rails), looking toward the
        // next point along the track.
        //   avgPts(rollerin[gCurrentCoaster], rollerout[gCurrentCoaster], rider);
        //   avgPts(rollerin[gCurrentCoaster + 1], rollerout[gCurrentCoaster + 1], nextrider);
        //   geyex = rider[0]; geyey = rider[1] + 0.5; geyez = rider[2];
        //   gcenterx = nextrider[0]; gcentery = nextrider[1] + 0.5; gcenterz = nextrider[2];
        //
        // NOTE ON `tilt`: the original's Idle also computes a `tilt`
        // variable (-15/-30/0 degrees) from gCurrentCoaster ranges, right
        // alongside this camera code, under the comment "These set the
        // tilt of the roller coaster rider to simulate the momentum."
        // Per the author (recalled while porting this): the intent was to
        // bank/tilt the camera during turns, like a real coaster leaning
        // into a curve. But `tilt` is never actually applied to
        // geyex/geyey/geyez or gupx/gupy/gupz anywhere — it's computed
        // and then dropped, dead code in the original. Not reproduced
        // here (there's no observable behavior to match), but worth
        // implementing for real at some point — rotating `up` around the
        // eye→center axis by `tilt` degrees during the ranges the
        // original flagged would be the natural way to do it now.
        coasterPosition += Self.coasterPointsPerSecond * Float(deltaTime)
        let numPts = coasterTrack.rollerIn.count - 1  // gRollPts
        let index = Int(coasterPosition) % numPts
        let rider = coasterTrack.riderPosition(at: index)
        let nextRider = coasterTrack.riderPosition(at: index + 1)
        let riderHeight = SIMD3<Float>(0, 0.5, 0)
        let eye = rider + riderHeight
        let center = nextRider + riderHeight
        let viewMatrix = float4x4.lookAt(eye: eye, center: center, up: SIMD3<Float>(0, 1, 0))

        // Reshape's own gluPerspective(0.1 * 600, width/height, 0.01, 150.0)
        // — fovy 60°, near 0.01, far 150. Reshape's aspect ratio is
        // actually broken in the original (integer division on the
        // `int width, height` parameters, truncating to ~1 for nearly any
        // real window), which this deliberately doesn't reproduce: it'd
        // distort the image on every one of the very different aspect
        // ratios this port actually targets, unlike the original's
        // single fixed-size GLUT window.
        let projectionMatrix = float4x4.perspective(
            fovyRadians: 60 * .pi / 180, aspect: aspectRatio, near: 0.01, far: 150)
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

        // coaster(rollPts) in drawScene is called bare, with no
        // glPushMatrix/glTranslatef wrapping it.
        draw(coaster, modelMatrix: float4x4(1), viewProjectionMatrix: viewProjectionMatrix, encoder: encoder)

        // The ferris wheel: unlike everything else, its geometry is
        // rebuilt fresh every frame (matching the original recomputing
        // each carriage's position from cos/sin(angle) every draw,
        // rather than rotating a static mesh with a matrix). Cheap
        // enough at this scene's scale — a few hundred vertices — to
        // just re-upload new buffers each frame rather than manage a
        // persistent ring buffer.
        //   glPushMatrix(); glTranslatef(-25.0, 6.5, 0.0); ferris(rotation, fwv); glPopMatrix();
        let wheelAngle = -Self.wheelAngularVelocity * elapsedTime
        let wheelGeometry = FerrisWheel.geometry(angle: wheelAngle)
        let wheelModel = float4x4.translation(SIMD3<Float>(-25.0, 6.5, 0.0))
        if let wheelTriangles = MeshBuffers(device: device, mesh: wheelGeometry.triangles) {
            draw(
                wheelTriangles, modelMatrix: wheelModel, viewProjectionMatrix: viewProjectionMatrix,
                encoder: encoder)
        }
        if let wheelLines = LineBuffers(device: device, vertices: wheelGeometry.lines) {
            draw(
                wheelLines, modelMatrix: wheelModel, viewProjectionMatrix: viewProjectionMatrix,
                encoder: encoder)
        }

        encoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
