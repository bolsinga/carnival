import simd

/// A path of points, in order, to be swept into a round "tube" by
/// `TubeMesh.make(paths:radius:sides:)`, all painted `color`.
struct TubePath {
    let points: [SIMD3<Float>]
    let color: SIMD4<Float>

    /// Whether the last point should connect back to the first,
    /// forming a closed loop (the ferris wheel's rims) rather than an
    /// open-ended tube (everything else here: the coaster's rails,
    /// cross-ties, and struts; the wheel's spokes, axle, and supports).
    var closed: Bool = false
}

/// Builds "tube" meshes — a ring of vertices swept along a path, with
/// consecutive rings connected by quads — as plain `StaticScene.Mesh`es,
/// so they draw with the same ordinary `carnival_vertex`/
/// `carnival_fragment` pipeline as everything else solid in the scene
/// (the ground, the tent, the ferris wheel's carriages). Used in place
/// of actual `.line` primitives, since Metal has no `glLineWidth`
/// equivalent to make those anything but ~1px, for the coaster track
/// and the ferris wheel's rims/spokes/axle/supports.
///
/// Two earlier approaches were tried and abandoned before this one,
/// both variations on expanding each independent 2-point segment into
/// its own quad in a vertex shader:
///   - sized in screen space (a segment's on-screen projected length
///     shrinks toward zero, and the computed "sideways" direction
///     becomes numerically unstable, when it points nearly straight at
///     or away from the camera — exactly what happens for every
///     segment right in front of the coaster's own ride camera, which
///     always looks straight down the track)
///   - sized in world space instead, fixing that, but still computing
///     each segment's own perpendicular independently, with no shared
///     "joint" between adjacent segments — visible, once lines were
///     wide enough, as sharp pinches or spiky overlaps at every joint
///     along a curve
/// A tube's ring vertices are shared between consecutive points along
/// the *same* path, so joints are seamless by construction: there's no
/// per-segment "which way is sideways" computation to disagree with a
/// neighboring segment's, because there's no such thing as an
/// independent segment here at all, just one continuous ring-vertex
/// mesh per path.
enum TubeMesh {
    static func make(paths: [TubePath], radius: Float, sides: Int) -> StaticScene.Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        for path in paths where path.points.count >= 2 {
            append(path, radius: radius, sides: sides, vertices: &vertices, indices: &indices)
        }
        return StaticScene.Mesh(vertices: vertices, indices: indices)
    }

    private static func append(
        _ tubePath: TubePath, radius: Float, sides: Int,
        vertices: inout [Vertex], indices: inout [UInt16]
    ) {
        let points = tubePath.points
        let count = points.count
        let worldUp = SIMD3<Float>(0, 1, 0)
        let fallbackAxis = SIMD3<Float>(0, 0, 1)

        var ringBase: [UInt16] = []
        ringBase.reserveCapacity(count)

        for i in 0..<count {
            // The local tangent direction at this point: the direction
            // from the previous point to the next one (an average of
            // the incoming/outgoing segment directions) for interior
            // points of an open path or any point of a closed one, or
            // just the single adjacent direction at the two ends of an
            // open path, where there's no "previous"/"next" to average.
            let tangent: SIMD3<Float>
            if tubePath.closed {
                let previous = points[(i - 1 + count) % count]
                let next = points[(i + 1) % count]
                tangent = normalize(next - previous)
            } else if i == 0 {
                tangent = normalize(points[1] - points[0])
            } else if i == count - 1 {
                tangent = normalize(points[i] - points[i - 1])
            } else {
                tangent = normalize(points[i + 1] - points[i - 1])
            }

            // Perpendicular to the tangent, via a fixed reference axis
            // — degenerates only when the path is itself vertical at
            // this point (parallel to world up), which falls back to a
            // different reference axis just for that case.
            var side1 = cross(tangent, worldUp)
            if length(side1) < 1e-4 {
                side1 = cross(tangent, fallbackAxis)
            }
            side1 = normalize(side1)
            let side2 = cross(tangent, side1)  // already unit length: tangent ⊥ side1, both unit

            ringBase.append(UInt16(vertices.count))
            for k in 0..<sides {
                let theta = 2 * Float.pi * Float(k) / Float(sides)
                let offset = side1 * (radius * cos(theta)) + side2 * (radius * sin(theta))
                vertices.append(Vertex(position: points[i] + offset, color: tubePath.color))
            }
        }

        let segmentCount = tubePath.closed ? count : count - 1
        for i in 0..<segmentCount {
            let baseA = ringBase[i]
            let baseB = ringBase[(i + 1) % count]
            for k in 0..<sides {
                let k0 = UInt16(k)
                let k1 = UInt16((k + 1) % sides)
                // Two triangles covering this quad of the tube's
                // surface (winding doesn't matter — the pipeline has no
                // back-face culling).
                indices.append(contentsOf: [
                    baseA + k0, baseB + k0, baseA + k1,
                    baseA + k1, baseB + k0, baseB + k1,
                ])
            }
        }
    }
}
