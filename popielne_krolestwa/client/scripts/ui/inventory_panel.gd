extends PanelContainer
## Okno plecaka i ekwipunku. Dotknięcie przedmiotu pokazuje jego opis i akcje
## (Użyj / Załóż / Zdejmij / Upuść). Wszystkie akcje wykonuje serwer.

const SLOT_SIZE := Vector2(72, 72)
const EQUIP_ORDER := ["head", "weapon", "body", "shield", "legs", "feet"]

var _bag_grid: GridContainer
var _equip_grid: GridContainer
var _details: Label
var _actions: HBoxContainer
var _gold: Label
var _weight: Label
var _bag: Array = []
var _eq: Dictionary = {}
## Zaznaczony przedmiot: {"src": "bag"/"eq", "key": indeks lub nazwa slotu}
var _selected: Dictionary = {}


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiTheme.label("Plecak i ekwipunek", 26, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_weight = UiTheme.label("", 18, Color(0.8, 0.75, 0.7))
	header.add_child(_weight)
	_gold = UiTheme.label("", 20, Color(1, 0.85, 0.3))
	header.add_child(_gold)
	var close := UiTheme.button("X", "", Vector2(56, 56))
	close.pressed.connect(hide)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	_equip_grid = GridContainer.new()
	_equip_grid.columns = 2
	body.add_child(_equip_grid)

	_bag_grid = GridContainer.new()
	_bag_grid.columns = 5
	body.add_child(_bag_grid)

	_details = UiTheme.label("Dotknij przedmiotu, aby zobaczyć szczegóły.", 18)
	_details.custom_minimum_size = Vector2(0, 90)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_details)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	root.add_child(_actions)


func set_data(bag: Array, eq: Dictionary) -> void:
	_bag = bag
	_eq = eq
	var gold := 0
	for s in bag:
		if s is Dictionary and s.item == "gold":
			gold += int(s.count)
	_gold.text = "%d zł  " % gold
	_rebuild()


func _rebuild() -> void:
	for c in _equip_grid.get_children():
		c.queue_free()
	for c in _bag_grid.get_children():
		c.queue_free()
	for slot in EQUIP_ORDER:
		var stack = _eq.get(slot)
		var b := _slot_button(stack, GameData.SLOT_LABELS[slot])
		b.pressed.connect(_select.bind("eq", slot))
		_equip_grid.add_child(b)
	for i in _bag.size():
		var b := _slot_button(_bag[i], "")
		b.pressed.connect(_select.bind("bag", i))
		_bag_grid.add_child(b)
	# Odśwież szczegóły zaznaczenia (albo wyczyść, jeśli przedmiot zniknął).
	if not _selected.is_empty():
		_select(_selected.src, _selected.key)


func _slot_button(stack, placeholder: String) -> Button:
	return UiTheme.item_slot(stack, placeholder, SLOT_SIZE)


## Udźwig z pakietu stats.
func set_weight(weight: float, cap: float) -> void:
	_weight.text = "%.0f/%.0f oz  " % [weight, cap]
	_weight.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if weight > cap * 0.9 else Color(0.8, 0.75, 0.7))


func _select(src: String, key) -> void:
	for c in _actions.get_children():
		c.queue_free()
	var stack = _bag[key] if src == "bag" else _eq.get(key)
	if not (stack is Dictionary):
		_selected = {}
		_details.text = "Pusty slot."
		return
	_selected = {"src": src, "key": key}
	var def := GameData.item_def(str(stack.item))
	_details.text = GameData.item_description(str(stack.item), int(stack.get("q", 1))) + ("  (x%d)" % int(stack.count) if int(stack.count) > 1 else "")
	if src == "eq":
		_action("Zdejmij", {"t": "unequip", "slot": key})
		return
	if def.has("use"):
		_action("Użyj", {"t": "use", "slot": key})
	if def.has("slot"):
		_action("Załóż", {"t": "equip", "slot": key})
	_action("Upuść", {"t": "drop", "slot": key})


func _action(text: String, msg: Dictionary) -> void:
	var b := UiTheme.button(text, "", Vector2(140, 60))
	b.pressed.connect(func(): Net.send(msg))
	_actions.add_child(b)
