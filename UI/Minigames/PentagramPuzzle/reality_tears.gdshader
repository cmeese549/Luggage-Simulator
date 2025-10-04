shader_type canvas_item;

uniform float chaos_level : hint_range(0.0, 1.0) = 0.5;
uniform float edge_width = 0.2;
uniform vec3 crack_color : source_color = vec3(0.6, 0.2, 0.8);
uniform vec3 glow_color : source_color = vec3(0.8, 0.4, 1.0);

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Voronoi for shattered glass effect
vec2 voronoi(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);

    float min_dist = 1.0;
    vec2 min_point = vec2(0.0);

    for(int j = -1; j <= 1; j++) {
        for(int i = -1; i <= 1; i++) {
            vec2 neighbor = vec2(float(i), float(j));
            vec2 point = vec2(hash(p + neighbor), hash(p + neighbor + 100.0));
            vec2 diff = neighbor + point - f;
            float dist = length(diff);

            if(dist < min_dist) {
                min_dist = dist;
                min_point = point;
            }
        }
    }

    return vec2(min_dist, hash(p + min_point));
}

void fragment() {
    vec2 uv = UV;

    // Distance from edges
    float dist_x = min(uv.x, 1.0 - uv.x);
    float dist_y = min(uv.y, 1.0 - uv.y);
    float edge_dist = min(dist_x, dist_y);

    // Edge mask
    float edge_mask = smoothstep(edge_width, 0.0, edge_dist);

    // Animated voronoi cracks
    vec2 voronoi_result = voronoi(uv * 15.0 + TIME * 0.3);
    float cracks = voronoi_result.x;

    // Sharp crack lines
    float crack_lines = smoothstep(0.08, 0.0, cracks);

    // Glow along cracks
    float crack_glow = smoothstep(0.15, 0.0, cracks) - crack_lines;

    // Combine with edge mask and chaos
    float final_cracks = crack_lines * edge_mask * chaos_level;
    float final_glow = crack_glow * edge_mask * chaos_level * 0.5;

    // Output
    vec3 color = crack_color * final_cracks + glow_color * final_glow;
    float alpha = (final_cracks + final_glow * 0.7) * 0.9;

    COLOR = vec4(color, alpha);
}