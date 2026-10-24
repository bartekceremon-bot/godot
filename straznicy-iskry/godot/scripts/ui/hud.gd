extends Control
## HUD: zdrowie/energia/PD, cel, BLIK, podpowiedź interakcji, pasek bossa,
## komunikaty i banery. Osobny układ dla ekranów szerokich i wąskich.

const SLOT := preload("res://scripts/ui/skill_slot.gd")

var stats: PanelContainer
var lvl_label: Label
var hp_bar: ProgressBar
var en_bar: ProgressBar
var xp_bar: ProgressBar
var objective: Label
var blik_box: PanelContainer
var blik_label: Label
var blik_face: Control
var prompt: PanelContainer
var prompt_label: Label
var toasts: VBoxContainer
var banner: VBoxContainer
var banner_title: Label
var banner_sub: Label
var boss_box: VBoxContainer
var boss_bar_pb: ProgressBar
var area_label: Label
var skillbar: HBoxContainer
var top_buttons: HBoxContainer
var slots: Array = []
var _blik_t := 0.0
var _narrow := false
var _banner_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stats()
	_build_top_buttons()
	_build_blik()
	_build_misc()
	_build_skillbar()
	GameState.stats_changed.connect(_refresh)
	GameState.xp_changed.connect(_refresh)
	GameState.flag_changed.connect(func(_f: String) -> void: _refresh_objective())
	GameState.mission_completed.connect(func(_m: String) -> void: _refresh_objective())
	Settings.changed.connect(_on_settings)
	_refresh()
	_refresh_objective()


func _build_stats() -> void:
	stats = PanelContainer.new()
	stats.theme_type_variation = "Soft"
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	stats.add_child(v)
	lvl_label = UITheme.label("", "Bold", false)
	v.add_child(lvl_label)
	hp_bar = _bar(Color("#e0566b"))
	v.add_child(hp_bar)
	en_bar = _bar(Art.TEAL)
	v.add_child(en_bar)
	xp_bar = _bar(Art.GOLD, 8)
	xp_bar.show_percentage = false
	v.add_child(xp_bar)
	objective = UITheme.label("", "Small")
	objective.custom_minimum_size.x = 260
	v.add_child(objective)


func _bar(c: Color, h := 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(260, h)
	b.show_percentage = false
	b.add_theme_stylebox_override("fill", UITheme.box(c, Color(0, 0, 0, 0), 8, 0, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_top_buttons() -> void:
	top_buttons = HBoxContainer.new()
	add_child(top_buttons)
	for spec in [["map", "Mapa", "map"], ["menu", "Menu", "journal"]]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.tooltip_text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		var icon_draw := Control.new()
		icon_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ic: String = spec[0]
		icon_draw.draw.connect(func() -> void: Icons.draw(icon_draw, ic, icon_draw.size * 0.5, 40, Art.CREAM))
		b.add_child(icon_draw)
		var tab: String = spec[2]
		b.pressed.connect(func() -> void:
			Audio.play("click", 0.05, -6.0)
			if World.current and not World.current.busy():
				World.current.open_menu(tab))
		top_buttons.add_child(b)


func _build_blik() -> void:
	blik_box = PanelContainer.new()
	blik_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blik_box.visible = false
	add_child(blik_box)
	var h := HBoxContainer.new()
	blik_box.add_child(h)
	blik_face = Control.new()
	blik_face.custom_minimum_size = Vector2(58, 58)
	blik_face.draw.connect(func() -> void:
		Art.with_parent(Transform2D(0, Vector2(1.4, 1.4), 0, Vector2(29, 80)))
		blik_face.draw_set_transform(Vector2(29, 80), 0, Vector2(1.4, 1.4))
		Art.blik(blik_face, Time.get_ticks_msec() / 1000.0, "happy", 1.0, true)
		blik_face.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		Art.with_parent(Transform2D.IDENTITY))
	h.add_child(blik_face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_l := UITheme.label("BLIK", "Bold", false)
	name_l.add_theme_color_override("font_color", Art.TEAL)
	v.add_child(name_l)
	blik_label = UITheme.label("")
	v.add_child(blik_label)


func _build_misc() -> void:
	area_label = UITheme.label("", "Title", false)
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_label.modulate.a = 0.0
	area_label.add_theme_constant_override("outline_size", 8)
	area_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(area_label)
	prompt = PanelContainer.new()
	prompt.theme_type_variation = "Soft"
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	add_child(prompt)
	prompt_label = UITheme.label("", "Bold", false)
	prompt.add_child(prompt_label)
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.alignment = BoxContainer.ALIGNMENT_END
	add_child(toasts)
	banner = VBoxContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	banner_title = UITheme.label("", "Title", false)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_constant_override("outline_size", 10)
	banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	banner_sub = UITheme.label("", "Bold")
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.add_theme_constant_override("outline_size", 6)
	banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	banner.add_child(banner_title)
	banner.add_child(banner_sub)
	add_child(banner)
	boss_box = VBoxContainer.new()
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := UITheme.label("Miraż, Władca Iluzji", "Header", false)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(bl)
	boss_bar_pb = _bar(Color("#b06bff"), 20)
	boss_bar_pb.max_value = 1.0
	boss_bar_pb.step = 0.001
	boss_box.add_child(boss_bar_pb)
	add_child(boss_box)


func _build_skillbar() -> void:
	skillbar = HBoxContainer.new()
	skillbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skillbar.add_theme_constant_override("separation", 14)
	add_child(skillbar)
	refresh_skills()


func refresh_skills() -> void:
	for c in skillbar.get_children():
		c.queue_free()
	slots.clear()
	var cid := GameState.class_id()
	var specs := [["attack", cid + "_basic", "LPM"], ["skill1", cid + "_skill1", "Q"], ["skill2", cid + "_skill2", "R"], ["dodge", "dodge", "Spacja"]]
	for s in specs:
		var slot: Control = SLOT.new()
		slot.setup(s[0], s[1], s[2], 32, false)
		skillbar.add_child(slot)
		slots.append(slot)


func apply_layout(narrow: bool) -> void:
	_narrow = narrow
	var m := Router.safe_margins()
	var pad := 12.0
	var L: float = m["left"] + pad
	var T: float = m["top"] + pad
	var R: float = m["right"] + pad
	var B: float = m["bottom"] + pad
	var vs := get_viewport_rect().size
	var bar_w := 200.0 if narrow else 260.0
	for b in [hp_bar, en_bar, xp_bar]:
		b.custom_minimum_size.x = bar_w
	objective.custom_minimum_size.x = bar_w
	stats.position = Vector2(L, T)
	stats.size = Vector2.ZERO
	top_buttons.position = Vector2(vs.x - R - 138, T)
	var bw := minf(vs.x - L - R, 620.0)
	blik_box.custom_minimum_size = Vector2(bw, 0)
	blik_box.size = Vector2(bw, 0)
	if narrow and vs.y > vs.x:
		# Pion: BLIK pod paskami, żeby nie zasłaniać środka ekranu.
		blik_box.position = Vector2(L, T + 170)
	else:
		blik_box.position = Vector2((vs.x - bw) * 0.5, T + (90 if narrow else 4))
	area_label.position = Vector2(0, vs.y * 0.18)
	area_label.size = Vector2(vs.x, 60)
	banner.position = Vector2(20, vs.y * 0.32)
	banner.size = Vector2(vs.x - 40, 100)
	boss_box.position = Vector2((vs.x - 420) * 0.5, T + (240 if narrow and vs.y > vs.x else 70))
	boss_box.size = Vector2(420, 0)
	boss_bar_pb.custom_minimum_size.x = 420
	toasts.position = Vector2((vs.x - 560) * 0.5, vs.y * 0.45)
	toasts.size = Vector2(560, 180)
	skillbar.position = Vector2(vs.x - R - 4 * 64 - 3 * 14, vs.y - B - 76)
	_on_settings()
	_place_prompt()


func _on_settings() -> void:
	skillbar.visible = not Settings.show_touch()


func _place_prompt() -> void:
	var vs := get_viewport_rect().size
	var m := Router.safe_margins()
	prompt.size = Vector2.ZERO
	var w := prompt.get_combined_minimum_size().x
	var y: float = vs.y - m["bottom"] - (150.0 if Settings.show_touch() else 96.0)
	if Settings.show_touch() and _narrow and vs.y > vs.x:
		y = vs.y - m["bottom"] - 420.0
	prompt.position = Vector2((vs.x - w) * 0.5, y)


func _process(delta: float) -> void:
	if _blik_t > 0.0:
		_blik_t -= delta
		blik_face.queue_redraw()
		if _blik_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(blik_box, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void: blik_box.visible = false)


func _refresh() -> void:
	var d := Data.get_class_def(GameState.class_id())
	lvl_label.text = "%s  •  Poziom %d" % [d.get("name", ""), GameState.level()]
	hp_bar.max_value = GameState.max_hp()
	hp_bar.value = GameState.hp
	en_bar.max_value = GameState.max_energy()
	en_bar.value = GameState.energy
	var lvl := GameState.level()
	if lvl >= GameState.MAX_LEVEL:
		xp_bar.max_value = 1
		xp_bar.value = 1
	else:
		var lo: int = GameState.XP_FOR_LEVEL[lvl]
		var hi: int = GameState.XP_FOR_LEVEL[lvl + 1]
		xp_bar.max_value = hi - lo
		xp_bar.value = int(GameState.data["xp"]) - lo


func _refresh_objective() -> void:
	for o in Data.story.get("objectives", []):
		if not GameState.flags_met(o.get("done", "")):
			objective.text = "Cel: " + str(o.get("text", ""))
			return
	objective.text = "Cel: odkrywaj Luminarę i szukaj sekretów."


func set_area_name(n: String) -> void:
	area_label.text = n
	var tw := create_tween()
	area_label.modulate.a = 0.0
	tw.tween_property(area_label, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	tw.tween_property(area_label, "modulate:a", 0.0, 0.8)


func update_interact(n: Node) -> void:
	if n == null:
		prompt.visible = false
		return
	var key := "" if Settings.show_touch() else "[E]  "
	var text: String = key + n.prompt()
	if prompt_label.text != text or not prompt.visible:
		prompt_label.text = text
		prompt.visible = true
		_place_prompt()


func blik_message(text: String) -> void:
	blik_label.text = text
	blik_box.visible = true
	blik_box.modulate.a = 1.0
	blik_box.size = Vector2(blik_box.custom_minimum_size.x, 0)
	_blik_t = clampf(2.5 + text.length() * 0.05, 3.5, 10.0)


func toast(text: String, kind := "info") -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = "Soft"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, "Bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var col = {"key": Art.GOLD, "item": Art.CREAM, "warn": Color("#ffb36b"), "info": Color("#cfe8df")}.get(kind, Art.CREAM)
	l.add_theme_color_override("font_color", col)
	p.add_child(l)
	toasts.add_child(p)
	while toasts.get_child_count() > 3:
		toasts.get_child(0).free()
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.2 if kind != "warn" else 7.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func show_banner(title: String, sub: String) -> void:
	banner_title.text = title
	banner_sub.text = sub
	if _banner_tween:
		_banner_tween.kill()
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.8, 0.8) if not Settings.reduced_motion else Vector2.ONE
	banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(2.2)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.6)


func boss_bar(on: bool, v: float) -> void:
	boss_box.visible = on
	boss_bar_pb.value = v
