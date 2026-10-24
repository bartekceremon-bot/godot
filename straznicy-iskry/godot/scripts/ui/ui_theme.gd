class_name UITheme
extends RefCounted
## Motyw interfejsu w kolorach AI Bliżej. Skaluje tekst wg ustawień.

const BG := Color("#0b231d")
const PANEL := Color("#123a30")
const PANEL2 := Color("#185044")
const CREAM := Color("#f5ecd7")
const MUTED := Color("#b9c9bf")
const TEAL := Color("#3fd1c1")
const GOLD := Color("#e8b84a")
const OK := Color("#7dffb0")
const BAD := Color("#ff8a8a")

static var _body: FontVariation
static var _bold: FontVariation
static var _title: FontVariation


static func body_font() -> Font:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = load("res://assets/fonts/Nunito.ttf")
		_body.variation_opentype = {"wght": 500}
	return _body


static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = load("res://assets/fonts/Nunito.ttf")
		_bold.variation_opentype = {"wght": 800}
	return _bold


static func title_font() -> Font:
	if _title == null:
		_title = FontVariation.new()
		_title.base_font = load("res://assets/fonts/Cinzel.ttf")
		_title.variation_opentype = {"wght": 700}
	return _title


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 14, bw := 2, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func fs(base: int) -> int:
	return int(round(base * Settings.text_scale))


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = fs(20)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	# Przyciski — duże cele dotykowe, wyraźny fokus (klawiatura).
	t.set_stylebox("normal", "Button", box(PANEL2, Color(TEAL, 0.55), 14, 2, 12))
	t.set_stylebox("hover", "Button", box(PANEL2.lightened(0.12), TEAL, 14, 2, 12))
	t.set_stylebox("pressed", "Button", box(TEAL.darkened(0.35), GOLD, 14, 2, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 14, 3, 12))
	t.set_stylebox("disabled", "Button", box(Color(PANEL, 0.6), Color(MUTED, 0.25), 14, 2, 12))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", fs(20))
	t.set_constant("h_separation", "Button", 8)
	t.set_stylebox("panel", "PanelContainer", box(Color(BG, 0.94), Color(GOLD, 0.6), 18, 2, 18))
	t.set_stylebox("panel", "Panel", box(Color(BG, 0.94), Color(GOLD, 0.6), 18, 2, 18))
	# Warianty
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", title_font())
	t.set_font_size("font_size", "Title", fs(44))
	t.set_color("font_color", "Title", GOLD)
	t.set_type_variation("Header", "Label")
	t.set_font("font", "Header", title_font())
	t.set_font_size("font_size", "Header", fs(28))
	t.set_color("font_color", "Header", GOLD)
	t.set_type_variation("Bold", "Label")
	t.set_font("font", "Bold", bold_font())
	t.set_type_variation("Small", "Label")
	t.set_font_size("font_size", "Small", fs(16))
	t.set_color("font_color", "Small", MUTED)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(Color(PANEL, 0.95), Color(TEAL, 0.35), 14, 2, 14))
	t.set_type_variation("CardOk", "PanelContainer")
	t.set_stylebox("panel", "CardOk", box(Color("#1d4a33"), OK, 14, 2, 14))
	t.set_type_variation("CardBad", "PanelContainer")
	t.set_stylebox("panel", "CardBad", box(Color("#4a2626"), BAD, 14, 2, 14))
	t.set_type_variation("Soft", "PanelContainer")
	t.set_stylebox("panel", "Soft", box(Color(BG, 0.78), Color(0, 0, 0, 0), 14, 0, 12))
	t.set_type_variation("Chip", "Button")
	t.set_stylebox("normal", "Chip", box(PANEL, Color(CREAM, 0.35), 22, 2, 10))
	t.set_stylebox("hover", "Chip", box(PANEL.lightened(0.1), CREAM, 22, 2, 10))
	t.set_stylebox("pressed", "Chip", box(Color("#5a4a1e"), GOLD, 22, 3, 10))
	t.set_font_size("font_size", "Chip", fs(18))
	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", box(Color("#c99a2e"), GOLD.lightened(0.3), 14, 2, 14))
	t.set_stylebox("hover", "Primary", box(Color("#dcae3f"), Color.WHITE, 14, 2, 14))
	t.set_stylebox("pressed", "Primary", box(Color("#a87e1f"), Color.WHITE, 14, 2, 14))
	t.set_color("font_color", "Primary", Color("#1a1306"))
	t.set_color("font_hover_color", "Primary", Color("#1a1306"))
	t.set_color("font_pressed_color", "Primary", Color("#1a1306"))
	t.set_color("font_focus_color", "Primary", Color("#1a1306"))
	t.set_font_size("font_size", "Primary", fs(22))
	# Paski postępu
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.8), 8, 2, 0))
	t.set_stylebox("fill", "ProgressBar", box(TEAL, Color(0, 0, 0, 0), 8, 0, 0))
	t.set_font_size("font_size", "ProgressBar", fs(14))
	# Suwaki, pola tekstowe, przewijanie
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 6, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", box(TEAL, Color(0, 0, 0, 0), 6, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 6, 0, 4))
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.45), Color(TEAL, 0.5), 10, 2, 10))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.45), GOLD, 10, 2, 10))
	t.set_stylebox("normal", "TextEdit", box(Color(0, 0, 0, 0.45), Color(TEAL, 0.5), 10, 2, 10))
	t.set_stylebox("focus", "TextEdit", box(Color(0, 0, 0, 0.45), GOLD, 10, 2, 10))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_color", "TextEdit", CREAM)
	t.set_stylebox("tab_selected", "TabBar", box(PANEL2, GOLD, 12, 2, 10))
	t.set_stylebox("tab_unselected", "TabBar", box(Color(PANEL, 0.8), Color(0, 0, 0, 0), 12, 0, 10))
	t.set_stylebox("tab_hovered", "TabBar", box(PANEL2, TEAL, 12, 2, 10))
	t.set_font("font", "TabBar", bold_font())
	t.set_font_size("font_size", "TabBar", fs(18))
	t.set_color("font_selected_color", "TabBar", GOLD)
	t.set_color("font_unselected_color", "TabBar", MUTED)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_stylebox("panel", "TooltipPanel", box(BG, GOLD, 8, 1, 8))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", fs(20))
	t.set_font_size("bold_font_size", "RichTextLabel", fs(20))
	t.set_constant("scrollbar_width", "VScrollBar", 10)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(TEAL, 0.6), Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(TEAL, Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, Color(0, 0, 0, 0), 6, 0, 0))
	return t


static func label(text: String, variation := "", autowrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(func() -> void:
		Audio.play("click", 0.05, -6.0)
		cb.call())
	return b


static func rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return r


static func margin(c: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(c)
	return mc
