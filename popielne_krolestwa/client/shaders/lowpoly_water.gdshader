shader_type spatial;
// Woda low-poly: fale w wierzchołkach, płaskie ścianki, piana przy brzegu (COLOR.r = odległość od brzegu 0..1).
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform vec3 deep_color : source_color = vec3(0.07, 0.25, 0.38);
uniform vec3 shallow_color : source_color = vec3(0.2, 0.55, 0.62);
uniform vec3 foam_color : source_color = vec3(0.85, 0.95, 0.95);

varying float shore;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(TIME * 1.1 + wpos.x * 1.7) * 0.5 + sin(TIME * 0.9 + wpos.z * 2.1 + wpos.x) * 0.5;
	VERTEX.y += w * 0.045 * COLOR.r;
	shore = COLOR.r;
}

void fragment() {
	// Płaskie cieniowanie z pochodnych pozycji (ładne „ścianki” fal).
	vec3 n = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	NORMAL = n;
	float foam = smoothstep(0.35, 0.0, shore) * (0.6 + 0.4 * sin(TIME * 2.0 + wpos.x * 3.0 + wpos.z * 2.0));
	vec3 c = mix(shallow_color, deep_color, smoothstep(0.1, 0.9, shore));
	ALBEDO = mix(c, foam_color, clamp(foam, 0.0, 1.0));
	ROUGHNESS = 0.12;
	METALLIC = 0.1;
	SPECULAR = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALPHA = clamp(0.72 + fres * 0.25 + foam * 0.3, 0.0, 1.0);
}
