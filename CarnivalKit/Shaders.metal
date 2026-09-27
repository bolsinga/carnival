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
