shader_type spatial;
// Teren z teksturami: każdy trójkąt ma warstwy trzech narożników (CUSTOM0) i współrzędne barycentryczne
// (UV2); warstwy mieszane są z uwzględnieniem wysokości tekstur (naturalne przejścia trawa/ziemia/bruk).
// Kolor wierzchołka barwi teksturę (kraina, strefa). UV.x = 1 – „naklejka” w jednolitym kolorze,
// UV.y – żar (szczeliny w popiele).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 layer_mean[14];
uniform float layer_tint[14];
uniform float layer_rough[14];
uniform float tex_scale = 0.42;
uniform float normal_strength = 1.3;
uniform int rock_layer = 5;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 ids;
varying vec3 bary;
varying float glow;
varying float plain;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ids = CUSTOM0.xyz;
	bary = vec3(UV2.x, UV2.y, 1.0 - UV2.x - UV2.y);
	glow = UV.y;
	plain = UV.x;
}

// Próbka warstwy: rgb + wysokość (a) oraz nachylenie z mapy normalnych (xz w przestrzeni świata).
void sample_layer(float id, vec3 n, out vec4 alb, out vec2 slope) {
	vec2 uv = wpos.xz * tex_scale;
	if (int(id + 0.5) == rock_layer && n.y < 0.8) {
		// Ściany gór – rzut trójpłaszczyznowy (bez rozciągania tekstury).
		vec3 bw = pow(abs(n), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec4 ax = texture(albedo_tex, vec3(wpos.zy * tex_scale, id));
		vec4 ay = texture(albedo_tex, vec3(uv, id));
		vec4 az = texture(albedo_tex, vec3(wpos.xy * tex_scale, id));
		alb = ax * bw.x + ay * bw.y + az * bw.z;
		slope = (texture(normal_tex, vec3(uv, id)).xy * 2.0 - 1.0) * bw.y;
		return;
	}
	alb = texture(albedo_tex, vec3(uv, id));
	// Makrowariacja: ta sama warstwa w dużej skali – mniej widoczne powtarzanie.
	float macro = texture(albedo_tex, vec3(uv * 0.11 + vec2(0.37, 0.71), id)).a;
	alb.rgb *= 0.8 + macro * 0.4;
	slope = texture(normal_tex, vec3(uv, id)).xy * 2.0 - 1.0;
}

void fragment() {
	if (plain > 0.5 || glow > 0.01) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.9;
		float pulse = 0.55 + 0.45 * sin(TIME * 1.7 + wpos.x * 1.3 + wpos.z * 0.9);
		EMISSION = vec3(1.0, 0.32, 0.06) * glow * pulse * 1.6;
	} else {
		vec3 n = normalize(wnorm);
		vec4 a0; vec4 a1; vec4 a2;
		vec2 s0; vec2 s1; vec2 s2;
		sample_layer(ids.x, n, a0, s0);
		if (abs(ids.y - ids.x) < 0.5) { a1 = a0; s1 = s0; } else { sample_layer(ids.y, n, a1, s1); }
		if (abs(ids.z - ids.x) < 0.5) { a2 = a0; s2 = s0; } else if (abs(ids.z - ids.y) < 0.5) { a2 = a1; s2 = s1; } else { sample_layer(ids.z, n, a2, s2); }
		// Mieszanie z wysokością: kamienie „wystają” ponad trawę, trawa wchodzi w szczeliny.
		vec3 w = bary + vec3(a0.a, a1.a, a2.a) * 0.45;
		float mx = max(w.x, max(w.y, w.z)) - 0.22;
		w = max(w - mx, vec3(0.0));
		w /= (w.x + w.y + w.z + 1e-4);
		int i0 = int(ids.x + 0.5);
		int i1 = int(ids.y + 0.5);
		int i2 = int(ids.z + 0.5);
		vec3 c = COLOR.rgb;
		vec3 t0 = mix(vec3(1.0), c / max(layer_mean[i0], vec3(0.04)), layer_tint[i0]);
		vec3 t1 = mix(vec3(1.0), c / max(layer_mean[i1], vec3(0.04)), layer_tint[i1]);
		vec3 t2 = mix(vec3(1.0), c / max(layer_mean[i2], vec3(0.04)), layer_tint[i2]);
		vec3 alb = a0.rgb * t0 * w.x + a1.rgb * t1 * w.y + a2.rgb * t2 * w.z;
		ALBEDO = clamp(alb, vec3(0.0), vec3(1.0));
		ROUGHNESS = layer_rough[i0] * w.x + layer_rough[i1] * w.y + layer_rough[i2] * w.z;
		SPECULAR = 0.3;
		vec2 sl = s0 * w.x + s1 * w.y + s2 * w.z;
		vec3 pn = normalize(n + vec3(sl.x, 0.0, sl.y) * normal_strength);
		NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
		// Wgłębienia tekstury ciemniejsze (tanie AO).
		float hgt = a0.a * w.x + a1.a * w.y + a2.a * w.z;
		AO = mix(0.55, 1.0, hgt);
		AO_LIGHT_AFFECT = 0.4;
	}
}
