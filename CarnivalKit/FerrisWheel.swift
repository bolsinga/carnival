import simd

/// The ferris wheel, ported from ferris.c's `ferris`/`carriage`. Unlike
/// everything ported so far, this is genuinely dynamic: the original
/// recomputes each carriage's position from `cos`/`sin(angle)` fresh
/// every frame rather than rotating a static mesh with a matrix, so
/// `geometry(angle:)` does the same — call it once per frame with the
/// wheel's current rotation and rebuild the GPU buffers from the result
/// (see `Renderer`).
///
/// The wheel mixes filled polygons (the carriages) with lines (rims,
/// spokes, axle, supports), so it returns both a `StaticScene.Mesh` and
/// a list of `TubePath`s — the same two shapes `StaticScene`/`Tent` and
/// `Coaster` produce respectively.
enum FerrisWheel {
    struct Geometry {
        let triangles: StaticScene.Mesh
        let linePaths: [TubePath]

        /// Equivalent of the `sight` (called `fwv`/`gFWV` at the call
        /// site) the original's `ferris()` returns: the position of the
        /// carriage-6 rider, in the wheel's local space (`Renderer` adds
        /// the wheel's own world translation, matching `drawScene`'s
        /// `fwv[0] += -25.0; fwv[1] += 6.5;` right after calling
        /// `ferris`). Used by the ferris-view camera.
        let sight: SIMD3<Float>
    }

    /// 8 evenly spaced spokes (2π / 8), matching `SPOKE` in ferris.h.
    private static let spoke: Float = .pi / 4

    static func geometry(angle startAngle: Float) -> Geometry {
        let yellow = SIMD4<Float>(255, 255, 40, 255) / 255
        let steel = SIMD4<Float>(65, 74, 82, 255) / 255

        let center1 = SIMD3<Float>(0, 0, 1.5)
        let center2 = SIMD3<Float>(0, 0, -1.5)
        let axel1 = SIMD3<Float>(0, 0, 2.5)
        let axel2 = SIMD3<Float>(0, 0, -2.5)
        let b1 = SIMD3<Float>(-4.5, -7.0, 3.0)
        let b2 = SIMD3<Float>(4.5, -7.0, 3.0)
        let b3 = SIMD3<Float>(4.5, -7.0, -3.0)
        let b4 = SIMD3<Float>(-4.5, -7.0, -3.0)

        var polygons: [[Vertex]] = []
        var linePaths: [TubePath] = []
        func addLine(_ a: SIMD3<Float>, _ b: SIMD3<Float>, color: SIMD4<Float>) {
            linePaths.append(TubePath(points: [a, b], color: color))
        }

        // The wheel's two rims. gluDisk(..., GLU_SILHOUETTE) suppresses
        // the radial spoke lines a plain disk would tessellate, leaving
        // only the outer boundary circle.
        linePaths.append(
            circleOutline(center: SIMD3<Float>(0, 0, -1.5), radius: 6.0, slices: 32, color: yellow))
        linePaths.append(
            circleOutline(center: SIMD3<Float>(0, 0, 1.5), radius: 6.0, slices: 32, color: yellow))

        var angle = startAngle
        for _ in 0..<8 {
            let rimFront = SIMD3<Float>(6.0 * cos(angle), 6.0 * sin(angle), 1.5)
            let rimBack = SIMD3<Float>(rimFront.x, rimFront.y, -1.5)

            addLine(rimFront, center1, color: yellow)
            addLine(rimBack, center2, color: yellow)

            let carriage = carriage(wheel1: rimFront, wheel2: rimBack)
            polygons.append(contentsOf: carriage.quads)
            linePaths.append(contentsOf: carriage.linePaths)

            angle += spoke
        }

        addLine(axel1, axel2, color: steel)
        // Each 3-point line strip (b1 -> axel1 -> b2) is two segments.
        addLine(b1, axel1, color: steel)
        addLine(axel1, b2, color: steel)
        addLine(b3, axel2, color: steel)
        addLine(axel2, b4, color: steel)

        return Geometry(
            triangles: StaticScene.makeMesh(polygons), linePaths: linePaths,
            sight: sight(angle: startAngle))
    }

    /// The rider-sight (eye) position, without building the rest of the
    /// wheel's geometry — lets `Renderer` track the ferris-view camera's
    /// position from a different, independently-paced angle than the
    /// one driving the wheel's own (possibly still-spinning) rendered
    /// rotation, without paying for two full mesh rebuilds a frame.
    /// Carriage 6 is the rider — this is where `View_Ferris` sits, not
    /// a rendering-only detail — and since each carriage is `spoke`
    /// apart, its angle is always `startAngle + 6 * spoke` regardless
    /// of anything the rendering loop in `geometry(angle:)` does, so
    /// this needs none of that loop to compute it.
    ///
    /// Deliberately not a literal port of the original's own formula
    /// (`sight[0] = 6*cos(bottom - 0.1); sight[1] = 6*sin(bottom - 0.1)
    /// + 0.5`): that `bottom - 0.1` is the original's own comment-
    /// documented compensation for *its* particular update order (its
    /// `Idle()` returns this frame's sight using an angle anticipating
    /// the *next* frame's rotation, since it renders this frame's
    /// carriages with the *old* angle before advancing `gRotation`).
    /// This port has no such lag to compensate for — eye and wheel
    /// angle are always computed fresh from the same instant — so
    /// carrying that `-0.1` over would just reintroduce a mismatch for
    /// no reason. Worse, it's what caused a real bug: carriage 6's own
    /// seatback panel (`carriage(wheel1:wheel2:)`'s v1-v4) is built from
    /// the *unshifted* `bottom` angle, so the original's `-0.1`-shifted
    /// eye and the seat's own `bottom`-based position drift in and out
    /// of alignment as the wheel turns — for a real arc of the
    /// rotation, the eye ends up on the wrong side of its own seatback,
    /// staring at its solid color instead of "out and about" (confirmed
    /// against ferris.c's exact formulas, independent of anything about
    /// this port — a latent bug in the original design, not something
    /// introduced here).
    ///
    /// Building the eye from the *same* `bottom`-based rim position the
    /// seatback itself uses, offset only by fixed, angle-independent
    /// amounts, guarantees by construction that the eye stays a
    /// constant, comfortable distance in front of the seatback at
    /// *every* angle (verified: a full 360-degree sweep found a
    /// constant +0.5 clearance, not just "positive most of the time") —
    /// which in turn means the original's simple fixed look direction
    /// (`lookDirection` below) can go back to being exactly what it
    /// was, rather than something hand-tuned to dodge a moving target.
    static func sight(angle startAngle: Float) -> SIMD3<Float> {
        let bottom = startAngle + 6 * spoke
        return SIMD3<Float>(6.0 * cos(bottom), 6.0 * sin(bottom) + 0.5, 0.0)
    }

    /// Equivalent of the original's fixed look direction
    /// (`gcenterx = gFWV[0] + 1.0`, etc. in main.c) — the rider faces
    /// one constant world direction the whole ride, same as a real
    /// (non-swinging) carriage seat would. Safe to use literally again
    /// (see `sight(angle:)`'s doc comment for why it wasn't, before
    /// that fix): with the eye now always a constant distance in front
    /// of its own seatback, this scores a comfortable worst-case dot
    /// product of -0.71 against "directly toward the seatback" at every
    /// angle, instead of +0.23 (mostly toward it) with the original's
    /// `sight(angle:)` formula.
    static let lookDirection = SIMD3<Float>(1, 0, 0)

    /// Equivalent of `carriage(wheel1, wheel2)`. `wheel1`/`wheel2` always
    /// share x/y (only z differs, 1.5 vs -1.5), which is what lets the
    /// original's chained C assignments (`v1[0] = v2[0] = ... -= 0.5`)
    /// apply the same offset to every vertex sharing that value; ported
    /// here as plain per-vertex arithmetic instead.
    private static func carriage(
        wheel1: SIMD3<Float>, wheel2: SIMD3<Float>
    ) -> (quads: [[Vertex]], linePaths: [TubePath]) {
        let dkgrey = SIMD4<Float>(76, 66, 102, 255) / 255
        let dkrgrey = SIMD4<Float>(40, 40, 40, 255) / 255
        let blue = SIMD4<Float>(66, 66, 230, 255) / 255
        let steel = SIMD4<Float>(65, 74, 82, 255) / 255

        let side1 = SIMD3<Float>(wheel1.x, wheel1.y, 1.25)
        let side2 = SIMD3<Float>(wheel2.x, wheel2.y, -1.25)
        let x = wheel1.x
        let y = wheel1.y

        let v1 = SIMD3<Float>(x - 0.5, y + 0.5, 1.25)
        let v2 = SIMD3<Float>(x - 0.5, y + 0.5, -1.25)
        let v3 = SIMD3<Float>(x - 0.5, y - 0.5, -1.25)
        let v4 = SIMD3<Float>(x - 0.5, y - 0.5, 1.25)
        let v5 = SIMD3<Float>(x - 0.5, y + 0.25, 1.25)
        let v6 = SIMD3<Float>(x - 0.5, y + 0.25, -1.25)
        let v7 = SIMD3<Float>(x + 0.25, y + 0.25, 1.25)
        let v8 = SIMD3<Float>(x + 0.25, y + 0.25, -1.25)
        let v9 = SIMD3<Float>(x + 0.25, y - 0.5, 1.25)
        let v10 = SIMD3<Float>(x + 0.25, y - 0.5, -1.25)
        let v11 = SIMD3<Float>(x + 0.25, y - 0.7, 1.25)
        let v12 = SIMD3<Float>(x + 0.25, y - 0.7, -1.25)

        let quads: [[Vertex]] = [
            [v1, v2, v3, v4].map { Vertex(position: $0, color: dkgrey) },  // back of chair
            [v4, v3, v10, v9].map { Vertex(position: $0, color: dkrgrey) },  // seat of chair
            [v11, v12, v10, v9].map { Vertex(position: $0, color: dkgrey) },  // foot part
            [v4, v5, v7, v9].map { Vertex(position: $0, color: blue) },  // one side
            [v3, v6, v8, v10].map { Vertex(position: $0, color: blue) },  // other side
        ]

        // Short stub lines filling the gap between the carriage (z =
        // ±1.25) and the rim itself (z = ±1.5).
        let linePaths = [
            TubePath(points: [side1, wheel1], color: steel),
            TubePath(points: [side2, wheel2], color: steel),
        ]

        return (quads, linePaths)
    }

    /// Equivalent of a `gluDisk` drawn with `GLU_SILHOUETTE` style: just
    /// the outer boundary circle, no radial spokes and no fill — a
    /// closed `TubePath` (see its doc comment), unlike everything else
    /// here.
    private static func circleOutline(
        center: SIMD3<Float>, radius: Float, slices: Int, color: SIMD4<Float>
    ) -> TubePath {
        var points: [SIMD3<Float>] = []
        for i in 0..<slices {
            let theta = 2 * Float.pi * Float(i) / Float(slices)
            points.append(center + SIMD3<Float>(radius * cos(theta), radius * sin(theta), 0))
        }
        return TubePath(points: points, color: color, closed: true)
    }
}
