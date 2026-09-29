class_name WindowPanel
extends PanelContainer
## Bazowe okno: tytuł, przycisk zamknięcia i kontener treści (`content`).
## Okna ekonomii dziedziczą po nim; zamknięcie emituje `closed`.

signal closed

var content: VBoxContainer
var _title: Label


func _init(title: String = "", min_size := Vector2(600, 0)) -> void:
	custom_minimum_size = min_size
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	_title = UiTheme.label(title, 26, UiTheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	header.add_child(_title)
	var close := UiTheme.button("X", "", Vector2(56, 56))
	close.pressed.connect(close_window)
	header.add_child(close)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	root.add_child(content)
	# Wyśrodkowanie na ekranie.
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	hide()


func set_title(t: String) -> void:
	_title.text = t


func close_window() -> void:
	if visible:
		hide()
		closed.emit()


## Rząd zakładek. Zwraca kontener; wywołuje on_select(indeks) przy zmianie.
func make_tabs(names: Array, on_select: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := UiTheme.button(str(names[i]), "", Vector2(0, 52))
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(on_select.bind(i))
		if i == 0:
			b.button_pressed = true
		row.add_child(b)
	return row
