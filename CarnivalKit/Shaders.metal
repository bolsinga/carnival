#include <metal_stdlib>
using namespace metal;

// Mirrors the `Vertex` struct in Vertex.swift — keep the two in sync.
struct Vertex {
    float3 position;
    float4 color;
};

// Mirrors the `Uniforms` struct in Vertex.swift — keep the two in sync.
struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// No lighting — the original never used any either. Per-vertex color
// (set via glColor3ubv before each glVertex3fv call) is the only shading
// the fixed-function pipeline did, and Metal's rasterizer interpolates
// `color` across each triangle the same way OpenGL's Gouraud shading did.
vertex VertexOut carnival_vertex(uint vertexID [[vertex_id]],
                                  constant Vertex *vertices [[buffer(0)]],
                                  constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    out.position = uniforms.modelViewProjectionMatrix * float4(vertices[vertexID].position, 1.0);
    out.color = vertices[vertexID].color;
    return out;
}

fragment float4 carnival_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// Mirrors the `ThickLineVertex` struct in Vertex.swift — keep the two
// in sync.
struct ThickLineVertex {
    float3 position;
    float3 otherEndpoint;
    float side;
    float4 color;
};

// Mirrors the `ThickLineUniforms` struct in Vertex.swift — keep the
// two in sync.
struct ThickLineUniforms {
    float4x4 modelViewProjectionMatrix;
    float2 viewportSize;
    float lineWidthInPixels;
};

// Fakes a "thick line" the way Metal (unlike OpenGL's now-removed
// glLineWidth) requires: expand each 2-vertex segment into a
// camera-facing quad, entirely here in the vertex shader, rather than
// drawing an actual .line primitive (always ~1px regardless of
// glLineWidth-style requests). `vertices` holds 4 entries per segment
// (this vertex's own endpoint repeated twice with side = -1/+1, plus
// the other endpoint carried along in `otherEndpoint` so this shader
// can compute the segment's on-screen direction) — see how
// `LineBuffers` builds this in Renderer.swift.
//
// Standard technique (mirrors e.g. three.js's Line2/LineMaterial
// vertex shader): project both endpoints to clip space, divide by `w`
// to get screen-facing directions in NDC, convert that direction to
// pixels using the viewport size, rotate it 90 degrees to get the
// perpendicular "sideways" direction, scale by the desired half-width
// in pixels, convert back to NDC, and nudge this vertex's own clip
// position by that offset (re-scaled by `w`, since clip-space xy needs
// to be un-normalized before the rasterizer's own divide-by-w happens).
vertex VertexOut carnival_thick_line_vertex(uint vertexID [[vertex_id]],
                                             constant ThickLineVertex *vertices [[buffer(0)]],
                                             constant ThickLineUniforms &uniforms [[buffer(1)]]) {
    ThickLineVertex v = vertices[vertexID];

    float4 clipSelf = uniforms.modelViewProjectionMatrix * float4(v.position, 1.0);
    float4 clipOther = uniforms.modelViewProjectionMatrix * float4(v.otherEndpoint, 1.0);

    float2 ndcSelf = clipSelf.xy / clipSelf.w;
    float2 ndcOther = clipOther.xy / clipOther.w;

    float2 halfViewport = uniforms.viewportSize * 0.5;
    float2 directionPixels = (ndcOther - ndcSelf) * halfViewport;

    // Degenerate (zero-length) segments have no well-defined direction
    // to be perpendicular to; fall back to a fixed direction rather
    // than dividing by zero in normalize().
    float directionLength = length(directionPixels);
    float2 perpendicularPixels = directionLength > 1e-5
        ? float2(-directionPixels.y, directionPixels.x) / directionLength
        : float2(1.0, 0.0);

    float2 offsetPixels = perpendicularPixels * (uniforms.lineWidthInPixels * 0.5) * v.side;
    float2 offsetNDC = offsetPixels / halfViewport;

    VertexOut out;
    out.position = clipSelf;
    out.position.xy += offsetNDC * clipSelf.w;
    out.color = v.color;
    return out;
}
