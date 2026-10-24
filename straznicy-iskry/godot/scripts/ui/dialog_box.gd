extends Control
## Dialogi z portretem. Tekst pojawia się stopniowo; dotknięcie/Enter przyspiesza.

signal closed

var panel: PanelContainer
var portrait: Control
var name_label: Label
var text_label: RichTextLabel
var next_btn: Button
var skip_btn: Button
var _lines: Array = []
var _i := 0
var _id := ""
var _npc: Node = null
var _who := "blik"
var _chars := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_tap)
	add_child(dim)
	panel = PanelContainer.new()
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	portrait = Control.new()
	portrait.custom_minimum_size = Vector2(110, 120)
	portrait.draw.connect(_draw_portrait)
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	name_label = UITheme.label("", "Header", false)
	v.add_child(name_label)
	text_label = UITheme.rich("")
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	text_label.gui_input.connect(_on_tap)
	v.add_child(text_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	skip_btn = UITheme.button("Pomiń rozmowę", _finish)
	skip_btn.theme_type_variation = "Chip"
	row.add_child(skip_btn)
	next_btn = UITheme.button("Dalej", _advance, "Primary")
	next_btn.custom_minimum_size.x = 150
	row.add_child(next_btn)


func apply_layout(narrow: bool) -> void:
	var vs := get_viewport_rect().size
	var m := Router.safe_margins()
	var w := minf(vs.x - 24 - m["left"] - m["right"], 980.0)
	panel.custom_minimum_size = Vector2(w, 220 if not narrow else 260)
	panel.size = panel.custom_minimum_size
	panel.position = Vector2((vs.x - w) * 0.5, vs.y - panel.size.y - 16 - m["bottom"])
	portrait.custom_minimum_size = Vector2(80, 100) if narrow else Vector2(110, 120)


func open(dialog_id: String, lines: Array, npc: Node) -> void:
	_id = dialog_id
	_lines = lines
	_npc = npc
	_i = 0
	visible = true
	apply_layout(Router.narrow)
	_show_line()
	next_btn.grab_focus()


func _show_line() -> void:
	var line: Dictionary = _lines[_i]
	_who = line.get("who", "blik")
	var nm: String = line.get("name", "")
	if _who == "player":
		_who = GameState.class_id()
		nm = "Ty"
	if nm.is_empty():
		nm = {"blik": "BLIK", "lumi": "Lumi", "fela": "Fela", "tosia": "Tosia", "sowa": "Pan Sowiński", "miraz": "Miraż"}.get(_who, _who.capitalize())
	name_label.text = nm
	var text: String = line.get("text", "")
	var by_class: Dictionary = line.get("by_class", {})
	if by_class.has(GameState.class_id()):
		text += " " + str(by_class[GameState.class_id()])
	text = text.replace("{class}", Data.get_class_def(GameState.class_id()).get("name", ""))
	text_label.text = text
	_chars = 0.0
	text_label.visible_characters = 0 if not Settings.reduced_motion else -1
	next_btn.text = "Dalej" if _i < _lines.size() - 1 else "Zakończ"
	skip_btn.visible = _lines.size() > 2 and _i < _lines.size() - 1
	if _who == "blik" and World.current:
		World.current.blik.set_mood(line.get("mood", "happy"), 3.0)
	Audio.play("blik" if _who == "blik" else "talk", 0.1, -10.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	portrait.queue_redraw()
	if text_label.visible_characters >= 0:
		_chars += delta * 55.0
		text_label.visible_characters = int(_chars)
		if text_label.visible_characters >= text_label.get_total_character_count():
			text_label.visible_characters = -1


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_finish()
		get_viewport().set_input_as_handled()


func _on_tap(event: InputEvent) -> void:
	# Dotyk dociera tu jako emulowane kliknięcie myszy — obsługujemy je raz.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	if text_label.visible_characters != -1:
		text_label.visible_characters = -1
		return
	_i += 1
	if _i >= _lines.size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	if not visible:
		return
	visible = false
	if _npc and is_instance_valid(_npc):
		_npc.talking = false
	var id := _id
	closed.emit()
	if World.current:
		World.current.dialog_finished(id)


func _draw_portrait() -> void:
	var s := portrait.size
	portrait.draw_circle(s * 0.5, minf(s.x, s.y) * 0.5, Color(Art.TEAL, 0.12))
	var scale := minf(s.x, s.y) / 75.0
	Art.portrait(portrait, _who, _t, Vector2(s.x * 0.5, s.y * 0.88), scale)
