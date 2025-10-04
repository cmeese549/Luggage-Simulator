shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float chaos_level : hint_range(0.0, 1.0) = 0.5;
uniform float aberration_strength = 0.003;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 offset = (uv - center) * chaos_level * aberration_strength;
	
	// Sample RGB channels at different offsets
	float r = texture(screen_texture, uv + offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offset).b;
	
	COLOR = vec4(r, g, b, 1.0);
}