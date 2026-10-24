// Źdźbła trawy kołyszą się na wietrze i odchylają przed graczem.
// UV.y = 0 na czubku, 1 u nasady źdźbła.
shader_type canvas_item;

uniform vec2 player_pos = vec2(-99999.0);
uniform float wind = 1.0;
uniform float push_radius = 64.0;

void vertex() {
	float h = 1.0 - UV.y;
	vec2 wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float sway = sin(TIME * 1.7 + wpos.x * 0.021 + wpos.y * 0.013) * 2.6 * wind;
	vec2 d = wpos - player_pos;
	float push = clamp(1.0 - length(d) / push_radius, 0.0, 1.0);
	VERTEX.x += (sway + sign(d.x) * push * 11.0) * h;
	VERTEX.y += push * 3.0 * h;
}
