shader_type canvas_item;

uniform float chaos_level : hint_range(0.0, 1.0) = 1.0;
uniform float vignette_strength = 1.0;

void fragment() {
	vec2 uv = UV - 0.5;  // Center coordinates
	float dist = length(uv);  // Distance from center

	// Simple radial fade
	float vignette = smoothstep(0.2, 0.8, dist);
	vignette *= chaos_level * vignette_strength;

	COLOR = vec4(0.0, 0.0, 0.0, vignette);
}