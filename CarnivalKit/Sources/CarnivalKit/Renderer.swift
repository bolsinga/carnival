import MetalKit
import os
import simd

/// Diagnostic only (the zero-size guard in `draw(in:)` below is the
/// actual fix) -- without this, a host handing `MetalView` a zero-size
/// drawable (observed in practice: System Settings' live Screen Saver
/// list thumbnail) left no trace of why rendering silently stopped,
/// since `CAMetalLayer`'s own `nextDrawable` failure is logged by
/// QuartzCore, not anything identifiable as ours.
private let rendererLogger = Logger(subsystem: "gdb.CarnivalKit", category: "Renderer")

/// Everything that can go wrong setting up `Renderer`'s GPU pipeline.
/// `Renderer.init` throws these instead of the `fatalError`s it used to --
/// a GPU/resource hiccup here shouldn't take down the whole host process,
/// particularly for `CarnivalScreenSaver`, which runs inside a shared
/// system process rather than its own app.
public enum RendererError: Error {
    case metalNotSupported
    case commandQueueCreationFailed
    case shaderLibraryLoadFailed
    case renderPipelineStateCreationFailed
    case depthStencilStateCreationFailed
    case meshBufferCreationFailed(String)
}

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
/// and draws the scene ported so far: the ground/mountains from
/// `StaticScene`, two tent instances from `Tent`, the roller coaster
/// track from `Coaster`, and the ferris wheel from `FerrisWheel` — all
/// from `drawScene` in the original carnival.c.
/// Equivalent of `View_Style`/`gStyle` in the original's main.c, now
/// exposed publicly as `CameraMode` on the `Carnival` model this holds
/// a reference to, rather than private state of its own — see
/// `Carnival.swift`. `View_Point` itself (a third `gStyle`, entered/
/// exited with `'s'`, translating the eye with arrow keys) isn't
/// ported as a `CameraMode` case — the iOS-only pause/look-around
/// feature (`Carnival.lookAround` below) covers the same
/// "pause and look around" idea with touch-first input instead, layered
/// on top of whichever of these two modes is active rather than being a
/// third mode of its own.
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    /// The single source of truth for which camera is showing —
    /// `carnival.camera` replaces what used to be this class's own
    /// private `cameraMode` state, read here but written only by
    /// `Carnival.toggleCamera()` (called directly by `MetalView`'s
    /// input handlers now, not proxied through a `Renderer` method).
    private let carnival: Carnival
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let groundAndMountains: MeshBuffers
    private let tent: MeshBuffers
    private let coaster: MeshBuffers
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

    /// Convenience accessor over `carnival.state`, written only by
    /// `Carnival.togglePause()` (called directly by `MetalView`'s input
    /// handlers, not proxied through a `Renderer` method) — this just
    /// saves spelling out `carnival.state == .animating` at every call
    /// site below.
    ///
    /// When `false`, elapsed time stops accumulating into
    /// `coasterPosition` below, freezing the coaster camera's progress.
    /// `clock.tick()` itself keeps running every frame regardless, so
    /// there's no big "catch up" jump when unpausing (the original
    /// instead stops calling Display entirely via `glutIdleFunc
    /// (gAnimating ? Idle : NULL)`, freezing the whole screen; this
    /// still renders continuously, just with a frozen camera, since
    /// MTKView doesn't have GLUT's "idle" concept to hook). See
    /// `wheelElapsedTime` for the equivalent gate on the ferris wheel.
    private var isAnimating: Bool { carnival.state == .animating }

    /// Drives the ferris wheel's own rendered rotation (and, since the
    /// ferris-view camera's angle is always computed directly from this
    /// too, its position). Gated by `carnival.wheelShouldTurn` rather
    /// than accumulating unconditionally — see there.
    private var wheelElapsedTime: Float = 0

    /// How far along the coaster track the camera currently is. Unlike
    /// the original's integer `gCurrentCoaster`, this accumulates
    /// continuously so it isn't tied to a fixed per-tick step — but
    /// `Int(coasterPosition)` is still used as a plain index below (no
    /// interpolation between points), matching the original's actual
    /// point-to-point jump motion, just paced by real time instead of a
    /// frame-count throttle.
    private var coasterPosition: Float = 0

    private var aspectRatio: Float = 1

    /// How thick the coaster track and ferris wheel's rims/spokes/axle/
    /// supports render — see `TubeMesh` for why they're round tubes at
    /// all rather than actual `.line` primitives. The original's
    /// `glLineWidth` calls distinguished rails/cross-ties/struts with
    /// different widths (1px/2px/3px, per Coaster.swift's doc comment),
    /// but this just picks one radius for every tube, for now.
    private static let tubeRadius: Float = 0.0125
    /// Sides per tube's cross-section — enough for a reasonably round
    /// look at this thinness without excessive vertex count.
    private static let tubeSides = 8

    private static let baseFovyRadians: Float = 60 * .pi / 180

    /// Temporary, for diagnosing https://github.com/bolsinga/carnival/issues
    /// -- a screen saver preview occasionally goes black after several
    /// rapid-fire open/closes within the same long-lived host process,
    /// with nothing else in the system log to explain why. Identifies
    /// each `Renderer` instance in that log, and `hasLoggedFirstDraw`
    /// below confirms whether a given instance's draw loop ever actually
    /// started.
    private let instanceID = UUID()
    private var hasLoggedFirstDraw = false

    init(device: MTLDevice, carnival: Carnival) throws(RendererError) {
        self.device = device
        self.carnival = carnival
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        // The pixel format here must match the MTKView's own
        // colorPixelFormat. MetalView.swift doesn't set one explicitly,
        // so this relies on MTKView's default of .bgra8Unorm.
        //
        // Bundle.module (not Bundle(for:)) since Shaders.metal now
        // compiles into this Swift package target's own resource
        // bundle, not the bundle backing Renderer's compiled code.
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module),
            let vertexFunction = library.makeFunction(name: "carnival_vertex"),
            let fragmentFunction = library.makeFunction(name: "carnival_fragment")
        else {
            throw RendererError.shaderLibraryLoadFailed
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        else {
            throw RendererError.renderPipelineStateCreationFailed
        }
        self.pipelineState = pipelineState

        // Equivalent of the original's glEnable(GL_DEPTH_TEST).
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        else {
            throw RendererError.depthStencilStateCreationFailed
        }
        self.depthStencilState = depthStencilState

        let coasterTrack = Coaster.computeTrack()
        let coasterMesh = TubeMesh.make(
            paths: Coaster.tubePaths(track: coasterTrack), radius: Self.tubeRadius,
            sides: Self.tubeSides)
        guard let groundAndMountains = MeshBuffers(device: device, mesh: StaticScene.groundAndMountains())
        else {
            throw RendererError.meshBufferCreationFailed("groundAndMountains")
        }
        guard let tent = MeshBuffers(device: device, mesh: Tent.mesh()) else {
            throw RendererError.meshBufferCreationFailed("tent")
        }
        guard let coaster = MeshBuffers(device: device, mesh: coasterMesh) else {
            throw RendererError.meshBufferCreationFailed("coaster")
        }
        self.groundAndMountains = groundAndMountains
        self.tent = tent
        self.coaster = coaster
        self.coasterTrack = coasterTrack

        super.init()
        rendererLogger.notice("init: \(self.instanceID, privacy: .public)")
    }

    deinit {
        rendererLogger.notice("deinit: \(self.instanceID, privacy: .public)")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            rendererLogger.notice(
                "drawableSizeWillChange: zero-size drawable (\(size.debugDescription, privacy: .public))"
            )
            return
        }
        aspectRatio = Float(size.width / size.height)
        // Undoes draw(in:)'s own pause below once the view is actually
        // given a real size -- e.g. a screen saver preview window
        // opening after starting out zero-sized.
        view.isPaused = false
    }

    private func draw(
        _ mesh: MeshBuffers, modelMatrix: float4x4, viewProjectionMatrix: float4x4,
        encoder: MTLRenderCommandEncoder
    ) {
        encoder.setRenderPipelineState(pipelineState)
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
        // A zero-size drawable (e.g. a screen saver preview view that
        // hasn't been laid out yet) can never produce a drawable --
        // `view.currentRenderPassDescriptor` below would just trigger an
        // endless, failing `CAMetalLayer nextDrawable` call every frame
        // forever. Stop MTKView's own draw loop entirely instead;
        // `mtkView(_:drawableSizeWillChange:)` above resumes it once a
        // real size arrives.
        guard view.drawableSize.width > 0, view.drawableSize.height > 0 else {
            view.isPaused = true
            rendererLogger.notice(
                "Pausing: view has a zero-size drawable (\(view.drawableSize.debugDescription, privacy: .public))"
            )
            return
        }

        if !hasLoggedFirstDraw {
            hasLoggedFirstDraw = true
            rendererLogger.notice("draw(in:) first successful call: \(self.instanceID, privacy: .public)")
        }

        deltaTime = clock.tick()
        if carnival.wheelShouldTurn {
            wheelElapsedTime += Float(deltaTime)
        }

        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        // The ferris wheel's geometry (and its rider's sight position)
        // is recomputed every frame regardless of which camera mode is
        // active — matching the original, which always calls
        // ferris(rotation, fwv) from drawScene every Display, keeping
        // gFWV fresh even while View_Coaster is active and the wheel
        // isn't being looked at.
        let wheelTranslation = SIMD3<Float>(-25.0, 6.5, 0.0)
        let wheelAngle = -Self.wheelAngularVelocity * wheelElapsedTime
        let wheelGeometry = FerrisWheel.geometry(angle: wheelAngle)
        // The ferris-view camera's own position — always tracks
        // wheelAngle directly, so the eye stays correctly placed
        // relative to carriage 6's seat geometry whether the wheel is
        // currently turning or (per wheelShouldTurn) held still.
        // drawScene: fwv[0] += -25.0; fwv[1] += 6.5; (z untouched,
        // matching the translation's own z offset of 0).
        let fwv =
            FerrisWheel.sight(angle: wheelAngle)
            + SIMD3<Float>(wheelTranslation.x, wheelTranslation.y, 0)

        if isAnimating {
            coasterPosition += Self.coasterPointsPerSecond * Float(deltaTime)
        }
        let numPts = coasterTrack.rollerIn.count - 1  // gRollPts
        let index = Int(coasterPosition) % numPts

        let eye: SIMD3<Float>
        let center: SIMD3<Float>
        switch carnival.camera {
        case .coaster:
            // eye sits at the rider's position (the midpoint between the
            // inner/outer rails), looking toward the next point along
            // the track.
            //   avgPts(rollerin[gCurrentCoaster], rollerout[gCurrentCoaster], rider);
            //   avgPts(rollerin[gCurrentCoaster + 1], rollerout[gCurrentCoaster + 1], nextrider);
            //   geyex = rider[0]; geyey = rider[1] + 0.5; geyez = rider[2];
            //   gcenterx = nextrider[0]; gcentery = nextrider[1] + 0.5; gcenterz = nextrider[2];
            //
            // NOTE ON `tilt`: the original's Idle also computes a `tilt`
            // variable (-15/-30/0 degrees) from gCurrentCoaster ranges,
            // right alongside this camera code, under the comment
            // "These set the tilt of the roller coaster rider to
            // simulate the momentum." Per the author (recalled while
            // porting this): the intent was to bank/tilt the camera
            // during turns, like a real coaster leaning into a curve.
            // But `tilt` is never actually applied to geyex/geyey/geyez
            // or gupx/gupy/gupz anywhere — it's computed and then
            // dropped, dead code in the original. Not reproduced here
            // (there's no observable behavior to match), but worth
            // implementing for real at some point — rotating `up`
            // around the eye→center axis by `tilt` degrees during the
            // ranges the original flagged would be the natural way to
            // do it now.
            let riderHeight = SIMD3<Float>(0, 0.5, 0)
            eye = coasterTrack.riderPosition(at: index) + riderHeight
            center = coasterTrack.riderPosition(at: index + 1) + riderHeight
        case .ferris:
            // eye sits at the wheel rider's position, looking a fixed
            // direction the whole ride, matching the original exactly
            // (gcenterx = gFWV[0] + 1.0, etc.) — see FerrisWheel.sight's
            // doc comment for why that fixed direction only became safe
            // to use literally again after fixing the eye position
            // itself, which is where the real bug was.
            //   geyex = gFWV[0]; geyey = gFWV[1]; geyez = gFWV[2];
            eye = fwv
            center = fwv + FerrisWheel.lookDirection
        }
        // Pause/look-around: rotate the gaze direction by
        // carnival.lookAround's yaw/pitch, keeping eye and the
        // eye->center distance fixed. lookAround is nil whenever not
        // paused (see Carnival.state's didSet), defaulting to the
        // identity LookAround() there, so this is a no-op while riding
        // on any platform.
        let lookAround = carnival.lookAround ?? LookAround()
        let baseDistance = distance(eye, center)
        let lookDirection = normalize(center - eye)
            .rotatedForLookAround(yaw: lookAround.yaw, pitch: lookAround.pitch)
        let adjustedCenter = eye + lookDirection * baseDistance
        let viewMatrix = float4x4.lookAt(eye: eye, center: adjustedCenter, up: SIMD3<Float>(0, 1, 0))

        // Reshape's own gluPerspective(0.1 * 600, width/height, 0.01, 150.0)
        // — fovy 60°, near 0.01, far 150. Reshape's aspect ratio is
        // actually broken in the original (integer division on the
        // `int width, height` parameters, truncating to ~1 for nearly any
        // real window), which this deliberately doesn't reproduce: it'd
        // distort the image on every one of the very different aspect
        // ratios this port actually targets, unlike the original's
        // single fixed-size GLUT window.
        // lookAround.zoom (also iOS pause/look-around only, otherwise 1
        // via the identity LookAround() above) narrows/widens this fovy
        // rather than moving the eye, so it can't clip through geometry
        // at whatever frozen vantage point the ride camera was paused at.
        let projectionMatrix = float4x4.perspective(
            fovyRadians: Self.baseFovyRadians / lookAround.zoom, aspect: aspectRatio, near: 0.01,
            far: 150)
        let viewProjectionMatrix = projectionMatrix * viewMatrix

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
        // persistent ring buffer. wheelGeometry/wheelTranslation were
        // already computed above (needed there for the ferris-view
        // camera's fwv, regardless of whether that mode is active).
        //   glPushMatrix(); glTranslatef(-25.0, 6.5, 0.0); ferris(rotation, fwv); glPopMatrix();
        let wheelModel = float4x4.translation(wheelTranslation)
        if let wheelTriangles = MeshBuffers(device: device, mesh: wheelGeometry.triangles) {
            draw(
                wheelTriangles, modelMatrix: wheelModel, viewProjectionMatrix: viewProjectionMatrix,
                encoder: encoder)
        }
        let wheelLineMesh = TubeMesh.make(
            paths: wheelGeometry.linePaths, radius: Self.tubeRadius, sides: Self.tubeSides)
        if let wheelLines = MeshBuffers(device: device, mesh: wheelLineMesh) {
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
