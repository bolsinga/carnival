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
    float lineWidthInWorldUnits;
};

// Fakes a "thick line" the way Metal (unlike OpenGL's now-removed
// glLineWidth) requires: expand each 2-vertex segment into a quad,
// entirely here in the vertex shader, rather than drawing an actual
// .line primitive (always ~1px regardless of glLineWidth-style
// requests). `vertices` holds 4 entries per segment (this vertex's own
// endpoint repeated twice with side = -1/+1, plus the other endpoint
// carried along in `otherEndpoint` so this shader can compute the
// segment's direction) — see how `LineBuffers` builds this in
// Renderer.swift.
//
// An earlier version of this computed the "sideways" direction from
// each segment's on-screen (2D, post-projection) direction, rotated 90
// degrees — a standard technique (mirrors e.g. three.js's Line2/
// LineMaterial vertex shader) that keeps a constant width in screen
// pixels regardless of distance. It broke down for the coaster camera
// specifically: it always looks along the track, i.e. along the very
// segments right in front of it, which is exactly the degenerate case
// for that technique (a segment's on-screen projected length shrinks
// toward zero the more directly it points at/away from the camera, so
// the "direction" computed from it becomes tiny and numerically
// unstable) — the rails visibly collapsed to hairline-thin and jittered
// right where the camera was looking, instead of just staying thick.
//
// This computes the sideways direction in world space instead, via a
// cross product with a fixed reference axis (world up) — a direction
// that has nothing to do with where the camera is looking, so it can't
// degenerate that way. The trade-off: width is now in world units, not
// screen pixels, so (like a real 3D guardrail) it looks slightly
// thinner from farther away rather than staying a fixed screen size —
// a reasonable exchange for actually staying straight.
vertex VertexOut carnival_thick_line_vertex(uint vertexID [[vertex_id]],
                                             constant ThickLineVertex *vertices [[buffer(0)]],
                                             constant ThickLineUniforms &uniforms [[buffer(1)]]) {
    ThickLineVertex v = vertices[vertexID];

    float3 direction = v.otherEndpoint - v.position;
    float directionLength = length(direction);
    float3 unitDirection = directionLength > 1e-5 ? direction / directionLength : float3(1, 0, 0);

    // Perpendicular to the segment, in the horizontal plane (assuming
    // "up" is +Y, matching every camera's up vector elsewhere in this
    // project). Degenerates only when the segment itself is vertical
    // (parallel to world up) -- falls back to a different reference
    // axis for just that case, rather than the "camera is looking
    // along the segment" case, which is the common one here.
    float3 worldUp = float3(0, 1, 0);
    float3 perpendicular = cross(unitDirection, worldUp);
    float perpendicularLength = length(perpendicular);
    if (perpendicularLength < 1e-4) {
        perpendicular = cross(unitDirection, float3(0, 0, 1));
        perpendicularLength = length(perpendicular);
    }
    float3 unitPerpendicular = perpendicularLength > 1e-5
        ? perpendicular / perpendicularLength
        : float3(1, 0, 0);

    float3 offset = unitPerpendicular * (uniforms.lineWidthInWorldUnits * 0.5) * v.side;

    VertexOut out;
    out.position = uniforms.modelViewProjectionMatrix * float4(v.position + offset, 1.0);
    out.color = v.color;
    return out;
}
