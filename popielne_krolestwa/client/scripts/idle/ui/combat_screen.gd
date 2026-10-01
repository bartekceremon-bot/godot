class_name CombatScreen
extends Control
## Ekran walki (układ „Popiół i żar”): widok 3D na całą wysokość, portret bohatera, nagłówek
## przeciwnika w żelaznej ramie, cele zadań, wielki przycisk ATAK! (przytrzymanie = seria),
## kafle umiejętności (auto-klik, czary, mikstury), liczby obrażeń i wyskakujące złoto.
## Dotknięcie sceny też jest ciosem.

signal open_tab(name: String)

const HOLD_DELAY := 0.3
const HOLD_RATE := 8.0
const MAX_FLOATERS := 40
## Auto-klik: ciosy na sekundę (tylko przy otwartej grze).
const AUTO_CLICK_RATE := 3.0

var ui: IdleMain
var gm: IdleGame
var view: BattleView
var _vpc: SubViewportContainer
var _vp: SubViewport
var _fx_layer: Control
var _region_l: Label
var _stage_bar: ProgressBar
var _enemy_l: Label
var _hp_bar: ProgressBar
var _hp_l: Label
var _timer_l: Label
var _boss_btn: Button
var _hud: VBoxContainer
var _hud_buttons: Array = []
var _bracket_l: Label
var _bar_holder: Control
var _lvl_badge: PanelContainer
var _elvl_l: Label
var _plvl_l: Label
var _team_btn: Button
var _team_dot: Label
var _menu_dot: Label
var _atk_btn: Button
var _atk_held := -1.0
var _auto_click_btn: Button
var _auto_acc := 0.0
var _gold_pop: PanelContainer
var _gold_pop_l: Label
var _gold_pop_sum := 0.0
var _gold_tw: Tween
var _edge: TextureRect
var _edge_tw: Tween
var _auto_btn: Button
var _goals_box: VBoxContainer
var _menu_btn: Button
## Umiejętność ostateczna klasy (obok ATAK!): ikona, pasek Żaru, napis.
var _ult_btn: Button
var _ult_fill: ColorRect
var _ult_l: Label
var _path_btn: Button
## Samouczek: łapka wskazująca, co nacisnąć (cele początkowe Ścieżki Popielnika).
var _hand: TextureRect
var _hand_t := 0.0
var _php: ProgressBar
var _php_l: Label
var _pmp: ProgressBar
var _shield_l: Label
var _stats_l: Label
var _spell_btns: Array = []
var _potion_btn: Button
var _mpotion_btn: Button
var _touches: Dictionary = {}
var _hold_acc := 0.0
var _floaters: Array = []
var _sparks: Array = []
var _spark_i := 0
var _ui_t := 0.0
var _shown_hp := 0.0


func setup(main: IdleMain) -> void:
	ui = main
	gm = main.gm
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vpc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	_vpc.add_child(_vp)
	view = BattleView.new()
	_vp.add_child(view)
	# Winieta: przyciemnione krawędzie – czytelniejsze napisy.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.5))
	grad.add_point(0.22, Color(0, 0, 0, 0.0))
	grad.add_point(0.62, Color(0, 0, 0, 0.0))
	grad.set_color(grad.get_point_count() - 1, Color(0.02, 0.015, 0.012, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Żarzące się krawędzie ekranu przy krytyku i zabiciu bossa.
	_edge = TextureRect.new()
	var eg := Gradient.new()
	eg.set_color(0, Color(1.0, 0.4, 0.08, 0.0))
	eg.add_point(0.62, Color(1.0, 0.4, 0.08, 0.0))
	eg.set_color(eg.get_point_count() - 1, Color(1.0, 0.45, 0.1, 0.85))
	var et := GradientTexture2D.new()
	et.gradient = eg
	et.fill = GradientTexture2D.FILL_RADIAL
	et.fill_from = Vector2(0.5, 0.5)
	et.fill_to = Vector2(1.05, 1.05)
	et.width = 64
	et.height = 64
	_edge.texture = et
	_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.modulate.a = 0.0
	add_child(_edge)
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	_build_header()
	_build_bottom()
	for i in 6:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 14
		p.lifetime = 0.45
		p.texture = load("res://assets/fx/soft_dot.png")
		p.spread = 180.0
		p.initial_velocity_min = 140.0
		p.initial_velocity_max = 360.0
		p.gravity = Vector2(0, 700)
		p.scale_amount_min = 0.08
		p.scale_amount_max = 0.22
		var cr := Gradient.new()
		cr.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
		cr.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
		p.color_ramp = cr
		_fx_layer.add_child(p)
		_sparks.append(p)
	gm.enemy_spawned.connect(_on_spawn)
	gm.enemy_hit.connect(_on_hit)
	gm.enemy_killed.connect(_on_killed)
	gm.spell_cast.connect(_on_spell)
	gm.level_up.connect(func(_l): view.on_level_up())
	gm.boss_failed.connect(func(reason): ui.banner("Boss niepokonany", reason + " Farmisz etap %d." % int(gm.s.stage), IdleUI.BAD))
	gm.player_hit.connect(_on_player_hit)
	gm.changed.connect(_on_changed)
	_refresh_all()
	_on_spawn()
	apply_quality()


## Jakość grafiki (ustawienia): 0 – oszczędna (połowa rozdzielczości 3D, bez cieni),
## 1 – zwykła (bez wygładzania krawędzi), 2 – wysoka (wygładzanie MSAA 2×).
func apply_quality() -> void:
	var q := int(gm.s.settings.get("quality", 1))
	_vpc.stretch_shrink = 2 if q == 0 else 1
	_vp.msaa_3d = Viewport.MSAA_2X if q == 2 else Viewport.MSAA_DISABLED
	view.set_shadows(q > 0)


func _build_header() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	_hud = IdleUI.pass_through(IdleUI.vbox(6))
	m.add_child(_hud)
	var head := IdleUI.pass_through(IdleUI.hbox(12))
	_hud.add_child(head)
	# Portret bohatera: poziom, zdrowie i mana; dotknięcie – statystyki postaci.
	var left := IdleUI.pass_through(IdleUI.vbox(4))
	head.add_child(left)
	var portrait := IdleUI.ash_button("slot", 18)
	portrait.custom_minimum_size = Vector2(118, 118)
	var face := IdleUI.icon_rect(IdleUI.ash_tex("portrait"), 100)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		face.set_offset(side, 7)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		face.set_offset(side, -7)
	portrait.add_child(face)
	portrait.pressed.connect(func():
		Sfx.play("click")
		open_tab.emit("stats"))
	left.add_child(portrait)
	_hud_buttons.append(portrait)
	_php = _thin_bar(Color(0.85, 0.2, 0.12), 12)
	_php_l = IdleUI.bar_label(_php, 11)
	left.add_child(_php)
	_pmp = _thin_bar(Color(0.25, 0.5, 1.0), 9)
	left.add_child(_pmp)
	_plvl_l = IdleUI.hud_label("LVL 1", 20, Color(1.0, 0.72, 0.3), 5)
	_plvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_plvl_l)
	_shield_l = IdleUI.hud_label("", 15, Color(0.6, 0.9, 1.0), 4)
	_shield_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_shield_l)
	# Przeciwnik: [NAZWA - PZ: a / b], pasek zdrowia w żelaznej ramie, etap i poziom.
	var right := IdleUI.pass_through(IdleUI.vbox(2))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(right)
	var title := IdleUI.pass_through(IdleUI.hbox(0))
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(title)
	_enemy_l = IdleUI.hud_label("", 24, Color(0.97, 0.95, 0.92), 7)
	title.add_child(_enemy_l)
	_hp_l = IdleUI.hud_label("", 24, Color(1.0, 0.3, 0.22), 7)
	title.add_child(_hp_l)
	_bracket_l = IdleUI.hud_label("]", 24, Color(0.97, 0.95, 0.92), 7)
	title.add_child(_bracket_l)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 66)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(holder)
	_bar_holder = holder
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 1.0
	_hp_bar.step = 0.0
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar.offset_left = 30
	_hp_bar.offset_right = -30
	_hp_bar.offset_top = 16
	_hp_bar.offset_bottom = -16
	var fill := StyleBoxTexture.new()
	var fg := Gradient.new()
	fg.set_color(0, Color(0.95, 0.28, 0.2))
	fg.add_point(0.45, Color(0.78, 0.1, 0.07))
	fg.set_color(fg.get_point_count() - 1, Color(0.4, 0.03, 0.03))
	var ft := GradientTexture2D.new()
	ft.gradient = fg
	ft.fill_from = Vector2(0, 0)
	ft.fill_to = Vector2(0, 1)
	ft.width = 4
	ft.height = 32
	fill.texture = ft
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.04, 0.04, 0.92)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", back)
	holder.add_child(_hp_bar)
	var frame := NinePatchRect.new()
	frame.texture = IdleUI.ash_tex("bar_frame")
	frame.patch_margin_left = 46
	frame.patch_margin_right = 46
	frame.patch_margin_top = 20
	frame.patch_margin_bottom = 20
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	# Pod paskiem: postęp etapu (albo czas bossa) i plakietka z poziomem przeciwnika.
	var sub := Control.new()
	sub.custom_minimum_size = Vector2(0, 36)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(sub)
	_stage_bar = _thin_bar(Color(1.0, 0.6, 0.18), 8)
	_stage_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_stage_bar.offset_left = 34
	_stage_bar.offset_right = -34
	_stage_bar.offset_top = 0
	_stage_bar.offset_bottom = 8
	sub.add_child(_stage_bar)
	_lvl_badge = PanelContainer.new()
	var bsb := IdleUI.ash_box("badge", 22, 0)
	bsb.content_margin_left = 20
	bsb.content_margin_right = 20
	_lvl_badge.add_theme_stylebox_override("panel", bsb)
	_lvl_badge.custom_minimum_size = Vector2(112, 36)
	_lvl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elvl_l = IdleUI.hud_label("LVL 1", 19, Color(0.95, 0.92, 0.88), 4)
	_elvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_badge.add_child(_elvl_l)
	sub.add_child(_lvl_badge)
	sub.resized.connect(func():
		_lvl_badge.reset_size()
		_lvl_badge.position = Vector2((sub.size.x - _lvl_badge.size.x) / 2.0, 0))
	_timer_l = IdleUI.hud_label("", 20, Color(1.0, 0.6, 0.25), 5)
	_timer_l.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_timer_l.offset_left = -110
	_timer_l.offset_right = -30
	_timer_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_child(_timer_l)
	_region_l = IdleUI.hud_label("", 17, Color(0.85, 0.8, 0.74), 5)
	_region_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_region_l)
	# Środek: cele zadań (z lewej), menu, drużyna i auto-etap (z prawej).
	var mid := IdleUI.pass_through(IdleUI.hbox(8))
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud.add_child(mid)
	var lcol := IdleUI.pass_through(IdleUI.vbox(8))
	lcol.custom_minimum_size = Vector2(118, 0)
	mid.add_child(lcol)
	_team_btn = _side_button(Sprites.icon("character"), "DRUŻYNA")
	_team_btn.pressed.connect(func(): open_tab.emit("heroes"))
	lcol.add_child(_team_btn.get_parent())
	_team_dot = ui._dot(_team_btn)
	_goals_box = IdleUI.pass_through(IdleUI.vbox(6))
	_goals_box.custom_minimum_size = Vector2(250, 0)
	_goals_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_goals_box)
	var rcol := IdleUI.pass_through(IdleUI.vbox(8))
	mid.add_child(rcol)
	var menu := _side_button(Sprites.icon("menu"), "MENU")
	_menu_btn = menu
	menu.pressed.connect(ui._open_menu)
	_menu_dot = ui._dot(menu)
	rcol.add_child(menu.get_parent())
	_auto_btn = _side_button(Sprites.icon("map"), "AUTO ETAP")
	_auto_btn.toggle_mode = true
	_auto_btn.add_theme_stylebox_override("pressed", IdleUI.ash_box("tile_on", 26))
	_auto_btn.add_theme_stylebox_override("hover_pressed", IdleUI.ash_box("tile_on", 26))
	_auto_btn.toggled.connect(func(on): gm.progression.toggle_auto(on))
	rcol.add_child(_auto_btn.get_parent())


## Mały kafel z ikoną i podpisem pod spodem (zwraca przycisk; rodzicem jest kolumna z podpisem).
func _side_button(tex: Texture2D, caption: String) -> Button:
	var v := IdleUI.pass_through(IdleUI.vbox(0))
	var b := IdleUI.ash_button("slot", 18)
	b.custom_minimum_size = Vector2(76, 76)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): Sfx.play("click"))
	v.add_child(b)
	var l := IdleUI.hud_label(caption, 14, Color(0.92, 0.9, 0.86), 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_hud_buttons.append(b)
	return b


func _thin_bar(col: Color, h: int) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.0
	pb.custom_minimum_size = Vector2(0, h)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.border_color = col.lightened(0.4)
	f.border_width_top = 2
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.04, 0.035, 0.035, 0.9)
	b.border_color = Color(0.3, 0.28, 0.28)
	b.set_border_width_all(1)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", b)
	return pb


func _build_bottom() -> void:
	var boss_row := IdleUI.pass_through(IdleUI.hbox(0))
	boss_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.add_child(boss_row)
	_boss_btn = IdleUI.ash_button("stone_button", 44)
	_boss_btn.text = "WALCZ Z BOSSEM"
	_boss_btn.add_theme_font_override("font", IdleUI.bold_font())
	_boss_btn.add_theme_font_size_override("font_size", 24)
	_boss_btn.add_theme_constant_override("outline_size", 6)
	_boss_btn.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_boss_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	_boss_btn.custom_minimum_size = Vector2(340, 84)
	_boss_btn.pressed.connect(func():
		if gm.challenge() != null:
			gm.challenge().leave()
		else:
			gm.progression.challenge_boss())
	boss_row.add_child(_boss_btn)
	_hud_buttons.append(_boss_btn)
	_stats_l = IdleUI.hud_label("", 17, Color(0.9, 0.86, 0.78), 5)
	_stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_stats_l)
	# ATAK! – wielka kamienna płyta z żarzącą się krawędzią.
	var atk_row := IdleUI.pass_through(IdleUI.hbox(0))
	atk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.add_child(atk_row)
	_atk_btn = IdleUI.ash_button("stone_button", 44)
	_atk_btn.custom_minimum_size = Vector2(560, 150)
	_atk_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	atk_row.add_child(_atk_btn)
	_hud_buttons.append(_atk_btn)
	var inner := IdleUI.pass_through(IdleUI.hbox(10))
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_atk_btn.add_child(inner)
	inner.add_child(IdleUI.icon_rect(IdleUI.ash_tex("ico_skull"), 92))
	var at := Label.new()
	at.text = "ATAK!"
	at.add_theme_font_override("font", UiTheme.TITLE_FONT)
	at.add_theme_font_size_override("font_size", 66)
	at.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	at.add_theme_constant_override("outline_size", 10)
	at.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.06))
	at.add_theme_constant_override("shadow_offset_y", 4)
	at.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	at.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(at)
	_atk_btn.button_down.connect(func():
		_atk_held = 0.0
		_attack_press())
	_atk_btn.button_up.connect(func(): _atk_held = -1.0)
	_ult_btn = IdleUI.ash_button("slot", 18)
	_ult_btn.custom_minimum_size = Vector2(118, 150)
	_ult_btn.clip_contents = true
	_ult_fill = ColorRect.new()
	_ult_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_fill.anchor_left = 0.0
	_ult_fill.anchor_right = 1.0
	_ult_fill.anchor_top = 1.0
	_ult_fill.anchor_bottom = 1.0
	_ult_fill.offset_left = 6
	_ult_fill.offset_right = -6
	_ult_fill.offset_bottom = -6
	_ult_btn.add_child(_ult_fill)
	var uic := TextureRect.new()
	uic.name = "icon"
	uic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	uic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	uic.anchor_left = 0.5
	uic.anchor_right = 0.5
	uic.offset_left = -36
	uic.offset_right = 36
	uic.offset_top = 14
	uic.offset_bottom = 86
	_ult_btn.add_child(uic)
	_ult_l = IdleUI.hud_label("", 15, Color(1.0, 0.9, 0.7), 5)
	_ult_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ult_l.offset_top = -50
	_ult_l.offset_bottom = -8
	_ult_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ult_btn.add_child(_ult_l)
	_ult_btn.pressed.connect(func():
		if gm.hero.activate():
			var d := gm.hero.def()
			ui.banner(str(d.ult).to_upper(), str(d.ult_text), d.color)
			view.shake(0.8)
			_buzz(120, true)
		else:
			Sfx.play("miss"))
	atk_row.add_theme_constant_override("separation", 8)
	atk_row.add_child(_ult_btn)
	_hud_buttons.append(_ult_btn)
	_update_ult()
	# Umiejętności: auto-klik, 4 czary, mikstury.
	var sp := IdleUI.pass_through(IdleUI.hbox(6))
	sp.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.add_child(sp)
	_auto_click_btn = _skill_slot(sp, IdleUI.ash_tex("ico_hand"), "AUTO KLIK")
	_auto_click_btn.pressed.connect(func():
		gm.s.settings["auto_click"] = not bool(gm.s.settings.get("auto_click", false))
		_update_spells())
	for i in 4:
		var b := _skill_slot(sp, null, "")
		var cd := ColorRect.new()
		cd.name = "cd"
		cd.color = Color(0, 0, 0, 0.62)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.anchor_right = 1.0
		cd.anchor_bottom = 1.0
		cd.offset_left = 5
		cd.offset_right = -5
		cd.offset_bottom = -5
		b.add_child(cd)
		var a := IdleUI.hud_label("AUTO", 11, Color(0.6, 1.0, 0.6), 3)
		a.name = "auto"
		a.position = Vector2(8, 4)
		b.add_child(a)
		var idx := i
		b.pressed.connect(func():
			var id := str(gm.s.spell_slots[idx])
			if id == "":
				open_tab.emit("spells")
			elif not gm.spells.cast(id):
				Sfx.play("miss"))
		_spell_btns.append(b)
	_potion_btn = _skill_slot(sp, Sprites.item_icon_for(gm.db.item("hp_potion")), "ŻYCIE")
	_potion_btn.pressed.connect(func():
		if not gm.combat.drink_best_hp():
			ui.toast_msg("Brak mikstur życia – kup je w sklepie.", IdleUI.BAD))
	_mpotion_btn = _skill_slot(sp, Sprites.item_icon_for(gm.db.item("mp_potion")), "MANA")
	_mpotion_btn.pressed.connect(func():
		if not gm.combat.drink_best_mp():
			ui.toast_msg("Brak mikstur many.", IdleUI.BAD))
	# Wyskakujące „ZŁOTO +X” po prawej przy zabiciu przeciwnika.
	_gold_pop = PanelContainer.new()
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0.03, 0.025, 0.02, 0.72)
	gs.corner_radius_top_left = 10
	gs.corner_radius_bottom_left = 10
	gs.content_margin_left = 14
	gs.content_margin_right = 16
	gs.content_margin_top = 4
	gs.content_margin_bottom = 4
	_gold_pop.add_theme_stylebox_override("panel", gs)
	_gold_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gh := IdleUI.pass_through(IdleUI.hbox(6))
	_gold_pop.add_child(gh)
	var gv := IdleUI.pass_through(IdleUI.vbox(-4))
	gh.add_child(gv)
	gv.add_child(IdleUI.hud_label("ZŁOTO", 18, Color(0.9, 0.86, 0.8), 4))
	_gold_pop_l = IdleUI.hud_label("+0", 24, Color(1.0, 0.75, 0.3), 5)
	gv.add_child(_gold_pop_l)
	gh.add_child(IdleUI.icon_rect(IdleUI.ash_tex("ico_gold"), 44))
	_gold_pop.modulate.a = 0.0
	add_child(_gold_pop)


## Kwadratowy kafel umiejętności z dwuwierszowym podpisem (nazwa + [stan]).
func _skill_slot(row: Control, tex: Texture2D, caption: String) -> Button:
	var v := IdleUI.pass_through(IdleUI.vbox(2))
	v.custom_minimum_size = Vector2(92, 0)
	row.add_child(v)
	var b := IdleUI.ash_button("slot", 18)
	b.custom_minimum_size = Vector2(76, 76)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 60)
	b.clip_contents = true
	v.add_child(b)
	var l := IdleUI.hud_label(caption, 12, Color(0.9, 0.88, 0.84), 4)
	l.name = "cap"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(92, 0)
	v.add_child(l)
	var st := IdleUI.hud_label("", 13, Color(0.6, 1.0, 0.55), 4)
	st.name = "state"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	b.set_meta("cap", l)
	b.set_meta("state", st)
	_hud_buttons.append(b)
	return b


## Dolna krawędź nagłówka przeciwnika (tam zaczyna się wysuwany panel zakładek).
func sheet_top() -> float:
	if _bar_holder == null:
		return 0.0
	return _bar_holder.get_global_rect().end.y - get_global_rect().position.y + 44.0


## Kropka przy DRUŻYNIE: można kupić poziom najemnika lub treningu.
func refresh_badges() -> void:
	var n := 0
	var gold := float(gm.s.gold)
	for d in gm.mercs.visible_list():
		if gm.mercs.cost(str(d.id)) <= gold:
			n += 1
	if gm.mercs.train_cost() <= gold:
		n += 1
	_team_dot.visible = n > 0
	_team_dot.text = str(n)
	var m := gm.achievements.ready_count() + gm.season.ready_count() + (1 if gm.daily.available() else 0) + gm.expeditions.ready_count() + maxi(0, gm.talents.free_points()) \
		+ gm.weekly.ready_count() + gm.mail.unread() + gm.wheel.free_spins()
	_menu_dot.visible = m > 0
	_menu_dot.text = str(m)


# --- Dotyk ------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _over_button(get_global_transform() * event.position):
				return
			_touches[event.index] = 0.0
			_tap_at(event.position)
		else:
			_touches.erase(event.index)
		accept_event()


## Dotknięcie przycisku (czary, mikstury, cele) nie jest ciosem.
func _over_button(gp: Vector2) -> bool:
	var list: Array = _hud_buttons.duplicate()
	list.append_array(_goals_box.get_children())
	for b in list:
		if b is Control and b.is_visible_in_tree() and b.get_global_rect().has_point(gp):
			return true
	return false


func _flash_edge(strength: float) -> void:
	if not bool(gm.s.settings.get("effects", true)):
		return
	if _edge_tw:
		_edge_tw.kill()
	_edge.modulate.a = maxf(_edge.modulate.a, strength)
	_edge_tw = _edge.create_tween()
	_edge_tw.tween_property(_edge, "modulate:a", 0.0, 0.35 + strength * 0.3)


## ATAK!: cios od razu, przytrzymanie – seria jak przy przytrzymaniu palca na scenie.
func _attack_press() -> void:
	_tap_at(_enemy_pos() + Vector2(randf_range(-40, 40), randf_range(-30, 50)))
	var br := _atk_btn.get_global_rect()
	_spark(br.position - global_position + Vector2(randf_range(0.2, 0.8) * br.size.x, 6), Color(1.0, 0.55, 0.15))
	_atk_btn.pivot_offset = _atk_btn.size / 2.0
	var tw := _atk_btn.create_tween()
	tw.tween_property(_atk_btn, "scale", Vector2(0.96, 0.94), 0.05)
	tw.tween_property(_atk_btn, "scale", Vector2.ONE, 0.1)


func _tap_at(pos: Vector2) -> void:
	gm.combat.tap()
	_spark(pos, Color(1.0, 0.85, 0.5))
	gm.audio.play("hit", 0.12)


func _process(delta: float) -> void:
	if gm == null or not gm.running:
		return
	# Przytrzymanie palca: automatyczne ciosy 8/s.
	if not _touches.is_empty():
		for k in _touches.keys():
			_touches[k] = float(_touches[k]) + delta
		var held := false
		for k in _touches:
			if float(_touches[k]) >= HOLD_DELAY:
				held = true
		if held:
			_hold_acc += delta * HOLD_RATE
			while _hold_acc >= 1.0:
				_hold_acc -= 1.0
				_tap_at(_enemy_pos() + Vector2(randf_range(-40, 40), randf_range(-30, 50)))
	if _atk_held >= 0.0:
		_atk_held += delta
		if _atk_held >= HOLD_DELAY:
			_hold_acc += delta * HOLD_RATE
			while _hold_acc >= 1.0:
				_hold_acc -= 1.0
				_attack_press()
	elif bool(gm.s.settings.get("auto_click", false)):
		_auto_acc += delta * AUTO_CLICK_RATE
		while _auto_acc >= 1.0:
			_auto_acc -= 1.0
			_tap_at(_enemy_pos() + Vector2(randf_range(-50, 50), randf_range(-30, 60)))
	_update_enemy(delta)
	_ui_t += delta
	_update_guide(delta)
	if _ui_t >= 0.1:
		_ui_t = 0.0
		_update_player()
		_update_spells()
		_update_ult()
		if _path_btn and is_instance_valid(_path_btn):
			var was := str(_path_btn.text)
			_update_path_card(_path_btn)
			if gm.path.ready() and not was.contains("✔"):
				Sfx.play("levelup")


func _enemy_pos() -> Vector2:
	var p := view.enemy_screen_pos()
	var sx := size.x / maxf(1.0, float(_vp.size.x))
	var sy := size.y / maxf(1.0, float(_vp.size.y))
	return Vector2(p.x * sx, p.y * sy)


## Pozycja przeciwnika w globalnych współrzędnych ekranu (animacje monet i łupu).
func enemy_global_pos() -> Vector2:
	return global_position + _enemy_pos()


# --- Aktualizacja ----------------------------------------------------------------

func _on_changed(what: String) -> void:
	match what:
		"stage", "all":
			_refresh_stage()
			if what == "all":
				_refresh_all()
		"gear", "level":
			view.set_hero(gm.skins.model(gm.equipment.model_equipment()))
		"mercs":
			_refresh_mercs()
		"stats":
			_refresh_stats()
		"quests":
			_refresh_goals()
		"spells":
			_refresh_spell_icons()
		"tower", "raid", "dungeon", "arena":
			_refresh_stage()
		"dream":
			_refresh_stage()
			_dream_choice()
		"path":
			_refresh_goals()
		"class":
			_update_ult()
		"pets", "dragon":
			_refresh_pets()


func _refresh_all() -> void:
	view.set_region(gm.progression.region(int(gm.s.stage)))
	view.set_hero(gm.skins.model(gm.equipment.model_equipment()))
	_refresh_mercs()
	_refresh_pets()
	_refresh_stage()
	_refresh_stats()
	_refresh_goals()
	_refresh_spell_icons()


func _refresh_pets() -> void:
	view.set_pets(gm.pets.active().map(func(id): return str(PetManager.def(str(id)).look)))
	view.set_dragon(gm.dragon.model_scale() if gm.dragon.alive() else 0.0)


func _refresh_mercs() -> void:
	var hired: Array = gm.db.mercs.filter(func(d): return gm.mercs.level(str(d.id)) > 0)
	hired.reverse()
	view.set_mercs(hired)


func _refresh_stage() -> void:
	var s := gm.s
	var st := int(s.stage)
	var pm := gm.progression
	var per := gm.db.stages_per_region
	var in_reg := (st - 1) % per + 1
	var kind := pm.boss_kind(st)
	var what: String = ["", "  •  ELITA", "  •  BOSS REGIONU"][kind] if not bool(s.farm_mode) else "  •  farmienie"
	_region_l.text = "%s  •  etap %d/%d%s" % [pm.region_title(st), in_reg, per, what]
	if gm.raid.active:
		_region_l.text = "BOSS TYGODNIA  •  suma tygodnia: %s" % IdleDB.fmt(gm.raid.damage())
		_boss_btn.text = "ZAKOŃCZ PRÓBĘ"
		_boss_btn.visible = true
		view.set_region(_tower_region())
		return
	if gm.dungeon.active or gm.arena.active or gm.dream.active:
		var ch = gm.challenge()
		_region_l.text = ch.hud_text()
		_boss_btn.text = "OPUŚĆ LOCH" if gm.dungeon.active else ("OBUDŹ SIĘ" if gm.dream.active else "PODDAJ WALKĘ")
		_boss_btn.visible = true
		if gm.dungeon.active:
			_stage_bar.value = float(gm.dungeon.kills) / float(DungeonManager.GUARDS)
		view.set_region(_challenge_region())
		return
	if gm.tower.active:
		_region_l.text = "WIEŻA POPIOŁU  •  piętro %d  •  rekord %d" % [gm.tower.floor_n, gm.tower.best()]
		_boss_btn.text = "OPUŚĆ WIEŻĘ"
		_boss_btn.visible = true
		view.set_region(_tower_region())
		return
	_boss_btn.text = "WALCZ Z BOSSEM"
	_stage_bar.value = float(s.kills_in_stage) / float(gm.db.kills_per_stage) if kind == 0 or bool(s.farm_mode) else 1.0
	_boss_btn.visible = bool(s.farm_mode)
	_auto_btn.set_pressed_no_signal(bool(s.auto_progress))
	view.set_region(pm.region(st))


## Sen Popielnika: wybór 1 z 3 błogosławieństw po każdym piętrze.
var _dream_modal: Control
func _dream_choice() -> void:
	var d := gm.dream
	if not d.active or not d.choosing:
		# Sen przerwany w czasie wyboru – zamknij okno.
		if is_instance_valid(_dream_modal) and not _dream_modal.is_queued_for_deletion():
			ui.close_modal(_dream_modal)
		return
	if is_instance_valid(_dream_modal) and not _dream_modal.is_queued_for_deletion():
		return
	var v := IdleUI.vbox(10)
	v.add_child(IdleUI.label("Piętro %d pokonane! Wybierz błogosławieństwo na resztę snu:" % (d.floor_n - 1), 20, UiTheme.TEXT, true))
	for i in d.options.size():
		var id: String = d.options[i]
		var info: Array = DreamManager.BLESSINGS[id]
		var have := d.count(id)
		var b := IdleUI.button("%s%s\n%s" % [info[0], ("  (masz ×%d)" % have) if have > 0 else "", info[1]], Vector2(0, 104), 21)
		var idx := i
		b.pressed.connect(func():
			ui.close_modal(_dream_modal)
			gm.dream.choose(idx)
			ui.banner("SEN %d" % gm.dream.floor_n, str(DreamManager.BLESSINGS[id][0]), Color(0.7, 0.6, 1.0)))
		v.add_child(b)
	_dream_modal = ui.modal("Błogosławieństwo snu", v, false)


## Loch: kraina strażników; Arena: Popielisko (jak Wieża).
func _challenge_region() -> Dictionary:
	if gm.dungeon.active:
		var ri: Array = DungeonManager.KINDS[gm.dungeon.kind].regions
		return gm.db.regions[int(ri[0]) % gm.db.regions.size()]
	return _tower_region()


## Wieża stoi w Popielisku (ruiny, żar, dym).
func _tower_region() -> Dictionary:
	for r in gm.db.regions:
		if str(r.id) == "ash":
			return r
	return gm.db.regions.back()


func _refresh_stats() -> void:
	var st := gm.stats
	_stats_l.text = "CIOS %s   •   DPS %s   •   KRYT %d%%   •   %s" % [IdleDB.fmt(st.click), IdleDB.fmt(st.dps), roundi(st.crit_chance * 100.0), SmartTranslation.t(str(gm.events.current().name)).to_upper()]


func _refresh_goals() -> void:
	IdleUI.clear(_goals_box)
	_path_btn = null
	var path_on := not gm.path.finished()
	if path_on:
		_path_btn = _path_card()
		_goals_box.add_child(_path_btn)
	for g in gm.quests.hud_goals(1 if path_on else 2):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 52)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_constant_override("outline_size", 4)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.1, 0.04, 0.8) if g.ready else Color(0.03, 0.025, 0.025, 0.62)
		sb.border_color = IdleUI.GOOD if g.ready else Color(0.45, 0.42, 0.4, 0.55)
		sb.border_width_left = 3
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 8
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var prog := "✔ Odbierz nagrodę!" if g.ready else "%s / %s" % [IdleDB.fmt(g.prog), IdleDB.fmt(g.need)]
		b.text = "%s\n%s" % [g.text, prog]
		b.add_theme_color_override("font_color", IdleUI.GOOD if g.ready else Color(0.92, 0.9, 0.84))
		var goal: Dictionary = g
		b.pressed.connect(func():
			Sfx.play("click")
			if goal.ready:
				if goal.kind == "quest":
					gm.quests.claim(str(goal.id))
				else:
					gm.quests.claim_task(int(goal.id))
			else:
				open_tab.emit("quests"))
		_goals_box.add_child(b)


## Karta bieżącego celu Ścieżki Popielnika (złota ramka).
func _path_card() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.02, 0.82)
	sb.border_color = IdleUI.GOLD_COL
	sb.set_border_width_all(2)
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func():
		Sfx.play("click")
		if gm.path.ready():
			var got := gm.path.claim()
			for it in got:
				ui.toast_msg("+%s %s" % [IdleDB.fmt(float(it[1])), _reward_name(str(it[0]))], IdleUI.GOLD_COL)
			if gm.path.finished():
				ui.banner("ŚCIEŻKA UKOŃCZONA", "Znasz już wszystkie drogi Popielnika!", IdleUI.GOLD_COL)
		else:
			var tab := str(gm.path.current()[4])
			if tab == "daily":
				ui.show_daily()
			elif tab != "fight":
				ui.show_tab(tab))
	_update_path_card(b)
	return b


func _reward_name(id: String) -> String:
	if id == "shards":
		return "odłamków relikwii"
	if id == "hp_potion":
		return "mikstura życia"
	return IdleUI.item_name(gm.db, id)


func _update_path_card(b: Button) -> void:
	var p := gm.path
	if p.finished():
		return
	var g := p.current()
	var rd := p.ready()
	b.text = "ŚCIEŻKA %d/%d: %s\n%s" % [p.index() + 1, PathManager.GOALS.size(), g[0], ("✔ Odbierz: " + PathManager.reward_text(g[3])) if rd else "%s / %s  •  %s" % [IdleDB.fmt(p.progress()), IdleDB.fmt(float(g[2])), PathManager.reward_text(g[3])]]
	b.add_theme_color_override("font_color", IdleUI.GOOD if rd else Color(1.0, 0.9, 0.62))


## Element wskazywany przez samouczek.
func _guide_target(name: String) -> Control:
	match name:
		"attack":
			return _atk_btn
		"party":
			return _team_btn
		"menu":
			return _menu_btn
		"spell":
			for b in _spell_btns:
				if str(b.text) != "+":
					return b
			return _spell_btns[0]
	return ui._nav_btns.get(name)


func _update_guide(delta: float) -> void:
	if _hand == null:
		_hand = TextureRect.new()
		_hand.texture = IdleUI.ash_tex("ico_hand")
		_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hand.custom_minimum_size = Vector2(72, 72)
		_hand.size = Vector2(72, 72)
		_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hand.z_index = 30
		ui._overlay.add_child(_hand)
	var p := gm.path
	var show := not p.finished() and p.index() < 12 and not p.ready() and is_visible_in_tree() \
		and ui._modals_open() == 0 and not ui._panel_host.visible and gm.challenge() == null
	var tgt: Control = null
	if show:
		tgt = _guide_target(str(p.current()[5]))
		show = tgt != null and tgt.is_visible_in_tree()
	_hand.visible = show
	if not show:
		return
	_hand_t += delta
	var r := tgt.get_global_rect()
	var bob := absf(sin(_hand_t * 4.0)) * 14.0
	_hand.global_position = r.position + Vector2(r.size.x * 0.55, r.size.y * 0.45 + bob)
	_hand.rotation = -0.35


const ULT_ICONS := {"warrior": "res://assets/ui/runes/fire.png", "hunter": "res://assets/ui/runes/wind.png", "mage": "res://assets/ui/runes/mind.png"}


func _update_ult() -> void:
	if _ult_btn == null:
		return
	var h := gm.hero
	var on := h.current() != ""
	_ult_btn.visible = on
	_atk_btn.custom_minimum_size.x = 450 if on else 560
	if not on:
		return
	var ic: TextureRect = _ult_btn.get_node("icon")
	var path: String = ULT_ICONS[h.current()]
	if ic.texture == null or ic.texture.resource_path != path:
		ic.texture = load(path)
	var col: Color = h.def().color
	var frac := h.charge() / ClassManager.CHARGE_MAX
	if h.ult_active():
		frac = h.ult_left() / maxf(1.0, float(h.def().ult_sec))
		_ult_l.text = "%.0f s" % h.ult_left()
	elif h.ready():
		_ult_l.text = "GOTOWE!"
	else:
		_ult_l.text = "ŻAR %d%%" % roundi(frac * 100.0)
	_ult_fill.color = Color(col.r, col.g, col.b, 0.75 if h.ready() or h.ult_active() else 0.4)
	_ult_fill.offset_top = -6.0 - (150.0 - 12.0) * clampf(frac, 0.0, 1.0)
	_ult_btn.modulate = Color(1, 1, 1, 1) if h.ready() or h.ult_active() else Color(0.85, 0.85, 0.85, 1)
	if h.ready():
		var p := 1.0 + 0.06 * sin(Time.get_ticks_msec() / 160.0)
		_ult_btn.scale = Vector2(p, p)
		_ult_btn.pivot_offset = _ult_btn.size / 2.0
	else:
		_ult_btn.scale = Vector2.ONE


func _refresh_spell_icons() -> void:
	for i in 4:
		var b: Button = _spell_btns[i]
		var id := str(gm.s.spell_slots[i])
		var cap: Label = b.get_meta("cap")
		if id == "" or not gm.spells.is_known(id):
			b.icon = null
			b.text = "+"
			cap.text = "CZAR %d" % (i + 1)
			b.get_node("auto").visible = false
		else:
			b.text = ""
			b.icon = Sprites.icon(str(gm.spells.def(id).icon))
			cap.text = SmartTranslation.t(str(gm.spells.def(id).get("name", ""))).to_upper()
			b.get_node("auto").visible = gm.spells.auto_enabled() and bool(gm.s.auto_spells.get(id, false))


func _update_spells() -> void:
	for i in 4:
		var b: Button = _spell_btns[i]
		var id := str(gm.s.spell_slots[i])
		var cd: ColorRect = b.get_node("cd")
		var state: Label = b.get_meta("state")
		if id == "" or not gm.spells.is_known(id):
			cd.visible = false
			_state(state, "[PUSTY]", Color(0.6, 0.58, 0.55))
			continue
		var left := gm.spells.cd_left(id)
		var total := gm.spells.cooldown_of(id)
		var mana := gm.spells.mana_of(id)
		cd.visible = left > 0.0 or gm.combat.mp < mana
		cd.anchor_top = 1.0 - (left / total if left > 0.0 else 1.0)
		cd.color = Color(0, 0, 0, 0.62) if left > 0.0 else Color(0.05, 0.1, 0.35, 0.55)
		if left > 0.0:
			_state(state, "[CD %d s]" % ceili(left), Color(1.0, 0.4, 0.3))
		elif gm.combat.mp < mana:
			_state(state, "[%d MP]" % int(mana), Color(0.55, 0.65, 1.0))
		else:
			_state(state, "[GOTOWY]", Color(0.6, 1.0, 0.55))
	var on := bool(gm.s.settings.get("auto_click", false))
	_state(_auto_click_btn.get_meta("state"), "[WŁ]" if on else "[WYŁ]", Color(0.6, 1.0, 0.55) if on else Color(0.7, 0.66, 0.62))
	_auto_click_btn.modulate = Color.WHITE if on else Color(0.8, 0.78, 0.76)
	var hp_n := gm.inventory.count("hp_potion") + gm.inventory.count("great_hp_potion")
	var mp_n := gm.inventory.count("mp_potion") + gm.inventory.count("great_mp_potion")
	_state(_potion_btn.get_meta("state"), "[%d]" % hp_n, Color(1.0, 0.55, 0.5) if hp_n > 0 else Color(0.6, 0.58, 0.55))
	_state(_mpotion_btn.get_meta("state"), "[%d]" % mp_n, Color(0.55, 0.7, 1.0) if mp_n > 0 else Color(0.6, 0.58, 0.55))


func _state(l: Label, text: String, col: Color) -> void:
	if l.text != text:
		l.text = text
	l.add_theme_color_override("font_color", col)


func _update_player() -> void:
	var st := gm.stats
	var c := gm.combat
	_php.value = c.hp / maxf(1.0, st.max_hp)
	_php_l.text = IdleDB.fmt(c.hp)
	_pmp.value = c.mp / maxf(1.0, st.max_mp)
	_plvl_l.text = "LVL %d" % int(gm.s.level)
	_shield_l.text = "TARCZA %s" % IdleDB.fmt(c.shield) if c.shield > 0.0 else ""


func _update_enemy(delta: float) -> void:
	var e := gm.enemy.cur
	if e.is_empty():
		return
	var target := clampf(float(e.hp) / maxf(1.0, float(e.max_hp)), 0.0, 1.0)
	_shown_hp = lerpf(_shown_hp, target, minf(1.0, delta * 14.0))
	_hp_bar.value = _shown_hp
	_hp_l.text = "PZ: %s / %s" % [IdleDB.fmt(maxf(0.0, float(e.hp))), IdleDB.fmt(float(e.max_hp))]
	# U bossa cienki pasek pod ramą odlicza czas walki.
	var boss := int(e.kind) > 0 or e.has("goblin")
	if boss:
		_stage_bar.value = float(e.time_left) / float(e.time_max)
		_timer_l.text = ("❄ " if float(e.frozen) > 0.0 else "") + "%.1f s" % maxf(0.0, float(e.time_left))
	elif _timer_l.text != "":
		_timer_l.text = ""


func _on_spawn() -> void:
	var e := gm.enemy.cur
	var kind := int(e.kind)
	var nm := SmartTranslation.t(str(e.name)).to_upper()
	_enemy_l.text = "[%s - " % (nm if nm.length() <= 18 else nm.left(17) + "…")
	_enemy_l.add_theme_color_override("font_color", [Color(0.97, 0.95, 0.92), Color(0.85, 0.65, 1.0), Color(1.0, 0.6, 0.3)][kind])
	_elvl_l.text = "LVL %d" % int(e.stage)
	(_stage_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(1.0, 0.6, 0.18) if kind == 0 else Color(1.0, 0.3, 0.12)
	_shown_hp = 1.0
	view.set_region(_challenge_region() if e.has("challenge") else (_tower_region() if e.has("tower") or e.has("raid") else gm.progression.region(int(e.stage))))
	view.spawn_enemy(e)
	_refresh_stage()
	if str(e.get("challenge", "")) == "arena":
		ui.banner("ARENA", str(e.name), Color(1.0, 0.5, 0.3))
	elif str(e.get("challenge", "")) == "dream":
		if gm.dream.floor_n == 1:
			ui.banner("SEN POPIELNIKA", "Piętro 1 – im głębiej, tym silniejsze zjawy", Color(0.7, 0.6, 1.0))
	elif str(e.get("challenge", "")) == "dungeon":
		if gm.dungeon.kills == 0:
			ui.banner(str(DungeonManager.KINDS[gm.dungeon.kind].name).to_upper(), "Pokonaj %d strażników w %d s!" % [DungeonManager.GUARDS, int(DungeonManager.TIME)], DungeonManager.KINDS[gm.dungeon.kind].color)
	elif e.has("raid"):
		ui.banner("BOSS TYGODNIA", str(gm.raid.boss().name) + " – zadaj jak najwięcej obrażeń!", Color(1.0, 0.45, 0.25))
	elif e.has("tower"):
		ui.banner("PIĘTRO %d" % int(e.tower), str(e.name).get_slice(" – ", 0), Color(1.0, 0.6, 0.3))
	elif e.has("goblin"):
		_enemy_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		ui.banner("ZŁOTY GOBLIN!", "Pokonaj go, zanim ucieknie (%d s)!" % int(e.time_max), Color(1.0, 0.85, 0.3))
		_buzz(60, true)
	elif kind > 0:
		ui.banner(["", "ELITA", "BOSS"][kind] + ": " + str(e.name), "Pokonaj w %d s!" % int(e.time_max), Color(1.0, 0.55, 0.3))


# --- Efekty -----------------------------------------------------------------------

## Krótka wibracja telefonu (ustawienie „Wibracje”); krytyki najwyżej co 0,25 s.
var _buzz_at := 0
func _buzz(ms: int, force := false) -> void:
	if not bool(gm.s.settings.get("vibration", true)) or not OS.has_feature("mobile"):
		return
	var now := Time.get_ticks_msec()
	if not force and now - _buzz_at < 250:
		return
	_buzz_at = now
	Input.vibrate_handheld(ms)


func _on_hit(amount: float, crit: bool, source: String) -> void:
	view.on_hit(crit, source)
	if crit and source == "tap":
		_buzz(18)
	if not bool(gm.s.settings.get("effects", true)) and not crit:
		return
	var pos := _enemy_pos() + Vector2(randf_range(-120, 120), randf_range(-70, 90))
	var yellow := Color(1.0, 0.84, 0.22)
	match source:
		"tap":
			_float(IdleDB.fmt(amount) + ("CRIT" if crit else ""), pos, yellow, 46 if crit else 38, crit)
		"auto":
			if crit or randf() < 0.35:
				_float(IdleDB.fmt(amount) + ("CRIT" if crit else ""), pos + Vector2(0, 30), yellow if crit else Color(0.97, 0.96, 0.94), 40 if crit else 30, crit)
		"spell":
			_float(IdleDB.fmt(amount), pos, Color(0.6, 0.85, 1.0), 46, true)
		"dragon":
			_float("🔥 " + IdleDB.fmt(amount), pos + Vector2(0, -30), Color(1.0, 0.55, 0.2), 44, true)
		"dot":
			if randf() < 0.5:
				_float(IdleDB.fmt(amount), pos + Vector2(0, 40), Color(0.6, 1.0, 0.45), 26, false)
	if crit:
		gm.audio.play("crit", 0.08)
		_spark(_enemy_pos(), Color(1.0, 0.7, 0.2))
		_flash_edge(0.45)


func _on_killed(info: Dictionary) -> void:
	if int(info.get("boss", 0)) > 0:
		_buzz(70, true)
	var boss := int(info.boss)
	view.on_kill(boss)
	gm.audio.play("death")
	var pos := _enemy_pos()
	_float("+%s PD" % IdleDB.fmt(float(info.xp)), pos + Vector2(80, -10), Color(0.8, 0.62, 1.0), 24, false)
	ui.fly_coins(global_position + pos, 3 + boss * 4)
	_pop_gold(float(info.gold))
	if boss > 0:
		_flash_edge(1.0)
	if info.has("goblin"):
		ui.fly_coins(global_position + pos, 14)
		_flash_edge(1.0)
		ui.banner("Złoty Goblin pokonany!", tr("+%s zł  •  +%d żarokr.") % [IdleDB.fmt(float(info.gold)), int(info.gems)] + ("  •  " + tr(str(info.extra)) if str(info.extra) != "" else ""), Color(1.0, 0.85, 0.3))
	if boss > 0 and float(info.gold) > 0.0:
		ui.banner("Pokonano: %s!" % info.name, "+%s zł  •  +%s XP" % [IdleDB.fmt(float(info.gold)), IdleDB.fmt(float(info.xp))], Color(1.0, 0.85, 0.35))


func _on_spell(id: String) -> void:
	view.on_spell(id)
	if id != "storm_bolt":
		gm.audio.play("spell")
		_float(str(gm.spells.def(id).get("name", "")), Vector2(size.x * 0.28, size.y * 0.45), Color(0.7, 0.85, 1.0), 26, false)


func _on_player_hit(amount: float) -> void:
	var p := Vector2(size.x * 0.25, size.y * 0.5)
	_float("-" + IdleDB.fmt(amount), p, IdleUI.BAD, 26, false)
	view.shake(0.2)


func _float(text: String, pos: Vector2, color: Color, size_px: int, pop: bool) -> void:
	var l: Label
	if _floaters.size() >= MAX_FLOATERS:
		l = _floaters.pop_front()
		if is_instance_valid(l):
			l.queue_free()
	l = IdleUI.hud_label(text, size_px, color, maxi(8, size_px / 4))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_fx_layer.add_child(l)
	l.position = pos - Vector2(l.get_minimum_size().x / 2.0, 0)
	l.pivot_offset = l.get_minimum_size() / 2.0
	_floaters.append(l)
	var tw := l.create_tween().set_parallel(true)
	if pop:
		l.scale = Vector2(0.4, 0.4)
		tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_delay(0.12)
	tw.tween_property(l, "position:y", pos.y - 90.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(func():
		_floaters.erase(l)
		l.queue_free())


## „ZŁOTO +X” wysuwa się z prawej krawędzi; kolejne zabójstwa sumują się, dopóki widać okienko.
func _pop_gold(amount: float) -> void:
	if amount <= 0.0:
		return
	_gold_pop_sum = (_gold_pop_sum if _gold_pop.modulate.a > 0.05 else 0.0) + amount
	_gold_pop_l.text = "+" + IdleDB.fmt(_gold_pop_sum)
	_gold_pop.reset_size()
	var y := size.y * 0.46
	var x := size.x - _gold_pop.size.x
	if _gold_tw:
		_gold_tw.kill()
	if _gold_pop.modulate.a < 0.5:
		_gold_pop.position = Vector2(size.x, y)
	_gold_tw = _gold_pop.create_tween()
	_gold_tw.tween_property(_gold_pop, "modulate:a", 1.0, 0.12)
	_gold_tw.parallel().tween_property(_gold_pop, "position", Vector2(x, y), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gold_tw.tween_interval(1.6)
	_gold_tw.tween_property(_gold_pop, "modulate:a", 0.0, 0.4)


func _spark(pos: Vector2, color: Color) -> void:
	if not bool(gm.s.settings.get("effects", true)):
		return
	var p: CPUParticles2D = _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % _sparks.size()
	p.position = pos
	p.color = color
	p.restart()
	p.emitting = true
