extends WindowPanel
## Sklep NPC: kupno z oferty NPC i sprzedaż przedmiotów z plecaka (NPC płaci ułamek wartości).

var hud: Node
var _npc := 0
var _sells: Array = []
var _buys := false
var _ratio := 0.2
var _tab := 0
var _list: VBoxContainer


func _init() -> void:
	super._init("Sklep", Vector2(640, 0))
	content.add_child(make_tabs(["Kup", "Sprzedaj"], func(i): _tab = i; _rebuild()))
	var sl := UiTheme.scroll_list(Vector2(620, 380))
	content.add_child(sl[0])
	_list = sl[1]


func show_shop(msg: Dictionary) -> void:
	_npc = int(msg.npc)
	_sells = msg.sells
	_buys = msg.buys
	_ratio = float(msg.buyRatio)
	set_title("Sklep – %s" % msg.name)
	_rebuild()
	show()


func refresh() -> void:
	if visible:
		_rebuild()


func _row(item_id: String, q: int, text: String, button: String, on_press: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiTheme.item_icon_rect(item_id))
	var l := UiTheme.label(text, 18)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var b := UiTheme.button(button, "", Vector2(130, 52))
	b.pressed.connect(on_press)
	row.add_child(b)
	_list.add_child(row)


func _rebuild() -> void:
	UiTheme.clear(_list)
	var gold: int = hud.count_item("gold")
	if _tab == 0:
		_list.add_child(UiTheme.label("Twoje złoto: %d zł" % gold, 18, Color(1, 0.85, 0.3)))
		for o in _sells:
			var id := str(o.item)
			var price := int(o.price)
			_row(id, 1, "%s\n%d zł" % [GameData.item_def(id).name, price], "Kup", func():
				hud.amount.open({"title": "Kup", "info": GameData.item_description(id), "max": maxi(1, mini(100, gold / maxi(1, price))),
					"button": "Kup", "price": price, "total": true}, func(n, _p, _q): Net.send({"t": "shop_buy", "item": id, "count": n})))
	else:
		if not _buys:
			_list.add_child(UiTheme.label("Ten NPC niczego nie skupuje.", 18))
			return
		var bag: Array = hud.bag()
		for i in bag.size():
			var s = bag[i]
			if not (s is Dictionary) or s.item == "gold":
				continue
			var d := GameData.item_def(str(s.item))
			var price := maxi(1, int(floor(float(d.get("value", 0)) * _ratio)))
			var slot := i
			var cnt := int(s.count)
			_row(str(s.item), int(s.get("q", 1)), "%s ×%d\n%d zł/szt." % [GameData.item_label(str(s.item), int(s.get("q", 1))), cnt, price], "Sprzedaj", func():
				hud.amount.open({"title": "Sprzedaj", "info": d.name, "max": cnt, "amount": cnt, "button": "Sprzedaj", "price": price, "total": true},
					func(n, _p, _q): Net.send({"t": "shop_sell", "slot": slot, "count": n})))
