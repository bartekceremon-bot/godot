extends Node2D
## Elementy świata, które zmieniają się po ukończeniu zadań:
## brama energii, ściana iluzji, kanał wody, przenośnik, grządki, regały, winda.

var kind := "gate"
var flag := ""
var size := Vector2(100, 40)
var state := 0.0           # 0 = przed zmianą, 1 = po zmianie
var t := 0.0
var body: StaticBody2D
var def: Dictionary = {}
var _dissolve: ShaderMaterial


func setup(d: Dictionary) -> void:
	def = d
	kind = d.get("type", "gate")
	flag = d.get("flag", "")
	size = Vector2(d.get("size", [100, 40])[0], d.get("size", [100, 40])[1])
	state = 1.0 if GameState.flags_met(flag) else 0.0
	if kind in ["gate", "fogwall", "crates"]:
		body = StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		body.add_child(cs)
		add_child(body)
		body.collision_layer = 1
		_update_body()
	if kind == "fogwall":
		_dissolve = ShaderMaterial.new()
		_dissolve.shader = preload("res://assets/shaders/dissolve.gdshader")
		material = _dissolve
		_dissolve.set_shader_parameter("amount", state)
	if kind == "water":
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/water.gdshader")
		material = m
		m.set_shader_parameter("fill", maxf(state, 0.15))
	GameState.flag_changed.connect(_on_flag)


func _update_body() -> void:
	if body:
		body.process_mode = Node.PROCESS_MODE_DISABLED if state >= 1.0 else Node.PROCESS_MODE_INHERIT
		for c in body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", state >= 1.0)


func _on_flag(f: String) -> void:
	if f != flag or state >= 1.0:
		return
	Audio.play("unlock" if kind != "water" else "water")
	var dur := 0.5 if Settings.reduced_motion else 1.8
	var tw := create_tween()
	tw.tween_method(_set_state, 0.0, 1.0, dur)
	tw.tween_callback(_update_body)
	if World.current:
		World.current.burst(global_position, Art.GOLD, 24)


func _set_state(v: float) -> void:
	state = v
	if _dissolve:
		_dissolve.set_shader_parameter("amount", v)
	if kind == "water" and material:
		(material as ShaderMaterial).set_shader_parameter("fill", maxf(v, 0.15))
	queue_redraw()


var _redraw_acc := 0.0


func _process(delta: float) -> void:
	t += delta
	# Animacje ambientowe odświeżamy ~12 razy na sekundę i tylko w kadrze —
	# każde przerysowanie wielokątów jest kosztowne na WebGL.
	var animated := (kind == "gate" and state < 1.0) or (kind == "fogwall" and state < 1.0) \
		or (kind == "conveyor" and state > 0.0) or (kind == "shelves" and state > 0.0)
	if not animated or not is_visible_in_tree():
		return
	if World.current and not World.current.on_screen(global_position, maxf(size.x, size.y)):
		return
	_redraw_acc += delta
	if _redraw_acc >= (1.0 / 12.0 if kind != "conveyor" else 1.0 / 20.0):
		_redraw_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	match kind:
		"gate":
			if state >= 1.0:
				# Otwarta brama: dwa słupki po bokach.
				_posts(r)
				return
			_posts(r)
			var a := (1.0 - state) * (0.55 + 0.15 * sin(t * 4.0))
			draw_rect(r, Color(Art.TEAL, a * 0.5))
			for i in 5:
				var y := r.position.y + r.size.y * (i + 0.5) / 5.0
				var pts := PackedVector2Array()
				for k in 11:
					var x := r.position.x + r.size.x * k / 10.0
					pts.append(Vector2(x, y + sin(t * 6.0 + k + i) * 3.0))
				draw_polyline(pts, Color(Art.CREAM, a), 2.0, true)
		"fogwall":
			var c := Color("#6b4a9a")
			for i in 14:
				var p := r.position + Vector2(fmod(i * 37.0, r.size.x), fmod(i * 23.0, r.size.y))
				draw_circle(p + Vector2(sin(t + i) * 6, cos(t * 0.8 + i) * 4), 22 + (i % 3) * 8, Color(c, 0.75))
			draw_rect(r, Color(c, 0.6))
		"water":
			draw_colored_polygon(Art.rrect(r, 14), Color(1, 1, 1, 1))
			draw_polyline(Art.rrect(r, 14) + PackedVector2Array([Art.rrect(r, 14)[0]]), Color("#6b5a48"), 5.0, true)
		"conveyor":
			Art.poly(self, Art.rrect(r, 8), Color("#3b4a44"))
			var spd := state * 60.0
			var n := int(r.size.x / 24.0)
			for i in n + 1:
				var x := r.position.x + fposmod(i * 24.0 + t * spd, r.size.x)
				draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4), Color("#5d6a73"), 4.0)
			for x in [r.position.x, r.end.x]:
				Art.circle(self, Vector2(x, 0), r.size.y * 0.5, Color("#7d8a93"))
			if state > 0.0:
				# Skrzynie jadą po taśmie.
				for i in 3:
					var x := r.position.x + fposmod(i * r.size.x / 3.0 + t * spd, r.size.x)
					Art.poly(self, Art.rrect(Rect2(x - 12, -16, 24, 22), 3), Color("#b07a42"))
		"crates":
			if state >= 1.0:
				return
			var off := state * 160.0
			for i in 3:
				var p := Vector2(-28 + i * 28 + off, (i % 2) * 8 - 6)
				Art.poly(self, Art.rrect(Rect2(p - Vector2(16, 30), Vector2(32, 32)), 3), Color("#b07a42"))
				draw_line(p - Vector2(16, 30), p + Vector2(16, 2), Color("#7a5228"), 3.0)
		"flowerbed":
			Art.poly(self, Art.rrect(r, 10), Color("#6e4a2a"))
			var rows := int(r.size.y / 26.0)
			var cols := int(r.size.x / 26.0)
			for y in rows:
				for x in cols:
					var p := r.position + Vector2(13 + x * 26, 18 + y * 26)
					var k := (x * 7 + y * 3) % 4
					var colr: Color = [Color("#ff7a8a"), Art.GOLD, Color("#c89bff"), Color("#f5ecd7")][k]
					var bloom := clampf(state * 1.4 - (x + y) * 0.04, 0.0, 1.0)
					var sway := 0.0
					draw_line(p, p + Vector2(sway, -6 - 6 * bloom), Color("#3f8a47"), 2.0)
					if bloom > 0.0:
						draw_circle(p + Vector2(sway, -8 - 6 * bloom), 2.0 + 3.0 * bloom, colr)
					else:
						draw_circle(p + Vector2(0, -6), 2.0, Color("#5a4a3a"))
		"shelves":
			var glow_a := state * (0.25 + 0.1 * sin(t * 2.0))
			Art.glow(self, Vector2.ZERO, size.x * 0.6, Color(Art.GOLD, glow_a))
			for i in 6:
				var a := t * 0.6 + i * TAU / 6
				var p := Vector2(cos(a) * size.x * 0.35, sin(a) * size.y * 0.3 - 30)
				if state > 0.0:
					Art.poly(self, Art.rrect(Rect2(p - Vector2(6, 4), Vector2(12, 8)), 2), Color(Art.CREAM, state), Art.INK, 1.0)
		"lift":
			Art.poly(self, Art.rrect(r, 10), Color("#5d6a73"))
			draw_rect(r.grow(-10), Color(Art.TEAL, 0.25 + 0.5 * state))
			var y := lerpf(r.end.y - 14, r.position.y + 14, state)
			Art.poly(self, Art.rrect(Rect2(r.position.x + 6, y - 8, r.size.x - 12, 16), 4), Color("#c9a24a"))


func _posts(r: Rect2) -> void:
	var wide := r.size.x >= r.size.y
	var ends := [r.position + Vector2(0, r.size.y * 0.5), r.position + Vector2(r.size.x, r.size.y * 0.5)] if wide \
		else [r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, r.size.y)]
	for p in ends:
		Art.shadow(self, p + Vector2(0, 4), 12, 5)
		Art.poly(self, Art.rrect(Rect2(p + Vector2(-8, -42), Vector2(16, 46)), 4), Color("#3b4a44"))
		draw_circle(p + Vector2(0, -44), 7, Art.TEAL if state < 1.0 else Art.GOLD)
