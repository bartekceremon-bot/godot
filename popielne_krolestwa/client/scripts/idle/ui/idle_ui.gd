class_name IdleUI
## Elementy interfejsu wersji idle (duże, wygodne na telefonie) w stylu motywu MMO (UiTheme):
## karty, paski, przyciski z ikonami, ikony przedmiotów z kolorem rzadkości.

const GOLD_COL := Color(1.0, 0.84, 0.35)
const GEM_COL := Color(1.0, 0.45, 0.3)
const ASH_COL := Color(0.82, 0.78, 0.92)
const DIM := Color(0.62, 0.58, 0.52)
const GOOD := Color(0.55, 1.0, 0.55)
const BAD := Color(1.0, 0.45, 0.4)


static func card(bg := Color(0.06, 0.065, 0.085, 0.94), border := Color(0.45, 0.35, 0.2, 0.9)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func vbox(sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep := 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func label(text: String, size := 22, color := UiTheme.TEXT, wrap := false) -> Label:
	var l := UiTheme.label(text, size, color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String, size := 30) -> Label:
	var l := UiTheme.label(text, size, UiTheme.ACCENT)
	l.add_theme_font_override("font", UiTheme.TITLE_FONT)
	return l


static func button(text: String, min_size := Vector2(0, 76), font := 22) -> Button:
	var b := UiTheme.button(text, "", min_size)
	b.add_theme_font_size_override("font_size", font)
	return b


static func icon_rect(tex: Texture2D, size := 56) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Ikona przedmiotu (także skrzynie, fragmenty wierzchowców, złoto i żarokryształy).
static func item_tex(db: IdleDB, id: String) -> Texture2D:
	if id == "gems":
		return Sprites.icon("gem")
	if id == "gold":
		return Sprites.item_icon("gold", 0)
	if id == "boost":
		return Sprites.icon("book")
	if id.begins_with("chest_"):
		return Sprites.icon("chest")
	if id.begins_with("frag_"):
		var d := db.item(id.substr(5))
		return Sprites.item_icon_for(d)
	return Sprites.item_icon_for(db.item(id))


static func item_name(db: IdleDB, id: String) -> String:
	if id == "gems":
		return "Żarokryształy"
	if id == "gold":
		return "Złoto"
	if id == "boost":
		return "Wzmocnienie"
	if id.begins_with("chest_"):
		return LootManager.CHEST_NAMES[clampi(int(id.substr(6)), 1, 5)]
	if id.begins_with("frag_"):
		return "Fragment: %s" % db.item_name(id.substr(5))
	return db.item_name(id)


## Kwadrat z ikoną i ramką rzadkości (przycisk).
static func item_button(tex: Texture2D, rarity := 0, count_text := "", size := 88) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var col: Color = IdleDB.RARITY_COLORS[clampi(rarity, 0, 5)] if rarity > 0 else Color(0.35, 0.3, 0.22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.045, 0.06, 0.96) if state != "pressed" else Color(0.1, 0.09, 0.08, 0.96)
		sb.border_color = col
		sb.set_border_width_all(3 if rarity > 1 else 2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, sb)
	if count_text != "":
		b.text = count_text
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_constant_override("outline_size", 5)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.pressed.connect(func(): Sfx.play("click"))
	return b


## Pasek postępu z kolorem wypełnienia i tekstem na środku.
static func bar(fill: Color, height := 26, bg := Color(0.03, 0.03, 0.04, 0.9)) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, height)
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.0
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(height / 2)
	f.border_color = fill.lightened(0.3)
	f.border_width_top = 2
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(height / 2)
	b.border_color = Color(0.5, 0.38, 0.2, 0.9)
	b.set_border_width_all(2)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", b)
	return pb


## Etykieta nałożona na pasek.
static func bar_label(pb: ProgressBar, size := 18) -> Label:
	var l := UiTheme.label("", size)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(l)
	return l


## Wiersz waluty: ikona + liczba.
static func currency(tex: Texture2D, color: Color, size := 26) -> Array:
	var h := hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_rect(tex, size + 12))
	var l := UiTheme.label("0", size, color)
	h.add_child(l)
	return [h, l]


static func scroll() -> Array:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	var box := vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	return [sc, box]


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Tekst ceny: „1,2K zł” zielony/czerwony wg dostępności.
static func price_text(amount: float, have: float, suffix := " zł") -> String:
	return IdleDB.fmt(amount) + suffix


static func set_affordable(b: Button, ok: bool) -> void:
	b.disabled = not ok
	b.modulate = Color.WHITE if ok else Color(0.75, 0.7, 0.68)
