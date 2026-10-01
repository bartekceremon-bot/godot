shader_type spatial;
// Liście / igły / trawa na kartach z przezroczystością (alpha scissor), obustronne.
// Normalne kart są „kuliste” (od środka korony) – miękkie, naturalne cieniowanie korony.
// INSTANCE_CUSTOM: rgb = barwa docelowa (jesień, spalenizna), a = siła przebarwienia.
// COLOR.rgb = mnożnik jasności (wnętrze korony ciemniejsze), COLOR.a = śnieg na gałęziach.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform float wind = 1.0;
uniform float flutter = 1.0;
uniform bool use_mask = false;
uniform sampler2D chunk_mask : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(-16.0);
uniform vec2 mask_span = vec2(288.0);

varying vec2 origin;
varying vec4 tint;
varying vec3 wn;

global uniform vec3 player_pos;

// Obiekty między kamerą a bohaterem (i tuż przy kamerze) są ażurowe – bohater zawsze widoczny.
bool occluding(vec3 view_vertex, vec2 frag, mat4 inv_view) {
	vec3 cam = inv_view[3].xyz;
	vec3 wp = (inv_view * vec4(view_vertex, 1.0)).xyz;
	vec3 target = player_pos + vec3(0.0, 0.9, 0.0);
	vec3 seg = target - cam;
	float t = clamp(dot(wp - cam, seg) / max(dot(seg, seg), 0.001), 0.0, 1.0);
	float d = length(wp - (cam + seg * t));
	float dith = fract(sin(dot(floor(frag), vec2(12.9898, 78.233))) * 43758.5453);
	if (length(view_vertex) < 2.2) {
		return true;
	}
	return t < 0.9 && d < 1.4 && dith < 0.7;
}

void vertex() {
	origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	tint = INSTANCE_CUSTOM;
	float hgt = max(VERTEX.y, 0.0);
	float ph = TIME * 1.1 + origin.x * 0.37 + origin.y * 0.23;
	VERTEX.x += sin(ph) * 0.012 * hgt * hgt * wind;
	VERTEX.z += cos(ph * 0.8) * 0.008 * hgt * hgt * wind;
	// Drganie liści.
	float f = sin(TIME * 4.3 + VERTEX.x * 3.1 + VERTEX.z * 2.3 + origin.x) * 0.025 * flutter * wind;
	VERTEX += NORMAL * f;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (!use_mask && occluding(VERTEX, FRAGCOORD.xy, INV_VIEW_MATRIX)) {
		discard;
	}
	if (use_mask) {
		vec2 m = (origin - mask_origin) / mask_span;
		if (m.x > 0.0 && m.y > 0.0 && m.x < 1.0 && m.y < 1.0 && texture(chunk_mask, m).r > 0.5) {
			discard;
		}
	}
	vec4 t = texture(leaf_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	vec3 c = t.rgb * COLOR.rgb;
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, tint.rgb * lum * 2.6, tint.a);
	float sn = COLOR.a * smoothstep(0.45, 0.85, wn.y) * smoothstep(0.08, 0.2, lum);
	ALBEDO = mix(c, vec3(0.9, 0.93, 0.98), sn);
	// Obustronnie z tą samą (kulistą) normalną.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.8;
}
