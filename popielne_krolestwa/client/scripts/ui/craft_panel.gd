extends WindowPanel
## Stacja rzemieślnicza (Rafineria / Kuźnia / Pracownia): lista receptur danego tieru,
## szczegóły (materiały: masz/potrzeba, wymagana specjalizacja) i wytwarzanie.

var hud: Node
var _station := ""
var _tier := 1
var _selected := ""
var _list: VBoxContainer
var _details: Label
var _bonus: Label
var _craft_btn: Button


func _init() -> void:
	super._init("Rzemiosło", Vector2(900, 0))
	_bonus = UiTheme.label("", 16, Color(0.8, 0.75, 0.7))
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_bonus)
	content.add_child(make_tabs(["T1", "T2", "T3", "T4"], func(i): _tier = i + 1; _selected = ""; _rebuild()))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	content.add_child(body)
	var sl := UiTheme.scroll_list(Vector2(440, 360))
	body.add_child(sl[0])
	_list = sl[1]
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	_details = UiTheme.label("Wybierz przedmiot z listy.", 18)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_details)
	_craft_btn = UiTheme.button("Wytwórz", "", Vector2(0, 64))
	_craft_btn.pressed.connect(_on_craft)
	right.add_child(_craft_btn)
	body.add_child(right)


func show_station(msg: Dictionary) -> void:
	_station = str(msg.station)
	set_title(str(msg.name))
	_bonus.text = str(msg.city)
	_selected = ""
	_rebuild()
	show()


func refresh() -> void:
	if visible:
		_rebuild()


## Ile razy można wykonać recepturę z materiałów w plecaku.
func _max_crafts(r: Dictionary) -> int:
	var m := 1000000
	for inp in r.inputs:
		m = mini(m, hud.count_item(str(inp.item)) / int(inp.count))
	return m


func _rebuild() -> void:
	UiTheme.clear(_list)
	for r in GameData.recipes_by_station.get(_station, []):
		if int(r.tier) != _tier:
			continue
		var n := _max_crafts(r)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		b.icon = Sprites.item_icon_for(GameData.item_def(str(r.output)))
		b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s%s" % [GameData.item_def(str(r.output)).name, ("  (×%d)" % n) if n > 0 else ""]
		b.add_theme_font_size_override("font_size", 16)
		if n == 0:
			b.modulate = Color(0.7, 0.7, 0.7)
		var id := str(r.id)
		b.pressed.connect(func(): _selected = id; _show_details())
		_list.add_child(b)
	_show_details()


func _show_details() -> void:
	if _selected.is_empty() or not GameData.recipes.has(_selected):
		_details.text = "Wybierz przedmiot z listy."
		_craft_btn.disabled = true
		return
	var r: Dictionary = GameData.recipes[_selected]
	var lines: PackedStringArray = [GameData.item_description(str(r.output)), "", "Materiały:"]
	for inp in r.inputs:
		var have: int = hud.count_item(str(inp.item))
		lines.append("  %d× %s  (masz %d)" % [int(inp.count), GameData.item_def(str(inp.item)).name, have])
	var req := int(GameData.tier_spec_req[int(r.tier)])
	var lvl: int = hud.spec_level(str(r.spec))
	lines.append("")
	lines.append("Specjalizacja %s: %d / wymagane %d" % [GameData.spec_name(str(r.spec)), lvl, req])
	_details.text = "\n".join(lines)
	_craft_btn.disabled = _max_crafts(r) == 0 or lvl < req


func _on_craft() -> void:
	var r: Dictionary = GameData.recipes[_selected]
	var n := _max_crafts(r)
	var id := _selected
	hud.amount.open({"title": "Wytwórz", "info": GameData.item_def(str(r.output)).name, "max": mini(100, n), "amount": n if r.station == "refinery" else 1,
		"button": "Wytwórz"}, func(c, _p, _q): Net.send({"t": "craft", "recipe": id, "count": c}))
