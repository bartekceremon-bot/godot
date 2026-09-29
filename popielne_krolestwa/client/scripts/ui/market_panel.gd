extends WindowPanel
## Rynek miejski (gracze handlują z graczami):
##  - Oferty: zlecenia sprzedaży innych graczy – kup od razu,
##  - Popyt: zlecenia kupna – sprzedaj od razu z plecaka,
##  - Wystaw: zlecenie sprzedaży przedmiotu z plecaka,
##  - Zamów: zlecenie kupna dowolnego przedmiotu,
##  - Moje: twoje aktywne zlecenia (anulowanie).

const TABS := ["Oferty", "Popyt", "Wystaw", "Zamów", "Moje"]
const CATEGORIES := [
	["Wszystko", []], ["Surowce", ["resource"]], ["Materiały", ["material"]],
	["Broń", ["weapon", "shield"]], ["Pancerz", ["armor"]], ["Narzędzia", ["tool"]],
	["Inne", ["consumable", "misc"]],
]

var hud: Node
var _data: Dictionary = {}
var _tab := 0
var _category := 0
var _tier := 0
var _list: VBoxContainer
var _filters: HBoxContainer
var _cat_btn: OptionButton
var _tier_btn: OptionButton
var _header: Label


func _init() -> void:
	super._init("Rynek", Vector2(900, 0))
	content.add_child(make_tabs(TABS, func(i): _tab = i; _rebuild()))
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 8)
	_cat_btn = OptionButton.new()
	_cat_btn.custom_minimum_size = Vector2(220, 48)
	for c in CATEGORIES:
		_cat_btn.add_item(c[0])
	_cat_btn.item_selected.connect(func(i): _category = i; _rebuild())
	_filters.add_child(_cat_btn)
	_tier_btn = OptionButton.new()
	_tier_btn.custom_minimum_size = Vector2(160, 48)
	_tier_btn.add_item("Każdy tier")
	for t in range(1, 5):
		_tier_btn.add_item("T%d" % t)
	_tier_btn.item_selected.connect(func(i): _tier = i; _rebuild())
	_filters.add_child(_tier_btn)
	_header = UiTheme.label("", 16, Color(0.8, 0.75, 0.7))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_filters.add_child(_header)
	content.add_child(_filters)
	var sl := UiTheme.scroll_list(Vector2(880, 380))
	content.add_child(sl[0])
	_list = sl[1]


func show_market(msg: Dictionary) -> void:
	_data = msg
	set_title("Rynek – %s" % msg.cityName)
	_rebuild()
	show()


func refresh() -> void:
	if visible:
		_rebuild()


func _matches(item_id: String) -> bool:
	var d := GameData.item_def(item_id)
	var cats: Array = CATEGORIES[_category][1]
	if not cats.is_empty() and not cats.has(str(d.get("category", ""))):
		return false
	return _tier == 0 or int(d.get("tier", 0)) == _tier


func _row(item_id: String, text: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiTheme.item_icon_rect(item_id))
	var l := UiTheme.label(text, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	for b in buttons:
		var btn := UiTheme.button(b[0], "", Vector2(130, 52))
		btn.pressed.connect(b[1])
		row.add_child(btn)
	_list.add_child(row)


func _empty(text: String) -> void:
	_list.add_child(UiTheme.label(text, 18, Color(0.7, 0.65, 0.6)))


func _rebuild() -> void:
	UiTheme.clear(_list)
	if _data.is_empty():
		return
	var gold: int = hud.count_item("gold")
	_header.text = "Złoto: %d zł  •  podatek %d%%" % [gold, roundi(float(_data.tax) * 100)]
	_filters.visible = _tab != 4
	match _tab:
		0:
			_tab_offers(gold)
		1:
			_tab_demand()
		2:
			_tab_sell()
		3:
			_tab_order(gold)
		4:
			_tab_mine()


func _q_text(q: int, minimum: bool) -> String:
	if q <= 1:
		return ""
	return " [%s%s]" % ["min. " if minimum else "", GameData.quality_name(q)]


func _tab_offers(gold: int) -> void:
	var n := 0
	for r in _data.sells:
		if not _matches(str(r.item)):
			continue
		n += 1
		var id := str(r.item)
		var q := int(r.q)
		var price := int(r.price)
		var amount := int(r.amount)
		_row(id, "%s%s\n%d zł/szt. • dostępne: %d" % [GameData.item_def(id).name, _q_text(q, false), price, amount], [["Kup", func():
			hud.amount.open({"title": "Kup na rynku", "info": GameData.item_description(id, q),
				"max": maxi(1, mini(amount, gold / maxi(1, price))), "button": "Kup", "price": price, "total": true},
				func(c, p, _q): Net.send({"t": "market_buy", "item": id, "q": q, "price": p, "count": c}))]])
	if n == 0:
		_empty("Brak ofert sprzedaży. Wystaw coś jako pierwszy!")


func _tab_demand() -> void:
	var n := 0
	var bag: Array = hud.bag()
	for r in _data.buys:
		if not _matches(str(r.item)):
			continue
		n += 1
		var id := str(r.item)
		var q := int(r.q)
		var price := int(r.price)
		var amount := int(r.amount)
		# Pierwszy pasujący stos w plecaku (jakość >= wymagana).
		var slot := -1
		for i in bag.size():
			var s = bag[i]
			if s is Dictionary and s.item == id and int(s.get("q", 1)) >= q:
				slot = i
				break
		var buttons := []
		if slot >= 0:
			var have := int(bag[slot].count)
			buttons.append(["Sprzedaj", func():
				hud.amount.open({"title": "Sprzedaj na rynku", "info": GameData.item_description(id, int(bag[slot].get("q", 1))),
					"max": mini(have, amount), "amount": mini(have, amount), "button": "Sprzedaj", "price": price, "total": true},
					func(c, p, _q): Net.send({"t": "market_sell", "slot": slot, "price": p, "count": c}))])
		_row(id, "%s%s\nkupują po %d zł • ilość: %d%s" % [GameData.item_def(id).name, _q_text(q, true), price, amount,
			"" if slot >= 0 else " • (nie masz)"], buttons)
	if n == 0:
		_empty("Nikt niczego nie zamówił.")


## Najniższa cena sprzedaży / najwyższa cena kupna dla przedmiotu (0 = brak).
func _best(side: String, id: String) -> int:
	var best := 0
	for r in _data[side]:
		if r.item == id and (best == 0 or (side == "sells" and int(r.price) < best) or (side == "buys" and int(r.price) > best)):
			best = int(r.price)
	return best


func _tab_sell() -> void:
	var bag: Array = hud.bag()
	var n := 0
	for i in bag.size():
		var s = bag[i]
		if not (s is Dictionary) or s.item == "gold" or not _matches(str(s.item)):
			continue
		n += 1
		var id := str(s.item)
		var q := int(s.get("q", 1))
		var cnt := int(s.count)
		var slot := i
		var best_sell := _best("sells", id)
		var best_buy := _best("buys", id)
		var suggest := best_sell if best_sell > 0 else maxi(1, int(GameData.item_def(id).get("value", 1)))
		var info := "%s ×%d\nnajtańsza oferta: %s • najlepszy popyt: %s" % [GameData.item_label(id, q), cnt,
			("%d zł" % best_sell) if best_sell else "–", ("%d zł" % best_buy) if best_buy else "–"]
		_row(id, info, [["Wystaw", func():
			hud.amount.open({"title": "Wystaw na sprzedaż", "info": GameData.item_label(id, q) + "\nJeśli ktoś zamówił po tej cenie lub wyżej – sprzedasz od razu.",
				"max": cnt, "amount": cnt, "button": "Wystaw", "price": suggest, "total": true},
				func(c, p, _q): Net.send({"t": "market_order", "side": "sell", "slot": slot, "price": p, "count": c}))]])
	if n == 0:
		_empty("Nie masz w plecaku nic do wystawienia.")


func _tab_order(gold: int) -> void:
	var n := 0
	for id in GameData.items:
		if id == "gold" or not _matches(id):
			continue
		n += 1
		var d: Dictionary = GameData.items[id]
		var best_sell := _best("sells", id)
		var suggest := maxi(1, int(d.get("value", 1)))
		var item_id: String = id
		var equip := d.has("slot") or d.has("tool")
		_row(item_id, "%s\nnajtańsza oferta: %s" % [d.name, ("%d zł" % best_sell) if best_sell else "–"], [["Zamów", func():
			hud.amount.open({"title": "Zlecenie kupna", "info": "%s\nZłoto (cena × ilość) zostanie zablokowane do realizacji zlecenia." % d.name,
				"max": maxi(1, mini(10000, gold / suggest)), "button": "Zamów", "price": suggest, "quality": equip, "total": true},
				func(c, p, q): Net.send({"t": "market_order", "side": "buy", "item": item_id, "q": q, "price": p, "count": c}))]])
		if n >= 60:
			_empty("…zawęź filtr, aby zobaczyć więcej.")
			break


func _tab_mine() -> void:
	if _data.mine.is_empty():
		_empty("Nie masz aktywnych zleceń.")
		return
	for o in _data.mine:
		var id := int(o.id)
		var side := "Sprzedaż" if o.side == "sell" else "Kupno"
		_row(str(o.item), "%s: %s%s\n%d szt. po %d zł" % [side, GameData.item_def(str(o.item)).name, _q_text(int(o.q), o.side == "buy"),
			int(o.amount), int(o.price)], [["Anuluj", func(): Net.send({"t": "market_cancel", "id": id})]])
