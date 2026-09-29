// Biały błysk przy trafieniu i przezroczystość (pojawianie/znikanie istoty).
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.95, 0.9);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, flash_color, flash * c.a);
	COLOR = c;
}
