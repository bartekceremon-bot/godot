// Teren świata rysowany jednym shaderem na całą mapę.
// Każdy kafelek ma typ terenu (tekstura map_tex, kanał R). Tekstury terenu są próbkowane
// we współrzędnych świata (bez widocznej siatki), a tereny o wyższym priorytecie
// „wylewają się” na sąsiednie kafelki z nieregularną, szumową krawędzią.
// Woda jest animowana (klatki + falowanie) i ma pianę przy brzegu.
shader_type canvas_item;

uniform sampler2D map_tex : filter_nearest;
uniform vec2 map_size = vec2(96.0, 96.0);
uniform sampler2D tex_grass : repeat_enable, filter_nearest;
uniform sampler2D tex_dirt : repeat_enable, filter_nearest;
uniform sampler2D tex_sand : repeat_enable, filter_nearest;
uniform sampler2D tex_ash : repeat_enable, filter_nearest;
uniform sampler2D tex_floor : repeat_enable, filter_nearest;
uniform sampler2D tex_marble : repeat_enable, filter_nearest;
uniform sampler2D tex_water : filter_nearest;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

const float TS = 32.0;
// Identyfikatory terenu (zgodne z game.gd): 0 trawa, 1 droga, 2 piasek, 3 popiół, 4 bruk, 5 marmur, 6 woda.

int tid(vec2 cell) {
	vec2 c = clamp(cell, vec2(0.0), map_size - 1.0);
	return int(texture(map_tex, (c + 0.5) / map_size).r * 255.0 + 0.5);
}

int priority(int id) {
	if (id == 0) return 5;
	if (id == 3) return 4;
	if (id == 1) return 3;
	if (id == 2) return 2;
	if (id == 6) return 0;
	return 10;
}

bool hard(int id) {
	return id == 4 || id == 5;
}

vec4 terrain(int id, vec2 p) {
	vec2 uv = p / 128.0;
	if (id == 0) return texture(tex_grass, uv);
	if (id == 1) return texture(tex_dirt, uv);
	if (id == 2) return texture(tex_sand, uv);
	if (id == 3) return texture(tex_ash, uv);
	if (id == 4) return texture(tex_floor, uv);
	if (id == 5) return texture(tex_marble, uv);
	vec2 d = vec2(sin(p.y * 0.07 + TIME * 1.3), cos(p.x * 0.06 + TIME * 1.1)) * 1.5;
	vec2 q = fract((p + d) / 128.0);
	float frame = floor(mod(TIME * 2.5, 4.0));
	return texture(tex_water, vec2((q.x + frame) / 4.0, q.y));
}

void fragment() {
	vec2 p = UV * map_size * TS;
	vec2 cell = floor(p / TS);
	int me = tid(cell);
	vec4 col = terrain(me, p);
	float n = texture(noise_tex, p / 64.0).r;
	float n2 = texture(noise_tex, p / 23.0 + 0.37).g;
	float reach = 8.0 + (n - 0.5) * 12.0 + (n2 - 0.5) * 4.0;

	if (!hard(me)) {
		int ids[8];
		vec2 offs[8] = vec2[8](vec2(-1, -1), vec2(0, -1), vec2(1, -1), vec2(-1, 0), vec2(1, 0), vec2(-1, 1), vec2(0, 1), vec2(1, 1));
		for (int i = 0; i < 8; i++) {
			ids[i] = tid(cell + offs[i]);
		}
		int my_pri = priority(me);
		float foam = 0.0;
		// Przejścia od najniższego do najwyższego priorytetu (wyższe przykrywają niższe).
		for (int pri = 1; pri <= 5; pri++) {
			if (pri <= my_pri) continue;
			float cov = 0.0;
			int src = -1;
			for (int i = 0; i < 8; i++) {
				int nb = ids[i];
				if (hard(nb) || priority(nb) != pri) continue;
				vec2 nmin = (cell + offs[i]) * TS;
				vec2 q = clamp(p, nmin, nmin + TS);
				float d = length(p - q);
				float c = 1.0 - smoothstep(reach - 1.5, reach + 0.5, d);
				if (c > cov) {
					cov = c;
					src = nb;
				}
				if (me == 6) {
					foam = max(foam, 1.0 - smoothstep(0.0, 2.5, abs(d - reach - 1.5)));
				}
			}
			if (src >= 0 && cov > 0.0) {
				col = mix(col, terrain(src, p), cov);
			}
		}
		if (me == 6) {
			float pulse = 0.55 + 0.45 * sin(TIME * 2.0 + p.x * 0.09 + p.y * 0.05);
			col.rgb = mix(col.rgb, vec3(0.78, 0.9, 0.95), foam * 0.55 * pulse);
		}
	}
	COLOR = col;
}
