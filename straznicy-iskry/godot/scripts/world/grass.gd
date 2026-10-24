extends Node2D
## Kępa trawy. Ruch liści i odchylanie przed graczem liczy shader (tanio).

var count := 18
var radius := 40.0
var tint := Color("#5aa854")


func setup(n: int, r: float, c: Color, seed_value: int) -> void:
	count = n
	radius = r
	tint = c
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	set_meta("rng_seed", seed_value)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(get_meta("rng_seed", 1))
	for i in count:
		var p := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius * 0.45, radius * 0.45))
		var h := rng.randf_range(10.0, 20.0)
		var w := rng.randf_range(2.0, 3.6)
		var lean := rng.randf_range(-4.0, 4.0)
		var c := tint.lightened(rng.randf_range(-0.12, 0.18))
		var pts := PackedVector2Array([p + Vector2(-w, 0), p + Vector2(w, 0), p + Vector2(lean, -h)])
		var cols := PackedColorArray([c.darkened(0.25), c.darkened(0.25), c])
		var uvs := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0)])
		draw_polygon(pts, cols, uvs)
