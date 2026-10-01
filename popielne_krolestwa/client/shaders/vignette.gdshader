// Winieta i lekkie ciepłe zabarwienie brzegów ekranu (klimat spalonego świata).
shader_type canvas_item;

uniform float strength = 0.55;
uniform vec3 tint : source_color = vec3(0.12, 0.05, 0.03);

void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.25, 1.0)));
	COLOR = vec4(tint, v * strength);
}
