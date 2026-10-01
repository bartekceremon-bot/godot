class_name IdleMain
extends Control
## UIManager wersji idle: menu główne, kamienny pasek górny (ZŁOTO | PD | STREFA), ekran walki
## na całą wysokość, zakładki wysuwane nad walką, dolna nawigacja (INWENTARZ / TWORZENIE / CZARY /
## ZADANIA / MAPA / SKLEP), menu (drużyna, stajnia, ołtarz, postać, ustawienia), okna i animacje łupu.
## Układ pionowy dla telefonu (16:9 … 20:9), na tabletach i w przeglądarce – wyśrodkowana kolumna.

const MAX_COLUMN := 900.0
const NAV := [["gear", "INWENTARZ", "nav_bag"], ["craft", "TWORZENIE", "nav_forge"], ["spells", "CZARY", "nav_book"],
	["quests", "ZADANIA", "nav_scroll"], ["map", "MAPA", "nav_compass"], ["shop", "SKLEP", "nav_gem"]]

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
var _zone_l: Label
var _gem_badge: Control
var _lvl_badge: Control
var _sheet_close: Button
var _banner_box: Control
var music: IdleMusic
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
	# Język trzeba znać już na ekranie tytułowym (przed wczytaniem gry).
	var saved: Dictionary = gm.save.load_game()
	SmartTranslation.apply_language(str(saved.get("settings", {}).get("lang", "auto")))
	theme = IdleUI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.13, 0.05, 0.03))
	g.set_color(1, Color(0.02, 0.015, 0.02))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.2, 1.0)
	gt.width = 128
	gt.height = 128
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	column = Control.new()
	add_child(column)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 20
	add_child(_overlay)
	_toasts = IdleUI.vbox(6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_toasts)
	resized.connect(_layout)
	get_tree().root.size_changed.connect(_layout)
	_layout()
	music = IdleMusic.new()
	add_child(music)
	_show_menu()
	music.play("menu")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--idle-shots="):
			var t = load("res://scripts/idle/ui/idle_autotest.gd").new()
			t.ui = self
			add_child(t)


func _layout() -> void:
	var w := minf(size.x, MAX_COLUMN)
	column.position = Vector2((size.x - w) / 2.0, 0)
	column.size = Vector2(w, size.y)
	_toasts.position = Vector2(column.position.x + 20, size.y * 0.5)
	_toasts.size = Vector2(w - 40, 0)
	if combat:
		_place_sheet.call_deferred()


# --- Menu główne ------------------------------------------------------------------

func _show_menu() -> void:
	var menu := IdleMenuScreen.new()
	_menu_screen = menu
	add_child(menu)
	move_child(menu, 2)
	menu.setup(gm)
	menu.play_pressed.connect(_start_game)
	menu.classic_pressed.connect(open_classic)


func _start_game() -> void:
	if _started:
		return
	_started = true
	gm.start()
	_setup_store()
	music.set_enabled(bool(gm.s.settings.get("music", true)))
	music.play("walka")
	var ev := gm.events.current()
	get_tree().create_timer(2.0).timeout.connect(func(): toast_msg("%s: %s" % [ev.name, ev.text], Color(1.0, 0.75, 0.35)))
	if gm.winter.active():
		get_tree().create_timer(6.0).timeout.connect(func(): banner("GWIAZDKA MROZU", "Zbieraj Płatki Szronu – Zimowy Kram czeka w Menu!", Color(0.6, 0.85, 1.0)))
	if gm.soul_night.active():
		get_tree().create_timer(6.0).timeout.connect(func(): banner("NOC DUSZ", "Zbieraj Płomyki Dusz – Upiorny Kram czeka w Menu!", Color(0.7, 0.55, 1.0)))
	if gm.festival.active():
		get_tree().create_timer(4.0).timeout.connect(func(): banner("FESTYN ŻARU", "Zbieraj lampiony – kram czeka w Menu!", Color(1.0, 0.65, 0.25)))
	gm.enemy_spawned.connect(_update_music)
	gm.changed.connect(func(w): if w in ["tower", "raid", "dungeon", "arena", "dream"]: _update_music())
	if _menu_screen.has_method("leave"):
		_menu_screen.leave()
	else:
		_menu_screen.queue_free()
	_build_game()
	# Codzienna nagroda (od drugiej sesji) – pod oknem „Witaj ponownie!”.
	if gm.daily.available() and int(gm.s.stats.kills) > 0:
		show_daily()
	if not gm.offline_report.is_empty():
		_show_offline(gm.offline_report)
	elif int(gm.s.stats.kills) == 0:
		dialog("Witaj, Popielniku!", "Uderzaj przyciskiem ATAK! albo dotykając przeciwnika (przytrzymaj, by bić seriami). Za złoto wynajmuj najemników (DRUŻYNA pod portretem) – walczą za ciebie także wtedy, gdy nie grasz. Ulepszaj ekwipunek, ucz się czarów u kapłanów i odblokowuj kolejne krainy.", [["Do boju!", Callable()]])


# --- Sklep premium i reklamy --------------------------------------------------------------

## Płatności (Google Play albo tryb testowy poza Androidem) i reklamy z nagrodą.
func _setup_store() -> void:
	var android := OS.get_name() == "Android"
	gm.billing.purchase_ok.connect(_on_purchase_ok)
	gm.billing.purchase_failed.connect(func(_pid, reason): toast_msg(reason, IdleUI.BAD))
	gm.billing.setup(gm.premium.catalog(), not android)
	gm.ads.setup(self, not android, str(ProjectSettings.get_setting("popielne/admob_rewarded_id", "")))


func buy_product(pid: String) -> void:
	if not gm.premium.can_buy(pid):
		toast_msg("Ten produkt już posiadasz.", IdleUI.BAD)
		return
	if gm.billing.is_sandbox():
		var p := gm.premium.product(pid)
		confirm("Tryb testowy", "Kupić „%s” (%s)? W tej wersji bez płatności – w aplikacji z Google Play zapłacisz przez Google Play." % [p.name, gm.billing.price_of(pid, str(p.price_pln))], func(): gm.billing.buy(pid))
	else:
		gm.billing.buy(pid)


func _on_purchase_ok(pid: String, token: String) -> void:
	var got := gm.premium.grant(pid, token)
	gm.billing.finish(pid, token)
	if got.is_empty() and gm.premium.product(pid).get("kind", "") in ["purse", "season"]:
		got = [["gems", 0, 0]]
	if got.is_empty():
		return
	gm.audio.play("levelup")
	var p := gm.premium.product(pid)
	var lines: Array = []
	for it in got:
		if int(it[1]) > 0:
			lines.append("+%s %s" % [IdleDB.fmt(float(it[1])), IdleUI.item_name(gm.db, str(it[0]))])
	banner("DZIĘKUJEMY!", str(p.get("name", "")), Color(1.0, 0.8, 0.35))
	if not lines.is_empty():
		dialog("Zakup udany", "\n".join(PackedStringArray(lines)), [["Super!", Callable()]])
	if combat:
		fly_coins(combat.enemy_global_pos(), 10)
	for k in _panels:
		_panels[k].request_refresh()


## Nagroda za reklamę (dobrowolną): z Mieszkiem Kupca – od razu, bez reklamy.
func ad_reward(place: String, done := Callable()) -> void:
	if not gm.premium.ad_available(place):
		toast_msg("Nagroda chwilowo niedostępna.", IdleUI.BAD)
		return
	var give := func():
		var txt := gm.premium.ad_reward(place)
		if txt != "":
			gm.audio.play("rare")
			toast_msg(txt, IdleUI.GOLD_COL)
		if done.is_valid():
			done.call()
	if gm.premium.has_purse():
		give.call()
	elif not gm.ads.show_rewarded(give):
		toast_msg("Reklama jeszcze się ładuje – spróbuj za chwilę.", IdleUI.DIM)


## Okno szans (ujawnianie prawdopodobieństw losowych nagród).
func show_odds(title_text: String, rows: Array) -> void:
	var v := IdleUI.vbox(6)
	v.add_child(IdleUI.label("Zawartość i szanse:", 20, UiTheme.ACCENT))
	for r in rows:
		var h := IdleUI.hbox(8)
		var a := IdleUI.label(str(r[0]), 17, UiTheme.TEXT, true)
		h.add_child(a)
		h.add_child(IdleUI.label(str(r[1]), 18, IdleUI.GOLD_COL))
		v.add_child(h)
	modal("Szanse – " + title_text, v)


## Muzyka bossa przy bossach, elitach i w Wieży Popiołu, w pozostałych walkach – temat walki.
func _update_music() -> void:
	var e := gm.enemy.cur
	music.play("boss" if gm.challenge() != null or (not e.is_empty() and int(e.kind) > 0) else "walka")


## Przejście do klasycznej wersji MMO (poziomy ekran, logowanie na serwer).
func open_classic() -> void:
	if music:
		music.set_enabled(false)
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
	_root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(_root_box)
	var top := _build_topbar()
	combat = CombatScreen.new()
	combat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(top)
	_root_box.add_child(combat)
	# Pasek górny rysowany nad sceną (wiszące plakietki XP / klejnoty / region).
	top.z_index = 2
	combat.setup(self)
	combat.open_tab.connect(show_tab)
	_root_box.add_child(_build_nav())
	# Wysuwany panel zakładek nad ekranem walki.
	_panel_host = PanelContainer.new()
	_panel_host.add_theme_stylebox_override("panel", IdleUI.ash_box("sheet", 30, 18))
	_panel_host.visible = false
	_panel_host.z_index = 1
	column.add_child(_panel_host)
	_sheet_close = IdleUI.ash_button("slot", 18)
	_sheet_close.text = "✕"
	_sheet_close.add_theme_font_size_override("font_size", 26)
	_sheet_close.custom_minimum_size = Vector2(60, 60)
	_sheet_close.pressed.connect(func():
		Sfx.play("click")
		show_tab("fight"))
	_sheet_close.z_index = 1
	column.add_child(_sheet_close)
	combat.resized.connect(_place_sheet)
	gm.changed.connect(_on_changed)
	gm.level_up.connect(_on_level_up)
	gm.loot_gained.connect(_on_loot)
	gm.toast.connect(toast_msg)
	gm.changed.connect(func(w): if w == "stage": _maybe_ask_rating())
	gm.unlocked.connect(func(t, x): banner("NOWOŚĆ: " + SmartTranslation.t(t).to_upper(), x, IdleUI.GOLD_COL))
	_refresh_top()
	show_tab("fight")


## Kamienny pasek: ZŁOTO | PD (pasek XP) | STREFA – jak w projekcie ekranu.
func _build_topbar() -> Control:
	var p := PanelContainer.new()
	var sb := IdleUI.ash_box("stone_panel", 26, 0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	sb.expand_margin_left = 4
	sb.expand_margin_right = 4
	sb.expand_margin_top = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := IdleUI.hbox(0)
	p.add_child(h)
	var cap_col := Color(0.72, 0.7, 0.68)
	var val_col := Color(1.0, 0.7, 0.28)
	# ZŁOTO
	var gold := IdleUI.hbox(6)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold.size_flags_stretch_ratio = 1.0
	h.add_child(gold)
	var gv := IdleUI.vbox(0)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gold.add_child(gv)
	var gc := IdleUI.hud_label("ZŁOTO:", 19, cap_col, 4)
	gc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gc)
	_gold_l = IdleUI.hud_label("0", 34, val_col, 6)
	_gold_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(_gold_l)
	gold.add_child(IdleUI.icon_rect(IdleUI.ash_tex("ico_gold"), 64))
	h.add_child(_divider())
	# PD (doświadczenie)
	var xp := IdleUI.vbox(4)
	xp.alignment = BoxContainer.ALIGNMENT_CENTER
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp.size_flags_stretch_ratio = 1.25
	h.add_child(xp)
	var xc := IdleUI.hud_label("PD:", 19, cap_col, 4)
	xc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp.add_child(xc)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.max_value = 1.0
	_xp_bar.step = 0.0
	_xp_bar.custom_minimum_size = Vector2(0, 38)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.5, 0.26, 0.85)
	fill.border_color = Color(0.75, 0.55, 1.0)
	fill.border_width_top = 3
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.05, 0.1)
	back.border_color = Color(0.42, 0.4, 0.45)
	back.set_border_width_all(2)
	back.set_corner_radius_all(5)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	_xp_bar.add_theme_stylebox_override("background", back)
	_xp_l = IdleUI.hud_label("", 18, Color.WHITE, 5)
	_xp_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar.add_child(_xp_l)
	xp.add_child(_xp_bar)
	h.add_child(_divider())
	# STREFA (etap) – dotknięcie otwiera mapę.
	var zone := IdleUI.hbox(6)
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(zone)
	var zv := IdleUI.vbox(0)
	zv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zv.alignment = BoxContainer.ALIGNMENT_CENTER
	zone.add_child(zv)
	var zc := IdleUI.hud_label("STREFA", 19, cap_col, 4)
	zc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(zc)
	_zone_l = IdleUI.hud_label("1", 34, val_col, 6)
	_zone_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(_zone_l)
	zone.add_child(IdleUI.icon_rect(IdleUI.ash_tex("ico_map"), 64))
	var zb := Button.new()
	zb.flat = true
	zb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zb.pressed.connect(func():
		Sfx.play("click")
		show_tab("map"))
	zone.add_child(zb)
	# Wiszące plakietki: żarokryształy (z lewej), poziom (środek), popiół (z prawej).
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 112)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(p)
	_gem_badge = _hang_badge(wrap, Sprites.icon("gem"), IdleUI.GEM_COL)
	_gem_l = _gem_badge.get_meta("label")
	_lvl_badge = _hang_badge(wrap, null, Color(0.78, 0.6, 1.0))
	_lvl_l = _lvl_badge.get_meta("label")
	_ash_box = _hang_badge(wrap, Sprites.icon("ash"), IdleUI.ASH_COL)
	_ash_l = _ash_box.get_meta("label")
	var place := func():
		var w := wrap.size.x
		for pair in [[_gem_badge, 0.17], [_lvl_badge, 0.5], [_ash_box, 0.83]]:
			var b: Control = pair[0]
			b.reset_size()
			b.position = Vector2(w * float(pair[1]) - b.size.x / 2.0, wrap.size.y - 16)
	wrap.resized.connect(place)
	_gem_l.resized.connect(place)
	_lvl_l.resized.connect(place)
	return wrap


func _divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(0.3, 0.29, 0.3, 0.8)
	d.custom_minimum_size = Vector2(2, 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(d)
	return m


## Sześciokątna plakietka wisząca pod paskiem (klejnoty, poziom, popiół).
func _hang_badge(parent: Control, tex: Texture2D, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := IdleUI.ash_box("badge", 22, 0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(96, 38)
	var h := IdleUI.hbox(4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	if tex:
		h.add_child(IdleUI.icon_rect(tex, 26))
	var l := IdleUI.hud_label("", 19, col, 4)
	h.add_child(l)
	p.set_meta("label", l)
	parent.add_child(p)
	p.top_level = false
	return p


## Dolna nawigacja: kamienne kafle z malowanymi ikonami.
func _build_nav() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.028, 0.03)
	sb.border_color = Color(0.22, 0.2, 0.2)
	sb.border_width_top = 2
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := IdleUI.hbox(6)
	p.add_child(h)
	for n in NAV:
		var b := IdleUI.ash_button("stone_panel", 26, "tile_on")
		b.custom_minimum_size = Vector2(0, 124)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.clip_contents = false
		var id := str(n[0])
		var icon := IdleUI.icon_rect(IdleUI.ash_tex(str(n[2])), 80)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		icon.position.y = 6
		b.add_child(icon)
		var l := IdleUI.hud_label(str(n[1]), 16, Color(0.96, 0.94, 0.9), 5)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -30
		l.offset_bottom = -6
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		b.add_child(l)
		b.pressed.connect(func():
			Sfx.play("click")
			show_tab("fight" if _current == id else id))
		h.add_child(b)
		_nav_btns[id] = b
		_badges[id] = _dot(b)
	return p


## Pomarańczowa kropka powiadomienia (z liczbą) w rogu przycisku.
func _dot(b: Control) -> Label:
	var badge := IdleUI.hud_label("", 14, Color.WHITE, 3)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(1.0, 0.45, 0.1)
	bs.border_color = Color(1.0, 0.8, 0.5)
	bs.set_border_width_all(1)
	bs.shadow_color = Color(1.0, 0.4, 0.05, 0.8)
	bs.shadow_size = 6
	bs.set_corner_radius_all(12)
	bs.content_margin_left = 6
	bs.content_margin_right = 6
	badge.add_theme_stylebox_override("normal", bs)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(22, 22)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-26, 4)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.visible = false
	b.add_child(badge)
	return badge


## Panel zakładki: od dołu nagłówka wroga do dolnej nawigacji.
func _place_sheet() -> void:
	if not combat or not _panel_host:
		return
	var r := combat.get_rect()
	var top := r.position.y + minf(combat.sheet_top(), r.size.y * 0.3)
	_panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_host.offset_left = r.position.x + 4
	_panel_host.offset_right = r.end.x - column.size.x - 4
	_panel_host.offset_top = top
	_panel_host.offset_bottom = r.end.y - column.size.y + 4
	_sheet_close.position = Vector2(r.end.x - 70, top - 26)


## Zakładki: „fight” zamyka panel (sam ekran walki), pozostałe wysuwają się nad walkę.
func show_tab(id: String) -> void:
	if id == "fight":
		_current = "fight"
		_close_sheet()
		for k in _nav_btns:
			_nav_btns[k].set_pressed_no_signal(false)
		return
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
	var was_open := _panel_host.visible
	_current = id
	panel.refresh()
	for k in _nav_btns:
		_nav_btns[k].set_pressed_no_signal(k == id)
	_place_sheet()
	_panel_host.visible = true
	_sheet_close.visible = true
	if not was_open:
		# Wysunięcie z dołu (przesunięcie rysowania – bez ruszania układu).
		_panel_host.modulate.a = 0.0
		_panel_host.scale = Vector2(1.0, 0.94)
		_panel_host.pivot_offset = Vector2(_panel_host.size.x / 2.0, _panel_host.size.y)
		var tw := _panel_host.create_tween().set_parallel(true)
		tw.tween_property(_panel_host, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel_host, "modulate:a", 1.0, 0.15)


func _close_sheet() -> void:
	if _panel_host:
		_panel_host.visible = false
		_sheet_close.visible = false


func _make_panel(id: String) -> IdlePanel:
	match id:
		"heroes":
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
		"achievements":
			return AchievementsPanel.new()
		"talents":
			return TalentsPanel.new()
		"expeditions":
			return ExpeditionsPanel.new()
		"bestiary":
			return BestiaryPanel.new()
		"tower":
			return TowerPanel.new()
		"runes":
			return RunesPanel.new()
		"pets":
			return PetsPanel.new()
		"chronicle":
			return ChroniclePanel.new()
		"phoenix":
			return PhoenixPanel.new()
		"skins":
			return SkinsPanel.new()
		"season":
			return SeasonPanel.new()
		"raid":
			return RaidPanel.new()
		"dungeon":
			return DungeonPanel.new()
		"arena":
			return ArenaPanel.new()
		"relics":
			return RelicsPanel.new()
		"wheel":
			return WheelPanel.new()
		"class":
			return ClassPanel.new()
		"festival":
			return FestivalPanel.new()
		"dream":
			return DreamPanel.new()
		"weekly":
			return WeeklyPanel.new()
		"mail":
			return MailPanel.new()
		"records":
			return RecordsPanel.new()
		"garden":
			return GardenPanel.new()
		"mastery":
			return MasteryPanel.new()
		"dragon":
			return DragonPanel.new()
		"stronghold":
			return StrongholdPanel.new()
		"soul_night":
			return SoulNightPanel.new()
		"auto":
			return AutoPanel.new()
		"titles":
			return TitlesPanel.new()
		"winter":
			return WinterPanel.new()
	return null


func _open_menu() -> void:
	# Kafle menu w sekcjach: [nazwa, ikona, zakładka, plakietka, etap odblokowania (0 – zawsze)].
	var sections := [
		["Codziennie", [["Codzienna nagroda", Sprites.icon("chest"), "daily", 1 if gm.daily.available() else 0, 0],
			["Poczta", Sprites.icon("book"), "mail", gm.mail.unread(), 0],
			["Koło Żaru", IdleUI.ash_tex("nav_gem"), "wheel", gm.wheel.free_spins(), 0],
			["Wyzwania tygodnia", Sprites.icon("quest"), "weekly", gm.weekly.ready_count(), 0],
			["Karnet Popiołu", Sprites.icon("book"), "season", gm.season.ready_count(), 0],
			["Festyn Żaru", load("res://assets/ui/modes/relic_lantern.png"), "festival", 1 if gm.festival.active() else 0, 0],
			["Noc Dusz", load("res://assets/ui/modes/soul_flame.png"), "soul_night", (1 if gm.soul_night.milestone_ready() else 0) + (1 if gm.soul_night.active() else 0), 0],
			["Gwiazdka Mrozu", load("res://assets/ui/modes/snowflake.png"), "winter", (1 if gm.winter.milestone_ready() else 0) + (1 if gm.winter.active() else 0), 0]]],
		["Walki i wyzwania", [["Lochy Żaru", load("res://assets/ui/modes/dungeon.png"), "dungeon", gm.dungeon.total_keys() if gm.dungeon.unlocked() else 0, 15],
			["Arena", load("res://assets/ui/modes/arena.png"), "arena", (gm.arena.tickets() + (1 if gm.arena.weekly_ready() else 0)) if gm.arena.unlocked() else 0, 25],
			["Wieża Popiołu", IdleUI.ash_tex("ico_skull"), "tower", gm.tower.attempts(), 0],
			["Boss tygodnia", Sprites.icon("attack"), "raid", gm.raid.attempts() + gm.raid.ready_tiers(), 0],
			["Sen Popielnika", load("res://assets/ui/runes/mind.png"), "dream", gm.dream.free_runs() if gm.dream.unlocked() else 0, DreamManager.UNLOCK_STAGE],
			["Wyprawy", IdleUI.ash_tex("nav_compass"), "expeditions", gm.expeditions.ready_count(), 0]]],
		["Twierdza i ogród", [["Twierdza Popielników", load("res://assets/ui/modes/stronghold.png"), "stronghold", gm.stronghold.ready_badge(), StrongholdManager.UNLOCK_STAGE],
			["Ogród Alchemika", load("res://assets/ui/modes/garden.png"), "garden", gm.garden.ready_count() + gm.garden.empty_count() if gm.garden.unlocked() else 0, GardenManager.UNLOCK_STAGE]]],
		["Rozwój bohatera", [["Klasa bohatera", load("res://assets/ui/runes/fire.png"), "class", 1 if gm.hero.unlocked() and gm.hero.current() == "" else 0, ClassManager.UNLOCK_STAGE],
			["Talenty", Sprites.icon("attack"), "talents", maxi(0, gm.talents.free_points()), 0],
			["Mistrzostwo broni", IdleUI.item_tex(gm.db, "sword_t4"), "mastery", 0, 0],
			["Relikwie", load("res://assets/ui/modes/relics.png"), "relics", int(gm.relics.shards() / RelicManager.PULL_COST), 0],
			["Runy", load("res://assets/ui/runes/fire.png"), "runes", 0, 0],
			["Chowańce", load("res://assets/ui/runes/egg.png"), "pets", gm.inventory.count("pet_egg"), 0],
			["Smoczy towarzysz", load("res://assets/ui/modes/dragon.png" if gm.dragon.alive() else "res://assets/ui/modes/dragon_egg.png"), "dragon", 1 if gm.dragon.unlocked() and gm.dragon.state() in ["none", "ready"] else 0, DragonManager.UNLOCK_STAGE],
			["Stajnia", Sprites.icon("mount"), "mounts", 0, 0],
			["Drużyna", Sprites.icon("character"), "heroes", 0, 0],
			["Ołtarz Popiołu", Sprites.icon("prestige"), "prestige", 1 if gm.prestige.can_rebirth() else 0, 0],
			["Feniks", Sprites.icon("prestige"), "phoenix", 1 if gm.phoenix.can_awaken() else 0, 0]]],
		["Kolekcje i inne", [["Osiągnięcia", Sprites.icon("quest"), "achievements", gm.achievements.ready_count(), 0],
			["Rekordy", IdleUI.ash_tex("badge"), "records", 0, 0],
			["Tytuły", load("res://assets/ui/modes/badge.png"), "titles", 0, 0],
			["Bestiariusz", IdleUI.ash_tex("nav_book"), "bestiary", 0, 0],
			["Opowieść", Sprites.icon("book"), "chronicle", 0, 0],
			["Garderoba", IdleUI.ash_tex("portrait"), "skins", 0, 0],
			["Postać", Sprites.icon("character"), "stats", 0, 0],
			["Kwatermistrz", Sprites.icon("people"), "auto", 0, 0],
			["Ustawienia", Sprites.icon("menu"), "settings", 0, 0]]],
	]
	var best := int(gm.achievements.value("best_stage"))
	var box := IdleUI.vbox(6)
	var m: Control
	for sec in sections:
		box.add_child(IdleUI.label(str(sec[0]), 21, UiTheme.ACCENT))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box.add_child(grid)
		for it in sec[1]:
			var locked := int(it[4]) > 0 and best < int(it[4])
			var b := IdleUI.ash_button("stone_panel", 26, "tile_on")
			b.custom_minimum_size = Vector2(0, 150)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ic := IdleUI.icon_rect(it[1], 76)
			ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			ic.position.y = 14
			if locked:
				ic.modulate = Color(0.3, 0.28, 0.3, 0.9)
			b.add_child(ic)
			var l := IdleUI.hud_label(str(it[0]) if not locked else "🔒 etap %d" % int(it[4]), 17, Color(0.96, 0.94, 0.9) if not locked else IdleUI.DIM, 5)
			l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			l.offset_top = -48
			l.offset_bottom = -8
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_child(l)
			var dot := _dot(b)
			dot.visible = int(it[3]) > 0 and not locked
			dot.text = str(it[3])
			b.text = ""
			b.set_meta("label", str(it[0]))
			var tab := str(it[2])
			b.pressed.connect(func():
				close_modal(m)
				if tab == "daily":
					show_daily()
				else:
					show_tab(tab))
			grid.add_child(b)
	m = modal("Menu", box)


## Jednorazowa prośba o ocenę w Google Play (po etapie 30 i 2 h gry; „Później” – za 30 etapów, maks. 2 razy).
func _maybe_ask_rating() -> void:
	var s := gm.s
	if not s.has("rate"):
		s["rate"] = {"done": false, "next": 30, "asks": 0}
	var r: Dictionary = s.rate
	if bool(r.done) or int(r.asks) >= 2 or int(s.max_stage) < int(r.next) or float(s.play_time) < 7200.0 or _modals_open() > 0 or gm.challenge() != null:
		return
	r.asks = int(r.asks) + 1
	r.next = int(s.max_stage) + 30
	dialog("Podoba Ci się gra?", "Jeśli Popielne Królestwa sprawiają Ci frajdę, zostaw ocenę w Google Play – to bardzo pomaga małej grze dotrzeć do nowych graczy. Dziękujemy!", [
		["Oceń ★★★★★", func():
			r.done = true
			OS.shell_open("market://details?id=pl.popielnekrolestwa.gra" if OS.get_name() == "Android" else RecordsPanel.STORE_URL)],
		["Może później", func(): pass]])


func _modals_open() -> int:
	_modals = _modals.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())
	return _modals.size()


## Scena fabuły: kolejne kwestie postaci (imię, tekst pisany na bieżąco), „Dalej”.
func show_story(scene: String) -> void:
	var lines := gm.story.lines(scene)
	if lines.is_empty():
		return
	var v := IdleUI.vbox(12)
	var head := IdleUI.hbox(14)
	v.add_child(head)
	var port := Panel.new()
	port.add_theme_stylebox_override("panel", IdleUI.ash_box("slot", 18))
	port.custom_minimum_size = Vector2(96, 96)
	var face := IdleUI.icon_rect(Sprites.icon("character"), 70)
	face.position = Vector2(13, 13)
	port.add_child(face)
	head.add_child(port)
	var who := IdleUI.title("", 26)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(who)
	var txt := IdleUI.label("", 23, Color(0.95, 0.92, 0.86), true)
	txt.custom_minimum_size = Vector2(0, 170)
	v.add_child(txt)
	var nxt := IdleUI.button("Dalej", Vector2(0, 84), 26)
	v.add_child(nxt)
	var idx := [0]
	var m: Control
	var show_line := func():
		var ln: Array = lines[idx[0]]
		who.text = str(ln[0])
		txt.text = str(ln[1])
		txt.visible_ratio = 0.0
		txt.create_tween().tween_property(txt, "visible_ratio", 1.0, clampf(str(ln[1]).length() / 70.0, 0.4, 2.2))
		nxt.text = "Dalej" if idx[0] < lines.size() - 1 else "Do boju!"
	nxt.pressed.connect(func():
		Sfx.play("click")
		if txt.visible_ratio < 1.0:
			txt.visible_ratio = 1.0
			return
		idx[0] += 1
		if idx[0] >= lines.size():
			close_modal(m)
		else:
			show_line.call())
	m = modal(gm.story.title(scene), v, false)
	show_line.call()


## Kafel menu po nazwie (testy automatyczne naciskają kafle jak przyciski z tekstem).
func menu_tile(name: String) -> Button:
	for c in _modals:
		if is_instance_valid(c):
			var r := _find_tile(c, name)
			if r:
				return r
	return null


func _find_tile(n: Node, name: String) -> Button:
	for c in n.get_children():
		if c is Button and str(c.get_meta("label", "")) == name:
			return c
		var r := _find_tile(c, name)
		if r:
			return r
	return null


## Codzienna nagroda: 7 kamiennych kafli serii, dzisiejszy świeci; przycisk odbioru.
func show_daily() -> void:
	var v := IdleUI.vbox(12)
	var avail := gm.daily.available()
	var today := gm.daily.current_day()
	v.add_child(IdleUI.label("Wracaj codziennie – seria 7 dni, siódmego dnia epicka skrzynia. Opuszczony dzień zaczyna serię od nowa.", 19, UiTheme.TEXT, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in DailyManager.REWARDS.size():
		var r: Dictionary = DailyManager.REWARDS[i]
		var p := PanelContainer.new()
		var cur := i == today
		p.add_theme_stylebox_override("panel", IdleUI.ash_box("tile_on" if cur and avail else "slot", 26 if cur and avail else 18, 8))
		p.custom_minimum_size = Vector2(0, 150)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i < today or (cur and not avail):
			p.modulate = Color(0.55, 0.55, 0.55)
		var b := IdleUI.vbox(2)
		b.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(b)
		var d := IdleUI.hud_label("DZIEŃ %d" % (i + 1), 15, Color(1.0, 0.75, 0.35) if cur else Color(0.85, 0.82, 0.78), 4)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(d)
		var main_id := "gold"
		var txt := ""
		if r.has("items"):
			main_id = str(r.items[0][0])
			txt = "%d× %s" % [int(r.items[0][1]), IdleUI.item_name(gm.db, main_id)] if not main_id.begins_with("chest_") else IdleUI.item_name(gm.db, main_id)
		elif r.has("gems"):
			main_id = "gems"
			txt = "%d żarokr." % int(r.gems)
		if r.has("gold_kills"):
			txt = ("%s zł" % IdleDB.fmt(gm.daily.gold_of(r))) + ("" if txt == "" else "\n+ " + txt)
		elif r.has("gems") and main_id != "gems":
			txt += "\n+ %d żarokr." % int(r.gems)
		var ic := IdleUI.icon_rect(IdleUI.item_tex(gm.db, main_id), 48)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_child(ic)
		var l := IdleUI.label(txt, 13, Color(0.92, 0.9, 0.84), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(l)
		if i < today or (cur and not avail):
			var ok := IdleUI.hud_label("✔", 22, IdleUI.GOOD, 4)
			ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_child(ok)
		grid.add_child(p)
	var m: Control
	var btn := IdleUI.button("Odbierz nagrodę dnia %d" % (today + 1) if avail else "Odebrano – wróć jutro", Vector2(0, 88), 26)
	btn.disabled = not avail
	btn.pressed.connect(func():
		var got := gm.daily.claim()
		close_modal(m)
		if not got.is_empty():
			gm.audio.play("levelup")
			for it in got:
				toast_msg("+%s %s" % [IdleDB.fmt(float(it[1])), IdleUI.item_name(gm.db, str(it[0]))], IdleUI.GOLD_COL)
			if combat:
				fly_coins(combat.enemy_global_pos(), 8))
	v.add_child(btn)
	m = modal("Codzienna nagroda", v)


func _process(delta: float) -> void:
	if not gm.running:
		return
	_ui_t += delta
	if _ui_t >= 0.25:
		_ui_t = 0.0
		_refresh_top()
		if _panels.has(_current) and _panel_host.visible:
			_panels[_current].tick_ui()
		_refresh_badges()
		# Fabuła: scena czeka, aż nie ma okien ani wysuniętego panelu.
		if gm.story.has_pending() and _modals_open() == 0 and not _panel_host.visible:
			show_story(gm.story.pop())


func _on_changed(what: String) -> void:
	if what in ["gold", "xp", "level", "stage", "all"]:
		_refresh_top()
	if _panels.has(_current) and _panel_host.visible:
		_panels[_current].on_changed(what)
	if what == "all":
		for k in _panels:
			_panels[k].refresh()


func _refresh_top() -> void:
	var s := gm.s
	var need := ProgressionManager.xp_next(int(s.level))
	var frac := clampf(float(s.xp) / need, 0.0, 1.0)
	_xp_bar.value = frac
	_xp_l.text = "%s / %s (%d%%)" % [IdleDB.fmt(float(s.xp)), IdleDB.fmt(need), int(frac * 100.0)]
	_lvl_l.text = "POZIOM %d" % int(s.level)
	_gold_l.text = IdleDB.fmt(float(s.gold))
	_gem_l.text = str(int(s.gems))
	_zone_l.text = str(int(s.stage))
	_ash_box.visible = int(s.ash_total) > 0 or gm.prestige.can_rebirth()
	_ash_l.text = str(int(s.ash))


func _refresh_badges() -> void:
	_set_badge("quests", gm.quests.ready_count())
	var chests := 0
	for r in range(1, 6):
		chests += gm.inventory.count("chest_%d" % r)
	_set_badge("gear", chests)
	var learn := 0
	for id in gm.db.spell_order:
		if gm.spells.can_learn(str(id)):
			learn += 1
	_set_badge("spells", learn)
	if combat:
		combat.refresh_badges()


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
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.025, 0.88)
	sb.border_color = color
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	c.add_theme_stylebox_override("panel", sb)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := IdleUI.hud_label(text, 19, color, 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(560.0, column.size.x - 60.0), 0)
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
	# Nowy napis zastępuje poprzedni (szybkie piętra wieży, bossy jeden po drugim).
	if is_instance_valid(_banner_box):
		_banner_box.queue_free()
	var box := IdleUI.vbox(0)
	_banner_box = box
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
	dim.z_index = 10
	add_child(dim)
	_modals.append(dim)
	var card := IdleUI.card(Color(0.06, 0.06, 0.08, 0.98), UiTheme.BORDER)
	card.add_theme_stylebox_override("panel", IdleUI.ash_box("sheet", 30, 24))
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
		var x := IdleUI.ash_button("slot", 18)
		x.text = "✕"
		x.custom_minimum_size = Vector2(64, 64)
		x.add_theme_font_size_override("font_size", 26)
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


## Gotowe do odebrania / użycia: [ikona, tekst, zakładka].
func waiting_list() -> Array:
	var out: Array = []
	var md := "res://assets/ui/modes/"
	if gm.garden.ready_count() > 0:
		out.append([load(md + "garden.png"), tr("Ogród: gotowe grządki: %d") % gm.garden.ready_count(), "garden"])
	if gm.stronghold.unlocked():
		gm.stronghold.check_done()
		if gm.stronghold.free_builders() > 0:
			out.append([load(md + "stronghold.png"), tr("Twierdza: wolni budowniczowie: %d") % gm.stronghold.free_builders(), "stronghold"])
	if gm.dragon.unlocked() and gm.dragon.state() in ["none", "ready"]:
		out.append([load(md + "dragon_egg.png"), tr("Smocze jajo czeka!"), "dragon"])
	if gm.expeditions.ready_count() > 0:
		out.append([IdleUI.ash_tex("nav_compass"), tr("Wyprawy wróciły: %d") % gm.expeditions.ready_count(), "expeditions"])
	if gm.wheel.free_spins() > 0:
		out.append([IdleUI.ash_tex("nav_gem"), tr("Darmowy obrót Koła Żaru"), "wheel"])
	if gm.mail.unread() > 0:
		out.append([Sprites.icon("book"), tr("Poczta: %d") % gm.mail.unread(), "mail"])
	return out


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
	# Co czeka na gracza: skróty do gotowych systemów (zamykają okno i otwierają zakładkę).
	var waiting := waiting_list()
	if not waiting.is_empty():
		v.add_child(IdleUI.label("Czeka na Ciebie:", 22, UiTheme.ACCENT))
		var wg := GridContainer.new()
		wg.columns = 2
		wg.add_theme_constant_override("h_separation", 8)
		wg.add_theme_constant_override("v_separation", 6)
		v.add_child(wg)
		for w in waiting:
			var wb := IdleUI.button(str(w[1]), Vector2(0, 58), 17)
			wb.icon = w[0]
			wb.add_theme_constant_override("icon_max_width", 36)
			wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var tab := str(w[2])
			wb.pressed.connect(func():
				close_modal(m)
				show_tab(tab))
			wg.add_child(wb)
	var row := IdleUI.hbox(10)
	v.add_child(row)
	var ok := IdleUI.button("Odbierz", Vector2(0, 92), 28)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		close_modal(m)
		if combat:
			fly_coins(combat.enemy_global_pos(), 10))
	row.add_child(ok)
	# Podwojenie (reklama z nagrodą albo Mieszek Kupca) – tylko gdy było co podwajać.
	if float(r.get("gold", 0.0)) > 0.0 and (gm.ads.available() or gm.premium.has_purse()):
		var dbl := IdleUI.button("×2 " + ("(Mieszek)" if gm.premium.has_purse() else "▶ reklama"), Vector2(0, 92), 24)
		dbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbl.pressed.connect(func():
			ad_reward("offline_double", func():
				gm.add_gold(float(r.gold))
				gm.progression.add_xp(float(r.get("xp", 0.0)))
				close_modal(m)
				banner("PODWOJONO!", "+%s złota" % IdleDB.fmt(float(r.gold)), IdleUI.GOLD_COL)))
		row.add_child(dbl)
	m = modal("Witaj ponownie!", v, false)
	Sfx.play("levelup")
