extends Node2D
## Most między wyspami. Bez flagi jest zerwany; po jej ustawieniu buduje się deska po desce.

signal built_changed

var a := Vector2.ZERO
var b := Vector2.ZERO
var width := 100.0
var flag := ""
var progress := 1.0          # 0..1 — ile desek widać
var _planks := 0


func setup(def: Dictionary) -> void:
	a = Vector2(def["a"][0], def["a"][1])
	b = Vector2(def["b"][0], def["b"][1])
	width = float(def.get("w", 100))
	flag = def.get("flag", "")
	_planks = int(a.distance_to(b) / 22.0)
	progress = 1.0 if GameState.flags_met(flag) else 0.0
	if not flag.is_empty():
		GameState.flag_changed.connect(_on_flag)


func is_built() -> bool:
	return progress >= 1.0


func _on_flag(f: String) -> void:
	if f == flag and progress < 1.0:
		build_animated()


func build_animated() -> void:
	Audio.play("bridge")
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		progress = v
		queue_redraw(), 0.0, 1.0, 0.4 if Settings.reduced_motion else 2.2)
	t.tween_callback(func() -> void: built_changed.emit())


func walk_polygon() -> PackedVector2Array:
	var dir := (b - a).normalized()
	var n := dir.orthogonal() * (width * 0.5 - 12.0)
	var a2 := a - dir * 50.0
	var b2 := b + dir * 50.0
	return PackedVector2Array([a2 + n, b2 + n, b2 - n, a2 - n])


func _draw() -> void:
	var dir := (b - a).normalized()
	var n := dir.orthogonal() * width * 0.5
	var wood := Color("#9a6b3f")
	var wood_d := Color("#6e4a2a")
	# Słupki na krańcach
	for p in [a + n, a - n, b + n, b - n]:
		draw_colored_polygon(Art.ellipse(p + Vector2(0, 6), 8, 4), Color(0, 0, 0, 0.25))
		Art.poly(self, Art.rrect(Rect2(p + Vector2(-5, -18), Vector2(10, 22)), 3), wood_d)
		draw_circle(p + Vector2(0, -18), 4, Art.GOLD)
	var shown := int(_planks * progress)
	for i in _planks:
		var built := i < shown
		# Zerwany most: zostaje kilka desek przy brzegach.
		if not built and not (i < 2 or i > _planks - 3):
			continue
		var t0 := float(i) / _planks
		var p0 := a.lerp(b, t0 + 0.5 / _planks)
		var sag := sin(t0 * PI) * 8.0 * float(built)
		var c := p0 + Vector2(0, sag)
		var half := dir * 9.0
		var quad := PackedVector2Array([c - half + n * 0.92, c + half + n * 0.92, c + half - n * 0.92, c - half - n * 0.92])
		draw_colored_polygon(Transform2D(0, Vector2(0, 7)) * quad, Color(0, 0, 0, 0.22))
		Art.poly(self, quad, wood if i % 2 == 0 else wood.darkened(0.08), Art.INK, 1.5)
	# Liny
	if progress > 0.0:
		var end := a.lerp(b, progress)
		for side in [1.0, -1.0]:
			var pts := PackedVector2Array()
			for k in 13:
				var t := float(k) / 12.0
				var p = a.lerp(end, t) + n * side * 0.98
				pts.append(p + Vector2(0, -14 + sin(t * PI) * 10.0 * progress))
			draw_polyline(pts, Color("#d8c39a"), 2.5, true)
