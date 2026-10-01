class_name TalentManager
extends RefCounted
## Drzewko talentów: trzy gałęzie (Wojownik, Dowódca, Mistyk) po 6 węzłów.
## Punkty są stałe (nie znikają po odrodzeniu): połowa najwyższego osiągniętego poziomu
## + 1 za każde 5 pięter Wieży Popiołu. Węzeł n gałęzi wymaga 4·n punktów wydanych w tej gałęzi.
## Stan: s.talents = {id: ranga}, s.talent_resets.

const BRANCHES := [
	{"id": "war", "name": "Wojownik", "color": Color(1.0, 0.42, 0.25), "icon": "attack", "nodes": [
		{"id": "heavy_hand", "name": "Ciężka ręka", "max": 20, "stat": "click", "per": 0.10, "text": "+%s obrażeń ciosu"},
		{"id": "hawk_eye", "name": "Oko sokoła", "max": 15, "stat": "crit", "per": 0.01, "text": "+%s szansy krytyka"},
		{"id": "butcher", "name": "Rzeźnik", "max": 20, "stat": "critdmg", "per": 0.10, "text": "+%s obrażeń krytycznych"},
		{"id": "fury", "name": "Furia", "max": 15, "stat": "speed", "per": 0.02, "text": "+%s szybkości ataku"},
		{"id": "slayer", "name": "Pogromca", "max": 20, "stat": "boss", "per": 0.05, "text": "+%s obrażeń bossom"},
		{"id": "wrath", "name": "Gniew Żarogniewa", "max": 5, "stat": "damage", "per": 0.25, "text": "+%s wszystkich obrażeń"},
	]},
	{"id": "lead", "name": "Dowódca", "color": Color(1.0, 0.8, 0.3), "icon": "character", "nodes": [
		{"id": "wages", "name": "Żołd", "max": 20, "stat": "merc", "per": 0.08, "text": "+%s DPS najemników"},
		{"id": "plunder", "name": "Łupieżca", "max": 20, "stat": "gold", "per": 0.05, "text": "+%s złota"},
		{"id": "quarter", "name": "Kwatermistrz", "max": 15, "stat": "merc_cost", "per": 0.01, "text": "-%s kosztu najemników"},
		{"id": "academy", "name": "Szkoła wojenna", "max": 20, "stat": "xp", "per": 0.05, "text": "+%s doświadczenia"},
		{"id": "scouts", "name": "Zwiadowcy", "max": 10, "stat": "exped", "per": 0.06, "text": "+%s łupu z wypraw, krótsze wyprawy"},
		{"id": "banner", "name": "Sztandar Popielgrodu", "max": 5, "stat": "banner", "per": 0.15, "text": "+%s DPS najemników i złota"},
	]},
	{"id": "myst", "name": "Mistyk", "color": Color(0.45, 0.7, 1.0), "icon": "book", "nodes": [
		{"id": "mana_well", "name": "Głębia many", "max": 20, "stat": "mp", "per": 0.05, "text": "+%s many"},
		{"id": "ember_might", "name": "Moc żaru", "max": 20, "stat": "spell", "per": 0.06, "text": "+%s siły czarów"},
		{"id": "focus", "name": "Skupienie", "max": 15, "stat": "cdr", "per": 0.02, "text": "-%s odnowienia czarów"},
		{"id": "dreamer", "name": "Senne czuwanie", "max": 15, "stat": "offline", "per": 0.03, "text": "+%s postępu offline"},
		{"id": "fortune", "name": "Szczęście", "max": 15, "stat": "loot", "per": 0.03, "text": "+%s szansy na łup"},
		{"id": "archmage", "name": "Arcymag", "max": 5, "stat": "archmage", "per": 0.2, "text": "+%s siły czarów, połowa tego do obrażeń"},
	]},
]
const RESET_COST := 100

var gm: IdleGame
var _totals: Dictionary = {}
var _dirty := true


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("talents"):
		gm.s["talents"] = {}
	return gm.s.talents


func rank(id: String) -> int:
	return int(_st().get(id, 0))


func earned() -> int:
	return int(gm.achievements.value("best_level") / 2.0) + int(gm.tower.best() / 5)


func spent() -> int:
	var n := 0
	for k in _st():
		n += int(_st()[k])
	return n


func free_points() -> int:
	return earned() - spent()


func branch_spent(b: Dictionary) -> int:
	var n := 0
	for nd in b.nodes:
		n += rank(str(nd.id))
	return n


static func node_req(index: int) -> int:
	return index * 4


func find(id: String) -> Array:
	for b in BRANCHES:
		for i in b.nodes.size():
			if str(b.nodes[i].id) == id:
				return [b, i]
	return []


func can_learn(id: String) -> bool:
	var f := find(id)
	if f.is_empty() or free_points() <= 0:
		return false
	var b: Dictionary = f[0]
	var i: int = f[1]
	return rank(id) < int(b.nodes[i].max) and branch_spent(b) >= node_req(i)


func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	_st()[id] = rank(id) + 1
	_dirty = true
	gm.stats.recalc()
	gm.changed.emit("talents")
	return true


func reset_cost() -> int:
	return 0 if int(gm.s.get("talent_resets", 0)) == 0 else RESET_COST


func reset() -> bool:
	if spent() == 0 or not gm.spend_gems(reset_cost()):
		return false
	gm.s["talent_resets"] = int(gm.s.get("talent_resets", 0)) + 1
	gm.s.talents = {}
	_dirty = true
	gm.stats.recalc()
	gm.changed.emit("talents")
	return true


## Suma premii: {stat: wartość}.
func totals() -> Dictionary:
	if not _dirty and not _totals.is_empty():
		return _totals
	var t := {}
	for b in BRANCHES:
		for nd in b.nodes:
			var r := rank(str(nd.id))
			if r > 0:
				t[str(nd.stat)] = float(t.get(str(nd.stat), 0.0)) + r * float(nd.per)
	_totals = t
	_dirty = false
	return t


func mark_dirty() -> void:
	_dirty = true
