import simd

/// CPU-side geometry for the parts of the scene that never move: the
/// ground plane and the three background mountains, ported directly from
/// `drawScene`/`mountains` in the original carnival.c. The two are
/// combined into one mesh since they're always drawn together with an
/// identity model matrix.
enum StaticScene {
    struct Mesh {
        let vertices: [Vertex]
        let indices: [UInt16]
    }

    /// Builds one mesh's worth of vertices/indices, fanning each convex
    /// polygon from its first vertex — matching the original's
    /// `glBegin(GL_POLYGON)`/`glVertex3fv` calls, which are always convex
    /// 3-4 vertex shapes here.
    private static func makeMesh(_ polygons: [[Vertex]]) -> Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []

        for polygon in polygons {
            let base = UInt16(vertices.count)
            vertices.append(contentsOf: polygon)
            for i in 1..<(polygon.count - 1) {
                indices.append(base)
                indices.append(base + UInt16(i))
                indices.append(base + UInt16(i + 1))
            }
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    static func groundAndMountains() -> Mesh {
        let grass = SIMD4<Float>(123, 193, 87, 255) / 255
        let brown = SIMD4<Float>(116, 87, 11, 255) / 255
        let snow = SIMD4<Float>(196, 196, 196, 255) / 255

        let ground: [Vertex] = [
            Vertex(position: SIMD3<Float>(100, -1.0, 100), color: grass),
            Vertex(position: SIMD3<Float>(100, -1.0, -100), color: grass),
            Vertex(position: SIMD3<Float>(-100, -1.0, -100), color: grass),
            Vertex(position: SIMD3<Float>(-100, -1.0, 100), color: grass),
        ]

        // Each mountain's base pair is brown, its peak is snow — the only
        // "shading" the original does anywhere, via per-vertex color
        // interpolation rather than lighting.
        let mountain1: [Vertex] = [
            Vertex(position: SIMD3<Float>(80, -1.0, -50), color: brown),
            Vertex(position: SIMD3<Float>(80, -1.0, 50), color: brown),
            Vertex(position: SIMD3<Float>(80, 50, 0), color: snow),
        ]
        let mountain2: [Vertex] = [
            Vertex(position: SIMD3<Float>(75, -1.0, -40), color: brown),
            Vertex(position: SIMD3<Float>(75, -1.0, 0.0), color: brown),
            Vertex(position: SIMD3<Float>(75, 40, -20), color: snow),
        ]
        let mountain3: [Vertex] = [
            Vertex(position: SIMD3<Float>(85, -1, -70), color: brown),
            Vertex(position: SIMD3<Float>(85, -1, -5), color: brown),
            Vertex(position: SIMD3<Float>(85, 45, -45), color: snow),
        ]

        return makeMesh([ground, mountain1, mountain2, mountain3])
    }
}
