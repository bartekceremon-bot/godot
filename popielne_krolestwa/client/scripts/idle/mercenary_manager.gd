class_name MercenaryManager
extends RefCounted
## Najemnicy (główne źródło DPS i najważniejszy „pochłaniacz” złota) oraz Trening ciosu
## (obrażenia kliknięcia). Koszt rośnie ×1,07 na poziom, kamienie milowe podwajają DPS.

const TRAIN_BASE := 5.0
## Przebudzenie: maks. gwiazdek, mnożnik DPS za gwiazdkę, wymagany poziom na gwiazdkę.
const MAX_STARS := 5
const STAR_MULT := 3.0
const STAR_LEVEL := 100

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
	return float(gm.db.merc_def(id).dps) * lvl * milestone_mult(lvl) * pow(STAR_MULT, stars(id))


func total_dps() -> float:
	var t := 0.0
	for d in gm.db.mercs:
		t += dps(str(d.id))
	return t


# --- Przebudzenie (gwiazdki zostają po odrodzeniu) ---------------------------------

func stars(id: String) -> int:
	return int(gm.s.get("merc_stars", {}).get(id, 0))


func seals() -> int:
	return int(gm.s.get("seals", 0))


func add_seals(n: int) -> void:
	gm.s["seals"] = seals() + n
	gm.changed.emit("mercs")


## Pieczęcie na kolejną gwiazdkę: 1, 2, 4, 8, 16.
func awaken_cost(id: String) -> int:
	return 1 << stars(id)


func awaken_level(id: String) -> int:
	return STAR_LEVEL * (stars(id) + 1)


func can_awaken(id: String) -> bool:
	return stars(id) < MAX_STARS and level(id) >= awaken_level(id) and seals() >= awaken_cost(id)


func awaken(id: String) -> bool:
	if not can_awaken(id):
		return false
	gm.s["seals"] = seals() - awaken_cost(id)
	if not gm.s.has("merc_stars"):
		gm.s["merc_stars"] = {}
	gm.s.merc_stars[id] = stars(id) + 1
	gm.notify("%s: przebudzenie ★%d – DPS ×%d!" % [gm.db.merc_def(id).name, stars(id), int(STAR_MULT)], Color(1.0, 0.85, 0.35))
	gm.audio.play("rare")
	gm.stats.recalc()
	gm.changed.emit("mercs")
	return true


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
