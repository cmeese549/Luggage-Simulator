shader_type canvas_item;

uniform float star_density = 0.002;
uniform float twinkle_speed = 0.5;
uniform vec3 star_color : source_color = vec3(0.8, 0.8, 1.0);
uniform float brightness = 0.6;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    vec2 uv = UV * 1000.0; // Scale up for more stars
    vec2 id = floor(uv);

    float random = hash(id);

    // Only create stars at certain positions
    if (random < star_density) {
        vec2 local_uv = fract(uv);
        vec2 star_center = vec2(hash(id + 0.1), hash(id + 0.2));

        float dist = length(local_uv - star_center);
        float star = smoothstep(0.05, 0.0, dist);

        // Twinkle effect
        float twinkle = sin(TIME * twinkle_speed + random * 10.0) * 0.3 + 0.7;

        float alpha = star * brightness * twinkle * random;
        COLOR = vec4(star_color, alpha);
    } else {
        COLOR = vec4(0.0);
    }
}