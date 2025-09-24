shader_type canvas_item;

// Uniforms for control
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float time_speed : hint_range(0.0, 5.0) = 1.0;
uniform float writhe_frequency : hint_range(0.1, 20.0) = 3.0;
uniform float vortex_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec2 center_position = vec2(0.5, 0.5);
uniform float order_level : hint_range(0.0, 1.0) = 0.0;  // 0 = full chaos, 1 = ordered
uniform vec4 chaos_tint : source_color = vec4(0.8, 0.2, 0.3, 0.1);

// Noise functions for organic movement
float noise(vec2 p) {
    return sin(p.x * 10.0) * sin(p.y * 10.0);
}

vec2 rotate2D(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME * time_speed;
    
    // Calculate distance from center for radial effects
    vec2 center_offset = uv - center_position;
    float dist_from_center = length(center_offset);
    
    // Layer 1: Writhing tentacle-like distortion
    vec2 writhe_offset = vec2(0.0);
    writhe_offset.x = sin(uv.y * writhe_frequency + time * 2.3) * cos(uv.x * writhe_frequency * 1.7 + time);
    writhe_offset.y = cos(uv.x * writhe_frequency + time * 1.9) * sin(uv.y * writhe_frequency * 1.3 + time);
    
    // Layer 2: Vortex spiral distortion around pentagram points
    float angle = atan(center_offset.y, center_offset.x);
    float spiral = sin(angle * 5.0 - time * 3.0 + dist_from_center * 10.0) * vortex_strength;
    vec2 vortex_offset = rotate2D(center_offset, spiral * (1.0 - dist_from_center)) - center_offset;
    
    // Layer 3: Pulsing reality warps
    float pulse = sin(time * 4.0 + dist_from_center * 20.0) * 0.5 + 0.5;
    vec2 pulse_offset = center_offset * pulse * 0.1;
    
    // Layer 4: Noise-based organic movement
    float n1 = noise(uv * 10.0 + vec2(time * 0.5, time * 0.3));
    float n2 = noise(uv * 20.0 - vec2(time * 0.7, time * 0.4));
    vec2 noise_offset = vec2(n1, n2) * 0.005;
    
    // Combine all distortion layers
    vec2 total_distortion = writhe_offset * distortion_strength;
    total_distortion += vortex_offset * distortion_strength * 2.0;
    total_distortion += pulse_offset * distortion_strength;
    total_distortion += noise_offset;
    
    // Apply order level to reduce distortion as puzzle is solved
    total_distortion *= (1.0 - order_level * 0.8);
    
    // Sample the screen with distortion
    vec2 distorted_uv = uv + total_distortion;
    vec4 screen_color = texture(screen_texture, distorted_uv);
    
    // Add chaos tint that fades with order
    vec4 final_color = screen_color;
    float chaos_factor = 1.0 - order_level;
    final_color = mix(final_color, final_color * (1.0 + chaos_tint), chaos_factor * chaos_tint.a);
    
    // Edge darkening for eldritch atmosphere
    float vignette = 1.0 - smoothstep(0.3, 0.7, dist_from_center);
    final_color.rgb *= mix(1.0, vignette, chaos_factor * 0.5);
    
    COLOR = final_color;
}