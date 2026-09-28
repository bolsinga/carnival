import simd

/// Mirrors the `Vertex` struct in Shaders.metal — keep the two in sync.
/// `SIMD3<Float>` and Metal's `float3` both have a 16-byte stride, so
/// `color` lands at the same offset (16) on both sides.
struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

/// Mirrors the `Uniforms` struct in Shaders.metal — keep the two in sync.
struct Uniforms {
    var modelViewProjectionMatrix: float4x4
}
