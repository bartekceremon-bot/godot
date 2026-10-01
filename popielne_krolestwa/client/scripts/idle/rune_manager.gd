class_name RuneManager
extends RefCounted
## Runy: kamienie z mocą wkładane w gniazda slotów ekwipunku (gniazda należą do slotów, więc
## zostają przy zmianie przedmiotów i po odrodzeniu). 6 rodzajów × 5 stopni; 3 runy stopnia n
## łączą się w 1 runę stopnia n+1. Wypadają z bossów, elit, Wieży, wypraw i skrzyń.
## Stan: s.runes = {slot: [id|"" ...]} (2 gniazda, trzecie za żarokryształy); runy w s.inv jako "rune_<rodzaj>_<stopień>".

const KINDS := {
	"fire": {"name": "Ognia", "stat": "dmg", "vals": [0.05, 0.12, 0.25, 0.45, 0.8], "color": Color(1.0, 0.4, 0.15), "text": "obrażeń"},
	"blood": {"name": "Krwi", "stat": "crit", "vals": [0.01, 0.02, 0.04, 0.06, 0.09], "color": Color(0.9, 0.12, 0.2), "text": "szansy krytyka"},
	"ember": {"name": "Żaru", "stat": "critdmg", "vals": [0.1, 0.25, 0.5, 0.9, 1.5], "color": Color(1.0, 0.7, 0.2), "text": "obrażeń krytycznych"},
	"gold": {"name": "Złota", "stat": "gold", "vals": [0.05, 0.12, 0.25, 0.45, 0.8], "color": Color(1.0, 0.86, 0.3), "text": "złota"},
	"mind": {"name": "Mądrości", "stat": "xp", "vals": [0.05, 0.12, 0.25, 0.45, 0.8], "color": Color(0.6, 0.45, 1.0), "text": "doświadczenia"},
	"wind": {"name": "Wichru", "stat": "speed", "vals": [0.02, 0.05, 0.09, 0.14, 0.2], "color": Color(0.45, 0.9, 1.0), "text": "szybkości ataku"},
}
const TIER_NAMES := ["Okruch", "Runa", "Wielka runa", "Pradawna runa", "Popielna runa"]
const BASE_SOCKETS := 2
const THIRD_SOCKET_GEMS := 150

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("runes"):
		gm.s["runes"] = {}
	var st: Dictionary = gm.s.runes
	for slot in IdleDB.SLOTS:
		if not st.has(slot):
			st[slot] = []
			for i in BASE_SOCKETS:
				st[slot].append("")
	return st


static func rid(kind: String, tier: int) -> String:
	return "rune_%s_%d" % [kind, tier]


static func parse(id: String) -> Array:
	var p := id.split("_")
	return [p[1], int(p[2])] if p.size() == 3 else ["", 0]


static func rune_name(id: String) -> String:
	var p := parse(id)
	if not KINDS.has(p[0]):
		return id
	return "%s %s" % [TIER_NAMES[clampi(int(p[1]) - 1, 0, 4)], KINDS[p[0]].name]


static func value(id: String) -> float:
	var p := parse(id)
	return float(KINDS[p[0]].vals[clampi(int(p[1]) - 1, 0, 4)]) if KINDS.has(p[0]) else 0.0


static func describe(id: String) -> String:
	var p := parse(id)
	if not KINDS.has(p[0]):
		return ""
	return "+%d%% %s" % [roundi(value(id) * 100.0), KINDS[p[0]].text]


func sockets(slot: String) -> Array:
	return _st()[slot]


func socket(slot: String, i: int, id: String) -> bool:
	var sk := sockets(slot)
	if i < 0 or i >= sk.size() or gm.inventory.count(id) <= 0:
		return false
	if str(sk[i]) != "":
		gm.inventory.add(str(sk[i]), 1)
	gm.inventory.remove(id, 1)
	sk[i] = id
	gm.stats.mark_dirty()
	gm.changed.emit("runes")
	return true


func unsocket(slot: String, i: int) -> bool:
	var sk := sockets(slot)
	if i < 0 or i >= sk.size() or str(sk[i]) == "":
		return false
	gm.inventory.add(str(sk[i]), 1)
	sk[i] = ""
	gm.stats.mark_dirty()
	gm.changed.emit("runes")
	return true


func buy_socket(slot: String) -> bool:
	var sk := sockets(slot)
	if sk.size() >= BASE_SOCKETS + 1 or not gm.spend_gems(THIRD_SOCKET_GEMS):
		return false
	sk.append("")
	gm.changed.emit("runes")
	return true


## Koszt łączenia 3 run stopnia t w złocie (rośnie z etapem, żeby złoto miało cel do końca).
func combine_cost(tier: int) -> float:
	return ProgressionManager.gold_for(int(gm.s.max_stage)) * 30.0 * pow(3.0, tier - 1)


func combine(kind: String, tier: int) -> bool:
	var id := rid(kind, tier)
	if tier >= 5 or gm.inventory.count(id) < 3 or not gm.spend_gold(combine_cost(tier)):
		return false
	gm.inventory.remove(id, 3)
	gm.inventory.add(rid(kind, tier + 1), 1)
	gm.audio.play("rare")
	gm.changed.emit("runes")
	return true


## Losowa runa; stopień zależy od źródła (0..1 = siła źródła).
func random_rune(power: float) -> String:
	var keys := KINDS.keys()
	var kind: String = keys[_rng.randi() % keys.size()]
	var t := 1
	var p := clampf(power, 0.0, 1.0)
	for i in 4:
		if _rng.randf() < 0.18 + p * 0.45:
			t += 1
		else:
			break
	return rid(kind, mini(t, 1 + int(p * 4.0)))


func give(id: String, n := 1) -> void:
	gm.inventory.add(id, n)


## Suma premii z włożonych run: {stat: wartość}.
func totals() -> Dictionary:
	var t := {}
	for slot in _st():
		for id in _st()[slot]:
			if str(id) != "":
				var p := parse(str(id))
				var stat: String = KINDS[p[0]].stat
				t[stat] = float(t.get(stat, 0.0)) + value(str(id))
	return t


func owned() -> Array:
	var out: Array = []
	for id in gm.s.inv:
		if str(id).begins_with("rune_") and int(gm.s.inv[id]) > 0:
			out.append(str(id))
	out.sort()
	return out
