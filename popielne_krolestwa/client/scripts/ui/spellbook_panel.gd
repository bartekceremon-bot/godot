class_name SpellbookPanel
extends WindowPanel
## Księga czarów: wszystkie czary pięciu szkół. Znane można rzucić albo przypiąć do paska
## czarów (4 miejsca); u kapłana (pakiet spell_shop) pojawiają się przyciski nauki.

const SCHOOLS := ["light", "fire", "ice", "lightning", "death"]
const SCHOOL_NAMES := {"light": "Światło", "fire": "Ogień", "ice": "Lód", "lightning": "Błyskawica", "death": "Nekromancja"}
const SCHOOL_COL := {"light": Color(1.0, 0.88, 0.5), "fire": Color(1.0, 0.55, 0.25), "ice": Color(0.6, 0.85, 1.0),
	"lightning": Color(0.78, 0.74, 1.0), "death": Color(0.78, 0.45, 0.9)}

var hud
var known: Array = ["heal"]
## Oferta kapłana: id -> cena (tylko gdy okno otworzone u kapłana).
var _shop := {}
var _list: VBoxContainer
var _info: Label


func _init() -> void:
	super._init("Księga czarów", Vector2(760, 0))


func _ready() -> void:
	_info = UiTheme.label("Dotknij „Na pasek”, by przypiąć czar do jednego z czterech miejsc paska czarów.", 16, Color(0.8, 0.78, 0.72))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_info)
	var sc: Array = UiTheme.scroll_list(Vector2(720, 460))
	content.add_child(sc[0])
	_list = sc[1]


## Otwarcie z menu (bez nauki).
func open_book() -> void:
	_shop = {}
	set_title("Księga czarów")
	_rebuild()
	show()


## Oferta kapłana: {city, schools[], spells:[{id, price, known}]}.
func open_shop(msg: Dictionary) -> void:
	_shop = {}
	for s in msg.spells:
		_shop[str(s.id)] = int(s.price)
	set_title("Nauka czarów – %s" % ", ".join(PackedStringArray(msg.schools)))
	_rebuild()
	show()


func set_known(list: Array) -> void:
	if list == known:
		return
	known = list
	if visible:
		_rebuild()


func _rebuild() -> void:
	UiTheme.clear(_list)
	for school in SCHOOLS:
		var head := UiTheme.label("— %s —" % SCHOOL_NAMES[school], 22, SCHOOL_COL[school])
		head.add_theme_font_override("font", UiTheme.TITLE_FONT)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(head)
		for id in GameData.spells:
			var sp: Dictionary = GameData.spells[id]
			if str(sp.get("school", "light")) != school:
				continue
			_list.add_child(_row(sp))


func _row(sp: Dictionary) -> Control:
	var id := str(sp.id)
	var is_known := known.has(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = Sprites.icon(str(sp.icon))
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if is_known else Color(0.5, 0.5, 0.55)
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	var name_l := UiTheme.label("%s  „%s”" % [sp.name, sp.words], 19, UiTheme.ACCENT if is_known else Color(0.7, 0.68, 0.62))
	box.add_child(name_l)
	var d := UiTheme.label("%s  •  %d many  •  poz. %d, magia %d" % [sp.description, int(sp.mana), int(sp.minLevel), int(sp.get("minMagic", 0))], 14, Color(0.8, 0.78, 0.72))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)
	row.add_child(box)
	if is_known:
		var cast := UiTheme.button("Rzuć", "", Vector2(90, 52))
		cast.pressed.connect(func(): hud.cast_spell(id))
		row.add_child(cast)
		var pin := UiTheme.button("Na pasek", "", Vector2(120, 52))
		pin.pressed.connect(func(): hud.pin_spell(id))
		row.add_child(pin)
	elif _shop.has(id):
		var learn := UiTheme.button("Naucz – %d zł" % _shop[id], "", Vector2(200, 52))
		learn.pressed.connect(func(): Net.send({"t": "learn", "spell": id}))
		row.add_child(learn)
	else:
		row.add_child(UiTheme.label("nieznany", 15, Color(0.55, 0.52, 0.5)))
	return row
