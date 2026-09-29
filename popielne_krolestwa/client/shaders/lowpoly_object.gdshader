shader_type spatial;
// Obiekty low-poly: kolor z wierzchołków, UV.x = metaliczność, UV.y = świecenie.
// flash – biały błysk po trafieniu (ustawiany osobno dla każdej istoty).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float flash = 0.0;
uniform float fade = 1.0;

varying vec2 ch;

void vertex() {
	ch = UV;
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c, vec3(1.0), flash);
	METALLIC = ch.x;
	ROUGHNESS = mix(0.85, 0.32, ch.x);
	SPECULAR = mix(0.25, 0.6, ch.x);
	EMISSION = c * ch.y * 2.2 + vec3(flash * 0.6);
}
