extends CanvasLayer
## Interfejs w grze: paski HP/MP/EXP, joystick, pasek szybkiego dostępu (atak, czar,
## mikstury), czat, przyciski okien (plecak, postać, online, menu), ekran śmierci.

const Joystick := preload("res://scripts/ui/virtual_joystick.gd")
const InventoryPanel := preload("res://scripts/ui/inventory_panel.gd")
const CharacterPanel := preload("res://scripts/ui/character_panel.gd")
const NpcDialog := preload("res://scripts/ui/npc_dialog.gd")
const ShopPanel := preload("res://scripts/ui/shop_panel.gd")
const DepotPanel := preload("res://scripts/ui/depot_panel.gd")
const MarketPanel := preload("res://scripts/ui/market_panel.gd")
const CraftPanel := preload("res://scripts/ui/craft_panel.gd")
const SpecsPanel := preload("res://scripts/ui/specs_panel.gd")
const AmountDialog := preload("res://scripts/ui/amount_dialog.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")

const CHAT_LINES := 60

## Ustawiane przez game.gd przed dodaniem do drzewa.
var game: Node = null

var _root: Control
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _exp_bar: ProgressBar
var _hp_label: Label
var _mp_label: Label
var _lvl_label: Label
var _joystick: Joystick
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_lines: PackedStringArray = []
var _inventory: InventoryPanel
var _character: CharacterPanel
var _online: PanelContainer
var _online_list: Label
var _menu: PanelContainer
var _death: ColorRect
var _death_label: Label
var _perf: Label
var _spell_btn: Button
var _cooldowns: Dictionary = {}  # id -> [pozostało, całość]
var _ability_btns: Array[Button] = []
var _spell_slots: Array[Button] = []
var spellbook: SpellbookPanel
var quests: QuestPanel
var _tracker: PanelContainer
var _tracker_box: VBoxContainer
var _zone_label: Label
var _zone_toast: Label
var _hp_potion_btn: Button
var _mp_potion_btn: Button

var _bag: Array = []
var _eq: Dictionary = {}
var _specs: Array = []

var npc_dialog: NpcDialog
var shop: ShopPanel
var depot: DepotPanel
var market: MarketPanel
var craft: CraftPanel
var specs: SpecsPanel
var amount: AmountDialog
var minimap: Minimap
var world_map: WorldMapPanel
var _mount_btn: Button
var _time_label: Label
var _portrait_icon: TextureRect
var _lvl_badge: Label
var _region_title: Label
var _region_sub: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_build_status()
	_build_tracker()
	_build_region_banner()
	_build_top_buttons()
	_build_joystick()
	_build_actions()
	_build_chat()
	_build_windows()


# ============================================================================
# Budowa interfejsu
# ============================================================================

func _build_status() -> void:
	# Portret w złotej obręczy z odznaką poziomu + nazwa i paski (jak w klasycznych MMO).
	var row := HBoxContainer.new()
	row.position = Vector2(10, 10)
	row.add_theme_constant_override("separation", -14)
	_root.add_child(row)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.z_index = 1
	row.add_child(portrait)
	var disc := Panel.new()
	var disc_sb := StyleBoxFlat.new()
	disc_sb.bg_color = Color(0.1, 0.11, 0.14)
	disc_sb.set_corner_radius_all(56)
	disc.add_theme_stylebox_override("panel", disc_sb)
	disc.position = Vector2(8, 8)
	disc.size = Vector2(96, 96)
	portrait.add_child(disc)
	_portrait_icon = TextureRect.new()
	_portrait_icon.texture = load("res://assets/ui/icon_character.png")
	_portrait_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_icon.position = Vector2(16, 14)
	_portrait_icon.size = Vector2(80, 80)
	portrait.add_child(_portrait_icon)
	var ring := TextureRect.new()
	ring.texture = load("res://assets/ui/frame_round.png")
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.size = Vector2(112, 112)
	portrait.add_child(ring)
	var badge := PanelContainer.new()
	var badge_sb := UiTheme._box(Color(0.08, 0.06, 0.03, 0.96), UiTheme.BORDER, 2, 10)
	badge_sb.set_content_margin_all(2)
	badge_sb.content_margin_left = 8
	badge_sb.content_margin_right = 8
	badge.add_theme_stylebox_override("panel", badge_sb)
	badge.position = Vector2(34, 92)
	portrait.add_child(badge)
	_lvl_badge = UiTheme.label("1", 16, UiTheme.ACCENT)
	_lvl_badge.add_theme_font_override("font", UiTheme.TITLE_FONT)
	badge.add_child(_lvl_badge)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_lvl_label = UiTheme.label(GameData.my_name, 20, UiTheme.ACCENT)
	_lvl_label.add_theme_font_override("font", UiTheme.TITLE_FONT)
	box.add_child(_lvl_label)
	var hp := _bar("hp", 26)
	_hp_bar = hp[0]
	_hp_label = hp[1]
	box.add_child(_hp_bar)
	var mp := _bar("mp", 26)
	_mp_bar = mp[0]
	_mp_label = mp[1]
	box.add_child(_mp_bar)
	_exp_bar = _bar("exp", 12)[0]
	box.add_child(_exp_bar)


## Pasek z napisem w środku. Zwraca [ProgressBar, Label].
func _bar(kind: String, height: int) -> Array:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, height)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UiTheme.tex_box("bar_" + kind, 6, 0))
	bar.add_theme_stylebox_override("background", UiTheme.tex_box("bar_bg", 6, 0))
	var l := UiTheme.label("", 16)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	return [bar, l]


func _build_top_buttons() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.position = Vector2(-12, 12)
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var defs := [
		["bag", "Plecak", func(): _toggle(_inventory)],
		["character", "Postać", func(): _toggle(_character)],
		["specs", "Specjalizacje", func(): _toggle(specs)],
		["people", "Gracze online", func(): Net.send({"t": "who"})],
		["book", "Księga czarów", func(): _toggle_spellbook()],
		["menu", "Menu", func(): _toggle(_menu)],
	]
	for d in defs:
		var b := UiTheme.button("", d[0], Vector2(68, 68))
		b.tooltip_text = d[1]
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(d[2])
		row.add_child(b)
	# Minimapa i pora dnia pod przyciskami.
	var mm_row := HBoxContainer.new()
	mm_row.alignment = BoxContainer.ALIGNMENT_END
	mm_row.add_theme_constant_override("separation", 8)
	col.add_child(mm_row)
	var info := VBoxContainer.new()
	_time_label = UiTheme.label("", 16, Color(1, 0.9, 0.6))
	info.add_child(_time_label)
	_zone_label = UiTheme.label("", 16)
	info.add_child(_zone_label)
	_perf = UiTheme.label("", 14, Color(0.7, 0.7, 0.7))
	info.add_child(_perf)
	mm_row.add_child(info)
	minimap = Minimap.new()
	mm_row.add_child(minimap)


## Panel „Aktualne zadania” pod portretem (z pakietu qlog).
func _build_tracker() -> void:
	_tracker = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.55)
	sb.border_color = Color(0.78, 0.58, 0.28, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	_tracker.add_theme_stylebox_override("panel", sb)
	_tracker.position = Vector2(12, 132)
	_tracker.custom_minimum_size = Vector2(300, 0)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.hide()
	_root.add_child(_tracker)
	_tracker_box = VBoxContainer.new()
	_tracker_box.add_theme_constant_override("separation", 1)
	_tracker.add_child(_tracker_box)


func update_quest_log(list: Array) -> void:
	UiTheme.clear(_tracker_box)
	_tracker.visible = not list.is_empty()
	if list.is_empty():
		return
	var head := UiTheme.label("Aktualne zadania", 18, UiTheme.ACCENT)
	head.add_theme_font_override("font", UiTheme.TITLE_FONT)
	_tracker_box.add_child(head)
	for q in list.slice(0, 4):
		_tracker_box.add_child(UiTheme.label(str(q.name), 15, Color(0.95, 0.9, 0.75)))
		if bool(q.ready):
			_tracker_box.add_child(UiTheme.label("  ✔ Wróć po nagrodę", 14, Color(0.55, 1.0, 0.55)))
			continue
		for g in q.goals:
			var done := int(g[1]) >= int(g[2])
			_tracker_box.add_child(UiTheme.label("  %s %s (%d/%d)" % ["✔" if done else "•", g[0], int(g[1]), int(g[2])], 14, Color(0.6, 1.0, 0.6) if done else Color(0.85, 0.85, 0.85)))


## Baner krainy u góry ekranu: nazwa miasta/krainy i strefa (jak „Thais – strefa bezpieczna”).
func _build_region_banner() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -4)
	_root.add_child(box)
	_region_title = UiTheme.label("", 30, UiTheme.ACCENT)
	_region_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_title.add_theme_constant_override("outline_size", 8)
	box.add_child(_region_title)
	_region_sub = UiTheme.label("", 16, Color(0.85, 0.85, 0.8))
	_region_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_region_sub)


func set_region(name: String) -> void:
	if _region_title.text == name:
		return
	_region_title.text = name
	_region_title.modulate.a = 0.0
	create_tween().tween_property(_region_title, "modulate:a", 1.0, 0.6)


func _build_joystick() -> void:
	_joystick = Joystick.new()
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.position = Vector2(30, -30 - Joystick.RADIUS * 2)
	_root.add_child(_joystick)


func _build_actions() -> void:
	# Pasek akcji: górny rząd – 3 umiejętności założonej broni + atak; dolny – czar i mikstury.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	grid.position = Vector2(-20, -20)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_root.add_child(grid)

	var size := Vector2(86, 86)
	# Rząd czarów przypiętych z Księgi czarów.
	for i in 4:
		var sb := _action_button("", "book", size)
		sb.add_theme_font_size_override("font_size", 13)
		sb.pressed.connect(_cast_slot.bind(i))
		_spell_slots.append(sb)
		grid.add_child(sb)
	for i in 3:
		var b := _action_button("", "attack", size)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): Net.send({"t": "ability", "slot": i + 1}))
		_ability_btns.append(b)
		grid.add_child(b)
	var atk := _action_button("Atak", "attack", size)
	atk.pressed.connect(func(): game.attack_nearest())
	grid.add_child(atk)
	_spell_btn = _action_button("exura", "spell_heal", size)
	_spell_btn.pressed.connect(func(): Net.send({"t": "cast", "spell": "heal"}); _cooldowns["heal"] = [1.0, 1.0])
	grid.add_child(_spell_btn)
	_hp_potion_btn = _action_button("0", "hp_potion", size)
	_hp_potion_btn.pressed.connect(_use_item.bind("hp_potion"))
	grid.add_child(_hp_potion_btn)
	_mp_potion_btn = _action_button("0", "mp_potion", size)
	_mp_potion_btn.pressed.connect(_use_item.bind("mp_potion"))
	grid.add_child(_mp_potion_btn)
	_mount_btn = _action_button("Jazda", "mount_horse", size)
	_mount_btn.add_theme_font_size_override("font_size", 15)
	_mount_btn.tooltip_text = "Wierzchowiec: wsiądź / zsiądź"
	_mount_btn.pressed.connect(func(): Net.send({"t": "mount"}))
	grid.add_child(_mount_btn)
	_refresh_abilities()
	_refresh_spell_slots()


## Czary przypięte do paska (Config.spell_slots); puste miejsce otwiera Księgę czarów.
func _refresh_spell_slots() -> void:
	for i in 4:
		var b: Button = _spell_slots[i]
		var id := str(Config.spell_slots[i]) if i < Config.spell_slots.size() else ""
		var sp: Dictionary = GameData.spells.get(id, {})
		b.set_meta("ability", id)
		if sp.is_empty():
			b.text = "+"
			b.icon = Sprites.icon("book")
			b.tooltip_text = "Przypnij czar z Księgi czarów"
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			b.text = str(sp.name).get_slice(" ", 0)
			b.icon = Sprites.icon(str(sp.icon))
			b.tooltip_text = "%s „%s” – %d many" % [sp.name, sp.words, int(sp.mana)]
			# Czar nieznany tej postaci (pasek jest wspólny dla konta na urządzeniu) – wyszarzony.
			b.modulate = Color(1, 1, 1, 0.95) if spellbook == null or spellbook.known.has(id) else Color(0.45, 0.45, 0.5, 0.7)


func _cast_slot(i: int) -> void:
	var id := str(Config.spell_slots[i])
	if id == "" or not GameData.spells.has(id):
		_toggle_spellbook()
		return
	cast_spell(id)


func cast_spell(id: String) -> void:
	Net.send({"t": "cast", "spell": id})


## Przypina czar do pierwszego wolnego miejsca (albo przesuwa pasek, gdy pełny).
func pin_spell(id: String) -> void:
	var slots: Array = Config.spell_slots.duplicate()
	if slots.has(id):
		return
	var free := slots.find("")
	if free < 0:
		slots.pop_front()
		slots.append(id)
	else:
		slots[free] = id
	Config.spell_slots = slots
	Config.save_settings()
	_refresh_spell_slots()
	add_chat("[color=#a0d0ff]Przypięto czar „%s” do paska.[/color]" % GameData.spells[id].name)


func _toggle_spellbook() -> void:
	var show_it := not spellbook.visible
	_toggle(spellbook)
	if show_it:
		spellbook.open_book()


## Umiejętności zależą od broni w ręku (jak w Albionie). Bez broni przyciski są wyłączone.
func _refresh_abilities() -> void:
	var weapon = _eq.get("weapon")
	var kind := GameData.weapon_kind(str(weapon.item)) if weapon is Dictionary else ""
	var defs: Array = GameData.abilities.get(kind, [null, null, null])
	for i in 3:
		var b: Button = _ability_btns[i]
		var d = defs[i]
		b.set_meta("ability", d.id if d else "")
		if d:
			b.text = str(d.name).get_slice(" ", 0)
			b.icon = Sprites.icon(str(d.icon))
			b.tooltip_text = "%s – %s (%d many)" % [d.name, d.description, int(d.mana)]
			b.disabled = false
		else:
			b.text = "—"
			b.icon = null
			b.tooltip_text = "Załóż broń, aby odblokować umiejętności."
			b.disabled = true


## Serwer potwierdził użycie umiejętności – odliczanie na przycisku.
func ability_cooldown(id: String, seconds: float) -> void:
	_cooldowns[id] = [seconds, seconds]


func _action_button(text: String, icon_name: String, min_size: Vector2) -> Button:
	var b := UiTheme.button(text, icon_name, min_size)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 18)
	b.modulate = Color(1, 1, 1, 0.9)
	return b


func _build_chat() -> void:
	# Czat na dole, pośrodku – między joystickiem a paskiem akcji.
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -300
	panel.offset_right = 200
	panel.offset_top = -200
	panel.offset_bottom = -10
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.05, 0.62)
	style.border_color = Color(0.78, 0.58, 0.28, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.custom_minimum_size = Vector2(0, 130)
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_chat_log)
	var row := HBoxContainer.new()
	box.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Napisz... (exura = leczenie, /pomoc)"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size = Vector2(0, 48)
	_chat_input.max_length = 200
	_chat_input.text_submitted.connect(_send_chat)
	row.add_child(_chat_input)
	var send := UiTheme.button("Wyślij", "", Vector2(100, 48))
	send.pressed.connect(func(): _send_chat(_chat_input.text))
	row.add_child(send)


func _build_windows() -> void:
	_inventory = InventoryPanel.new()
	_inventory.set_anchors_preset(Control.PRESET_CENTER)
	_inventory.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_inventory.grow_vertical = Control.GROW_DIRECTION_BOTH
	_inventory.hide()
	_root.add_child(_inventory)

	_character = CharacterPanel.new()
	_character.set_anchors_preset(Control.PRESET_CENTER)
	_character.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_character.grow_vertical = Control.GROW_DIRECTION_BOTH
	_character.hide()
	_root.add_child(_character)

	# Okna ETAPU 2 (ekonomia).
	npc_dialog = NpcDialog.new()
	shop = ShopPanel.new()
	depot = DepotPanel.new()
	market = MarketPanel.new()
	craft = CraftPanel.new()
	specs = SpecsPanel.new()
	world_map = WorldMapPanel.new()
	world_map.game = game
	spellbook = SpellbookPanel.new()
	spellbook.hud = self
	quests = QuestPanel.new()
	quests.hud = self
	minimap.opened.connect(func(): _toggle(world_map))
	for w in [npc_dialog, shop, depot, market, craft, specs, world_map, spellbook, quests]:
		w.set("hud", self)
		_root.add_child(w)
	for w in [shop, depot, market, craft]:
		w.closed.connect(func(): Net.send({"t": "close"}))
	amount = AmountDialog.new()

	_online = _simple_window("Gracze online")
	_online_list = UiTheme.label("", 20)
	_online.get_child(0).add_child(_online_list)

	_menu = _simple_window("Menu")
	var box: VBoxContainer = _menu.get_child(0)
	var sound := UiTheme.button("", "", Vector2(320, 60))
	var set_sound_text := func(): sound.text = "Dźwięk: %s" % ("włączony" if Config.sound_enabled else "wyłączony")
	set_sound_text.call()
	sound.pressed.connect(func():
		Config.sound_enabled = not Config.sound_enabled
		Config.save_settings()
		set_sound_text.call())
	box.add_child(sound)
	var fps := UiTheme.button("", "", Vector2(320, 60))
	var set_fps_text := func(): fps.text = "Licznik FPS: %s" % ("tak" if Config.show_fps else "nie")
	set_fps_text.call()
	fps.pressed.connect(func():
		Config.show_fps = not Config.show_fps
		Config.save_settings()
		set_fps_text.call())
	box.add_child(fps)
	var fx_btn := UiTheme.button("", "", Vector2(320, 60))
	var set_fx_text := func(): fx_btn.text = "Efekty graficzne: %s" % ("wysokie" if Config.effects else "niskie")
	set_fx_text.call()
	fx_btn.pressed.connect(func():
		Config.effects = not Config.effects
		Config.save_settings()
		game.apply_effects()
		set_fx_text.call())
	box.add_child(fx_btn)
	var guild := UiTheme.button("Gildia", "", Vector2(320, 60))
	guild.pressed.connect(func(): Net.send({"t": "say", "text": "/gildia"}); _menu.hide())
	box.add_child(guild)
	var wmap := UiTheme.button("Mapa świata", "", Vector2(320, 60))
	wmap.pressed.connect(func(): _toggle(world_map))
	box.add_child(wmap)
	var logout := UiTheme.button("Wyloguj", "", Vector2(320, 60))
	logout.pressed.connect(func(): game.logout())
	box.add_child(logout)

	_death = ColorRect.new()
	_death.color = Color(0.25, 0, 0, 0.6)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.hide()
	_root.add_child(_death)
	_death_label = UiTheme.label("", 40, Color(1, 0.8, 0.7))
	_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death.add_child(_death_label)
	_root.add_child(amount)
	_zone_toast = UiTheme.label("", 34)
	_zone_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_zone_toast.position.y = 150
	_zone_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_toast.add_theme_constant_override("outline_size", 10)
	_zone_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_toast.hide()
	_root.add_child(_zone_toast)


## Proste okno z tytułem i przyciskiem zamknięcia. Zawartość dodaje się do get_child(0).
func _simple_window(title: String) -> PanelContainer:
	var w := PanelContainer.new()
	w.set_anchors_preset(Control.PRESET_CENTER)
	w.grow_horizontal = Control.GROW_DIRECTION_BOTH
	w.grow_vertical = Control.GROW_DIRECTION_BOTH
	w.custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	w.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var t := UiTheme.label(title, 26, UiTheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var close := UiTheme.button("X", "", Vector2(56, 56))
	close.pressed.connect(w.hide)
	header.add_child(close)
	w.hide()
	_root.add_child(w)
	return w


func _all_windows() -> Array:
	return [_inventory, _character, _online, _menu, shop, depot, market, craft, specs, world_map, spellbook, quests]


func _toggle(w: Control) -> void:
	var show_it := not w.visible
	for other in _all_windows():
		if other.visible and other.has_method("close_window"):
			other.close_window()
		else:
			other.hide()
	w.visible = show_it
	if show_it and w == _inventory and game and game.me:
		_inventory.set_preview(game.me.appearance())


## Pokazuje okno ekonomii (zamyka inne duże okna, zostawia dialog NPC).
func _open_window(w: Control) -> void:
	for other in _all_windows():
		if other != w:
			other.hide()
	amount.hide()
	npc_dialog.hide()
	w.show()


# ============================================================================
# Aktualizacje z serwera
# ============================================================================

func update_stats(s: Dictionary) -> void:
	if s.has("spells") and spellbook:
		var changed: bool = spellbook.known != s.spells
		spellbook.set_known(s.spells)
		if changed:
			_refresh_spell_slots()
	_lvl_label.text = GameData.my_name
	_lvl_badge.text = str(int(s.lvl))
	_hp_bar.max_value = float(s.mhp)
	_hp_bar.value = float(s.hp)
	_hp_label.text = "%d / %d" % [int(s.hp), int(s.mhp)]
	_mp_bar.max_value = float(s.mmp)
	_mp_bar.value = float(s.mp)
	_mp_label.text = "%d / %d" % [int(s.mp), int(s.mmp)]
	_inventory.set_weight(float(s.get("weight", 0)), float(s.get("cap", 400)))
	_specs = s.get("specs", [])
	specs.set_specs(_specs)
	var span := maxf(1.0, float(s.expNext) - float(s.expCur))
	_exp_bar.max_value = 100
	_exp_bar.value = (float(s.exp) - float(s.expCur)) / span * 100.0
	_character.set_stats(s)
	var mounted := str(s.get("mount", "")) != ""
	_mount_btn.text = "Zsiądź" if mounted else "Jazda"
	_mount_btn.modulate = Color(1.0, 0.85, 0.45) if mounted else Color(1, 1, 1, 0.9)


func update_inventory(msg: Dictionary) -> void:
	_bag = msg.bag
	_eq = msg.eq
	_inventory.set_data(_bag, _eq)
	if game and game.me:
		_inventory.set_preview.call_deferred(game.me.appearance())
	_hp_potion_btn.text = str(_count("hp_potion"))
	_mp_potion_btn.text = str(_count("mp_potion"))
	_refresh_abilities()
	for w in [shop, depot, market, craft]:
		w.refresh()


func equipped(slot: String):
	return _eq.get(slot)


func bag() -> Array:
	return _bag


func count_item(item: String) -> int:
	return _count(item)


func spec_level(id: String) -> int:
	for s in _specs:
		if str(s[0]) == id:
			return int(s[1])
	return 1


# --- Okna NPC / ekonomii (wywoływane z game.gd) ---

func show_npc_dialog(msg: Dictionary) -> void:
	npc_dialog.show_dialog(msg)


func show_shop(msg: Dictionary) -> void:
	shop.show_shop(msg)
	_open_window(shop)


func show_depot(msg: Dictionary) -> void:
	depot.show_depot(msg)
	_open_window(depot)


func show_market(msg: Dictionary) -> void:
	market.show_market(msg)
	_open_window(market)


func show_craft(msg: Dictionary) -> void:
	craft.show_station(msg)
	_open_window(craft)


## Gracz odszedł – zamykamy okna związane z NPC.
func close_npc_windows() -> void:
	npc_dialog.hide()
	for w in [shop, depot, market, craft]:
		w.close_window()


func _count(item: String) -> int:
	var n := 0
	for s in _bag:
		if s is Dictionary and s.item == item:
			n += int(s.count)
	return n


func _use_item(item: String) -> void:
	for i in _bag.size():
		var s = _bag[i]
		if s is Dictionary and s.item == item:
			Net.send({"t": "use", "slot": i})
			return
	add_chat("[color=#a0a0a0]Nie masz już tego przedmiotu.[/color]")


func add_chat(bbcode: String) -> void:
	_chat_lines.append(bbcode)
	if _chat_lines.size() > CHAT_LINES:
		_chat_lines.remove_at(0)
	_chat_log.text = "\n".join(_chat_lines)


func _send_chat(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	Net.send({"t": "say", "text": text})
	_chat_input.clear()
	_chat_input.release_focus()


func show_online(list: Array) -> void:
	var lines: PackedStringArray = []
	for p in list:
		lines.append("%s (poziom %d)" % [p.n, int(p.l)])
	_online_list.text = "\n".join(lines)
	_toggle(_online)


func show_death(msg: Dictionary) -> void:
	var lines: PackedStringArray = ["ZGINĄŁEŚ", "Zabójca: %s" % msg.by, "Stracone doświadczenie: %d" % int(msg.lost)]
	if int(msg.get("items", 0)) > 0:
		lines.append("Utracone przedmioty: %d – leżą w miejscu śmierci" % int(msg.items))
	if int(msg.get("bless", 0)) > 0:
		lines.append("Błogosławieństwa złagodziły karę (%d)" % int(msg.bless))
	_death_label.text = "\n".join(lines)
	_death.show()
	get_tree().create_timer(4.0).timeout.connect(_death.hide)


## Strefa ryzyka: napis przy minimapie + komunikat na środku ekranu przy zmianie.
func set_zone(z: String, announce: bool) -> void:
	var col: Color = GameData.ZONE_COLORS[z]
	_zone_label.text = GameData.ZONE_NAMES[z]
	_zone_label.add_theme_color_override("font_color", col)
	_region_sub.text = GameData.ZONE_NAMES[z]
	_region_sub.add_theme_color_override("font_color", col)
	if not announce:
		return
	_zone_toast.text = "%s\n%s" % [GameData.ZONE_NAMES[z].to_upper(), GameData.ZONE_HINTS[z]]
	_zone_toast.add_theme_color_override("font_color", col)
	_zone_toast.modulate.a = 1.0
	_zone_toast.show()
	var t := create_tween()
	t.tween_interval(2.2)
	t.tween_property(_zone_toast, "modulate:a", 0.0, 0.8)
	if z == "r":
		Sfx.play("hurt")


## Zegar świata (0..1 doby cyklu -> godzina, 6:00 = początek dnia).
func set_clock(t: float) -> void:
	var minutes := int(fmod(t * 24.0 + 6.0, 24.0) * 60.0)
	var txt := "%02d:%02d" % [minutes / 60, minutes % 60]
	if _clock_text != txt:
		_clock_text = txt
		_update_time_label()


var _clock_text := ""
var _tod_text := ""


var _weather_text := ""


func set_weather(w: String, amount: float) -> void:
	var t := ""
	if amount > 0.2:
		t = "  •  Burza" if w == "storm" else "  •  Deszcz"
	if t != _weather_text:
		_weather_text = t
		_update_time_label()


func _update_time_label() -> void:
	_time_label.text = "%s  %s%s" % [_clock_text, _tod_text, _weather_text]


## Pora dnia (0 = dzień, 1 = noc) – napis przy minimapie.
func set_time_of_day(n: float) -> void:
	var t := "Dzień"
	if n > 0.85:
		t = "Noc"
	elif n > 0.05:
		t = "Zmierzch"
	_tod_text = t
	_update_time_label()


func joystick_vector() -> Vector2:
	return _joystick.get_vector()


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id][0] -= delta
		if _cooldowns[id][0] <= 0:
			_cooldowns.erase(id)
	_spell_btn.modulate = Color(0.55, 0.55, 0.55, 0.9) if _cooldowns.has("heal") else Color(1, 1, 1, 0.95)
	for b in _spell_slots:
		var sid := str(b.get_meta("ability", ""))
		if sid == "":
			continue
		if _cooldowns.has(sid):
			b.modulate = Color(0.5, 0.5, 0.5, 0.9)
			b.text = "%.0f s" % ceil(_cooldowns[sid][0])
		elif b.text.ends_with(" s"):
			_refresh_spell_slots()
	for b in _ability_btns:
		var id := str(b.get_meta("ability", ""))
		if _cooldowns.has(id):
			b.modulate = Color(0.5, 0.5, 0.5, 0.9)
			b.text = "%.0f s" % ceil(_cooldowns[id][0])
		else:
			b.modulate = Color(1, 1, 1, 0.95)
			if id != "" and b.text.ends_with(" s"):
				_refresh_abilities()
	_perf.visible = Config.show_fps
	if Config.show_fps:
		_perf.text = "FPS %d  •  ping %d ms" % [Engine.get_frames_per_second(), Net.latency_ms]
