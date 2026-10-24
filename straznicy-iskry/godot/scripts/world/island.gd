extends Node2D
## Unosząca się wyspa: organiczny kształt, klif (głębia), kamienie pod spodem.

var poly := PackedVector2Array()
var pal: Dictionary = {}
var depth := 70.0
var _rng := RandomNumberGenerator.new()
var _spots: Array = []
var _roots: Array = []
var _under: Array = []


static func make_shape(rect: Rect2, seed_value: int, jag := 12.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base := Art.rrect(rect, min(rect.size.x, rect.size.y) * 0.32, 6)
	var pts := PackedVector2Array()
	for i in base.size():
		var a := base[i]
		var b := base[(i + 1) % base.size()]
		var steps := int(max(1.0, a.distance_to(b) / 46.0))
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			var n := (b - a).orthogonal().normalized()
			pts.append(p + n * rng.randf_range(-jag, jag * 0.5))
	return pts


func setup(rect: Rect2, seed_value: int, palette: Dictionary) -> void:
	pal = palette
	poly = make_shape(rect, seed_value)
	_rng.seed = seed_value * 7 + 3
	depth = clampf(rect.size.y * 0.09, 46.0, 90.0)
	# Plamy w odcieniach podłoża i kwiatki.
	for i in int(rect.size.x * rect.size.y / 26000.0):
		var p := Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
		if Geometry2D.is_point_in_polygon(p, poly):
			_spots.append([p, _rng.randf_range(18, 60), _rng.randf()])
	# Korzenie zwisające z klifu.
	for i in poly.size():
		var p := poly[i]
		if p.y > rect.get_center().y and _rng.randf() < 0.35:
			_roots.append([p, _rng.randf_range(20, 60), _rng.randf_range(-6, 6)])
	# Drobne skały pod wyspą.
	for i in 3:
		var x := _rng.randf_range(rect.position.x + 60, rect.end.x - 60)
		_under.append([Vector2(x, rect.end.y + depth + _rng.randf_range(30, 120)), _rng.randf_range(10, 26), _rng.randf() * TAU])


func _draw() -> void:
	var cliff_top: Color = Data.col(pal.get("cliff", "#6b4f3a"))
	var cliff_bot: Color = Data.col(pal.get("cliff2", "#3a2a22"))
	var ground: Color = Data.col(pal.get("ground", "#4f8a4a"))
	var ground2: Color = Data.col(pal.get("ground2", "#5f9c55"))
	var rim: Color = Data.col(pal.get("rim", "#8fcf6a"))
	# Skały pod wyspą
	for u in _under:
		var c: Vector2 = u[0]
		var r: float = u[1]
		var shape := PackedVector2Array([c + Vector2(-r, -r * 0.3), c + Vector2(r, -r * 0.4), c + Vector2(r * 0.4, r), c + Vector2(-r * 0.3, r * 0.8)])
		Art.poly(self, shape, cliff_bot.darkened(0.1), Color(0, 0, 0, 0.4), 1.5)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.3), c + Vector2(r, -r * 0.4), c + Vector2(r * 0.7, -r * 0.1), c + Vector2(-r * 0.8, 0)]), ground.darkened(0.15))
	# Klif: warstwy przesunięte w dół (efekt bryły).
	var layers := 7
	for i in range(layers, 0, -1):
		var k := float(i) / layers
		var off := Vector2(0, depth * k)
		var tp := Transform2D(0, off)
		draw_colored_polygon(tp * poly, cliff_top.lerp(cliff_bot, k))
	# Prążki skały
	for i in range(0, poly.size(), 3):
		var p := poly[i]
		draw_line(p + Vector2(0, depth * 0.3), p + Vector2(0, depth * 0.85), Color(0, 0, 0, 0.18), 2.0)
	for r in _roots:
		var p: Vector2 = r[0]
		var l: float = r[1]
		draw_polyline(PackedVector2Array([p + Vector2(0, depth * 0.6), p + Vector2(r[2], depth + l * 0.5), p + Vector2(-r[2], depth + l)]), Color("#2d3b22"), 2.0, true)
	# Wierzch wyspy
	draw_colored_polygon(poly, ground)
	for s in _spots:
		var col := ground2 if s[2] > 0.3 else ground.darkened(0.08)
		draw_colored_polygon(Art.ellipse(s[0], s[1], s[1] * 0.55, 14), Color(col, 0.55))
		if s[2] > 0.82:
			var fc := Color("#f5ecd7") if s[2] > 0.92 else Color("#e8b84a")
			for j in 3:
				draw_circle(s[0] + Vector2(j * 7 - 7, (j % 2) * 4), 2.2, fc)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, rim, 4.0, true)
	draw_polyline(closed, Color(0, 0, 0, 0.35), 1.5, true)


func walk_polygon() -> PackedVector2Array:
	var inset := Geometry2D.offset_polygon(poly, -18.0)
	if inset.is_empty():
		return poly
	var best: PackedVector2Array = inset[0]
	for p in inset:
		if p.size() > best.size():
			best = p
	return best
