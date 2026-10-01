class_name MercenaryManager
extends RefCounted
## Najemnicy (główne źródło DPS i najważniejszy „pochłaniacz” złota) oraz Trening ciosu
## (obrażenia kliknięcia). Koszt rośnie ×1,07 na poziom, kamienie milowe podwajają DPS.

const TRAIN_BASE := 5.0

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func level(id: String) -> int:
	return int(gm.s.mercs.get(id, 0))


## Koszt `count` kolejnych poziomów (suma ciągu geometrycznego).
func cost(id: String, count := 1) -> float:
	return _cost(id, count) * (1.0 - minf(0.5, float(gm.talents.totals().get("merc_cost", 0.0))))


func _cost(id: String, count := 1) -> float:
	var d := gm.db.merc_def(id)
	return _geo(float(d.cost), level(id), count)


func train_cost(count := 1) -> float:
	return _geo(TRAIN_BASE, int(gm.s.train_lvl), count)


func _geo(base: float, lvl: int, count: int) -> float:
	var g := gm.db.merc_growth
	return ceilf(base * pow(g, lvl) * (pow(g, count) - 1.0) / (g - 1.0))


## Ile poziomów stać gracza (dla przycisku „MAKS”).
func affordable(base: float, lvl: int) -> int:
	var g := gm.db.merc_growth
	var gold := float(gm.s.gold)
	var first := base * pow(g, lvl)
	if gold < first:
		return 0
	return maxi(1, int(floor(log(gold * (g - 1.0) / first + 1.0) / log(g))))


func milestone_mult(lvl: int) -> float:
	var m := 1.0
	for ms in gm.db.merc_milestones:
		if lvl >= int(ms):
			m *= 2.0
	return m


func next_milestone(lvl: int) -> int:
	for ms in gm.db.merc_milestones:
		if lvl < int(ms):
			return int(ms)
	return 0


func dps(id: String, lvl := -1) -> float:
	if lvl < 0:
		lvl = level(id)
	if lvl <= 0:
		return 0.0
	return float(gm.db.merc_def(id).dps) * lvl * milestone_mult(lvl)


func total_dps() -> float:
	var t := 0.0
	for d in gm.db.mercs:
		t += dps(str(d.id))
	return t


func buy(id: String, count := 1) -> bool:
	var d := gm.db.merc_def(id)
	if d.is_empty():
		return false
	if count <= 0:
		count = affordable(float(d.cost), level(id))
	if count <= 0:
		return false
	var c := cost(id, count)
	if not gm.spend_gold(c):
		return false
	var before := level(id)
	gm.s.mercs[id] = before + count
	if before == 0:
		gm.notify("%s dołącza do drużyny!" % d.name, Color(0.7, 0.9, 1.0))
	elif milestone_mult(before + count) > milestone_mult(before):
		gm.notify("%s: kamień milowy – DPS ×2!" % d.name, Color(1.0, 0.8, 0.3))
	gm.quests.on_event("mercs", count)
	gm.stats.recalc()
	gm.changed.emit("mercs")
	return true


func buy_train(count := 1) -> bool:
	if count <= 0:
		count = affordable(TRAIN_BASE, int(gm.s.train_lvl))
	if count <= 0:
		return false
	if not gm.spend_gold(train_cost(count)):
		return false
	gm.s.train_lvl = int(gm.s.train_lvl) + count
	gm.stats.recalc()
	gm.changed.emit("mercs")
	return true


## Widoczni najemnicy: wszyscy wynajęci + dwóch kolejnych.
func visible_list() -> Array:
	var out: Array = []
	var extra := 0
	for d in gm.db.mercs:
		if level(str(d.id)) > 0:
			out.append(d)
		elif extra < 2:
			out.append(d)
			extra += 1
	return out
