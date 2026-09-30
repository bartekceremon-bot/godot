shader_type spatial;
// Kora drzew i pnie: tekstura kory (UV), COLOR.rgb = barwa, COLOR.a = siła tekstury.
// Lekkie kołysanie na wietrze rosnące z wysokością. Maska (use_mask) – dalekie drzewa
// znikają nad załadowanymi kawałkami pełnego świata.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float wind = 1.0;
uniform float snow = 0.0;
uniform bool use_mask = false;
uniform sampler2D chunk_mask : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(-16.0);
uniform vec2 mask_span = vec2(288.0);

varying vec2 origin;
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
	float hgt = max(VERTEX.y, 0.0);
	float ph = TIME * 1.1 + origin.x * 0.37 + origin.y * 0.23;
	VERTEX.x += sin(ph) * 0.012 * hgt * hgt * wind;
	VERTEX.z += cos(ph * 0.8) * 0.008 * hgt * hgt * wind;
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
	vec3 t = texture(bark_tex, UV).rgb;
	float l = dot(t, vec3(0.3, 0.55, 0.15)) / 0.25;
	vec3 c = COLOR.rgb * mix(vec3(1.0), vec3(l), COLOR.a);
	float sn = snow * smoothstep(0.2, 0.7, wn.y);
	ALBEDO = mix(c, vec3(0.92, 0.95, 1.0), sn);
	ROUGHNESS = 0.9;
	NORMAL_MAP = texture(bark_normal, UV).rgb;
	NORMAL_MAP_DEPTH = COLOR.a;
}
