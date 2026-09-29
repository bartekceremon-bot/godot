shader_type spatial;
// Roślinność low-poly kołysana wiatrem: UV.x = waga kołysania (0 przy ziemi), UV.y = żar.
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float wind = 1.0;

varying float glow;

void vertex() {
	float w = UV.x * UV.x;
	float ph = TIME * 1.3 + VERTEX.x * 0.45 + VERTEX.z * 0.35;
	VERTEX.x += sin(ph) * 0.07 * w * wind;
	VERTEX.z += cos(ph * 0.8 + 1.3) * 0.05 * w * wind;
	glow = UV.y;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	float pulse = 0.65 + 0.35 * sin(TIME * 2.5 + FRAGCOORD.x * 0.01);
	EMISSION = vec3(1.0, 0.38, 0.1) * glow * pulse * 1.8;
	BACKLIGHT = COLOR.rgb * 0.25;
}
