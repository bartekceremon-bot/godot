shader_type sky;
// Niebo świata: gradient pory dnia, tarcza słońca / księżyca, płynące chmury i gwiazdy nocą.

uniform vec3 zenith_color : source_color = vec3(0.26, 0.47, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.83, 0.92);
uniform vec3 ground_color : source_color = vec3(0.35, 0.38, 0.4);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.6, 0.65, 0.75);
uniform float cloud_cover = 0.5;
uniform float night = 0.0;
uniform float storm = 0.0;
uniform float flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, pow(smoothstep(-0.03, 0.5, h), 0.55));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, h));

	vec3 ldir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.3, 0.6, 0.4));
	float s = max(dot(d, ldir), 0.0);
	float day = 1.0 - night;
	// Słońce: tarcza + poświata; nocą ten sam kierunek jest księżycem (mniejsza, zimna tarcza).
	vec3 disk = sun_color * (smoothstep(0.9993, 0.9996, s) * 6.0 + pow(s, 12.0) * 0.35 + pow(s, 3.0) * 0.12) * day;
	float moon = smoothstep(0.99955, 0.99975, s);
	float crater = noise(d.xz * 900.0) * 0.25;
	disk += vec3(0.85, 0.9, 1.0) * (moon * (1.3 - crater) + pow(s, 30.0) * 0.12) * night;
	col += disk * (1.0 - storm * 0.85);

	// Gwiazdy.
	if (night > 0.01 && h > 0.0) {
		vec2 g = floor(d.xz / (h + 0.3) * 260.0);
		float st = step(0.996, hash(g)) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(g + 3.0) * 30.0));
		col += vec3(st) * night * smoothstep(0.0, 0.25, h) * (1.0 - storm);
	}

	// Chmury na płaszczyźnie nieba.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.9 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv * 1.6);
		float cover = mix(cloud_cover, 0.95, storm);
		float a = smoothstep(1.0 - cover, 1.05 - cover * 0.6, n);
		float shade = fbm(uv * 1.6 + ldir.xz * 0.08);
		vec3 lit = mix(cloud_color, cloud_shade, clamp((shade - n) * 4.0 + 0.45, 0.0, 1.0));
		lit += sun_color * pow(s, 6.0) * 0.5 * day;
		lit = mix(lit, cloud_shade * 0.5, storm * 0.6);
		col = mix(col, lit, a * smoothstep(0.0, 0.12, h) * 0.95);
	}
	col += vec3(0.8, 0.85, 1.0) * flash * smoothstep(-0.1, 0.3, h);
	COLOR = col;
}
