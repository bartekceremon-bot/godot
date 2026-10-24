// Niebo pod wyspami: gradient i delikatne migotanie gwiazd.
shader_type canvas_item;

uniform vec4 top : source_color = vec4(0.06, 0.16, 0.20, 1.0);
uniform vec4 bottom : source_color = vec4(0.16, 0.36, 0.38, 1.0);
uniform vec4 haze : source_color = vec4(0.91, 0.72, 0.29, 1.0);
uniform float stars = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec4 c = mix(top, bottom, UV.y);
	c.rgb += haze.rgb * 0.10 * smoothstep(0.55, 1.0, UV.y);
	vec2 cells = vec2(120.0, 68.0);
	vec2 g = floor(UV * cells);
	float h = hash(g);
	// Okrągła gwiazdka w losowym miejscu komórki, tylko w nielicznych komórkach.
	vec2 local = fract(UV * cells) - vec2(0.3 + 0.4 * hash(g + 3.1), 0.3 + 0.4 * hash(g + 7.7));
	float dotv = smoothstep(0.16, 0.0, length(local * vec2(1.0, 0.56)));
	float tw = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 30.0);
	c.rgb += vec3(step(0.985, h) * dotv * tw * 0.7 * stars * (1.0 - UV.y));
	COLOR = c;
}
