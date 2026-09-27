import simd

/// The circus tent from `tent.c`'s `tent()`, drawn twice by `drawScene`
/// at different positions (one also rotated) — see `Renderer.draw(in:)`.
enum Tent {
    static func mesh() -> StaticScene.Mesh {
        let dkgrey = SIMD4<Float>(110, 110, 110, 255) / 255
        let ltgrey = SIMD4<Float>(230, 230, 230, 255) / 255
        let blue = SIMD4<Float>(0, 0, 255, 255) / 255
        let ltblue = SIMD4<Float>(0, 0, 175, 255) / 255
        let red = SIMD4<Float>(255, 0, 0, 255) / 255
        let ltpink = SIMD4<Float>(255, 223, 227, 255) / 255

        let v0 = SIMD3<Float>(0.0, 0.0, 3.0)
        let v1 = SIMD3<Float>(0.0, 0.0, 0.0)
        let v2 = SIMD3<Float>(0.0, 2.0, 0.0)
        let v3 = SIMD3<Float>(0.0, 3.0, 1.0)
        let v4 = SIMD3<Float>(0.0, 2.0, 3.0)
        let v5 = SIMD3<Float>(4.5, 0.0, 3.0)
        let v6 = SIMD3<Float>(4.5, 0.0, 0.0)
        let v7 = SIMD3<Float>(4.5, 2.0, 0.0)
        let v8 = SIMD3<Float>(4.5, 3.0, 1.0)
        let v9 = SIMD3<Float>(4.5, 2.0, 3.0)
        let v10 = SIMD3<Float>(0.0, 0.5, 3.0)
        let v11 = SIMD3<Float>(4.5, 0.5, 3.0)
        let v12 = SIMD3<Float>(0.0, 0.5, 2.5)
        let v13 = SIMD3<Float>(4.5, 0.5, 2.5)

        // The two side walls (pentagons) and the back wall.
        let side1: [Vertex] = [
            Vertex(position: v0, color: dkgrey),
            Vertex(position: v1, color: ltgrey),
            Vertex(position: v2, color: dkgrey),
            Vertex(position: v3, color: dkgrey),
            Vertex(position: v4, color: ltgrey),
        ]
        let side2: [Vertex] = [
            Vertex(position: v5, color: dkgrey),
            Vertex(position: v6, color: ltgrey),
            Vertex(position: v7, color: dkgrey),
            Vertex(position: v8, color: dkgrey),
            Vertex(position: v9, color: ltgrey),
        ]
        let back: [Vertex] = [
            Vertex(position: v1, color: ltgrey),
            Vertex(position: v2, color: dkgrey),
            Vertex(position: v7, color: ltgrey),
            Vertex(position: v6, color: dkgrey),
        ]

        // The front ticket counter (two solid-color slabs, unlike
        // everything else here which is per-vertex shaded).
        let counterTop = [v0, v10, v11, v5].map { Vertex(position: $0, color: blue) }
        let counterFront = [v10, v12, v13, v11].map { Vertex(position: $0, color: ltblue) }

        var polygons: [[Vertex]] = [side1, side2, back, counterTop, counterFront]

        // The awning: 11 equal-width strips spanning the full x extent
        // (0...4.5), alternating red/pink, each with a scalloped
        // semicircular valance hanging along its front eave.
        let stripWidth: Float = 4.5 / 11
        var isRed = true
        for i in 0..<11 {
            let x0 = Float(i) * stripWidth
            let x1 = Float(i + 1) * stripWidth
            let midX = (Float(i) + 0.5) * stripWidth
            let color = isRed ? red : ltpink

            let frontEave0 = SIMD3<Float>(x0, 2, 3)
            let frontEave1 = SIMD3<Float>(x1, 2, 3)
            let ridge0 = SIMD3<Float>(x0, 3, 1)
            let ridge1 = SIMD3<Float>(x1, 3, 1)
            let backEave0 = SIMD3<Float>(x0, 2, 0)
            let backEave1 = SIMD3<Float>(x1, 2, 0)

            polygons.append(
                [frontEave0, ridge0, ridge1, frontEave1].map { Vertex(position: $0, color: color) })
            polygons.append(
                [ridge0, backEave0, backEave1, ridge1].map { Vertex(position: $0, color: color) })

            // gluPartialDisk(qobj, 0, stripWidth/2, 32, 1, 270, -180) in
            // the original — a filled half-disk (inner radius 0) at the
            // strip's midpoint, sweeping from 270° to 90° (clockwise
            // through 180°), i.e. the half of the circle bulging toward
            // -x. GLU has no Metal equivalent, so this walks the same
            // angle steps by hand.
            polygons.append(
                partialDisk(
                    center: SIMD3<Float>(midX, 2, 3),
                    radius: stripWidth / 2,
                    startAngleDegrees: 270,
                    sweepAngleDegrees: -180,
                    slices: 32,
                    color: color
                ))

            isRed.toggle()
        }

        return StaticScene.makeMesh(polygons)
    }

    /// Builds a filled circular sector as a fan (disk center first, then
    /// each boundary point in order) so it triangulates the same way any
    /// other convex polygon in `StaticScene.makeMesh` does.
    private static func partialDisk(
        center: SIMD3<Float>,
        radius: Float,
        startAngleDegrees: Float,
        sweepAngleDegrees: Float,
        slices: Int,
        color: SIMD4<Float>
    ) -> [Vertex] {
        var points = [Vertex(position: center, color: color)]
        for i in 0...slices {
            let degrees = startAngleDegrees + sweepAngleDegrees * Float(i) / Float(slices)
            let radians = degrees * .pi / 180
            let offset = SIMD3<Float>(radius * cos(radians), radius * sin(radians), 0)
            points.append(Vertex(position: center + offset, color: color))
        }
        return points
    }
}
