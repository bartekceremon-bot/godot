// Rozpraszanie iluzji / mgły: progresywne „wygryzanie” szumem.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge : source_color = vec4(0.91, 0.72, 0.29, 1.0);
varying vec2 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float n = noise(wpos * 0.05);
	if (n < amount) { discard; }
	if (n < amount + 0.06 && amount > 0.0) { COLOR = edge; }
}
