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
/// a flat line-vertex list, the same two shapes `StaticScene`/`Tent` and
/// `Coaster` produce respectively.
enum FerrisWheel {
    struct Geometry {
        let triangles: StaticScene.Mesh
        let lines: [Vertex]
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
        var lines: [Vertex] = []
        func addLine(_ a: SIMD3<Float>, _ b: SIMD3<Float>, color: SIMD4<Float>) {
            lines.append(Vertex(position: a, color: color))
            lines.append(Vertex(position: b, color: color))
        }

        // The wheel's two rims. gluDisk(..., GLU_SILHOUETTE) suppresses
        // the radial spoke lines a plain disk would tessellate, leaving
        // only the outer boundary circle.
        lines.append(
            contentsOf: circleOutline(
                center: SIMD3<Float>(0, 0, -1.5), radius: 6.0, slices: 32, color: yellow))
        lines.append(
            contentsOf: circleOutline(
                center: SIMD3<Float>(0, 0, 1.5), radius: 6.0, slices: 32, color: yellow))

        var angle = startAngle
        for _ in 0..<8 {
            let rimFront = SIMD3<Float>(6.0 * cos(angle), 6.0 * sin(angle), 1.5)
            let rimBack = SIMD3<Float>(rimFront.x, rimFront.y, -1.5)

            addLine(rimFront, center1, color: yellow)
            addLine(rimBack, center2, color: yellow)

            let carriage = carriage(wheel1: rimFront, wheel2: rimBack)
            polygons.append(contentsOf: carriage.quads)
            lines.append(contentsOf: carriage.lines)

            angle += spoke
        }

        addLine(axel1, axel2, color: steel)
        // Each 3-point line strip (b1 -> axel1 -> b2) is two segments.
        addLine(b1, axel1, color: steel)
        addLine(axel1, b2, color: steel)
        addLine(b3, axel2, color: steel)
        addLine(axel2, b4, color: steel)

        return Geometry(triangles: StaticScene.makeMesh(polygons), lines: lines)
    }

    /// Equivalent of `carriage(wheel1, wheel2)`. `wheel1`/`wheel2` always
    /// share x/y (only z differs, 1.5 vs -1.5), which is what lets the
    /// original's chained C assignments (`v1[0] = v2[0] = ... -= 0.5`)
    /// apply the same offset to every vertex sharing that value; ported
    /// here as plain per-vertex arithmetic instead.
    private static func carriage(
        wheel1: SIMD3<Float>, wheel2: SIMD3<Float>
    ) -> (quads: [[Vertex]], lines: [Vertex]) {
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
        var lines: [Vertex] = []
        lines.append(Vertex(position: side1, color: steel))
        lines.append(Vertex(position: wheel1, color: steel))
        lines.append(Vertex(position: side2, color: steel))
        lines.append(Vertex(position: wheel2, color: steel))

        return (quads, lines)
    }

    /// Equivalent of a `gluDisk` drawn with `GLU_SILHOUETTE` style: just
    /// the outer boundary circle, no radial spokes and no fill.
    private static func circleOutline(
        center: SIMD3<Float>, radius: Float, slices: Int, color: SIMD4<Float>
    ) -> [Vertex] {
        var points: [SIMD3<Float>] = []
        for i in 0..<slices {
            let theta = 2 * Float.pi * Float(i) / Float(slices)
            points.append(center + SIMD3<Float>(radius * cos(theta), radius * sin(theta), 0))
        }

        var lines: [Vertex] = []
        for i in 0..<slices {
            lines.append(Vertex(position: points[i], color: color))
            lines.append(Vertex(position: points[(i + 1) % slices], color: color))
        }
        return lines
    }
}
