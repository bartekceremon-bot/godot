shader_type spatial;
// Malowane tło krainy (próbka stylu C).
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb;
}
