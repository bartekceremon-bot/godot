class_name IdleMain
extends Control
## UIManager wersji idle: menu główne, górny pasek (poziom, XP, złoto, żarokryształy, popiół),
## ekran walki, panel zakładek, dolna nawigacja (WALKA / EKWIPUNEK / CRAFT / CZARY / QUESTY / MAPA),
## menu boczne (sklep, targ, stajnia, ołtarz, postać, ustawienia), powiadomienia, okna i animacje łupu.
## Układ pionowy dla telefonu (16:9 … 20:9), na tabletach i w przeglądarce – wyśrodkowana kolumna.

const MAX_COLUMN := 900.0
const NAV := [["fight", "WALKA", "attack"], ["gear", "EKWIPUNEK", "bag"], ["craft", "CRAFT", "craft"],
	["spells", "CZARY", "book"], ["quests", "QUESTY", "quest"], ["map", "MAPA", "map"]]

var gm: IdleGame
var column: Control
var combat: CombatScreen
var _root_box: VBoxContainer
var _panel_host: PanelContainer
var _panels: Dictionary = {}
var _current := ""
var _nav_btns: Dictionary = {}
var _badges: Dictionary = {}
var _overlay: Control
var _toasts: VBoxContainer
var _lvl_l: Label
var _xp_bar: ProgressBar
var _xp_l: Label
var _gold_l: Label
var _gem_l: Label
var _ash_box: Control
var _ash_l: Label
var _menu_screen: Control
var _ui_t := 0.0
var _started := false
## Otwarte okna modalne (od najstarszego).
var _modals: Array = []


func _ready() -> void:
	gm = Idle
	# Testy automatyczne klasycznego MMO (tools, run3d.sh) – od razu stara scena.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			open_classic.call_deferred()
			return
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.03, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	column = Control.new()
	add_child(column)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_toasts = IdleUI.vbox(6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_toasts)
	resized.connect(_layout)
	get_tree().root.size_changed.connect(_layout)
	_layout()
	_show_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--idle-shots="):
			var t = load("res://scripts/idle/ui/idle_autotest.gd").new()
			t.ui = self
			add_child(t)


func _layout() -> void:
	var w := minf(size.x, MAX_COLUMN)
	column.position = Vector2((size.x - w) / 2.0, 0)
	column.size = Vector2(w, size.y)
	_toasts.position = Vector2(column.position.x + 20, size.y * 0.3)
	_toasts.size = Vector2(w - 40, 0)
	if combat:
		_resize_combat()


# --- Menu główne ------------------------------------------------------------------

func _show_menu() -> void:
	_menu_screen = Control.new()
	_menu_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_child(_menu_screen)
	var splash := TextureRect.new()
	splash.texture = load("res://assets/splash.png")
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.modulate = Color(0.55, 0.5, 0.5)
	_menu_screen.add_child(splash)
	var v := IdleUI.vbox(18)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.custom_minimum_size = Vector2(minf(620.0, column.size.x - 40.0), 0)
	_menu_screen.add_child(v)
	var t := IdleUI.title("POPIELNE KRÓLESTWA", 46)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := IdleUI.label("Łowy w Popiele  •  RPG idle", 24, Color(1.0, 0.7, 0.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var desc := IdleUI.label("Klikaj, zabijaj potwory Popielnych Królestw, zbieraj łup i ulepszaj bohatera. Twoja drużyna walczy dalej, nawet gdy nie grasz.", 20, Color(0.85, 0.82, 0.75), true)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	v.add_child(IdleUI.spacer(20))
	var has := gm.save.has_save()
	var play := IdleUI.button("Kontynuuj" if has else "Rozpocznij przygodę", Vector2(0, 96), 30)
	play.pressed.connect(_start_game)
	v.add_child(play)
	var mmo := IdleUI.button("Klasyczne MMO (wymaga serwera)", Vector2(0, 72), 20)
	mmo.pressed.connect(open_classic)
	v.add_child(mmo)
	var ver := IdleUI.label("v%s" % ProjectSettings.get_setting("application/config/version"), 16, IdleUI.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)


func _start_game() -> void:
	if _started:
		return
	_started = true
	gm.start()
	_menu_screen.queue_free()
	_build_game()
	if not gm.offline_report.is_empty():
		_show_offline(gm.offline_report)
	elif int(gm.s.stats.kills) == 0:
		dialog("Witaj, Popielniku!", "Dotknij przeciwnika, by go zaatakować (albo przytrzymaj palec). Za złoto wynajmuj najemników – walczą za ciebie także wtedy, gdy nie grasz. Ulepszaj ekwipunek, ucz się czarów u kapłanów i odblokowuj kolejne krainy.", [["Do boju!", Callable()]])


## Przejście do klasycznej wersji MMO (poziomy ekran, logowanie na serwer).
func open_classic() -> void:
	if gm.running:
		gm.save.save_game()
		gm.running = false
		gm.set_process(false)
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		get_window().size = Vector2i(1280, 720)
		get_window().move_to_center()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Gra ----------------------------------------------------------------------------

func _build_game() -> void:
	_root_box = IdleUI.vbox(0)
	_root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_child(_root_box)
	_root_box.add_child(_build_topbar())
	combat = CombatScreen.new()
	combat.custom_minimum_size = Vector2(0, 600)
	_root_box.add_child(combat)
	combat.setup(self)
	combat.open_tab.connect(show_tab)
	_panel_host = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.045, 0.055)
	sb.border_color = Color(0.55, 0.42, 0.22)
	sb.border_width_top = 3
	sb.set_content_margin_all(10)
	_panel_host.add_theme_stylebox_override("panel", sb)
	_panel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_panel_host)
	_root_box.add_child(_build_nav())
	gm.changed.connect(_on_changed)
	gm.level_up.connect(_on_level_up)
	gm.loot_gained.connect(_on_loot)
	gm.toast.connect(toast_msg)
	_refresh_top()
	show_tab("fight")


func _build_topbar() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.065)
	sb.border_color = Color(0.6, 0.45, 0.22)
	sb.border_width_bottom = 3
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := IdleUI.hbox(12)
	p.add_child(h)
	# Portret z poziomem.
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(84, 84)
	var fr := IdleUI.icon_rect(load("res://assets/ui/frame_round.png"), 84)
	portrait.add_child(fr)
	var face := IdleUI.icon_rect(Sprites.icon("character"), 52)
	face.position = Vector2(16, 12)
	portrait.add_child(face)
	_lvl_l = IdleUI.label("1", 22, UiTheme.ACCENT)
	_lvl_l.position = Vector2(0, 58)
	_lvl_l.size = Vector2(84, 26)
	_lvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.add_child(_lvl_l)
	var pb := Button.new()
	pb.flat = true
	pb.set_anchors_preset(Control.PRESET_FULL_RECT)
	pb.pressed.connect(func(): show_tab("stats"))
	portrait.add_child(pb)
	h.add_child(portrait)
	var mid := IdleUI.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var cur := IdleUI.hbox(18)
	mid.add_child(cur)
	var g := IdleUI.currency(Sprites.item_icon("gold", 0), IdleUI.GOLD_COL, 26)
	_gold_l = g[1]
	cur.add_child(g[0])
	var gem := IdleUI.currency(Sprites.icon("gem"), IdleUI.GEM_COL, 24)
	_gem_l = gem[1]
	cur.add_child(gem[0])
	var ash := IdleUI.currency(Sprites.icon("ash"), IdleUI.ASH_COL, 24)
	_ash_box = ash[0]
	_ash_l = ash[1]
	cur.add_child(_ash_box)
	_xp_bar = IdleUI.bar(Color(0.55, 0.35, 0.9), 22)
	_xp_l = IdleUI.bar_label(_xp_bar, 15)
	mid.add_child(_xp_bar)
	var menu := Button.new()
	menu.custom_minimum_size = Vector2(84, 84)
	menu.icon = Sprites.icon("menu")
	menu.expand_icon = true
	menu.pressed.connect(_open_menu)
	h.add_child(menu)
	return p


func _build_nav() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.048, 0.055)
	sb.border_color = Color(0.6, 0.45, 0.22)
	sb.border_width_top = 3
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var h := IdleUI.hbox(6)
	p.add_child(h)
	for n in NAV:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.icon = Sprites.icon(str(n[2]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = str(n[1])
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_constant_override("icon_max_width", 56)
		var id := str(n[0])
		b.pressed.connect(func():
			Sfx.play("click")
			show_tab(id))
		h.add_child(b)
		_nav_btns[id] = b
		var badge := UiTheme.label("", 16, Color.WHITE)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.8, 0.12, 0.1)
		bs.set_corner_radius_all(12)
		bs.content_margin_left = 7
		bs.content_margin_right = 7
		badge.add_theme_stylebox_override("normal", bs)
		badge.position = Vector2(6, 2)
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		_badges[id] = badge
	return p


## Proporcje: na zakładce WALKA widok walki jest wyższy.
func _resize_combat() -> void:
	var h := column.size.y
	var ratio := 0.54 if _current == "fight" else 0.4
	combat.custom_minimum_size = Vector2(0, maxf(460.0, h * ratio))


func show_tab(id: String) -> void:
	if not _panels.has(id):
		var p: IdlePanel = _make_panel(id)
		if p == null:
			return
		p.setup(self)
		_panels[id] = p
	for k in _panels:
		var pn: Control = _panels[k]
		if pn.get_parent():
			_panel_host.remove_child(pn)
	var panel: IdlePanel = _panels[id]
	_panel_host.add_child(panel)
	_current = id
	panel.refresh()
	for k in _nav_btns:
		_nav_btns[k].set_pressed_no_signal(k == id)
	_resize_combat()


func _make_panel(id: String) -> IdlePanel:
	match id:
		"fight":
			return HeroesPanel.new()
		"gear":
			return IdleInventoryPanel.new()
		"craft":
			return IdleCraftPanel.new()
		"spells":
			return SpellsPanel.new()
		"quests":
			return QuestsPanel.new()
		"map":
			return MapPanel.new()
		"shop":
			return IdleShopPanel.new()
		"mounts":
			return MountsPanel.new()
		"prestige":
			return PrestigePanel.new()
		"stats":
			return StatsPanel.new()
		"settings":
			return SettingsPanel.new()
	return null


func _open_menu() -> void:
	var items := [["Sklep i targ", "shop", "shop"], ["Stajnia – wierzchowce", "mount", "mounts"], ["Ołtarz Popiołu – odrodzenie", "prestige", "prestige"],
		["Postać i statystyki", "character", "stats"], ["Ustawienia", "menu", "settings"]]
	var box := IdleUI.vbox(10)
	var m: Control
	for it in items:
		var b := IdleUI.button(str(it[0]), Vector2(0, 84), 24)
		b.icon = Sprites.icon(str(it[1]))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tab := str(it[2])
		b.pressed.connect(func():
			close_modal(m)
			show_tab(tab))
		box.add_child(b)
	m = modal("Menu", box)


func _process(delta: float) -> void:
	if not gm.running:
		return
	_ui_t += delta
	if _ui_t >= 0.25:
		_ui_t = 0.0
		_refresh_top()
		if _panels.has(_current):
			_panels[_current].tick_ui()
		_refresh_badges()


func _on_changed(what: String) -> void:
	if what in ["gold", "xp", "level", "all"]:
		_refresh_top()
	if _panels.has(_current):
		_panels[_current].on_changed(what)
	if what == "all":
		for k in _panels:
			_panels[k].refresh()


func _refresh_top() -> void:
	var s := gm.s
	_lvl_l.text = str(int(s.level))
	var need := ProgressionManager.xp_next(int(s.level))
	_xp_bar.value = float(s.xp) / need
	_xp_l.text = "Poziom %d  •  %s / %s XP" % [int(s.level), IdleDB.fmt(float(s.xp)), IdleDB.fmt(need)]
	_gold_l.text = IdleDB.fmt(float(s.gold))
	_gem_l.text = str(int(s.gems))
	_ash_box.visible = int(s.ash_total) > 0 or gm.prestige.can_rebirth()
	_ash_l.text = str(int(s.ash))


func _refresh_badges() -> void:
	var q := gm.quests.ready_count()
	_set_badge("quests", q)
	var chests := 0
	for r in range(1, 6):
		chests += gm.inventory.count("chest_%d" % r)
	_set_badge("gear", chests)
	var learn := 0
	for id in gm.db.spell_order:
		if gm.spells.can_learn(str(id)):
			learn += 1
	_set_badge("spells", learn)


func _set_badge(id: String, n: int) -> void:
	var b: Label = _badges[id]
	b.visible = n > 0
	b.text = str(n)


func _on_level_up(level: int) -> void:
	gm.audio.play("levelup")
	banner("POZIOM %d!" % level, "Twoja siła rośnie.", Color(0.85, 0.7, 1.0))


func _on_loot(items: Array) -> void:
	var start := combat.enemy_global_pos() if combat else size / 2.0
	var target: Button = _nav_btns["gear"]
	var shown := 0
	for it in items:
		var id := str(it[0])
		var rarity := int(it[2])
		if id == "gold":
			continue
		if rarity >= 4:
			gm.audio.play("rare")
			toast_msg("%s: %s" % [IdleDB.RARITY_NAMES[rarity] if not id.begins_with("frag_") else "Rzadki łup", IdleUI.item_name(gm.db, id)], IdleDB.RARITY_COLORS[rarity])
		elif rarity >= 1:
			gm.audio.play("pickup")
		if shown < 4:
			fly_icon(IdleUI.item_tex(gm.db, id), start + Vector2(shown * 36 - 50, 0), target.get_global_rect().get_center(), IdleDB.RARITY_COLORS[rarity] if rarity > 0 else Color.WHITE)
			shown += 1


# --- Animacje -----------------------------------------------------------------------

func fly_coins(from: Vector2, n: int) -> void:
	if not bool(gm.s.settings.get("effects", true)):
		return
	var target := _gold_l.get_global_rect().get_center()
	for i in mini(n, 10):
		var off := Vector2(randf_range(-50, 50), randf_range(-40, 20))
		fly_icon(Sprites.item_icon("gold", 0), from + off, target, Color.WHITE, 0.45 + i * 0.05, 34)
	get_tree().create_timer(0.5).timeout.connect(func():
		gm.audio.play("coin")
		var tw := _gold_l.create_tween()
		_gold_l.pivot_offset = _gold_l.size / 2.0
		tw.tween_property(_gold_l, "scale", Vector2(1.25, 1.25), 0.08)
		tw.tween_property(_gold_l, "scale", Vector2.ONE, 0.12))


func fly_icon(tex: Texture2D, from: Vector2, to: Vector2, tint := Color.WHITE, dur := 0.7, size_px := 52) -> void:
	var t := IdleUI.icon_rect(tex, size_px)
	t.size = Vector2(size_px, size_px)
	t.modulate = tint.lerp(Color.WHITE, 0.6)
	_overlay.add_child(t)
	t.position = from - t.size / 2.0
	var mid := from.lerp(to, 0.5) + Vector2(randf_range(-60, 60), -120)
	var tw := t.create_tween()
	tw.tween_property(t, "position", mid - t.size / 2.0, dur * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(t, "position", to - t.size / 2.0, dur * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(t, "scale", Vector2(0.5, 0.5), dur * 0.55)
	tw.tween_callback(t.queue_free)


func toast_msg(text: String, color := UiTheme.ACCENT) -> void:
	var c := IdleUI.card(Color(0.04, 0.04, 0.05, 0.92), color)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := IdleUI.label(text, 20, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	_toasts.add_child(c)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)


## Duży napis na środku ekranu walki (boss, awans, nowy region).
func banner(title_text: String, sub: String, color: Color) -> void:
	var box := IdleUI.vbox(0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := IdleUI.title(title_text, 44)
	t.add_theme_color_override("font_color", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := IdleUI.label(sub, 22, Color(0.95, 0.92, 0.85))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	_overlay.add_child(box)
	var cr := combat.get_global_rect() if combat else get_global_rect()
	box.size = Vector2(cr.size.x, 0)
	box.position = Vector2(cr.position.x, cr.position.y + cr.size.y * 0.36)
	box.pivot_offset = Vector2(cr.size.x / 2.0, 30)
	box.scale = Vector2(0.6, 0.6)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.3)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


# --- Okna --------------------------------------------------------------------------

## Okno modalne z treścią; zwraca węzeł (do zamknięcia close_modal).
func modal(title_text: String, content: Control, closable := true) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_modals.append(dim)
	var card := IdleUI.card(Color(0.06, 0.06, 0.08, 0.98), UiTheme.BORDER)
	card.add_theme_stylebox_override("panel", UiTheme.tex_box("panel", 32, 26))
	var w := minf(column.size.x - 30.0, 700.0)
	card.custom_minimum_size = Vector2(w, 0)
	dim.add_child(card)
	var v := IdleUI.vbox(12)
	card.add_child(v)
	var head := IdleUI.hbox(8)
	v.add_child(head)
	var t := IdleUI.title(title_text, 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	if closable:
		var x := IdleUI.button("✕", Vector2(64, 64), 26)
		x.pressed.connect(func(): close_modal(dim))
		head.add_child(x)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	v.add_child(sc)
	card.reset_size()
	var place := func():
		card.reset_size()
		card.position = Vector2((size.x - card.size.x) / 2.0, maxf(20.0, (size.y - card.size.y) / 2.0))
	place.call()
	card.resized.connect(place)
	# Wysokość przewijanej treści = jej naturalna wysokość (po zawinięciu tekstu), maks. 72% ekranu.
	var fit := func():
		if is_instance_valid(sc) and is_instance_valid(content):
			var h := minf(content.get_combined_minimum_size().y, size.y * 0.72)
			if absf(sc.custom_minimum_size.y - h) > 1.0:
				sc.custom_minimum_size.y = h
				place.call_deferred()
	content.minimum_size_changed.connect(fit)
	content.resized.connect(fit)
	fit.call()
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.85, 0.85)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return dim


## Zamyka okno. Obsługa przycisków w oknach tworzona jest przed samym oknem (lambdy GDScript
## przechwytują wartość zmiennej), więc pusty argument = zamknij okno na wierzchu.
func close_modal(m: Control) -> void:
	_modals = _modals.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())
	if m == null or not is_instance_valid(m):
		if _modals.is_empty():
			return
		m = _modals.back()
	_modals.erase(m)
	m.queue_free()


## Okno z tekstem i przyciskami [[tekst, Callable], ...].
func dialog(title_text: String, text: String, buttons: Array) -> Control:
	var v := IdleUI.vbox(14)
	v.add_child(IdleUI.label(text, 22, UiTheme.TEXT, true))
	var row := IdleUI.hbox(10)
	v.add_child(row)
	var m: Control
	for b in buttons:
		var btn := IdleUI.button(str(b[0]), Vector2(0, 84), 24)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = b[1]
		btn.pressed.connect(func():
			close_modal(m)
			if cb.is_valid():
				cb.call())
		row.add_child(btn)
	m = modal(title_text, v, false)
	return m


func confirm(title_text: String, text: String, on_yes: Callable) -> void:
	dialog(title_text, text, [["Anuluj", Callable()], ["Tak", on_yes]])


## „Witaj ponownie!” – animowane liczniki nagród z postępu offline.
func _show_offline(r: Dictionary) -> void:
	var v := IdleUI.vbox(12)
	var away := IdleUI.label("Nie było cię: %s%s" % [IdleDB.fmt_time(float(r.away)), " (liczone maks. %s)" % IdleDB.fmt_time(float(r.get("counted", 0.0))) if bool(r.get("capped", false)) else ""], 20, IdleUI.DIM, true)
	v.add_child(away)
	if r.has("note"):
		v.add_child(IdleUI.label(str(r.note), 22, UiTheme.TEXT, true))
	else:
		var head := IdleUI.label("Podczas twojej nieobecności drużyna pokonała %s przeciwników." % IdleDB.fmt(float(r.kills)), 24, UiTheme.TEXT, true)
		v.add_child(head)
		if int(r.stages) > 0:
			v.add_child(IdleUI.label("Przebyto %d etapów – jesteś na etapie %d." % [int(r.stages), int(gm.s.stage)], 20, IdleUI.GOOD, true))
		v.add_child(IdleUI.label("Zdobyłeś:", 22, UiTheme.ACCENT))
		var rows := [[Sprites.item_icon("gold", 0), float(r.gold), "złota", IdleUI.GOLD_COL], [Sprites.icon("book"), float(r.xp), "doświadczenia", Color(0.8, 0.65, 1.0)],
			[Sprites.item_icon("wood", 2), float(r.materials), "surowców", Color(0.8, 0.95, 0.7)], [Sprites.item_icon("sword", 3), float(r.items.size()), "przedmiotów", Color(0.6, 0.8, 1.0)]]
		if int(r.get("gems", 0)) > 0:
			rows.append([Sprites.icon("gem"), float(r.gems), "żarokryształów", IdleUI.GEM_COL])
		var i := 0
		for row in rows:
			var h := IdleUI.hbox(12)
			h.add_child(IdleUI.icon_rect(row[0], 52))
			var l := IdleUI.label("0 " + str(row[2]), 28, row[3])
			h.add_child(l)
			v.add_child(h)
			var target: float = row[1]
			var suffix: String = row[2]
			var tw := l.create_tween()
			tw.tween_interval(0.25 + i * 0.25)
			tw.tween_method(func(x: float): l.text = "%s %s" % [IdleDB.fmt(x), suffix], 0.0, target, 0.9).set_ease(Tween.EASE_OUT)
			i += 1
	var m: Control
	var ok := IdleUI.button("Odbierz", Vector2(0, 92), 28)
	ok.pressed.connect(func():
		close_modal(m)
		if combat:
			fly_coins(combat.enemy_global_pos(), 10))
	v.add_child(ok)
	m = modal("Witaj ponownie!", v, false)
	Sfx.play("levelup")
