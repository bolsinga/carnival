import simd

/// 4x4 matrix helpers standing in for the fixed-function OpenGL matrix
/// stack (`glPushMatrix`/`glTranslatef`/`glRotatef`) and the GLU camera/
/// projection helpers (`gluLookAt`/`gluPerspective`) used throughout the
/// original carnival.c/main.c.
extension float4x4 {
    /// Equivalent of `gluPerspective`. Produces clip-space z in Metal's
    /// [0, 1] range (OpenGL's is [-1, 1]), since that's what Metal's depth
    /// testing expects.
    static func perspective(fovyRadians fovy: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zScale = far / (near - far)

        return float4x4(
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, zScale * near, 0)
        )
    }

    /// Equivalent of `gluLookAt`.
    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        let translation = SIMD3<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye))

        return float4x4(
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }

    /// Equivalent of `glRotatef(radians, 0, 1, 0)` — used once for the tent
    /// placement in `drawScene`, and here for the placeholder camera orbit
    /// below.
    static func rotationY(radians: Float) -> float4x4 {
        let c = cos(radians)
        let s = sin(radians)

        return float4x4(
            SIMD4<Float>(c, 0, -s, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(s, 0, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}
