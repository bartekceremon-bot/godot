shader_type spatial;
// Próbki stylu: pełnoekranowy przebieg – kontury z bufora głębi, korekcja koloru, winieta.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float outline = 1.0;
uniform float outline_px = 1.6;
uniform vec3 outline_color : source_color = vec3(0.06, 0.04, 0.04);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 1.0;
uniform float vignette = 0.0;
uniform vec3 vignette_color : source_color = vec3(0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float posterize = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float lin(float d, mat4 inv_proj, vec2 uv) {
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	if (outline > 0.0) {
		vec2 px = outline_px / VIEWPORT_SIZE;
		vec2 ux = vec2(px.x, 0.0);
		vec2 uy = vec2(0.0, px.y);
		float z = lin(texture(depth_tex, uv).r, INV_PROJECTION_MATRIX, uv);
		float zs = lin(texture(depth_tex, uv + ux).r, INV_PROJECTION_MATRIX, uv + ux) + lin(texture(depth_tex, uv - ux).r, INV_PROJECTION_MATRIX, uv - ux)
			+ lin(texture(depth_tex, uv + uy).r, INV_PROJECTION_MATRIX, uv + uy) + lin(texture(depth_tex, uv - uy).r, INV_PROJECTION_MATRIX, uv - uy);
		float e = abs(zs - 4.0 * z) / max(z, 0.01);
		float edge = smoothstep(0.06, 0.16, e) * (1.0 - smoothstep(25.0, 45.0, z));
		c = mix(c, outline_color, edge * outline);
	}
	if (posterize > 0.0) {
		c = mix(c, floor(c * posterize + 0.5) / posterize, 0.35);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness * tint;
	vec2 d = uv - 0.5;
	float v = smoothstep(0.3, 0.85, length(d * vec2(1.0, 0.8)));
	c = mix(c, vignette_color, v * vignette);
	ALBEDO = clamp(c, 0.0, 1.0);
}
