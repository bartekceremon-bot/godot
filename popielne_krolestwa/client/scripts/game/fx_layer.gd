extends Node2D
## Efekty wizualne: liczby obrażeń, pociski, leczenie, śmierć, awans, teksty nad głową.

const TS := 32

## Aktywne efekty: słowniki z polami kind, pos, t (czas życia), dur, ...
var _fx: Array[Dictionary] = []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 100


func _center(x, y) -> Vector2:
	return Vector2(float(x) * TS + TS / 2.0, float(y) * TS + TS / 2.0)


const DOT := preload("res://assets/fx/soft_dot.png")


## Jednorazowy wybuch cząsteczek (iskry trafienia, awans, zbieranie).
func burst(pos: Vector2, color: Color, amount: int, speed: float, gravity: float = 60.0, life: float = 0.5) -> void:
	if not Config.effects:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = DOT
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var g := Gradient.new()
	g.colors = PackedColorArray([color.lightened(0.4), color, Color(color, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


## Dodaje efekt z pakietu "fx" serwera.
func spawn(f: Dictionary) -> void:
	var p := _center(f.x, f.y)
	match str(f.k):
		"num":
			var col := Color(1, 0.25, 0.2)
			if f.c == "heal":
				col = Color(0.3, 1, 0.4)
			elif f.c == "mana":
				col = Color(0.4, 0.6, 1)
			_add({"kind": "text", "pos": p, "text": str(int(f.v)), "col": col, "dur": 1.0, "rise": 24.0, "size": 10})
			if f.c == "dmg":
				_add({"kind": "splat", "pos": p, "dur": 0.35})
				burst(p, Color(0.9, 0.15, 0.1), 10, 70.0)
			elif f.c == "heal":
				burst(p, Color(0.4, 1.0, 0.5), 10, 40.0, -40.0, 0.8)
		"miss":
			_add({"kind": "puff", "pos": p, "dur": 0.4, "col": Color(0.8, 0.8, 0.8)})
		"block":
			_add({"kind": "puff", "pos": p, "dur": 0.4, "col": Color(0.5, 0.7, 1)})
			burst(p, Color(0.7, 0.85, 1.0), 6, 60.0)
		"puff":
			_add({"kind": "puff", "pos": p, "dur": 0.5, "col": Color(0.6, 0.6, 0.6)})
		"shot":
			_add({"kind": "shot", "pos": p, "to": _center(f.tx, f.ty), "dur": 0.2})
		"heal":
			_add({"kind": "sparkle", "pos": p, "dur": 0.8, "col": Color(0.4, 1, 0.5)})
		"death":
			_add({"kind": "death", "pos": p, "dur": 3.0})
		"levelup":
			_add({"kind": "sparkle", "pos": p, "dur": 1.2, "col": Color(1, 0.85, 0.3)})
			burst(p, Color(1, 0.8, 0.3), 40, 120.0, -30.0, 1.2)
			_add({"kind": "text", "pos": p, "text": "AWANS!", "col": Color(1, 0.85, 0.3), "dur": 2.0, "rise": 30.0, "size": 12})
		"gather":
			burst(p, Color(0.85, 0.75, 0.5), 8, 50.0, 90.0, 0.5)
			var d := GameData.item_def(str(f.get("item", "")))
			_add({"kind": "text", "pos": p - Vector2(0, 8), "text": "+%d %s" % [int(f.v), str(d.name).get_slice(" (", 0)], "col": Color(0.6, 1, 0.5), "dur": 1.4, "rise": 20.0, "size": 8})
		"craft":
			_add({"kind": "sparkle", "pos": p, "dur": 0.9, "col": Color(1, 0.7, 0.3)})
		"words":
			_add({"kind": "text", "pos": p - Vector2(0, 26), "text": str(f.text), "col": Color(1, 0.6, 0.2), "dur": 1.6, "rise": 6.0, "size": 9})


## Wypowiedź z czatu nad głową gracza.
func say(x, y, who: String, text: String) -> void:
	var p := _center(x, y) - Vector2(0, 30)
	_add({"kind": "text", "pos": p, "text": "%s: %s" % [who, text.left(60)], "col": Color(1, 1, 0.5), "dur": 3.5, "rise": 4.0, "size": 8})


## Znacznik miejsca dotknięcia.
func tap_marker(tile: Vector2i) -> void:
	_add({"kind": "marker", "pos": _center(tile.x, tile.y), "dur": 0.4})


func _add(d: Dictionary) -> void:
	d.t = 0.0
	_fx.append(d)
	queue_redraw()


func _process(delta: float) -> void:
	if _fx.is_empty():
		return
	for f in _fx:
		f.t += delta
	_fx = _fx.filter(func(f): return f.t < f.dur)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for f in _fx:
		var k: float = f.t / f.dur
		var a := 1.0 - k
		match f.kind:
			"text":
				var pos: Vector2 = f.pos - Vector2(60, f.rise * k + 14)
				draw_string_outline(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, f.size, 2, Color(0, 0, 0, a))
				draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, f.size, Color(f.col, a))
			"splat":
				draw_circle(f.pos, 6.0 + 4.0 * k, Color(0.7, 0.05, 0.05, a * 0.8))
			"puff":
				for i in 5:
					var ang := i * TAU / 5.0
					draw_circle(f.pos + Vector2(cos(ang), sin(ang)) * (4 + 10 * k), 3.0 * a + 1, Color(f.col, a))
			"shot":
				var head: Vector2 = f.pos.lerp(f.to, k)
				var tail: Vector2 = f.pos.lerp(f.to, maxf(0.0, k - 0.25))
				draw_line(tail, head, Color(0.85, 0.7, 0.45), 2.0)
				draw_circle(head, 1.5, Color.WHITE)
			"sparkle":
				for i in 8:
					var ang := i * TAU / 8.0 + k * 3.0
					var r := 6.0 + 12.0 * k
					draw_circle(f.pos + Vector2(cos(ang), sin(ang)) * r - Vector2(0, 10 * k), 1.8, Color(f.col, a))
			"death":
				draw_circle(f.pos + Vector2(0, 6), 9.0, Color(0.45, 0.05, 0.05, a * 0.7))
				draw_circle(f.pos + Vector2(5, 9), 4.0, Color(0.45, 0.05, 0.05, a * 0.7))
			"marker":
				draw_rect(Rect2(f.pos - Vector2(15, 15), Vector2(30, 30)), Color(1, 1, 1, a * 0.7), false, 1.0)
