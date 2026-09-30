shader_type spatial;
// Kępy trawy (MultiMesh): karta z teksturą źdźbeł, kolor z INSTANCE_CUSTOM (kolor gruntu),
// kołysanie na wietrze, zanikanie z odległością od kamery.
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade_start = 22.0;
uniform float fade_end = 34.0;
uniform float wind = 1.0;

varying vec4 tint;
varying float dist;

void vertex() {
	tint = INSTANCE_CUSTOM;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y < 0.5 ? 1.0 - UV.y : 0.0;
	h = 1.0 - UV.y;
	float ph = TIME * 1.6 + wp.x * 0.55 + wp.z * 0.4;
	VERTEX.x += sin(ph) * 0.08 * h * h * wind;
	VERTEX.z += cos(ph * 0.7) * 0.05 * h * h * wind;
	dist = length(wp - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

void fragment() {
	vec4 t = texture(grass_tex, UV);
	float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
	// Dithering przy zanikaniu (bez przezroczystości – szybkie na telefonach).
	float d = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (t.a < 0.45 || d > fade) {
		discard;
	}
	float lum = dot(t.rgb, vec3(0.3, 0.55, 0.15));
	vec3 c = mix(t.rgb, tint.rgb * lum * 3.2, tint.a);
	ALBEDO = c * mix(0.55, 1.0, 1.0 - UV.y);
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.5;
}
