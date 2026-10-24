extends Node2D
## Elementy pierwszego planu (liście, łańcuchy, kryształy) z lekką paralaksą.
## Przezroczyste, gdy gracz jest pod nimi — nie zasłaniają rozgrywki.

const PARALLAX := 0.12

var kind := "leaves"
var t := 0.0
var _alpha := 0.85
var _anchor := Vector2.ZERO


func _ready() -> void:
	_anchor = position


func _process(delta: float) -> void:
	t += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		position = _anchor + (_anchor - cam.get_screen_center_position()) * PARALLAX
	var p := World.player()
	var target := 0.85
	if p and p.global_position.distance_to(global_position + Vector2(0, 40)) < 190.0:
		target = 0.18
	_alpha = move_toward(_alpha, target, delta * 2.5)
	modulate.a = _alpha
	queue_redraw()


func _draw() -> void:
	var sway := 0.0 if Settings.reduced_motion else sin(t * 0.9) * 0.04
	draw_set_transform(Vector2.ZERO, sway, Vector2.ONE)
	match kind:
		"leaves":
			var cols := [Color("#1c4a33"), Color("#245c3e"), Color("#2f6b3a")]
			for i in 9:
				var a := i * 0.7
				var p := Vector2(cos(a) * (40 + i * 9), sin(a) * 30 + i * 4)
				draw_colored_polygon(Art.ellipse(p, 46 - i * 2, 22, 14, a), cols[i % 3])
		"chains":
			for i in 3:
				var x := -40.0 + i * 40.0
				var pts := PackedVector2Array()
				for k in 8:
					pts.append(Vector2(x + sin(t + k * 0.5 + i) * 3.0, -60 + k * 22))
				draw_polyline(pts, Color("#2a2f3a"), 5.0, true)
				draw_circle(pts[pts.size() - 1], 9, Color("#c9a24a"))
		"crystals":
			for i in 4:
				var x := -60.0 + i * 38.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 12, -40), Vector2(x + 12, -40), Vector2(x, 30 + (i % 2) * 30)]), Color("#2aa89b", 0.9))
		"vines":
			for i in 5:
				var x := -80.0 + i * 40.0
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(Vector2(x + sin(t * 0.8 + k * 0.6 + i) * 6.0, -50 + k * 18))
				draw_polyline(pts, Color("#245c3e"), 6.0, true)
				for k in range(1, 7, 2):
					draw_colored_polygon(Art.ellipse(pts[k] + Vector2(8, 0), 9, 5, 10, 0.5), Color("#2f6b3a"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
