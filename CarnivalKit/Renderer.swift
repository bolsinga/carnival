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

/// A line list's vertex/index buffers on the GPU, drawn as triangles by
/// `carnival_thick_line_vertex` rather than an actual `.line` primitive
/// — see `ThickLineVertex`'s doc comment for why. Takes the same flat
/// list of segment-endpoint pairs `Coaster`/`FerrisWheel` already
/// produce (so neither needs to know anything about the thick-line
/// trick) and expands each pair into a 4-vertex, 2-triangle quad here.
private struct LineBuffers {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int

    init?(device: MTLDevice, vertices: [Vertex]) {
        precondition(
            vertices.count % 2 == 0, "LineBuffers expects a flat list of segment-endpoint pairs.")

        var thickVertices: [ThickLineVertex] = []
        var indices: [UInt16] = []
        thickVertices.reserveCapacity(vertices.count * 2)
        indices.reserveCapacity(vertices.count * 3)

        for segmentStart in stride(from: 0, to: vertices.count, by: 2) {
            let a = vertices[segmentStart]
            let b = vertices[segmentStart + 1]
            let base = UInt16(thickVertices.count)

            // Two vertices per endpoint (side -1/+1), so the vertex
            // shader can push each one sideways to form a quad.
            thickVertices.append(
                ThickLineVertex(
                    position: a.position, otherEndpoint: b.position, side: -1, color: a.color))
            thickVertices.append(
                ThickLineVertex(
                    position: a.position, otherEndpoint: b.position, side: 1, color: a.color))
            thickVertices.append(
                ThickLineVertex(
                    position: b.position, otherEndpoint: a.position, side: -1, color: b.color))
            thickVertices.append(
                ThickLineVertex(
                    position: b.position, otherEndpoint: a.position, side: 1, color: b.color))

            // Two triangles covering the quad (winding doesn't matter —
            // the pipeline has no back-face culling).
            indices.append(contentsOf: [base, base + 1, base + 2, base + 2, base + 1, base + 3])
        }

        guard
            let vertexBuffer = device.makeBuffer(
                bytes: thickVertices,
                length: MemoryLayout<ThickLineVertex>.stride * thickVertices.count,
                options: []
            ),
            let indexBuffer = device.makeBuffer(
                bytes: indices,
                length: MemoryLayout<UInt16>.stride * indices.count,
                options: []
            )
        else { return nil }
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        self.indexCount = indices.count
    }
}

/// `MTKViewDelegate` that clears the frame to the carnival's sky-blue
/// background (matching the original `glClearColor(0.33, 0.67, 1.0, 1.0)`)
/// and draws the scene ported so far: the ground/mountains from
/// `StaticScene`, two tent instances from `Tent`, the roller coaster
/// track from `Coaster`, and the ferris wheel from `FerrisWheel` — all
/// from `drawScene` in the original carnival.c.
/// Equivalent of `View_Style`/`gStyle` in the original's main.c.
/// `View_Point` itself (a third `gStyle`, entered/exited with `'s'`,
/// translating the eye with arrow keys) isn't ported as a `CameraMode`
/// case — the iOS-only pause/look-around feature (`lookYaw`/`lookPitch`/
/// `zoomScale` below) covers the same "pause and look around" idea with
/// touch-first input instead, layered on top of whichever of these two
/// modes is active rather than being a third mode of its own.
private enum CameraMode: Equatable {
    case coaster
    case ferris
}

final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    /// Separate pipeline for `carnival_thick_line_vertex` — a distinct
    /// vertex function (and vertex input layout, `ThickLineVertex`
    /// rather than `Vertex`) needs its own `MTLRenderPipelineState`;
    /// they share `depthStencilState` and the same fragment function.
    private let linePipelineState: MTLRenderPipelineState
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

    /// Equivalent of `gAnimating`. When `false`, elapsed time stops
    /// accumulating into `cameraWheelElapsedTime`/`coasterPosition`
    /// below, freezing the coaster camera's progress and (if riding it)
    /// the ferris camera's position — but `clock.tick()` itself keeps
    /// running every frame regardless, so there's no big "catch up"
    /// jump when unpausing (the original instead stops calling Display
    /// entirely via `glutIdleFunc(gAnimating ? Idle : NULL)`, freezing
    /// the whole screen; this still renders continuously, just with a
    /// frozen camera, since MTKView doesn't have GLUT's "idle" concept
    /// to hook). Notably, `wheelElapsedTime` below is deliberately
    /// exempt from this gate: pausing freezes the camera, not the world
    /// — the wheel itself keeps visibly turning while paused, the same
    /// way it would if you stepped out of the ride and just watched.
    private(set) var isAnimating = true

    /// Drives the ferris wheel's own rendered rotation. Always
    /// accumulates every frame regardless of `isAnimating` — see
    /// `isAnimating`'s doc comment above, and `cameraWheelElapsedTime`
    /// below.
    private var wheelElapsedTime: Float = 0

    /// Drives the ferris-view camera's position on the wheel
    /// specifically (via `FerrisWheel.sight(angle:)`), independently of
    /// the wheel's own rendered rotation (`wheelElapsedTime`, always
    /// live). Only accumulates while `isAnimating`, so pausing freezes
    /// a ferris-view camera's position even though the wheel it's
    /// riding keeps turning underneath it.
    private var cameraWheelElapsedTime: Float = 0

    /// How far along the coaster track the camera currently is. Unlike
    /// the original's integer `gCurrentCoaster`, this accumulates
    /// continuously so it isn't tied to a fixed per-tick step — but
    /// `Int(coasterPosition)` is still used as a plain index below (no
    /// interpolation between points), matching the original's actual
    /// point-to-point jump motion, just paced by real time instead of a
    /// frame-count throttle.
    private var coasterPosition: Float = 0

    /// Equivalent of `gStyle`. Defaults to `.coaster`, matching the
    /// original's default `gStyle = View_Coaster` (and the README:
    /// "you are first riding the roller coaster"). `toggleCameraMode()`
    /// switches it, wired to `'t'` on macOS, a swipe on iOS, and
    /// left/right arrow presses on tvOS.
    private var cameraMode: CameraMode = .coaster

    private var aspectRatio: Float = 1

    /// The drawable's size in pixels — `carnival_thick_line_vertex`
    /// needs this (unlike everything else here) to convert a desired
    /// pixel width into clip-space offsets. Updated alongside
    /// `aspectRatio`.
    private var viewportSize = SIMD2<Float>(1, 1)

    /// How wide the coaster track and ferris wheel's rims/spokes/axle/
    /// supports render, in pixels — the original's `glLineWidth` calls
    /// distinguished rails/cross-ties/struts with different widths
    /// (1px/2px/3px, per Coaster.swift's doc comment), but this just
    /// picks one width for everything drawn as a thick line, for now.
    private static let lineWidthInPixels: Float = 6

    /// Pause/look-around feature (macOS: two-finger trackpad drag; iOS:
    /// one-finger drag + pinch; tvOS: arrow presses nudge by a fixed
    /// step, there being no touch surface to pan/pinch on the remote —
    /// see `MetalView`): rotates the gaze
    /// direction and adjusts the field of view, while the eye itself
    /// stays exactly where the paused ride camera left it. The
    /// original's `View_Point` is a different feature (it translates
    /// the *eye* with arrow keys, and freezes `center`/`up` at whatever
    /// the previous camera had); this is a fresh take on the same
    /// underlying idea ("pause and look around"), not a literal port.
    /// Both only ever have an effect while paused: `togglePause()`
    /// resets them to their identity values the moment animation
    /// resumes, so unpausing always returns cleanly to the normal ride
    /// camera.
    private var lookYaw: Float = 0
    private var lookPitch: Float = 0
    private var zoomScale: Float = 1

    /// Keeps `lookPitch` well short of vertical, so the look-around
    /// right vector (`cross(gazeDirection, up)`) never degenerates.
    private static let maxLookPitch: Float = 80 * .pi / 180
    private static let minZoomScale: Float = 0.5
    private static let maxZoomScale: Float = 3.0
    private static let baseFovyRadians: Float = 60 * .pi / 180

    init?(device: MTLDevice) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue

        // The pixel format here must match the MTKView's own
        // colorPixelFormat. MetalView.swift doesn't set one explicitly,
        // so this relies on MTKView's default of .bgra8Unorm.
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle(for: Renderer.self)),
            let vertexFunction = library.makeFunction(name: "carnival_vertex"),
            let fragmentFunction = library.makeFunction(name: "carnival_fragment"),
            let thickLineVertexFunction = library.makeFunction(name: "carnival_thick_line_vertex")
        else { return nil }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        else { return nil }
        self.pipelineState = pipelineState

        // Same fragment function and attachment formats as above — just
        // a different vertex function/input layout for thick lines.
        let linePipelineDescriptor = MTLRenderPipelineDescriptor()
        linePipelineDescriptor.vertexFunction = thickLineVertexFunction
        linePipelineDescriptor.fragmentFunction = fragmentFunction
        linePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        linePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        guard
            let linePipelineState = try? device.makeRenderPipelineState(
                descriptor: linePipelineDescriptor)
        else { return nil }
        self.linePipelineState = linePipelineState

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
        viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    /// Equivalent of the `'t'` case in the original's `Key`: toggles
    /// between the coaster and ferris-wheel cameras. (The original also
    /// guards this with `if (gStyle != View_Point)`; `CameraMode` has no
    /// equivalent guard here since it only has these two cases, but
    /// `MetalView`'s iOS gesture delegate applies the analogous guard at
    /// the input layer instead, disabling the camera-toggle swipe while
    /// paused so it doesn't fight with the pause/look-around gestures.)
    func toggleCameraMode() {
        cameraMode = (cameraMode == .coaster) ? .ferris : .coaster
    }

    /// Equivalent of the `' '` (space) case in the original's `Key`:
    /// pauses/resumes the animation.
    func togglePause() {
        isAnimating.toggle()
        if isAnimating {
            // Resuming always returns to a clean, unmodified ride camera.
            lookYaw = 0
            lookPitch = 0
            zoomScale = 1
        }
    }

    /// Pause/look-around input (see `lookYaw`/`lookPitch` above). A
    /// no-op while animating — callers (macOS's pan gesture, iOS's
    /// gesture delegate, tvOS's `isAnimating` branch in `MetalView`)
    /// are expected to only forward this while paused (macOS has no
    /// gating of its own to enforce that, since it's already covered
    /// here), but this guards against it regardless.
    func adjustLookAround(deltaYaw: Float, deltaPitch: Float) {
        guard !isAnimating else { return }
        lookYaw += deltaYaw
        lookPitch = min(max(lookPitch + deltaPitch, -Self.maxLookPitch), Self.maxLookPitch)
    }

    /// Pause/look-around zoom input — iOS only (via pinch); neither
    /// macOS's trackpad pan nor tvOS's remote has a zoom gesture wired
    /// up, so they have no zoom control.
    /// `factor` is a multiplier on the current zoom (as
    /// `UIPinchGestureRecognizer.scale` naturally is): >1 zooms in
    /// (narrows the field of view), <1 zooms out.
    func adjustZoom(byFactor factor: Float) {
        guard !isAnimating else { return }
        zoomScale = min(max(zoomScale * factor, Self.minZoomScale), Self.maxZoomScale)
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

    private func draw(
        _ lines: LineBuffers, modelMatrix: float4x4, viewProjectionMatrix: float4x4,
        encoder: MTLRenderCommandEncoder
    ) {
        encoder.setRenderPipelineState(linePipelineState)
        var uniforms = ThickLineUniforms(
            modelViewProjectionMatrix: viewProjectionMatrix * modelMatrix,
            viewportSize: viewportSize,
            lineWidthInPixels: Self.lineWidthInPixels)
        encoder.setVertexBuffer(lines.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<ThickLineUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: lines.indexCount,
            indexType: .uint16,
            indexBuffer: lines.indexBuffer,
            indexBufferOffset: 0
        )
    }

    func draw(in view: MTKView) {
        deltaTime = clock.tick()
        // The wheel keeps visibly spinning even while paused (see
        // isAnimating's doc comment) — only the camera's own position
        // freezes.
        wheelElapsedTime += Float(deltaTime)
        if isAnimating {
            cameraWheelElapsedTime += Float(deltaTime)
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
        // The ferris-view camera's own position, computed from a
        // separately-paced (pause-freezable) angle rather than the
        // wheel's own live rendered angle above — see
        // cameraWheelElapsedTime's doc comment.
        // drawScene: fwv[0] += -25.0; fwv[1] += 6.5; (z untouched,
        // matching the translation's own z offset of 0).
        let cameraWheelAngle = -Self.wheelAngularVelocity * cameraWheelElapsedTime
        let fwv =
            FerrisWheel.sight(angle: cameraWheelAngle)
            + SIMD3<Float>(wheelTranslation.x, wheelTranslation.y, 0)

        if isAnimating {
            coasterPosition += Self.coasterPointsPerSecond * Float(deltaTime)
        }
        let numPts = coasterTrack.rollerIn.count - 1  // gRollPts
        let index = Int(coasterPosition) % numPts

        let eye: SIMD3<Float>
        let center: SIMD3<Float>
        switch cameraMode {
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
            // +1 in x — not toward any particular point, unlike the
            // coaster's forward-looking center.
            //   geyex = gFWV[0]; geyey = gFWV[1]; geyez = gFWV[2];
            //   gcenterx = gFWV[0] + 1.0; gcentery = gFWV[1]; gcenterz = gFWV[2];
            eye = fwv
            center = fwv + SIMD3<Float>(1, 0, 0)
        }
        // Pause/look-around (iOS and tvOS): rotate the gaze direction by
        // lookYaw/lookPitch, keeping eye and the eye->center distance
        // fixed. Both are 0 whenever not paused (see togglePause()), so
        // this is a no-op on macOS (no input ever changes them there)
        // and while riding on any platform.
        let baseDistance = distance(eye, center)
        let lookDirection = normalize(center - eye)
            .rotatedForLookAround(yaw: lookYaw, pitch: lookPitch)
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
        // zoomScale (also iOS pause/look-around only, otherwise 1)
        // narrows/widens this fovy rather than moving the eye, so it
        // can't clip through geometry at whatever frozen vantage point
        // the ride camera was paused at.
        let projectionMatrix = float4x4.perspective(
            fovyRadians: Self.baseFovyRadians / zoomScale, aspect: aspectRatio, near: 0.01, far: 150)
        let viewProjectionMatrix = projectionMatrix * viewMatrix

        // Each draw(...) call below sets its own pipeline state (mesh vs.
        // thick-line), since they differ; depthStencilState is the same
        // for both, so it's set just once here.
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
