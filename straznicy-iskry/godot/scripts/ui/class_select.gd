extends Control
## Wybór jednej z czterech klas. Każdą można ukończyć całą grę.

const CARD := preload("res://scripts/ui/class_card.gd")

var grid: GridContainer
var scroll: ScrollContainer
var header: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.color = Color("#0b231d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var margin := UITheme.margin(VBoxContainer.new(), 16)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(margin)
	var v: VBoxContainer = margin.get_child(0)
	var t := UITheme.label("Wybierz swoją drogę Strażnika", "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UITheme.label("Każda klasa przejdzie całą przygodę i wykona wszystkie zadania. Klasę możesz później zmienić w Latarni Wiedzy bez utraty postępu.", "Small")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for cid in Data.class_order:
		var c: PanelContainer = CARD.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
		c.setup(cid, false)
		c.chosen.connect(_choose)
	Router.layout_changed.connect(func(_n: bool) -> void: _layout())
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	grid.columns = 1 if vs.x < 900 else 2


func _choose(cid: String) -> void:
	Audio.play("start")
	GameState.new_game(cid)
	Router.go("world")
