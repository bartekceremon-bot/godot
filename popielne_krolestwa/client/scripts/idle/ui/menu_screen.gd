class_name IdleMenuScreen
extends Control
## Ekran tytułowy: żywa scena 3D (Świątynia Ognia, Żarogniew, bohater z drużyną, czary, żar,
## kamera okrążająca scenę), kute logo z przelatującym refleksem, szklane panele, żarzący się
## przycisk, unoszące się iskry i płynne wejście. Wszystko z assetów gry.

signal play_pressed
signal classic_pressed

const SHINE_SHADER := """
shader_type canvas_item;
uniform float speed = 0.22;
uniform float width = 0.1;
uniform float strength = 0.7;
void fragment() {
	vec4 c = COLOR;
	float p = fract(TIME * speed) * 2.6 - 0.8;
	float d = abs((UV.x + UV.y * 0.4) - p);
	float s = smoothstep(width, 0.0, d) * strength;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb += s * vec3(1.0, 0.96, 0.85) * smoothstep(0.35, 0.85, lum) * c.a;
	COLOR = c;
}
"""
const SPELLS := ["fireball", "lightning", "icebolt", "holy", "chain", "fireball", "meteor", "frost_nova"]

var gm: IdleGame
var view: BattleView
var _logo: TextureRect
var _play: Button
var _fade: ColorRect
var _t := 0.0
var _fx_t := 1.5
var _spell_i := 0
var _content: VBoxContainer


func setup(g: IdleGame) -> void:
	gm = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene()
	_build_overlay()
	_build_ui()
	_intro()


func _build_scene() -> void:
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vpc.add_child(vp)
	view = BattleView.new()
	vp.add_child(view)
	view.set_region(gm.db.regions[7])
	view.set_hero(["plate_head_t8", "plate_body_t8", "plate_legs_t8", "plate_feet_t8", "sword_t8", "shield_t8"])
	var party: Array = []
	for id in ["dragon_hunter", "frost_mage", "guildmaster"]:
		party.append(gm.db.merc_def(id))
	view.set_mercs(party)
	view.spawn_enemy({"name": "Żarogniew", "look": "ash_dragon", "kind": 2})
	view.orbit = true
	view.orbit_focus = Vector3(0.0, 1.6, 0.3)
	view.orbit_radius = 9.5
	view.orbit_height = 1.4
	view.camera.position = Vector3(2.0, 7.0, 16.0)


func _build_overlay() -> void:
	# Przyciemnienie góry (logo) i dołu (przyciski), środek – widok sceny.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.01, 0.01, 0.85))
	grad.add_point(0.3, Color(0.02, 0.01, 0.01, 0.1))
	grad.add_point(0.52, Color(0.02, 0.01, 0.01, 0.0))
	grad.add_point(0.72, Color(0.02, 0.01, 0.01, 0.6))
	grad.set_color(grad.get_point_count() - 1, Color(0.02, 0.01, 0.01, 0.97))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Winieta boczna.
	var vig := TextureRect.new()
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0))
	vg.set_color(1, Color(0, 0, 0, 0.7))
	vg.set_offset(0, 0.55)
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.1, 0.5)
	vt.width = 128
	vt.height = 128
	vig.texture = vt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	# Unoszące się iskry.
	var sparks := CPUParticles2D.new()
	sparks.texture = load("res://assets/fx/soft_dot.png")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = mat
	sparks.amount = 70
	sparks.lifetime = 7.0
	sparks.preprocess = 7.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(500, 20)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 25
	sparks.gravity = Vector2(10, -12)
	sparks.initial_velocity_min = 30
	sparks.initial_velocity_max = 110
	sparks.scale_amount_min = 0.05
	sparks.scale_amount_max = 0.22
	sparks.angular_velocity_min = -40
	sparks.angular_velocity_max = 40
	var cr := Gradient.new()
	cr.set_color(0, Color(1.0, 0.75, 0.3, 0.0))
	cr.add_point(0.15, Color(1.0, 0.62, 0.22, 0.95))
	cr.set_color(cr.get_point_count() - 1, Color(1.0, 0.3, 0.05, 0.0))
	sparks.color_ramp = cr
	sparks.name = "sparks"
	add_child(sparks)
	resized.connect(func():
		sparks.position = Vector2(size.x / 2.0, size.y + 10)
		sparks.emission_rect_extents = Vector2(size.x / 2.0, 20))


func _build_ui() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 26)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 34)
	add_child(m)
	_content = IdleUI.vbox(14)
	_content.custom_minimum_size = Vector2(minf(620.0, get_viewport_rect().size.x - 52.0), 0)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.add_child(_content)
	# Logo.
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/ui/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(620, 292)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHINE_SHADER
	sm.shader = sh
	_logo.material = sm
	_content.add_child(_logo)
	_content.add_child(_subtitle("ŁOWY  W  POPIELE"))
	var tag := IdleUI.label("RPG idle  •  klikaj, zdobywaj łup, odradzaj się z popiołu", 18, Color(0.88, 0.8, 0.7))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	var save := gm.save.load_game()
	if not save.is_empty():
		_content.add_child(_save_card(save))
	# Kamienna płyta z żarem – jak przycisk ATAK! na ekranie walki.
	_play = IdleUI.ash_button("stone_button", 44)
	_play.text = "KONTYNUUJ" if not save.is_empty() else "ROZPOCZNIJ PRZYGODĘ"
	_play.custom_minimum_size = Vector2(0, 124)
	_play.add_theme_font_override("font", UiTheme.TITLE_FONT)
	_play.add_theme_font_size_override("font_size", 36)
	_play.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88))
	_play.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.92))
	_play.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.6))
	_play.add_theme_constant_override("outline_size", 9)
	_play.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.06))
	_play.pressed.connect(func():
		Sfx.play("levelup")
		play_pressed.emit())
	_content.add_child(_play)
	var row := IdleUI.hbox(12)
	_content.add_child(row)
	var mmo := IdleUI.button("Klasyczne MMO", Vector2(0, 72), 20)
	mmo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mmo.pressed.connect(func(): classic_pressed.emit())
	row.add_child(mmo)
	var snd := IdleUI.button("Dźwięk: wł." if Config.sound_enabled else "Dźwięk: wył.", Vector2(190, 72), 18)
	snd.pressed.connect(func():
		Config.sound_enabled = not Config.sound_enabled
		var main := get_parent()
		if main is IdleMain and main.music:
			main.music.set_enabled(Config.sound_enabled)
		snd.text = "Dźwięk: wł." if Config.sound_enabled else "Dźwięk: wył.")
	row.add_child(snd)
	var chips := IdleUI.hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(chips)
	for c in ["8 krain", "%d potworów" % gm.db.monsters.size(), "%d czarów" % gm.db.spells.size(), "gra offline"]:
		chips.add_child(_chip(c))
	var ver := IdleUI.label("v%s  •  Popielne Królestwa" % ProjectSettings.get_setting("application/config/version"), 15, Color(0.6, 0.55, 0.5))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(ver)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _subtitle(text: String) -> Control:
	var h := IdleUI.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var line := func() -> ColorRect:
		var r := ColorRect.new()
		r.color = Color(1.0, 0.65, 0.3, 0.7)
		r.custom_minimum_size = Vector2(70, 2)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return r
	h.add_child(line.call())
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Exo2-ExtraBold.ttf")
	f.spacing_glyph = 5
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1.0, 0.72, 0.4))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.04, 0.0, 0.9))
	l.add_theme_constant_override("shadow_outline_size", 14)
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.4, 0.05, 0.45))
	h.add_child(l)
	h.add_child(line.call())
	return h


func _chip(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := IdleUI.ash_box("badge", 22, 4)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(IdleUI.label(text, 15, Color(0.95, 0.85, 0.72)))
	return p


## Karta zapisu: bohater, etap, kraina, złoto, kiedy grano.
func _save_card(s: Dictionary) -> Control:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", IdleUI.ash_box("stone_panel", 26, 16))
	var h := IdleUI.hbox(16)
	c.add_child(h)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(88, 88)
	var fr := Panel.new()
	fr.add_theme_stylebox_override("panel", IdleUI.ash_box("slot", 18))
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(fr)
	var face := IdleUI.icon_rect(IdleUI.ash_tex("portrait"), 76)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(6, 6)
	portrait.add_child(face)
	h.add_child(portrait)
	var v := IdleUI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var stage := int(s.get("stage", 1))
	var reg: Dictionary = gm.db.regions[((stage - 1) / gm.db.stages_per_region) % gm.db.regions.size()]
	var t := IdleUI.label("Poziom %d  •  Etap %d" % [int(s.get("level", 1)), stage], 24, UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.TITLE_FONT)
	v.add_child(t)
	v.add_child(IdleUI.label(str(reg.name), 19, Color(1.0, 0.72, 0.42)))
	var ago := Time.get_unix_time_from_system() - float(s.get("last_time", 0.0))
	var cur := IdleUI.hbox(14)
	v.add_child(cur)
	var g := IdleUI.currency(Sprites.item_icon("gold", 0), IdleUI.GOLD_COL, 20)
	g[1].text = IdleDB.fmt(float(s.get("gold", 0.0)))
	cur.add_child(g[0])
	var gem := IdleUI.currency(Sprites.icon("gem"), IdleUI.GEM_COL, 20)
	gem[1].text = str(int(s.get("gems", 0)))
	cur.add_child(gem[0])
	if ago > 120.0:
		v.add_child(IdleUI.label("Drużyna walczy od %s – czeka na ciebie łup!" % IdleDB.fmt_time(ago), 16, IdleUI.GOOD))
	return c


func _intro() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 1.4).set_ease(Tween.EASE_OUT)
	_logo.modulate.a = 0.0
	_logo.pivot_offset = Vector2(310, 146)
	_logo.scale = Vector2(1.25, 1.25)
	var lt := _logo.create_tween().set_parallel(true)
	lt.tween_property(_logo, "modulate:a", 1.0, 1.2).set_delay(0.5)
	lt.tween_property(_logo, "scale", Vector2.ONE, 1.6).set_delay(0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var i := 0
	for c in _content.get_children():
		if c == _logo:
			continue
		if c is CanvasItem:
			c.modulate.a = 0.0
			var ct := c.create_tween()
			ct.tween_interval(1.1 + i * 0.12)
			ct.tween_property(c, "modulate:a", 1.0, 0.5)
			i += 1


func _process(delta: float) -> void:
	_t += delta
	# Pulsujący żar wokół przycisku.
	if _play:
		var g := 1.0 + sin(_t * 2.6) * 0.08
		_play.self_modulate = Color(g, g * 0.97, g * 0.94)
	if _logo:
		var b := 1.0 + sin(_t * 0.9) * 0.012
		if _t > 2.2:
			_logo.scale = Vector2(b, b)
	# Walka w tle: czary drużyny, ryk smoka.
	_fx_t -= delta
	if _fx_t <= 0.0 and view:
		_fx_t = randf_range(1.6, 2.8)
		var id: String = SPELLS[_spell_i % SPELLS.size()]
		_spell_i += 1
		view.on_spell(id)
		if view.enemy:
			view.get_tree().create_timer(0.35).timeout.connect(func():
				if is_instance_valid(view) and view.enemy:
					view.enemy.flash()
					if randf() < 0.5:
						view.enemy.play_attack("melee"))


## Wyjście do gry: zanik i zwolnienie sceny 3D.
func leave() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)
