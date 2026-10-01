shader_type spatial;
// Teren low-poly: kolor z wierzchołków (płaskie cieniowanie), UV.y = żarzące się szczeliny popiołu.
render_mode cull_back, diffuse_burley, specular_disabled;

varying float ember;
varying vec3 wpos;

void vertex() {
	ember = UV.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	float pulse = 0.55 + 0.45 * sin(TIME * 1.7 + wpos.x * 1.3 + wpos.z * 0.9);
	EMISSION = vec3(1.0, 0.32, 0.06) * ember * pulse * 1.6;
}
