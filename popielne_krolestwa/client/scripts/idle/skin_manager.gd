class_name SkinManager
extends RefCounted
## Stroje bohatera: wygląd modelu 3D niezależny od ekwipunku (premie zostają z ekwipunku).
## Odblokowywane postępem. Stan: s.skin = id ("" – wygląd założonego ekwipunku).

## eq: [głowa, tułów, nogi, stopy, broń, tarcza]
const SKINS := [
	{"id": "", "name": "Założony ekwipunek", "eq": [], "req": "", "text": "Wygląd tego, co masz na sobie."},
	{"id": "guard", "name": "Strażnik Popielgrodu", "eq": ["plate_head_t2", "plate_body_t2", "plate_legs_t2", "plate_feet_t2", "sword_t2", "shield_t2"], "req": "stage:10", "text": "Dotrzyj do etapu 10"},
	{"id": "hunter", "name": "Łowca Puszczy", "eq": ["leather_head_t4", "leather_body_t4", "leather_legs_t4", "leather_feet_t4", "bow_t4", ""], "req": "bestiary:15", "text": "15 stopni bestiariusza"},
	{"id": "mage", "name": "Mag Szronogrodu", "eq": ["cloth_head_t6", "cloth_body_t6", "cloth_legs_t6", "cloth_feet_t6", "staff_t6", ""], "req": "spells:500", "text": "Rzuć 500 czarów"},
	{"id": "ashknight", "name": "Rycerz Popiołu", "eq": ["plate_head_t7", "plate_body_t7", "plate_legs_t7", "plate_feet_t7", "sword_t7", "shield_t7"], "req": "tower:20", "text": "20. piętro Wieży Popiołu"},
	{"id": "dragonslayer", "name": "Pogromca Smoka", "eq": ["plate_head_t8", "plate_body_t8", "plate_legs_t8", "plate_feet_t8", "sword_t8", "shield_t8"], "req": "story:outro:fire_temple", "text": "Pokonaj Żarogniewa"},
	{"id": "ashprince", "name": "Popielny Książę", "eq": ["plate_head_t8", "leather_body_t8", "plate_legs_t8", "leather_feet_t8", "staff_t8", ""], "req": "owned:ashprince", "text": "Nagroda 30. poziomu Złotego Karnetu"},
	{"id": "festival", "name": "Mistrz Festynu", "eq": ["cloth_head_t8", "plate_body_t7", "leather_legs_t8", "plate_feet_t8", "mace_t8", "shield_t8"], "req": "owned:festival", "text": "Kram Festynu Żaru (600 lampionów)"},
	{"id": "phoenix", "name": "Feniks", "eq": ["leather_head_t8", "leather_body_t8", "leather_legs_t8", "leather_feet_t8", "axe_t8", ""], "req": "phoenix:1", "text": "Przebudź się jako Feniks"},
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


static func def(id: String) -> Dictionary:
	for s in SKINS:
		if str(s.id) == id:
			return s
	return SKINS[0]


func unlocked(id: String) -> bool:
	var req := str(def(id).req)
	if req == "":
		return true
	var p := req.split(":", true, 1)
	var n := p[1]
	match p[0]:
		"stage":
			return gm.achievements.value("best_stage") >= float(n)
		"bestiary":
			return gm.bestiary.total_tiers() >= int(n)
		"spells":
			return float(gm.s.stats.get("spells", 0)) >= float(n)
		"tower":
			return gm.tower.best() >= int(n)
		"story":
			return gm.story.seen().has(n)
		"phoenix":
			return gm.phoenix.count() >= int(n)
		"owned":
			return (gm.s.get("skins_owned", []) as Array).has(n)
	return false


func give(id: String) -> void:
	if not gm.s.has("skins_owned"):
		gm.s["skins_owned"] = []
	if not gm.s.skins_owned.has(id):
		gm.s.skins_owned.append(id)
	gm.notify("Nowy strój: %s!" % def(id).name, Color(1.0, 0.8, 0.35))


func current() -> String:
	var id := str(gm.s.get("skin", ""))
	return id if unlocked(id) else ""


func select(id: String) -> bool:
	if not unlocked(id):
		return false
	gm.s["skin"] = id
	gm.changed.emit("gear")
	return true


## Lista wyglądu dla modelu 3D: strój albo ekwipunek.
func model(eq: Array) -> Array:
	var d := def(current())
	return eq if (d.eq as Array).is_empty() else d.eq
