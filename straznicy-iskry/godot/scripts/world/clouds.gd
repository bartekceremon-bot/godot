extends Node2D
## Chmury pod wyspami z paralaksą (wolniej niż świat = wrażenie głębi).
## Każdy kłębek to sprite przesuwany co klatkę — bez przerysowywania geometrii.

const TILE := Vector2(1700, 1100)

var depth := 0
var tint := Color("#f5ecd7"):
	set(v):
		tint = v
		for p in _puffs:
			for sp in p[2]:
				sp.modulate = Color(tint, sp.modulate.a)
var t := 0.0
var _puffs: Array = []      # [pozycja w kafelku, skala, [sprite'y]]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + depth
	var alpha := 0.2 if depth == 0 else 0.32
	var size_mul := 1.0 if depth == 0 else 1.5
	for i in (5 if Settings.low_quality() else 9):
		var sc := rng.randf_range(0.7, 1.4) * size_mul
		var sprites: Array = []
		for k in 4:
			var sp := Sprite2D.new()
			sp.texture = Art.soft_texture()
			var r := (44.0 - absf(k - 1.5) * 8.0) * sc
			sp.scale = Vector2.ONE * (r * 2.4 / 64.0)
			sp.modulate = Color(tint, alpha)
			sp.set_meta("off", Vector2(k * 46.0 - 70.0, sin(k * 1.7) * 14.0) * sc)
			add_child(sp)
			sprites.append(sp)
		_puffs.append([Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y), sc, sprites])


func _process(delta: float) -> void:
	t += delta
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var factor := 0.35 if depth == 0 else 0.6
	var speed := 0.0 if Settings.reduced_motion else (6.0 + depth * 8.0)
	var scroll := c * factor + Vector2(t * speed, 0)
	for p in _puffs:
		var base: Vector2 = p[0] - scroll
		base = Vector2(fposmod(base.x, TILE.x), fposmod(base.y, TILE.y)) - TILE * 0.5
		for sp in p[2]:
			sp.position = c + base + sp.get_meta("off")
