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

/// Vertex format for "thick" lines (the coaster track and the ferris
/// wheel's rims/spokes/axle/supports) — see `carnival_thick_line_vertex`
/// in Shaders.metal for why a plain `.line` primitive can't do this:
/// Metal has no `glLineWidth` equivalent (confirmed against Apple's own
/// `MTLPrimitiveType` docs — no width parameter exists anywhere), so
/// `.line`/`.lineStrip` always rasterize at a fixed ~1px width,
/// regardless of what the original's `glLineWidth` calls asked for.
/// Each line segment becomes a quad: 4 of these vertices (2 per
/// endpoint, `side` flipped between them), expanded into a
/// camera-facing ribbon entirely in the vertex shader. Mirrors the
/// `ThickLineVertex` struct in Shaders.metal — keep the two in sync.
struct ThickLineVertex {
    var position: SIMD3<Float>
    var otherEndpoint: SIMD3<Float>
    var side: Float
    var color: SIMD4<Float>
}

/// Mirrors the `ThickLineUniforms` struct in Shaders.metal — keep the
/// two in sync.
struct ThickLineUniforms {
    var modelViewProjectionMatrix: float4x4
    var viewportSize: SIMD2<Float>
    var lineWidthInPixels: Float
}
