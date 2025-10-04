shader_type canvas_item;

uniform float time_speed = 0.3;
uniform vec3 fog_color : source_color = vec3(0.05, 0.0, 0.1);
uniform float fog_intensity = 0.4;

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_speed;
    
    // Multiple layers of moving fog
    float fog1 = noise(uv * 3.0 + vec2(time * 0.1, time * 0.15));
    float fog2 = noise(uv * 5.0 - vec2(time * 0.08, time * 0.12));
    float fog3 = noise(uv * 8.0 + vec2(time * 0.05, -time * 0.1));
    
    float combined = (fog1 + fog2 + fog3) / 3.0;
    combined = smoothstep(0.3, 0.7, combined);
    
    COLOR = vec4(fog_color, combined * fog_intensity);
}