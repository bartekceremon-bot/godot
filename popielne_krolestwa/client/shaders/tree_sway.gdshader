// Delikatne kołysanie koron drzew na wietrze (wierzchołki górne przesuwane w poziomie).
// Drzewa leżą w pierwszym wierszu atlasu obiektów (UV.y 0..0.5), więc waga = 1 u góry, 0 u dołu.
shader_type canvas_item;

uniform float strength = 1.6;
uniform float bottom_uv = 0.5;

void vertex() {
	float w = clamp(1.0 - UV.y / bottom_uv, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.4 + VERTEX.x * 0.043 + VERTEX.y * 0.031) * strength * w;
}
