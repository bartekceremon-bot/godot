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
