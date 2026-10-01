class_name IdleUI
## Elementy interfejsu wersji idle (duże, wygodne na telefonie) w stylu motywu MMO (UiTheme):
## karty, paski, przyciski z ikonami, ikony przedmiotów z kolorem rzadkości.

const GOLD_COL := Color(1.0, 0.84, 0.35)
const GEM_COL := Color(1.0, 0.45, 0.3)
const ASH_COL := Color(0.82, 0.78, 0.92)
const DIM := Color(0.62, 0.58, 0.52)
const GOOD := Color(0.55, 1.0, 0.55)
const BAD := Color(1.0, 0.45, 0.4)
## Paleta „kuźni przyszłości”: obsydianowe szkło, żar, chłodny błękit.
const EMBER := Color(1.0, 0.52, 0.18)
const GLASS := Color(0.055, 0.05, 0.065, 0.84)
const CYAN := Color(0.4, 0.88, 1.0)

static var _theme: Theme = null
static var _ui_font: Font = null


## Czcionka interfejsu: Exo 2 (OFL), grubość 600.
static func ui_font(weight := 600) -> Font:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Exo2-SemiBold.ttf")
	return f


## Szklany panel: półprzezroczyste tło, cienka świecąca krawędź, poświata (cień w kolorze).
static func glass(bg := GLASS, border := Color(1.0, 0.62, 0.3, 0.3), radius := 16, bw := 2, glow := Color(0, 0, 0, 0.45), glow_size := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = glow
	sb.shadow_size = glow_size
	sb.anti_aliasing = true
	sb.set_content_margin_all(12)
	return sb


## Motyw wersji idle: szkło, żarzące się krawędzie, Exo 2 i Cinzel.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t: Theme = UiTheme.get_theme().duplicate()
	_ui_font = ui_font(600)
	t.default_font = _ui_font
	t.default_font_size = 22
	# Kamienne płyty „Popiół i żar” (assets/ui/ash): zwykła, wciśnięta/aktywna z żarem, wyłączona – przygaszona.
	var normal := ash_box("stone_panel", 26, 10)
	var hover := ash_box("stone_panel", 26, 10)
	hover.modulate_color = Color(1.12, 1.08, 1.04)
	var pressed := ash_box("tile_on", 26, 10)
	var disabled := ash_box("stone_panel", 26, 10)
	disabled.modulate_color = Color(0.55, 0.52, 0.5, 0.9)
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.96, 0.93, 0.86))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.9, 0.7))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.46))
	t.set_stylebox("panel", "PanelContainer", ash_box("slot", 18, 12))
	t.set_stylebox("panel", "Panel", ash_box("slot", 18, 12))
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1.0, 0.6, 0.25, 0.55)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 5
	grab.content_margin_right = 5
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.04)
	track.set_corner_radius_all(4)
	track.content_margin_left = 5
	track.content_margin_right = 5
	t.set_stylebox("scroll", "VScrollBar", track)
	_theme = t
	return t


static func card(bg := Color(0.065, 0.058, 0.078, 0.86), border := Color(1.0, 0.65, 0.35, 0.22)) -> PanelContainer:
	var p := PanelContainer.new()
	# Karta = ciemny kamienny kafel; kolor obramowania (np. „gotowe”, rzadkość) jako cienka poświata.
	var sb := ash_box("slot", 18, 14)
	if border.a > 0.5:
		sb.modulate_color = Color(1, 1, 1).lerp(border, 0.25)
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
	if id.begins_with("rune_"):
		return load("res://assets/ui/runes/%s.png" % str(RuneManager.parse(id)[0]))
	if id == "pet_egg":
		return load("res://assets/ui/runes/egg.png")
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
	if id.begins_with("rune_"):
		return RuneManager.rune_name(id)
	if id == "pet_egg":
		return "Jajo chowańca"
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
	var col: Color = IdleDB.RARITY_COLORS[clampi(rarity, 0, 5)] if rarity > 0 else Color(1.0, 0.65, 0.35, 0.3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg := Color(0.05, 0.045, 0.06, 0.9) if state != "pressed" else Color(0.18, 0.1, 0.06, 0.95)
		# Rzadkie przedmioty świecą w swoim kolorze.
		var glow := Color(col, 0.45) if rarity >= 3 else Color(0, 0, 0, 0.45)
		var sb := glass(bg, col, 14, 3 if rarity > 1 else 2, glow, 10 if rarity >= 3 else 5)
		sb.set_content_margin_all(7)
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
	# Neonowy pasek: jasna górna krawędź i poświata w kolorze wypełnienia.
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(height / 2)
	f.border_color = fill.lightened(0.45)
	f.border_width_top = maxi(1, height / 8)
	f.shadow_color = Color(fill, 0.55)
	f.shadow_size = maxi(3, height / 3)
	f.anti_aliasing = true
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.02, 0.02, 0.03, 0.78)
	b.set_corner_radius_all(height / 2)
	b.border_color = Color(1.0, 0.7, 0.4, 0.22)
	b.set_border_width_all(1)
	b.anti_aliasing = true
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


# --- Oprawa „Popiół i żar” (assets/ui/ash, tools/textures/gen_ui_ash.py) -----------

static var _bold: Font = null


static func ash_tex(name: String) -> Texture2D:
	return load("res://assets/ui/ash/%s.png" % name)


## Kamienna płyta 9-patch (stone_panel, slot, sheet, stone_button, badge, tile_on).
static func ash_box(name: String, margin: int, content := -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = ash_tex(name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content if content >= 0 else margin * 0.6)
	return sb


## Gruba czcionka HUD-u (Exo 2 ExtraBold).
static func bold_font() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/Exo2-ExtraBold.ttf")
	return _bold


## Napis HUD-u: gruby, z ciemnym obrysem – czytelny na tle sceny 3D.
static func hud_label(text: String, size := 22, color := Color(0.95, 0.93, 0.9), outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Przycisk z kamienną płytą: ten sam wygląd we wszystkich stanach, wciśnięty – przygaszony.
static func ash_button(name: String, margin: int, pressed_name := "") -> Button:
	var b := Button.new()
	var n := ash_box(name, margin)
	var p := ash_box(pressed_name if pressed_name != "" else name, margin)
	if pressed_name == "":
		p.modulate_color = Color(0.78, 0.74, 0.7)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Przestawia pojemnik i jego dzieci-pojemniki na przepuszczanie dotyku (do ekranu walki).
static func pass_through(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
