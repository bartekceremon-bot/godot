extends Control
## Krótkie scenki fabularne: animowana ilustracja + tekst. Zawsze można pominąć.

signal finished

var panels: Array = []
var i := 0
var t := 0.0
var art: Control
var text: RichTextLabel
var text_box: PanelContainer
var next_btn: Button
var _chars := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#07181a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	art = Control.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_art)
	add_child(art)
	text_box = PanelContainer.new()
	add_child(text_box)
	var v := VBoxContainer.new()
	text_box.add_child(v)
	text = UITheme.rich("")
	v.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var skip := UITheme.button("Pomiń scenkę", _end)
	skip.theme_type_variation = "Chip"
	row.add_child(skip)
	next_btn = UITheme.button("Dalej", _next, "Primary")
	next_btn.custom_minimum_size.x = 150
	row.add_child(next_btn)
	get_tree().root.size_changed.connect(_layout)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - 24, 900.0)
	text_box.custom_minimum_size = Vector2(w, 0)
	text_box.size = Vector2(w, 0)
	text_box.position = Vector2((vs.x - w) * 0.5, vs.y - 230 - Router.safe_margins()["bottom"])


func play(p: Array) -> void:
	panels = p
	i = 0
	_layout()
	_show()


func _show() -> void:
	if i >= panels.size():
		_end()
		return
	t = 0.0
	_chars = 0.0
	text.text = panels[i].get("text", "")
	text.visible_characters = -1 if Settings.reduced_motion else 0
	next_btn.text = "Dalej" if i < panels.size() - 1 else "Zaczynamy!"
	next_btn.grab_focus.call_deferred()


func _next() -> void:
	if text.visible_characters != -1:
		text.visible_characters = -1
		return
	i += 1
	_show()


func _end() -> void:
	if i >= 999:
		return
	i = 999
	finished.emit()


func _process(delta: float) -> void:
	t += delta
	if text.visible_characters >= 0:
		_chars += delta * 45.0
		text.visible_characters = int(_chars)
		if text.visible_characters >= text.get_total_character_count():
			text.visible_characters = -1
	art.queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_end()
		get_viewport().set_input_as_handled()


func _draw_art() -> void:
	if i >= panels.size():
		return
	var vs := art.size
	var scene: String = panels[i].get("scene", "islands")
	var c := Vector2(vs.x * 0.5, vs.y * 0.42)
	var k := minf(vs.x / 1280.0, vs.y / 720.0) * 1.3
	var fade := clampf(t / 0.8, 0.0, 1.0)
	art.modulate.a = fade
	# Niebo i gwiazdy
	for s in 40:
		var p := Vector2(fposmod(s * 137.0, vs.x), fposmod(s * 71.0, vs.y * 0.6))
		art.draw_circle(p, 1.5, Color(1, 1, 1, 0.3 + 0.3 * sin(t * 2.0 + s)))
	var drift := 0.0 if Settings.reduced_motion else t * 10.0
	match scene:
		"islands", "restored":
			for j in 3:
				var ip := c + Vector2((j - 1) * 330 * k + sin(t * 0.5 + j) * 6, (j % 2) * 60 * k + sin(t + j) * 8)
				_island(ip, 120 * k, Color("#4f8a4a") if scene == "restored" or j == 1 else Color("#3d6b44"))
			if scene == "restored":
				_tower(c + Vector2(0, -20 * k), k, 1.0)
				var a := t * 0.7
				art.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -200 * k), c + Vector2(cos(a - 0.1), sin(a - 0.1) * 0.4) * 900, c + Vector2(cos(a + 0.1), sin(a + 0.1) * 0.4) * 900]), Color(Art.GOLD, 0.12))
			else:
				_tower(c + Vector2(0, -20 * k), k, 0.6)
		"fog":
			_island(c, 160 * k, Color("#3d5a44"))
			_tower(c + Vector2(0, -20 * k), k, 0.1)
			for j in 14:
				var fp := c + Vector2(cos(j * 0.9 + t * 0.2) * (220 + j * 14) * k, sin(j * 1.3 + t * 0.3) * 120 * k)
				Art.glow(art, fp + Vector2(drift, 0), 110 * k, Color("#8a5bbf", 0.35))
			art.draw_set_transform(c + Vector2(140 * k, 40 * k), 0, Vector2(2.0, 2.0) * k)
			Art.blik(art, t, "worried", 0.0)
			art.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"blik":
			_island(c + Vector2(0, 80 * k), 180 * k, Color("#4f8a4a"))
			art.draw_set_transform(c + Vector2(0, 60 * k), 0, Vector2(3.0, 3.0) * k)
			Art.blik(art, t, panels[i].get("mood", "happy"), 1.0)
			art.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"hero":
			_island(c + Vector2(0, 80 * k), 180 * k, Color("#4f8a4a"))
			Art.with_parent(Transform2D(0, Vector2(2.6, 2.6) * k, 0, c + Vector2(-50 * k, 70 * k)))
			Art.hero(art, GameState.class_id(), {"t": t, "aim": Vector2.RIGHT})
			Art.with_parent(Transform2D.IDENTITY)
			art.draw_set_transform(c + Vector2(90 * k, 40 * k), 0, Vector2(2.4, 2.4) * k)
			Art.blik(art, t, "cheer", 0.0)
			art.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"fragments":
			_tower(c + Vector2(0, 40 * k), k, 0.4 + 0.2 * sin(t))
			var cols := [Color("#ffd86b"), Art.TEAL, Color("#c89bff")]
			for j in 3:
				var a := t * 0.8 + j * TAU / 3
				var fp := c + Vector2(cos(a) * 180 * k, sin(a) * 70 * k - 160 * k)
				Art.glow(art, fp, 50 * k, Color(cols[j], 0.6))
				Art.poly(art, PackedVector2Array([fp + Vector2(0, -22) * k, fp + Vector2(14, 0) * k, fp + Vector2(0, 22) * k, fp + Vector2(-14, 0) * k]), cols[j], Art.INK, 2.0)


func _island(p: Vector2, r: float, col: Color) -> void:
	for j in range(6, 0, -1):
		art.draw_colored_polygon(Art.ellipse(p + Vector2(0, j * r * 0.08), r, r * 0.42, 26), Color("#5a4232").lerp(Color("#2a1f1a"), j / 6.0))
	art.draw_colored_polygon(Art.ellipse(p, r, r * 0.42, 26), col)


func _tower(p: Vector2, k: float, power: float) -> void:
	var h := 220.0 * k
	art.draw_colored_polygon(PackedVector2Array([p + Vector2(-34 * k, 0), p + Vector2(34 * k, 0), p + Vector2(22 * k, -h), p + Vector2(-22 * k, -h)]), Color("#efe6d2"))
	for j in 3:
		var y := -50 * k - j * 55 * k
		art.draw_rect(Rect2(p + Vector2(-30 * k + j * 3 * k, y), Vector2((60 - j * 6) * k, 12 * k)), Color("#2d6b5f"))
	var lc := p + Vector2(0, -h - 24 * k)
	Art.glow(art, lc, (60 + 120 * power) * k, Color(Art.GOLD, 0.2 + 0.5 * power))
	art.draw_circle(lc, 16 * k, Color(Art.GOLD, 0.3 + 0.7 * power))
	art.draw_colored_polygon(PackedVector2Array([lc + Vector2(-30, -16) * k, lc + Vector2(30, -16) * k, lc + Vector2(0, -50) * k]), Color("#c8553d"))
