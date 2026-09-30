shader_type spatial;
// Daleki świat (niski poziom szczegółów): kolory wierzchołków, UV.y = żar (lawa).
// Fragmenty nad załadowanymi kawałkami (maska chunk_mask, 1 piksel = 1 kawałek) są odrzucane –
// tam rysuje się pełnoszczegółowy świat.
// by_instance: drzewa MultiMesh odrzucane w całości według położenia instancji.
render_mode cull_back, diffuse_burley, specular_disabled;

uniform sampler2D chunk_mask : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(-16.0);
uniform vec2 mask_span = vec2(288.0);
uniform bool by_instance = false;
uniform float wind = 1.0;

varying vec3 wpos;
varying vec2 origin;
varying float glow;

void vertex() {
	glow = UV.y;
	origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	if (by_instance) {
		float w = clamp(VERTEX.y / 2.5, 0.0, 1.0);
		float ph = TIME * 1.1 + origin.x * 0.45 + origin.y * 0.35;
		VERTEX.x += sin(ph) * 0.05 * w * w * wind;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = by_instance ? origin : wpos.xz;
	vec2 m = (p - mask_origin) / mask_span;
	if (m.x > 0.0 && m.y > 0.0 && m.x < 1.0 && m.y < 1.0 && texture(chunk_mask, m).r > 0.5) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	float pulse = 0.6 + 0.4 * sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5);
	EMISSION = vec3(1.0, 0.35, 0.08) * glow * pulse * 1.8;
}
