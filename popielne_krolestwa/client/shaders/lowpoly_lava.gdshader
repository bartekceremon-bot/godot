shader_type spatial;
// Lawa: płynąca, świecąca tafla z ciemniejszą skorupą przy brzegu (COLOR.r = 1 w środku lawy).
render_mode cull_back, unshaded;

varying vec3 wpos;
varying float inner;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inner = COLOR.r;
	VERTEX.y += sin(TIME * 0.8 + wpos.x * 1.3 + wpos.z) * 0.02;
}

void fragment() {
	vec2 uv = wpos.xz * 0.9 + vec2(TIME * 0.06, TIME * 0.04);
	float n = noise(uv) * 0.6 + noise(uv * 2.3 - TIME * 0.1) * 0.4;
	float crust = smoothstep(0.42, 0.62, n);
	vec3 hot = mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.8, 0.25), smoothstep(0.2, 0.5, n));
	vec3 col = mix(hot * 1.15, vec3(0.1, 0.035, 0.02), crust * 0.9);
	col = mix(vec3(0.15, 0.05, 0.03), col, 0.35 + inner * 0.65);
	ALBEDO = col;
}
