extends Control
## Okno tekstu (tablice wiedzy, Kamienie Prawdy) oraz zmiany klasy przy ołtarzu.

signal closed

const CARD := preload("res://scripts/ui/class_card.gd")

var panel: PanelContainer
var title: Label
var content: VBoxContainer
var scroll: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title = UITheme.label("", "Header")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UITheme.button("Zamknij", close_panel)
	close.theme_type_variation = "Chip"
	head.add_child(close)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)


func apply_layout(narrow: bool) -> void:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - (16 if narrow else 80), 1100.0)
	var h := minf(vs.y - (16 if narrow else 60), 860.0)
	panel.position = (vs - Vector2(w, h)) * 0.5
	panel.size = Vector2(w, h)
	panel.custom_minimum_size = panel.size


func _open(t: String) -> void:
	for c in content.get_children():
		c.queue_free()
	title.text = t
	visible = true
	apply_layout(Router.narrow)
	scroll.scroll_vertical = 0


func show_text(t: String, text: String) -> void:
	_open(t)
	content.add_child(UITheme.rich(text))
	var ok := UITheme.button("Rozumiem", close_panel, "Primary")
	content.add_child(ok)
	ok.grab_focus.call_deferred()
	Audio.play("open")


func show_class_picker() -> void:
	_open("Ołtarz Klas")
	content.add_child(UITheme.label("Zmień klasę bez utraty postępu: poziom, zadania, ekwipunek i wiedza zostają z Tobą.", "Small"))
	var grid := GridContainer.new()
	grid.columns = 1 if Router.narrow else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	for cid in Data.class_order:
		var c: PanelContainer = CARD.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
		c.setup(cid, true, cid == GameState.class_id())
		c.chosen.connect(func(id: String) -> void:
			close_panel()
			World.current.change_class(id))


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()
