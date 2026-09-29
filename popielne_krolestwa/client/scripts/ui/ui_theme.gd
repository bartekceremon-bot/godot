class_name UiTheme
## Wspólny motyw interfejsu – duże elementy wygodne na telefonie.

const BG := Color(0.09, 0.07, 0.07, 0.92)
const BORDER := Color(0.55, 0.36, 0.2)
const ACCENT := Color(0.92, 0.55, 0.22)
const TEXT := Color(0.94, 0.9, 0.84)

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22

	var panel := _box(BG, BORDER, 2, 8)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_stylebox("normal", "Button", _box(Color(0.22, 0.15, 0.11), BORDER, 2, 6))
	t.set_stylebox("hover", "Button", _box(Color(0.3, 0.2, 0.14), ACCENT, 2, 6))
	t.set_stylebox("pressed", "Button", _box(Color(0.4, 0.24, 0.12), ACCENT, 2, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _box(Color(0.15, 0.12, 0.1), Color(0.3, 0.25, 0.2), 2, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)

	t.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.04, 0.04), BORDER, 2, 4))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.05, 0.04, 0.04), ACCENT, 2, 4))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	var bar_bg := _box(Color(0.05, 0.03, 0.03, 0.9), Color(0.3, 0.2, 0.12), 1, 3)
	bar_bg.content_margin_top = 0
	bar_bg.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, ACCENT, 0, 3))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## Przycisk z tekstem i opcjonalną ikoną.
static func button(text: String, icon_name: String = "", min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if icon_name != "":
		b.icon = Sprites.icon(icon_name)
		b.expand_icon = true
	b.pressed.connect(func(): Sfx.play("click"))
	return b


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Przycisk slotu z przedmiotem: ikona z tierem, liczba sztuk, ramka koloru jakości.
static func item_slot(stack, placeholder: String = "", min_size := Vector2(72, 72)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(func(): Sfx.play("click"))
	if stack is Dictionary:
		var def := GameData.item_def(str(stack.item))
		b.icon = Sprites.item_icon_for(def)
		var q := int(stack.get("q", 1))
		if q > 1:
			var col: Color = Sprites.QUALITY_COLORS[q]
			for state in ["normal", "hover", "pressed"]:
				var sb := _box(Color(0.22, 0.15, 0.11), col, 3, 6)
				b.add_theme_stylebox_override(state, sb)
		if int(stack.count) > 1:
			b.text = _short_count(int(stack.count))
			b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		b.text = placeholder
		b.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	return b


static func _short_count(n: int) -> String:
	if n >= 1000000:
		return "%dM" % (n / 1000000)
	if n >= 10000:
		return "%dk" % (n / 1000)
	return str(n)


## Mała ikona przedmiotu do wierszy list.
static func item_icon_rect(item_id: String, size: int = 40) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.item_icon_for(GameData.item_def(item_id))
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


## Przewijana lista (VBox w ScrollContainer). Zwraca [scroll, vbox].
static func scroll_list(min_size: Vector2) -> Array:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = min_size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	sc.add_child(box)
	return [sc, box]


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
