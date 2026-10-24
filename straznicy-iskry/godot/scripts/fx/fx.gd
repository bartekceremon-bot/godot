extends Node2D
## Krótkotrwałe efekty wizualne: iskry, pierścienie, liczby obrażeń, błyskawice, cięcia.

var kind := "burst"
var life := 0.0
var duration := 0.6
var color := Color.WHITE
var size := 40.0
var text := ""
var points := PackedVector2Array()
var dir := Vector2.RIGHT
var _parts: Array = []


func init(k: String, pos: Vector2, c: Color, s: float, n := 10) -> void:
	kind = k
	position = pos
	color = c
	size = s
	z_index = 20
	match kind:
		"burst":
			duration = 0.55
			for i in n:
				var a := randf() * TAU
				_parts.append([Vector2(cos(a), sin(a) * 0.7) * randf_range(0.4, 1.0) * size, randf_range(2.0, 4.5)])
		"ring":
			duration = 0.5
		"text":
			duration = 0.9
		"lightning":
			duration = 0.28
		"slash":
			duration = 0.22


func _process(delta: float) -> void:
	life += delta
	if life >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := life / duration
	match kind:
		"burst":
			for p in _parts:
				var pos: Vector2 = p[0] * (0.2 + k)
				var r: float = p[1] * (1.0 - k)
				draw_rect(Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), Color(color, 1.0 - k))
		"ring":
			var r := size * (0.3 + 0.7 * k)
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.6))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"text":
			var font := UITheme.bold_font()
			var y := -30.0 * k
			draw_string_outline(font, Vector2(-30, y), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 20, 5, Color(Art.INK, 1.0 - k * k))
			draw_string(font, Vector2(-30, y), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 20, Color(color, 1.0 - k * k))
		"lightning":
			if points.size() >= 2:
				draw_polyline(points, Color(color, (1.0 - k) * 0.5), 7.0, true)
				draw_polyline(points, Color(Art.CREAM, 1.0 - k), 2.5, true)
		"slash":
			var ang := dir.angle()
			draw_set_transform(Vector2(0, -24), ang, Vector2.ONE)
			draw_arc(Vector2.ZERO, 54, -1.1 + k * 0.4, 1.1 + k * 0.4, 18, Color(color, 1.0 - k), 9.0 * (1.0 - k) + 2.0, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
