import simd

/// The roller coaster track, ported from coaster.c. Unlike the ground/
/// mountains/tent, this is drawn as thin lines (`GL_LINE_STRIP` pairs in
/// the original), not filled polygons, and always in one solid color —
/// `coaster()` sets `glColor3ubv(tracks)` once and never changes it,
/// even inside `drawStrut`.
///
/// Metal has no line-width control (unlike `glLineWidth`), so the
/// original's 1px/2px/3px distinctions between rails, cross-ties, and
/// struts aren't reproduced — everything here draws as a plain 1px line.
enum Coaster {
    struct Track {
        let rollerIn: [SIMD3<Float>]
        let rollerOut: [SIMD3<Float>]

        /// Equivalent of `avgPts(rollerin[index], rollerout[index], result)`
        /// — the coaster rider's actual position along the centerline, at
        /// a given track index.
        func riderPosition(at index: Int) -> SIMD3<Float> {
            (rollerIn[index] + rollerOut[index]) * 0.5
        }
    }

    /// Equivalent of `getCoasterPts`. Computes the coaster's inner/outer
    /// rail points once, up front — exactly as the original does it (its
    /// own comment: "so that they don't have to be calculated each time
    /// it is drawn"). All arithmetic uses `Float` (not `Double`) to match
    /// the original's `float`, since the loop trip counts below depend
    /// on the exact same IEEE754 single-precision accumulation.
    static func computeTrack() -> Track {
        let jump: Float = 0.1
        let radiusOut: Float = 8.0
        let radiusIn: Float = 7.0
        let length: Float = 40.0
        let speed1: Float = 10.392
        let speed2: Float = 5.555
        let pi = Float.pi

        var rollerIn: [SIMD3<Float>] = []
        var rollerOut: [SIMD3<Float>] = []

        let maxY = (5.0 * pi) / (radiusOut / 4.0)  // the tallest the coaster gets
        let slope = maxY / length  // the slope of the falling part
        let theta = atan(slope)
        let dy = speed1 * jump * sin(theta)  // change in y on the falling part
        let dz = speed1 * jump * cos(theta)  // change in z on the falling part
        let totalDist = sqrt(length * length + maxY * maxY)  // length of the falling part

        // The first part of the flat straightaway.
        var a: Float = -length / 2.0
        while a <= 0.0 {
            rollerOut.append(SIMD3<Float>(radiusOut, 0.0, a))
            rollerIn.append(SIMD3<Float>(radiusIn, 0.0, a))
            a += speed2 * jump
        }

        // The climbing part.
        a = jump
        while a <= 5 * pi {
            let y = a / (radiusOut / 4.0)
            rollerOut.append(SIMD3<Float>(radiusOut * cos(a), y, radiusOut * sin(a)))
            rollerIn.append(SIMD3<Float>(radiusIn * cos(a), y, radiusIn * sin(a)))
            a += jump
        }

        // The downward slope straightaway.
        a = speed1 * jump
        while a <= totalDist {
            let previousOut = rollerOut[rollerOut.count - 1]
            let previousIn = rollerIn[rollerIn.count - 1]
            rollerOut.append(SIMD3<Float>(-radiusOut, previousOut.y - dy, previousOut.z - dz))
            rollerIn.append(SIMD3<Float>(-radiusIn, previousIn.y - dy, previousIn.z - dz))
            a += speed1 * jump
        }

        // The flat half circle.
        a = jump
        while a <= pi {
            rollerOut.append(
                SIMD3<Float>(radiusOut * cos(a - pi), 0.0, radiusOut * sin(a - pi) - length))
            rollerIn.append(
                SIMD3<Float>(radiusIn * cos(a - pi), 0.0, radiusIn * sin(a - pi) - length))
            a += jump
        }

        // The last part of the flat straightaway.
        a = -length
        while a <= -length / 2.0 {
            rollerOut.append(SIMD3<Float>(radiusOut, 0.0, a))
            rollerIn.append(SIMD3<Float>(radiusIn, 0.0, a))
            a += speed2 * jump
        }

        return Track(rollerIn: rollerIn, rollerOut: rollerOut)
    }

    /// Equivalent of `drawStrut`'s strut/height selection. Returns the
    /// rail index to anchor the strut to, and the Y it should drop to,
    /// or `nil` if no strut is drawn for this track index.
    private static func strut(at i: Int, rollerIn: [SIMD3<Float>]) -> (index: Int, height: Float)? {
        // A few points can't drop straight down without intersecting the
        // track itself, so they anchor to a nearby point instead.
        let strutIndex: Int
        switch i {
        case 93, 157: strutIndex = 155
        case 97, 159: strutIndex = 161
        case 193: strutIndex = 191
        case 195: strutIndex = 197
        default: strutIndex = i
        }

        if strutIndex != i {
            // Matches the original exactly: `height` is declared `int`,
            // so this float expression truncates toward zero — anchor
            // about 2/3 of the way up rather than the full height.
            return (strutIndex, Float(Int(2.0 * rollerIn[i].y / 3.0)))
        }
        if (i <= 33 || i >= 129) && (i <= 156 || i >= 161) && (i <= 192 || i >= 197) {
            // Only the highest parts of the track drop struts to the
            // ground; everywhere else, no strut.
            return (strutIndex, -1.0)
        }
        return nil
    }

    /// Equivalent of `coaster(numpts)` (which also calls `drawStrut`
    /// internally) — builds the flat list of line-segment vertex pairs:
    /// two segments per track index (inner rail, outer rail), plus, on
    /// every other index, a cross-tie and the struts. Takes a
    /// pre-computed `Track` rather than calling `computeTrack()` itself
    /// so callers that also need the raw points (e.g. the ride-follow
    /// camera) can compute it once and reuse it.
    static func lineVertices(track: Track) -> [Vertex] {
        let color = SIMD4<Float>(51, 51, 51, 255) / 255
        let numPts = track.rollerIn.count - 1

        var vertices: [Vertex] = []
        func addLine(_ a: SIMD3<Float>, _ b: SIMD3<Float>) {
            vertices.append(Vertex(position: a, color: color))
            vertices.append(Vertex(position: b, color: color))
        }

        var alternate = false
        for i in 0..<numPts {
            addLine(track.rollerIn[i], track.rollerIn[i + 1])
            addLine(track.rollerOut[i], track.rollerOut[i + 1])

            // Alternating the beams "so that motion is better simulated"
            // (the original's comment).
            if alternate {
                addLine(track.rollerIn[i], track.rollerOut[i])

                if let (strutIndex, height) = strut(at: i, rollerIn: track.rollerIn) {
                    var innerSupport = track.rollerIn[strutIndex]
                    innerSupport.y = height
                    addLine(track.rollerIn[i], innerSupport)

                    var outerSupport = track.rollerOut[strutIndex]
                    outerSupport.y = height
                    addLine(track.rollerOut[i], outerSupport)
                }
            }
            alternate.toggle()
        }

        return vertices
    }
}
