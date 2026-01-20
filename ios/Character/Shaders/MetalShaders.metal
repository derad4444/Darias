#include <metal_stdlib>
using namespace metal;

// Vertex input structure
struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

// Vertex output structure
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Uniform buffer structure
struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
};

// Vertex shader
vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Fragment shader
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    // Sample the texture
    float4 color = texture.sample(textureSampler, in.texCoord);
    
    // Simple alpha blending
    if (color.a < 0.01) {
        discard_fragment();
    }
    
    return color;
}

// Simple vertex shader for placeholder
vertex VertexOut simpleVertexShader(uint vertexID [[vertex_id]],
                                   constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // Create a quad
    float2 positions[4] = {
        float2(-0.5, -0.5),
        float2( 0.5, -0.5),
        float2(-0.5,  0.5),
        float2( 0.5,  0.5)
    };
    
    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    
    return out;
}

// Simple fragment shader for placeholder
fragment float4 simpleFragmentShader(VertexOut in [[stage_in]]) {
    // Create a gradient effect
    float2 center = float2(0.5, 0.5);
    float distance = length(in.texCoord - center);
    
    float3 color1 = float3(0.8, 0.4, 0.8); // Pink
    float3 color2 = float3(0.4, 0.8, 0.8); // Cyan
    
    float3 color = mix(color1, color2, distance * 2.0);
    
    return float4(color, 1.0);
}