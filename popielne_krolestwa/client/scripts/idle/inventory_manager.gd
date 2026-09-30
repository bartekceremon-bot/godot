class_name InventoryManager
extends RefCounted
## Plecak: przedmioty liczone (surowce, materiały, mikstury, trofea, skrzynie) w s.inv
## oraz egzemplarze ekwipunku w s.gear: {uid, id („sword_t3”), q (rzadkość 1–5), lvl (ulepszenie)}.

const GEAR_LIMIT := 80

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func count(id: String) -> int:
	return int(gm.s.inv.get(id, 0))


func add(id: String, n: int) -> void:
	if n <= 0:
		return
	gm.s.inv[id] = count(id) + n
	var def := gm.db.item(id)
	if str(def.get("category", "")) == "resource":
		gm.quests.on_event("materials", n)
	gm.quests.on_gather(id, n)
	gm.changed.emit("inventory")


func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	var left := count(id) - n
	if left <= 0:
		gm.s.inv.erase(id)
	else:
		gm.s.inv[id] = left
	gm.changed.emit("inventory")
	return true


func has_all(inputs: Array, times := 1) -> bool:
	for inp in inputs:
		if count(str(inp[0])) < int(inp[1]) * times:
			return false
	return true


func remove_all(inputs: Array, times := 1) -> bool:
	if not has_all(inputs, times):
		return false
	for inp in inputs:
		remove(str(inp[0]), int(inp[1]) * times)
	return true


## Nowy egzemplarz ekwipunku. Zwraca słownik przedmiotu (albo pusty, gdy plecak pełny – wtedy sprzedaż).
func add_gear(id: String, q: int, lvl := 0) -> Dictionary:
	var s := gm.s
	var it := {"uid": int(s.next_uid), "id": id, "q": clampi(q, 1, 5), "lvl": lvl}
	s.next_uid = int(s.next_uid) + 1
	if s.gear.size() >= GEAR_LIMIT:
		var price := gm.shop.sell_price_gear(it)
		gm.add_gold(price)
		gm.notify("Plecak pełny – sprzedano %s za %s zł" % [gm.equipment.gear_name(it), IdleDB.fmt(price)])
		return {}
	s.gear.append(it)
	gm.changed.emit("gear")
	return it


func gear_by_uid(uid: int) -> Dictionary:
	for it in gm.s.gear:
		if int(it.uid) == uid:
			return it
	return {}


func remove_gear(uid: int) -> void:
	var s := gm.s
	for i in s.gear.size():
		if int(s.gear[i].uid) == uid:
			s.gear.remove_at(i)
			break
	gm.changed.emit("gear")


## Posortowana lista przedmiotów liczonych danej kategorii (resource, material, consumable, misc, chest, fragment).
func list_counted(filter: Callable) -> Array:
	var out: Array = []
	for id in gm.s.inv:
		if filter.call(str(id)):
			out.append(str(id))
	out.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
	return out


func _sort_key(id: String) -> String:
	var def := gm.db.item(id)
	return "%s_%d_%s" % [str(def.get("category", "z")), int(def.get("tier", 0)), id]


## Kategoria przedmiotu liczonego (skrzynie i fragmenty wierzchowców mają własne identyfikatory).
func category(id: String) -> String:
	if id.begins_with("chest_"):
		return "chest"
	if id.begins_with("frag_"):
		return "fragment"
	return str(gm.db.item(id).get("category", "misc"))
