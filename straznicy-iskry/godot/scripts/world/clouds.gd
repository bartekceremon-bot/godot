extends Node2D
## Chmury pod wyspami z paralaksą (wolniej niż świat = wrażenie głębi).

const TILE := Vector2(1700, 1100)

var depth := 0
var tint := Color("#f5ecd7")
var t := 0.0
var _puffs: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + depth
	for i in (5 if Settings.low_quality() else 9):
		_puffs.append([Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y), rng.randf_range(0.7, 1.4)])


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var factor := 0.35 if depth == 0 else 0.6
	var speed := 0.0 if Settings.reduced_motion else (6.0 + depth * 8.0)
	var scroll := c * factor + Vector2(t * speed, 0)
	var alpha := 0.18 if depth == 0 else 0.3
	var size_mul := 1.0 if depth == 0 else 1.5
	for p in _puffs:
		var base: Vector2 = p[0] - scroll
		base = Vector2(fposmod(base.x, TILE.x), fposmod(base.y, TILE.y)) - TILE * 0.5
		var pos := c + base
		var s: float = p[1] * size_mul
		for k in 4:
			var o := Vector2(k * 46.0 - 70.0, sin(k * 1.7) * 14.0) * s
			draw_circle(pos + o, (44.0 - absf(k - 1.5) * 8.0) * s, Color(tint, alpha))
