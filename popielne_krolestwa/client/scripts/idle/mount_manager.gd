class_name MountManager
extends RefCounted
## Wierzchowce MMO (koń, łoś, wielbłąd, wilk bojowy, drake) jako stałe premie.
## Odblokowanie fragmentami (bossowie, skrzynie) albo zakupem; ulepszanie fragmentami i złotem.

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func level(id: String) -> int:
	return int(gm.s.mounts.get(id, 0))


func frags(id: String) -> int:
	return gm.inventory.count("frag_" + id)


func bonus(id: String, lvl := -1) -> float:
	if lvl < 0:
		lvl = level(id)
	if lvl <= 0:
		return 0.0
	var b := float(gm.db.mount_def(id).bonus)
	return b * (1.0 + 0.5 * (lvl - 1))


func totals() -> Dictionary:
	var t := {}
	for m in gm.db.mounts:
		var v := bonus(str(m.id))
		if v > 0.0:
			t[str(m.stat)] = float(t.get(str(m.stat), 0.0)) + v
	return t


## Koszt następnego poziomu: {frags, gold}; poziom 0 -> odblokowanie.
func next_cost(id: String) -> Dictionary:
	var d := gm.db.mount_def(id)
	var lvl := level(id)
	if lvl == 0:
		return {"frags": int(d.unlock_frags), "gold": 0.0}
	return {"frags": int(d.unlock_frags) / 2 + lvl * 3, "gold": ceilf(ProgressionManager.gold_for(int(gm.s.max_stage)) * 30.0 * pow(1.5, lvl))}


func can_upgrade(id: String) -> bool:
	var c := next_cost(id)
	return frags(id) >= int(c.frags) and float(gm.s.gold) >= float(c.gold)


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var c := next_cost(id)
	gm.inventory.remove("frag_" + id, int(c.frags))
	gm.spend_gold(float(c.gold))
	_level_up(id)
	return true


## Zakup: koń za złoto (od etapu), wilk bojowy za żarokryształy.
func buy_price(id: String) -> Dictionary:
	var d := gm.db.mount_def(id)
	if d.has("buy_gold_stage"):
		return {"gold": ceilf(ProgressionManager.gold_for(int(d.buy_gold_stage)) * 150.0), "stage": int(d.buy_gold_stage)}
	if d.has("buy_gems"):
		return {"gems": int(d.buy_gems)}
	return {}


func buy(id: String) -> bool:
	if level(id) > 0:
		return false
	var p := buy_price(id)
	if p.is_empty():
		return false
	if p.has("gold"):
		if int(gm.s.max_stage) < int(p.stage) or not gm.spend_gold(float(p.gold)):
			return false
	elif not gm.spend_gems(int(p.gems)):
		return false
	_level_up(id)
	return true


func _level_up(id: String) -> void:
	gm.s.mounts[id] = level(id) + 1
	var name := gm.db.item_name(id)
	gm.notify("%s – poziom %d!" % [name, level(id)] if level(id) > 1 else "Nowy wierzchowiec: %s!" % name, Color(1.0, 0.8, 0.3))
	gm.audio.play("rare")
	gm.stats.recalc()
	gm.changed.emit("mounts")
