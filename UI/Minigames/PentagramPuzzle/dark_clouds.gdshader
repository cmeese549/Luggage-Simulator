shader_type canvas_item;

uniform float chaos_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float time_speed = 0.15;
uniform vec3 cloud_color : source_color = vec3(0.08, 0.0, 0.15);
uniform float cloud_scale = 2.0;

// Better noise function
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.13);
    p3 += dot(p3, p3.yzx + 3.333);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_speed;
    
    // Large slow-moving clouds
    float cloud1 = noise(uv * cloud_scale + vec2(time * 0.05, time * 0.03));
    float cloud2 = noise(uv * cloud_scale * 1.5 - vec2(time * 0.04, time * 0.06));
    float cloud3 = noise(uv * cloud_scale * 0.8 + vec2(time * 0.02, -time * 0.04));
    
    float combined = (cloud1 * 0.5 + cloud2 * 0.3 + cloud3 * 0.2);
    combined = smoothstep(0.2, 0.8, combined);
    
    // Pulse with chaos intensity
    float opacity = combined * chaos_intensity * 0.9;
    
    COLOR = vec4(cloud_color, opacity);
}