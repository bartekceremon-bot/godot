class_name UiTheme
## Wspólny motyw interfejsu (dark fantasy: grafitowe panele, złocone ramki) – duże elementy
## wygodne na telefonie. Grafiki ramek: tools/textures/gen_ui.py -> res://assets/ui/.

const BG := Color(0.06, 0.065, 0.08, 0.94)
const BORDER := Color(0.78, 0.58, 0.28)
const ACCENT := Color(0.96, 0.8, 0.48)
const TEXT := Color(0.93, 0.91, 0.86)
## Czcionka tytułów: Cinzel (OFL) w grubości 700.
static var TITLE_FONT: Font = _title_font()


static func _title_font() -> Font:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Cinzel-Bold.ttf")
	return f

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22

	# Ramki okien i przyciski z tekstur 9-patch (res://assets/ui/, generowane w pixel arcie).
	var panel := tex_box("panel", 32, 22)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "Button", tex_box("button_" + state, 20, 12))
		t.set_stylebox(state, "OptionButton", tex_box("button_" + state, 20, 12))
	t.set_stylebox("hover_pressed", "Button", tex_box("button_pressed", 20, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("fff0c8"))
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.4))
	t.set_constant("outline_size", "Button", 4)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))

	t.set_stylebox("normal", "LineEdit", _box(Color(0.03, 0.035, 0.045, 0.95), Color(0.35, 0.3, 0.22), 2, 6))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.03, 0.035, 0.045, 0.95), ACCENT, 2, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_stylebox("background", "ProgressBar", tex_box("bar_bg", 8, 0))
	t.set_stylebox("fill", "ProgressBar", tex_box("bar_exp", 8, 0))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_constant("outline_size", "RichTextLabel", 4)
	t.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.8))
	var tip := _box(Color(0.05, 0.055, 0.07, 0.96), BORDER, 2, 6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	_theme = t
	return t


## StyleBoxTexture z pliku res://assets/ui/<name>.png (margines 9-patch, margines treści).
static func tex_box(name: String, margin: int, content: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/%s.png" % name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	# Gładkie grafiki – środek i krawędzie rozciągane.
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = maxi(4, content - 4)
	sb.content_margin_bottom = maxi(4, content - 4)
	return sb


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
	# Tytuły (duże, złote) – czcionka szeryfowa.
	if size >= 24 and color == ACCENT:
		l.add_theme_font_override("font", TITLE_FONT)
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02, 0.95))
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
	var slot_box := tex_box("slot", 16, 5)
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, slot_box)
	if stack is Dictionary:
		var def := GameData.item_def(str(stack.item))
		b.icon = Sprites.item_icon_for(def)
		var q := int(stack.get("q", 1))
		if q > 1:
			var col: Color = Sprites.QUALITY_COLORS[q]
			for state in ["normal", "hover", "pressed"]:
				var sb := _box(Color(0.04, 0.045, 0.06, 0.96), col, 3, 7)
				sb.set_content_margin_all(5)
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
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
