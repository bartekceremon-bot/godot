extends Control
## Animowany ekran tytułowy. Dźwięk startuje dopiero po kliknięciu „Graj”.

const SETTINGS := preload("res://scripts/ui/settings_view.gd")

var t := 0.0
var art: Control
var menu: VBoxContainer
var overlay: PanelContainer
var overlay_body: VBoxContainer
var overlay_title: Label
var note: Label
var _has_save := false
var _beam := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/sky.gdshader")
	m.set_shader_parameter("top", Color("#06171c"))
	m.set_shader_parameter("bottom", Color("#1f4c4c"))
	sky.material = m
	add_child(sky)
	art = Control.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_art)
	add_child(art)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	add_child(menu)
	var brand := UITheme.label("AI BLIŻEJ  PRZEDSTAWIA", "Small", false)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_color_override("font_color", Art.TEAL)
	menu.add_child(brand)
	var title := UITheme.label("Strażnicy Iskry", "Title", false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.fs(58))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	menu.add_child(title)
	var sub := UITheme.label("Przygoda o mądrym korzystaniu z AI, logice i bezpieczeństwie w sieci", "", true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(sub)
	menu.add_child(Control.new())
	_has_save = GameState.has_save()
	var play := UITheme.button("Graj" if not _has_save else "Graj dalej", _play, "Primary")
	play.custom_minimum_size = Vector2(320, 64)
	menu.add_child(play)
	if _has_save:
		menu.add_child(UITheme.button("Nowa gra", _confirm_new))
	menu.add_child(UITheme.button("Ustawienia", _show_settings))
	menu.add_child(UITheme.button("Sterowanie", _show_controls))
	menu.add_child(UITheme.button("O grze", _show_about))
	note = UITheme.label("", "Small")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(note)
	_build_overlay()
	Router.layout_changed.connect(func(_n: bool) -> void: _layout())
	_layout()
	play.grab_focus.call_deferred()
	if _has_save:
		# Sprawdzamy zapis od razu, żeby uszczegółowić komunikat przed kliknięciem.
		if not GameState.load_game():
			note.text = GameState.load_message
			_has_save = false
			play.text = "Graj"
		elif GameState.load_message != "":
			note.text = GameState.load_message
	if not GameState.persistent_storage:
		note.text += ("\n" if note.text != "" else "") + "Uwaga: przeglądarka nie zapisze postępu na stałe (np. tryb prywatny)."


func _build_overlay() -> void:
	overlay = PanelContainer.new()
	overlay.visible = false
	add_child(overlay)
	var v := VBoxContainer.new()
	overlay.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	overlay_title = UITheme.label("", "Header")
	overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(overlay_title)
	var close := UITheme.button("Zamknij", func() -> void: overlay.visible = false; menu.visible = true)
	close.theme_type_variation = "Chip"
	head.add_child(close)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	overlay_body = VBoxContainer.new()
	overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(overlay_body)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - 40, 560.0)
	menu.size = Vector2(w, 0)
	menu.custom_minimum_size.x = w
	var portrait := vs.y > vs.x
	menu.position = Vector2((vs.x - w) * 0.5 if portrait else vs.x * 0.56, vs.y * (0.40 if portrait else 0.16))
	if not portrait and menu.position.x + w > vs.x - 20:
		menu.position.x = vs.x - w - 20
	var ow := minf(vs.x - 24, 900.0)
	var oh := minf(vs.y - 24, 760.0)
	overlay.position = (vs - Vector2(ow, oh)) * 0.5
	overlay.size = Vector2(ow, oh)
	overlay.custom_minimum_size = overlay.size


func _open_overlay(title: String) -> void:
	for c in overlay_body.get_children():
		c.queue_free()
	overlay_title.text = title
	overlay.visible = true
	menu.visible = false


func _play() -> void:
	Audio.unlock()
	Audio.play("start")
	if _has_save and GameState.load_game():
		Router.go("world")
	else:
		_start_new()


func _start_new() -> void:
	Audio.unlock()
	GameState.delete_save()
	GameState.data = GameState.default_data("tkacz")
	Router.go("intro")


func _confirm_new() -> void:
	_open_overlay("Nowa gra")
	overlay_body.add_child(UITheme.label("Rozpocząć przygodę od nowa? Obecny zapis w tej przeglądarce zostanie usunięty. Jeśli chcesz go zachować, najpierw użyj eksportu w menu Zapis podczas gry."))
	overlay_body.add_child(UITheme.button("Tak, zaczynam od nowa", _start_new, "Primary"))


func _show_settings() -> void:
	_open_overlay("Ustawienia")
	var s := SETTINGS.new()
	s.text_scale_changed.connect(func() -> void: Router.go("title", {}, 0.2))
	overlay_body.add_child(s)


func _show_controls() -> void:
	_open_overlay("Sterowanie")
	overlay_body.add_child(UITheme.rich(Data.story.get("controls_text", "")))


func _show_about() -> void:
	_open_overlay("O grze")
	overlay_body.add_child(UITheme.rich(Data.story.get("about_text", "")))


func _process(delta: float) -> void:
	t += delta
	art.queue_redraw()


func _draw_art() -> void:
	var vs := art.size
	var portrait := vs.y > vs.x
	var k := minf(vs.x / 1280.0, vs.y / 720.0)
	var base := Vector2(vs.x * (0.5 if portrait else 0.28), vs.y * (0.24 if portrait else 0.6))
	if portrait:
		k *= 1.4
	var motion := 0.0 if Settings.reduced_motion else 1.0
	# Odległe wyspy (paralaksa)
	for j in 5:
		var p := Vector2(fposmod(j * 310.0 + t * 8.0 * motion, vs.x + 300) - 150, vs.y * (0.2 + 0.13 * (j % 3)))
		var r := (40.0 + j * 9.0) * k
		art.draw_colored_polygon(Art.ellipse(p + Vector2(0, r * 0.3), r, r * 0.3, 16), Color("#1c2f2a", 0.7))
		art.draw_colored_polygon(Art.ellipse(p, r, r * 0.32, 16), Color("#2e5a46", 0.8))
	# Wyspa główna
	var bob := sin(t * 0.9) * 8.0 * k * motion
	var ic := base + Vector2(0, bob)
	var R := 230.0 * k
	for j in range(8, 0, -1):
		art.draw_colored_polygon(Art.ellipse(ic + Vector2(0, j * R * 0.06), R, R * 0.36, 30), Color("#6b4f3a").lerp(Color("#2a1f1a"), j / 8.0))
	art.draw_colored_polygon(Art.ellipse(ic, R, R * 0.36, 30), Color("#4f8a4a"))
	art.draw_colored_polygon(Art.ellipse(ic + Vector2(-R * 0.3, -R * 0.05), R * 0.4, R * 0.12, 20), Color("#5f9c55"))
	# Latarnia
	var tp := ic + Vector2(0, -R * 0.08)
	var h := 260.0 * k
	art.draw_colored_polygon(PackedVector2Array([tp + Vector2(-44 * k, 0), tp + Vector2(44 * k, 0), tp + Vector2(28 * k, -h), tp + Vector2(-28 * k, -h)]), Color("#efe6d2"))
	for j in 4:
		var y := -50.0 * k - j * 52.0 * k
		art.draw_colored_polygon(PackedVector2Array([tp + Vector2(-40 * k + j * 3 * k, y), tp + Vector2(40 * k - j * 3 * k, y), tp + Vector2(38 * k - j * 3 * k, y - 13 * k), tp + Vector2(-38 * k + j * 3 * k, y - 13 * k)]), Color("#2d6b5f"))
	var lc := tp + Vector2(0, -h - 30 * k)
	var a := t * 0.6 * motion + 0.4
	art.draw_colored_polygon(PackedVector2Array([lc, lc + Vector2(cos(a - 0.09), sin(a - 0.09) * 0.35) * 2000, lc + Vector2(cos(a + 0.09), sin(a + 0.09) * 0.35) * 2000]), Color(Art.GOLD, 0.10))
	Art.glow(art, lc, 140 * k, Color(Art.GOLD, 0.45))
	art.draw_rect(Rect2(lc - Vector2(30, 26) * k, Vector2(60, 48) * k), Color("#1d3b36"))
	art.draw_circle(lc, 16 * k, Color("#ffe39a"))
	art.draw_colored_polygon(PackedVector2Array([lc + Vector2(-36, -26) * k, lc + Vector2(36, -26) * k, lc + Vector2(0, -62) * k]), Color("#c8553d"))
	# Bohaterowie i BLIK
	var ids := ["tkacz", "mechanik", "tropiciel", "straznik"]
	for j in 4:
		var hp := ic + Vector2((-150 + j * 100) * k, R * 0.18)
		if j >= 2:
			hp.x += 60 * k
		Art.with_parent(Transform2D(0, Vector2(1.5, 1.5) * k, 0, hp))
		Art.hero(art, ids[j], {"t": t + j, "aim": Vector2.RIGHT if j < 2 else Vector2.LEFT, "reduced": Settings.reduced_motion})
	Art.with_parent(Transform2D.IDENTITY)
	art.draw_set_transform(ic + Vector2(90 * k, -R * 0.05), 0, Vector2(1.8, 1.8) * k)
	Art.blik(art, t, "happy", 0.0, Settings.reduced_motion)
	art.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Drobiny światła
	for j in 26:
		var p := Vector2(fposmod(j * 97.0 + sin(t * 0.3 + j) * 30.0, vs.x), fposmod(vs.y - j * 53.0 - t * 14.0 * motion, vs.y))
		art.draw_circle(p, 2.0 + (j % 3), Color(Art.GOLD if j % 2 else Art.TEAL, 0.5))
