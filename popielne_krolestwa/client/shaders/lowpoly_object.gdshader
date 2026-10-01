shader_type spatial;
// Obiekty: kolor z wierzchołków, UV.x = metaliczność (0..1) albo numer tekstury (>= 2),
// UV.y = świecenie. Tekstury nakładane rzutem trójpłaszczyznowym w przestrzeni świata
// (kamienne bloki, dachówka, deski, tynk, skała, śnieg) – kolor wierzchołka nadaje barwę,
// tekstura szczegół (jasność) i nierówności (mapy normalnych).
// flash – biały błysk po trafieniu (ustawiany osobno dla każdej istoty).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float flash = 0.0;
uniform float fade = 1.0;
uniform sampler2D tex_stone : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_stone_n : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_roof : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_roof_n : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_wood : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_wood_n : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_plaster : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray terrain_array : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform float wet = 0.0;

varying vec2 ch;
varying vec3 wpos;
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
	ch = UV;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

// Rzut trójpłaszczyznowy: rgb + nachylenie (xy) z mapy normalnych w przestrzeni świata.
vec4 tri_sample(sampler2D t, vec3 p, vec3 bw, float s) {
	return texture(t, p.zy * s) * bw.x + texture(t, p.xz * s) * bw.y + texture(t, p.xy * s) * bw.z;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float metal = ch.x;
	float rough = mix(0.85, 0.32, ch.x);
	if (textured && occluding(VERTEX, FRAGCOORD.xy, INV_VIEW_MATRIX)) {
		discard;
	}
	if (textured && ch.x > 1.5) {
		metal = 0.0;
		int id = int(ch.x + 0.5);
		vec3 n = normalize(wn);
		vec3 bw = pow(abs(n), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 detail = vec3(1.0);
		vec3 nrm = vec3(0.5, 0.5, 1.0);
		if (id == 2) {
			detail = tri_sample(tex_stone, wpos, bw, 0.55).rgb / 0.49;
			nrm = tri_sample(tex_stone_n, wpos, bw, 0.55).rgb;
			rough = 0.9;
		} else if (id == 3) {
			// Dachówka: rzędy wzdłuż spadku dachu (rzut na płaszczyznę prostopadłą do kalenicy).
			vec2 uv = abs(n.x) > abs(n.z) ? vec2(wpos.z, wpos.y + wpos.x * sign(n.x)) : vec2(wpos.x, wpos.y + wpos.z * sign(n.z));
			detail = texture(tex_roof, uv * 0.36).rgb / vec3(0.566, 0.217, 0.128);
			detail = vec3(lum(detail * vec3(0.566, 0.217, 0.128)) / 0.29);
			nrm = texture(tex_roof_n, uv * 0.36).rgb;
			rough = 0.75;
		} else if (id == 4) {
			detail = vec3(lum(tri_sample(tex_wood, wpos, bw, 0.9).rgb) / 0.29);
			nrm = tri_sample(tex_wood_n, wpos, bw, 0.9).rgb;
			rough = 0.85;
		} else if (id == 5) {
			detail = vec3(lum(tri_sample(tex_plaster, wpos, bw, 0.6).rgb) / 0.82);
			rough = 0.95;
		} else if (id == 6) {
			vec3 r = (texture(terrain_array, vec3(wpos.zy * 0.5, 5.0)).rgb * bw.x + texture(terrain_array, vec3(wpos.xz * 0.5, 5.0)).rgb * bw.y + texture(terrain_array, vec3(wpos.xy * 0.5, 5.0)).rgb * bw.z);
			detail = vec3(lum(r) / 0.45);
			rough = 0.85;
		} else if (id == 7) {
			detail = vec3(lum(texture(terrain_array, vec3(wpos.xz * 0.5, 4.0)).rgb) / 0.88);
			rough = 0.6;
		}
		c *= clamp(detail, vec3(0.0), vec3(2.0));
		c *= mix(1.0, 0.75, wet * step(0.5, n.y + 0.3));
		rough = mix(rough, 0.3, wet * 0.7);
		// Nierówności z mapy normalnych (bez stycznych – zaburzenie normalnej w przestrzeni świata).
		vec2 sl = nrm.xy * 2.0 - 1.0;
		vec3 pn = normalize(n + (vec3(0.0, sl.y, sl.x) * bw.x + vec3(sl.x, 0.0, sl.y) * bw.y + vec3(sl.x, sl.y, 0.0) * bw.z) * 0.9);
		NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	}
	ALBEDO = mix(c, vec3(1.0), flash);
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = mix(0.25, 0.6, metal);
	EMISSION = COLOR.rgb * ch.y * 2.2 + vec3(flash * 0.6);
}
