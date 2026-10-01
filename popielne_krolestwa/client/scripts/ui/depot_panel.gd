extends WindowPanel
## Depozyt miasta: przenoszenie przedmiotów między depozytem a plecakiem.
## Tu trafiają też towary i złoto z rynku.

var hud: Node
var _items: Array = []
var _depot_grid: GridContainer
var _bag_grid: GridContainer
var _info: Label


func _init() -> void:
	super._init("Depozyt", Vector2(900, 0))
	_info = UiTheme.label("Dotknij przedmiotu, aby go przenieść.", 16, Color(0.8, 0.75, 0.7))
	content.add_child(_info)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)

	var left := VBoxContainer.new()
	left.add_child(UiTheme.label("Depozyt", 20, UiTheme.ACCENT))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(480, 400)
	_depot_grid = GridContainer.new()
	_depot_grid.columns = 6
	sc.add_child(_depot_grid)
	left.add_child(sc)
	body.add_child(left)

	var right := VBoxContainer.new()
	right.add_child(UiTheme.label("Plecak", 20, UiTheme.ACCENT))
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 5
	right.add_child(_bag_grid)
	body.add_child(right)


func show_depot(msg: Dictionary) -> void:
	_items = msg.items
	set_title("Depozyt – %s" % msg.cityName)
	_rebuild()
	show()


func refresh() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	UiTheme.clear(_depot_grid)
	UiTheme.clear(_bag_grid)
	for i in _items.size():
		var s: Dictionary = _items[i]
		var b := UiTheme.item_slot(s, "", Vector2(76, 76))
		var idx := i
		b.pressed.connect(func():
			hud.amount.open({"title": "Weź z depozytu", "info": GameData.item_description(str(s.item), int(s.get("q", 1))),
				"max": int(s.count), "amount": int(s.count), "button": "Weź"},
				func(n, _p, _q): Net.send({"t": "depot_take", "index": idx, "count": n})))
		_depot_grid.add_child(b)
	if _items.is_empty():
		_depot_grid.add_child(UiTheme.label("Pusto.", 18))
	var bag: Array = hud.bag()
	for i in bag.size():
		var s = bag[i]
		var b := UiTheme.item_slot(s, "", Vector2(64, 64))
		if s is Dictionary:
			var slot := i
			b.pressed.connect(func():
				hud.amount.open({"title": "Odłóż do depozytu", "info": GameData.item_description(str(s.item), int(s.get("q", 1))),
					"max": int(s.count), "amount": int(s.count), "button": "Odłóż"},
					func(n, _p, _q): Net.send({"t": "depot_put", "slot": slot, "count": n})))
		_bag_grid.add_child(b)
