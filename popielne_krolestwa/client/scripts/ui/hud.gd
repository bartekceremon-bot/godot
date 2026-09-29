extends CanvasLayer
## Interfejs w grze: paski HP/MP/EXP, joystick, pasek szybkiego dostępu (atak, czar,
## mikstury), czat, przyciski okien (plecak, postać, online, menu), ekran śmierci.

const Joystick := preload("res://scripts/ui/virtual_joystick.gd")
const InventoryPanel := preload("res://scripts/ui/inventory_panel.gd")
const CharacterPanel := preload("res://scripts/ui/character_panel.gd")

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
var _spell_cd := 0.0
var _hp_potion_btn: Button
var _mp_potion_btn: Button

var _bag: Array = []
var _eq: Dictionary = {}


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_build_status()
	_build_top_buttons()
	_build_joystick()
	_build_actions()
	_build_chat()
	_build_windows()


# ============================================================================
# Budowa interfejsu
# ============================================================================

func _build_status() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(330, 0)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_lvl_label = UiTheme.label(GameData.my_name, 20, UiTheme.ACCENT)
	box.add_child(_lvl_label)
	var hp := _bar(Color(0.8, 0.15, 0.12), 26)
	_hp_bar = hp[0]
	_hp_label = hp[1]
	box.add_child(_hp_bar)
	var mp := _bar(Color(0.2, 0.35, 0.9), 26)
	_mp_bar = mp[0]
	_mp_label = mp[1]
	box.add_child(_mp_bar)
	_exp_bar = _bar(Color(0.85, 0.7, 0.2), 8)[0]
	box.add_child(_exp_bar)


## Pasek z napisem w środku. Zwraca [ProgressBar, Label].
func _bar(color: Color, height: int) -> Array:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, height)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.03, 0.9)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	var l := UiTheme.label("", 16)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	return [bar, l]


func _build_top_buttons() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-12, 12)
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)
	var bag := UiTheme.button("Plecak", "bag", Vector2(0, 64))
	bag.pressed.connect(func(): _toggle(_inventory))
	row.add_child(bag)
	var ch := UiTheme.button("Postać", "", Vector2(0, 64))
	ch.pressed.connect(func(): _toggle(_character))
	row.add_child(ch)
	var online := UiTheme.button("Online", "", Vector2(0, 64))
	online.pressed.connect(func(): Net.send({"t": "who"}))
	row.add_child(online)
	var menu := UiTheme.button("Menu", "", Vector2(0, 64))
	menu.pressed.connect(func(): _toggle(_menu))
	row.add_child(menu)
	_perf = UiTheme.label("", 14, Color(0.7, 0.7, 0.7))
	_perf.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_perf.position = Vector2(-200, 84)
	_root.add_child(_perf)


func _build_joystick() -> void:
	_joystick = Joystick.new()
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.position = Vector2(30, -30 - Joystick.RADIUS * 2)
	_root.add_child(_joystick)


func _build_actions() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	grid.position = Vector2(-24, -24)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_root.add_child(grid)

	var size := Vector2(110, 96)
	_spell_btn = _action_button("exura", "spell_heal", size)
	_spell_btn.pressed.connect(func(): Net.send({"t": "cast", "spell": "heal"}); _spell_cd = 1.0)
	grid.add_child(_spell_btn)
	var atk := _action_button("Atak", "attack", size)
	atk.pressed.connect(func(): game.attack_nearest())
	grid.add_child(atk)
	_hp_potion_btn = _action_button("0", "hp_potion", size)
	_hp_potion_btn.pressed.connect(_use_item.bind("hp_potion"))
	grid.add_child(_hp_potion_btn)
	_mp_potion_btn = _action_button("0", "mp_potion", size)
	_mp_potion_btn.pressed.connect(_use_item.bind("mp_potion"))
	grid.add_child(_mp_potion_btn)


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
	panel.offset_left = -290
	panel.offset_right = 250
	panel.offset_top = -200
	panel.offset_bottom = -10
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_corner_radius_all(6)
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


func _toggle(w: Control) -> void:
	var show_it := not w.visible
	for other in [_inventory, _character, _online, _menu]:
		other.hide()
	w.visible = show_it


# ============================================================================
# Aktualizacje z serwera
# ============================================================================

func update_stats(s: Dictionary) -> void:
	_lvl_label.text = "%s  •  poziom %d" % [GameData.my_name, int(s.lvl)]
	_hp_bar.max_value = float(s.mhp)
	_hp_bar.value = float(s.hp)
	_hp_label.text = "%d / %d" % [int(s.hp), int(s.mhp)]
	_mp_bar.max_value = float(s.mmp)
	_mp_bar.value = float(s.mp)
	_mp_label.text = "%d / %d" % [int(s.mp), int(s.mmp)]
	var span := maxf(1.0, float(s.expNext) - float(s.expCur))
	_exp_bar.max_value = 100
	_exp_bar.value = (float(s.exp) - float(s.expCur)) / span * 100.0
	_character.set_stats(s)


func update_inventory(msg: Dictionary) -> void:
	_bag = msg.bag
	_eq = msg.eq
	_inventory.set_data(_bag, _eq)
	_hp_potion_btn.text = str(_count("hp_potion"))
	_mp_potion_btn.text = str(_count("mp_potion"))


func equipped(slot: String):
	return _eq.get(slot)


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


func show_death(by: String, lost: int) -> void:
	_death_label.text = "ZGINĄŁEŚ\nZabójca: %s\nStracone doświadczenie: %d" % [by, lost]
	_death.show()
	get_tree().create_timer(3.0).timeout.connect(_death.hide)


func joystick_vector() -> Vector2:
	return _joystick.get_vector()


func _process(delta: float) -> void:
	if _spell_cd > 0:
		_spell_cd -= delta
		_spell_btn.modulate = Color(0.6, 0.6, 0.6, 0.9) if _spell_cd > 0 else Color(1, 1, 1, 0.9)
	_perf.visible = Config.show_fps
	if Config.show_fps:
		_perf.text = "FPS %d  •  ping %d ms" % [Engine.get_frames_per_second(), Net.latency_ms]
