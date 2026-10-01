class_name BestiaryManager
extends RefCounted
## Bestiariusz: licznik zabitych potworów każdego gatunku. Progi 10 / 100 / 1000 / 10 000
## dają na stałe po +1% obrażeń i +1% złota (cała kolekcja). Stan: s.bestiary = {id: zabici}.

const TIERS := [10, 100, 1000, 10000]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("bestiary"):
		gm.s["bestiary"] = {}
	return gm.s.bestiary


func kills(id: String) -> int:
	return int(_st().get(id, 0))


static func tier_of(n: int) -> int:
	var t := 0
	for need in TIERS:
		if n >= need:
			t += 1
	return t


func on_kill(id: String) -> void:
	var before := tier_of(kills(id))
	_st()[id] = kills(id) + 1
	var after := tier_of(kills(id))
	if after > before:
		gm.stats.mark_dirty()
		gm.notify("Bestiariusz: %s – stopień %d (+1%% obrażeń i złota)" % [gm.db.monster(id).get("name", id), after], Color(0.8, 0.9, 0.6))


func total_tiers() -> int:
	var n := 0
	for id in _st():
		n += tier_of(int(_st()[id]))
	return n


## Wszystkie gatunki ze wszystkich krain (zwykli, elity, bossowie) – kolejność odkrywania.
func all_species() -> Array:
	var out: Array = []
	for reg in gm.db.regions:
		var list: Array = reg.monsters.duplicate()
		list.append(str(reg.elite.monster))
		list.append(str(reg.boss.monster))
		for m in list:
			if not out.has(str(m)):
				out.append(str(m))
	return out


func bonus() -> float:
	return total_tiers() * 0.01
