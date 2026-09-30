class_name CombatScreen
extends Control
## Ekran walki: widok 3D (BattleView), duży obszar dotyku (tapnięcie / przytrzymanie palca),
## nagłówek (region, etap, wróg, zdrowie, czas bossa), liczby obrażeń, cząsteczki, cele zadań,
## paski zdrowia i many bohatera, pasek czarów i mikstury.

signal open_tab(name: String)

const HOLD_DELAY := 0.3
const HOLD_RATE := 8.0
const MAX_FLOATERS := 40

var ui: IdleMain
var gm: IdleGame
var view: BattleView
var _vpc: SubViewportContainer
var _vp: SubViewport
var _fx_layer: Control
var _region_l: Label
var _stage_l: Label
var _stage_bar: ProgressBar
var _enemy_l: Label
var _hp_bar: ProgressBar
var _hp_l: Label
var _timer_bar: ProgressBar
var _timer_l: Label
var _boss_btn: Button
var _auto_btn: Button
var _goals_box: VBoxContainer
var _php: ProgressBar
var _php_l: Label
var _pmp: ProgressBar
var _pmp_l: Label
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
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.add_point(0.28, Color(0, 0, 0, 0.0))
	grad.add_point(0.78, Color(0, 0, 0, 0.0))
	grad.set_color(grad.get_point_count() - 1, Color(0, 0, 0, 0.6))
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


func _build_header() -> void:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_theme_constant_override("margin_top", 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var v := IdleUI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var row := IdleUI.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var left := IdleUI.vbox(0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_region_l = IdleUI.label("", 20, UiTheme.ACCENT)
	left.add_child(_region_l)
	_stage_l = IdleUI.label("", 18, Color(0.9, 0.88, 0.8))
	left.add_child(_stage_l)
	_auto_btn = IdleUI.button("AUTO", Vector2(110, 56), 18)
	_auto_btn.toggle_mode = true
	_auto_btn.toggled.connect(func(on): gm.progression.toggle_auto(on))
	row.add_child(_auto_btn)
	_stage_bar = IdleUI.bar(Color(0.85, 0.65, 0.25), 10)
	_stage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_stage_bar)
	v.add_child(IdleUI.spacer(2))
	_enemy_l = IdleUI.label("", 30, Color(1, 0.96, 0.9))
	_enemy_l.add_theme_font_override("font", UiTheme.TITLE_FONT)
	_enemy_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_enemy_l)
	_hp_bar = IdleUI.bar(Color(0.78, 0.12, 0.1), 34)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_l = IdleUI.bar_label(_hp_bar, 20)
	v.add_child(_hp_bar)
	_timer_bar = IdleUI.bar(Color(1.0, 0.55, 0.15), 18)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_l = IdleUI.bar_label(_timer_bar, 15)
	v.add_child(_timer_bar)
	_boss_btn = IdleUI.button("⚔ Walcz z bossem", Vector2(0, 64), 22)
	_boss_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_btn.pressed.connect(func(): gm.progression.challenge_boss())
	v.add_child(_boss_btn)


func _build_bottom() -> void:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.add_theme_constant_override("margin_bottom", 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var v := IdleUI.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var row := IdleUI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	_goals_box = IdleUI.vbox(6)
	_goals_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goals_box.size_flags_vertical = Control.SIZE_SHRINK_END
	_goals_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_goals_box)
	var bars := IdleUI.vbox(4)
	bars.custom_minimum_size = Vector2(210, 0)
	bars.size_flags_vertical = Control.SIZE_SHRINK_END
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bars)
	_shield_l = IdleUI.label("", 16, Color(0.6, 0.9, 1.0))
	_shield_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bars.add_child(_shield_l)
	_php = IdleUI.bar(Color(0.75, 0.15, 0.12), 22)
	_php.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_php_l = IdleUI.bar_label(_php, 15)
	bars.add_child(_php)
	_pmp = IdleUI.bar(Color(0.2, 0.4, 0.9), 22)
	_pmp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pmp_l = IdleUI.bar_label(_pmp, 15)
	bars.add_child(_pmp)
	# Pasek czarów i mikstur.
	var sp := IdleUI.hbox(8)
	sp.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(sp)
	for i in 4:
		var b := _spell_button(i)
		sp.add_child(b)
		_spell_btns.append(b)
	_potion_btn = _potion_button("hp_potion")
	_potion_btn.pressed.connect(func():
		if not gm.combat.drink_best_hp():
			ui.toast_msg("Brak mikstur życia – kup je w sklepie.", IdleUI.BAD))
	sp.add_child(_potion_btn)
	_mpotion_btn = _potion_button("mp_potion")
	_mpotion_btn.pressed.connect(func():
		if not gm.combat.drink_best_mp():
			ui.toast_msg("Brak mikstur many.", IdleUI.BAD))
	sp.add_child(_mpotion_btn)
	_stats_l = IdleUI.label("", 17, Color(0.92, 0.88, 0.78))
	_stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_stats_l)


func _spell_button(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 96)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := UiTheme.tex_box("slot", 16, 8)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var cd := ColorRect.new()
	cd.name = "cd"
	cd.color = Color(0, 0, 0, 0.62)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.anchor_right = 1.0
	cd.anchor_bottom = 1.0
	b.add_child(cd)
	var l := UiTheme.label("", 15)
	l.name = "txt"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	var a := UiTheme.label("AUTO", 12, Color(0.6, 1.0, 0.6))
	a.name = "auto"
	a.position = Vector2(6, 2)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(a)
	b.pressed.connect(func():
		var id := str(gm.s.spell_slots[i])
		if id == "":
			open_tab.emit("spells")
		elif not gm.spells.cast(id):
			Sfx.play("miss"))
	return b


func _potion_button(id: String) -> Button:
	var b := IdleUI.item_button(Sprites.item_icon_for(gm.db.item(id)), 0, "", 80)
	return b


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
	var list: Array = _spell_btns + [_potion_btn, _mpotion_btn, _auto_btn, _boss_btn]
	list.append_array(_goals_box.get_children())
	for b in list:
		if b is Control and b.is_visible_in_tree() and b.get_global_rect().has_point(gp):
			return true
	return false


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
	_update_enemy(delta)
	_ui_t += delta
	if _ui_t >= 0.1:
		_ui_t = 0.0
		_update_player()
		_update_spells()


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
			view.set_hero(gm.equipment.model_equipment())
		"mercs":
			_refresh_mercs()
		"stats":
			_refresh_stats()
		"quests":
			_refresh_goals()
		"spells":
			_refresh_spell_icons()


func _refresh_all() -> void:
	view.set_region(gm.progression.region(int(gm.s.stage)))
	view.set_hero(gm.equipment.model_equipment())
	_refresh_mercs()
	_refresh_stage()
	_refresh_stats()
	_refresh_goals()
	_refresh_spell_icons()


func _refresh_mercs() -> void:
	var hired: Array = gm.db.mercs.filter(func(d): return gm.mercs.level(str(d.id)) > 0)
	hired.reverse()
	view.set_mercs(hired)


func _refresh_stage() -> void:
	var s := gm.s
	var st := int(s.stage)
	var pm := gm.progression
	_region_l.text = pm.region_title(st)
	var per := gm.db.stages_per_region
	var in_reg := (st - 1) % per + 1
	var kind := pm.boss_kind(st)
	var what: String = ["", "  •  ELITA", "  •  BOSS REGIONU"][kind] if not bool(s.farm_mode) else "  •  farmienie"
	_stage_l.text = "Etap %d  (%d/%d)%s" % [st, in_reg, per, what]
	_stage_bar.value = float(s.kills_in_stage) / float(gm.db.kills_per_stage) if kind == 0 or bool(s.farm_mode) else 1.0
	_boss_btn.visible = bool(s.farm_mode)
	_auto_btn.set_pressed_no_signal(bool(s.auto_progress))
	view.set_region(pm.region(st))


func _refresh_stats() -> void:
	var st := gm.stats
	_stats_l.text = "Klik %s   •   DPS %s   •   Kryt %d%%" % [IdleDB.fmt(st.click), IdleDB.fmt(st.dps), roundi(st.crit_chance * 100.0)]


func _refresh_goals() -> void:
	IdleUI.clear(_goals_box)
	for g in gm.quests.hud_goals(2):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 54)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.12, 0.05, 0.85) if g.ready else Color(0.03, 0.03, 0.05, 0.72)
		sb.border_color = IdleUI.GOOD if g.ready else Color(0.5, 0.4, 0.22, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
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


func _refresh_spell_icons() -> void:
	for i in 4:
		var b: Button = _spell_btns[i]
		var id := str(gm.s.spell_slots[i])
		if id == "" or not gm.spells.is_known(id):
			b.icon = null
			b.get_node("txt").text = "+"
			b.get_node("auto").visible = false
		else:
			b.icon = Sprites.icon(str(gm.spells.def(id).icon))
			b.get_node("auto").visible = gm.spells.auto_enabled() and bool(gm.s.auto_spells.get(id, false))


func _update_spells() -> void:
	for i in 4:
		var b: Button = _spell_btns[i]
		var id := str(gm.s.spell_slots[i])
		var cd: ColorRect = b.get_node("cd")
		var txt: Label = b.get_node("txt")
		if id == "" or not gm.spells.is_known(id):
			cd.visible = false
			continue
		var left := gm.spells.cd_left(id)
		var total := gm.spells.cooldown_of(id)
		cd.visible = left > 0.0 or gm.combat.mp < gm.spells.mana_of(id)
		cd.anchor_top = 1.0 - (left / total if left > 0.0 else 1.0)
		cd.color = Color(0, 0, 0, 0.62) if left > 0.0 else Color(0.05, 0.1, 0.35, 0.55)
		txt.text = ("%.0f s" % ceil(left)) if left > 0.0 else str(int(gm.spells.mana_of(id)))
	_potion_btn.text = str(gm.inventory.count("hp_potion") + gm.inventory.count("great_hp_potion"))
	_mpotion_btn.text = str(gm.inventory.count("mp_potion") + gm.inventory.count("great_mp_potion"))


func _update_player() -> void:
	var st := gm.stats
	var c := gm.combat
	_php.value = c.hp / maxf(1.0, st.max_hp)
	_php_l.text = "%s / %s" % [IdleDB.fmt(c.hp), IdleDB.fmt(st.max_hp)]
	_pmp.value = c.mp / maxf(1.0, st.max_mp)
	_pmp_l.text = "%s / %s" % [IdleDB.fmt(c.mp), IdleDB.fmt(st.max_mp)]
	_shield_l.text = "Tarcza lodu: %s" % IdleDB.fmt(c.shield) if c.shield > 0.0 else ""


func _update_enemy(delta: float) -> void:
	var e := gm.enemy.cur
	if e.is_empty():
		return
	var target := clampf(float(e.hp) / maxf(1.0, float(e.max_hp)), 0.0, 1.0)
	_shown_hp = lerpf(_shown_hp, target, minf(1.0, delta * 14.0))
	_hp_bar.value = _shown_hp
	_hp_l.text = "%s / %s" % [IdleDB.fmt(maxf(0.0, float(e.hp))), IdleDB.fmt(float(e.max_hp))]
	var boss := int(e.kind) > 0
	_timer_bar.visible = boss
	if boss:
		_timer_bar.value = float(e.time_left) / float(e.time_max)
		_timer_l.text = ("ZAMROŻONY  " if float(e.frozen) > 0.0 else "") + "%.1f s" % maxf(0.0, float(e.time_left))


func _on_spawn() -> void:
	var e := gm.enemy.cur
	var kind := int(e.kind)
	_enemy_l.text = "%s  •  poz. %d" % [e.name, int(e.stage)]
	_enemy_l.add_theme_color_override("font_color", [Color(1, 0.96, 0.9), Color(0.85, 0.6, 1.0), Color(1.0, 0.55, 0.3)][kind])
	_shown_hp = 1.0
	view.set_region(gm.progression.region(int(e.stage)))
	view.spawn_enemy(e)
	_refresh_stage()
	if kind > 0:
		ui.banner(["", "ELITA", "BOSS"][kind] + ": " + str(e.name), "Pokonaj w %d s!" % int(e.time_max), Color(1.0, 0.55, 0.3))


# --- Efekty -----------------------------------------------------------------------

func _on_hit(amount: float, crit: bool, source: String) -> void:
	view.on_hit(crit, source)
	if not bool(gm.s.settings.get("effects", true)) and not crit:
		return
	var pos := _enemy_pos() + Vector2(randf_range(-70, 70), randf_range(-40, 30))
	match source:
		"tap":
			_float("-" + IdleDB.fmt(amount), pos, Color(1, 1, 1) if not crit else Color(1.0, 0.72, 0.2), 30 if not crit else 44, crit)
		"auto":
			if crit or randf() < 0.35:
				_float(IdleDB.fmt(amount), pos + Vector2(0, 30), Color(1.0, 0.85, 0.6) if not crit else Color(1.0, 0.72, 0.2), 22 if not crit else 34, crit)
		"spell":
			_float(IdleDB.fmt(amount), pos, Color(0.65, 0.8, 1.0), 42, true)
		"dot":
			if randf() < 0.5:
				_float(IdleDB.fmt(amount), pos + Vector2(0, 40), Color(0.6, 1.0, 0.45), 20, false)
	if crit:
		gm.audio.play("crit", 0.08)
		if source == "tap":
			_float("KRYTYK!", pos + Vector2(0, -42), Color(1.0, 0.55, 0.2), 24, false)
		_spark(_enemy_pos(), Color(1.0, 0.7, 0.2))


func _on_killed(info: Dictionary) -> void:
	var boss := int(info.boss)
	view.on_kill(boss)
	gm.audio.play("death")
	var pos := _enemy_pos()
	_float("+%s XP" % IdleDB.fmt(float(info.xp)), pos + Vector2(80, -10), Color(0.75, 0.6, 1.0), 20, false)
	ui.fly_coins(global_position + pos, 3 + boss * 4)
	if boss > 0:
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
	l = UiTheme.label(text, size_px, color)
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _spark(pos: Vector2, color: Color) -> void:
	if not bool(gm.s.settings.get("effects", true)):
		return
	var p: CPUParticles2D = _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % _sparks.size()
	p.position = pos
	p.color = color
	p.restart()
	p.emitting = true
