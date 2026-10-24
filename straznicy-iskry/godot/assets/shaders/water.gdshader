// Animowana woda: fale i odblaski bez tekstur.
shader_type canvas_item;

uniform vec4 deep : source_color = vec4(0.10, 0.36, 0.45, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.72, 0.76, 1.0);
uniform float speed = 1.0;
uniform float fill = 1.0;
varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = TIME * speed;
	float w = sin(wpos.x * 0.045 + t * 1.3) * 0.5 + sin(wpos.y * 0.06 - t * 1.1 + wpos.x * 0.02) * 0.5;
	vec4 c = mix(deep, shallow, 0.45 + 0.25 * w);
	float glint = smoothstep(0.86, 1.0, sin(wpos.x * 0.11 + wpos.y * 0.07 + t * 2.0) * sin(wpos.y * 0.09 - t * 1.4));
	c.rgb += vec3(glint) * 0.35;
	c.a *= COLOR.a * fill;
	COLOR = c;
}
