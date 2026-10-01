class_name WeeklyManager
extends RefCounted
## Wyzwania tygodnia: co tydzień (od poniedziałku) 7 celów wylosowanych z puli (te same dla
## wszystkich graczy w danym tygodniu). Nagroda za każdy cel i duża nagroda za komplet.
## Postęp z QuestManager.on_event. Stan: s.weekly = {week, prog: {rodzaj: n}, claimed: [i], final}.

## [rodzaj zdarzenia, opis, cel]
const POOL := [
	["bosses", "Pokonaj %d bossów i elit", 40],
	["kills", "Pokonaj %d przeciwników", 4000],
	["dungeon", "Przejdź %d lochów", 6],
	["arena", "Stocz %d pojedynków na Arenie", 8],
	["dream", "Zaśnij %d razy w Śnie Popielnika", 3],
	["wheel", "Zakręć Kołem Żaru %d razy", 4],
	["spells", "Rzuć %d czarów", 250],
	["crafts", "Wytwórz %d przedmiotów", 25],
	["upgrades", "Ulepsz ekwipunek %d razy", 15],
	["expeditions", "Ukończ %d wypraw", 5],
	["tower", "Pokonaj %d pięter Wieży Popiołu", 10],
	["crits", "Zadaj %d trafień krytycznych", 2000],
	["harvest", "Zbierz plony z grządek %d razy", 12],
]
const COUNT := 7
const GOAL_REWARDS := [{"gems": 40}, {"chest": 3}, {"gems": 40}, {"shards": 3}, {"gems": 50}, {"chest": 3}, {"gems": 60}]
const FINAL_REWARD := {"gems": 150, "chest": 5, "shards": 5, "seals": 1}

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("weekly"):
		gm.s["weekly"] = {"week": -1, "prog": {}, "claimed": [], "final": false}
	var w: Dictionary = gm.s.weekly
	if int(w.week) != RaidManager.week_id():
		w.week = RaidManager.week_id()
		w.prog = {}
		w.claimed = []
		w.final = false
	return w


## 7 celów tygodnia (deterministycznie z numeru tygodnia).
func goals() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = RaidManager.week_id() * 7919 + 13
	var idx: Array = []
	for i in POOL.size():
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	var out: Array = []
	for i in COUNT:
		out.append(POOL[idx[i]])
	return out


func on_event(type: String, amount: float) -> void:
	var w := _st()
	for g in goals():
		if str(g[0]) == type:
			w.prog[type] = float(w.prog.get(type, 0.0)) + amount
			gm.changed.emit("weekly")
			return


func progress(i: int) -> float:
	var g: Array = goals()[i]
	return minf(float(_st().prog.get(str(g[0]), 0.0)), float(g[2]))


func done(i: int) -> bool:
	return progress(i) >= float(goals()[i][2])


func claimed(i: int) -> bool:
	return (_st().claimed as Array).has(i)


func ready_count() -> int:
	var n := 0
	for i in COUNT:
		if done(i) and not claimed(i):
			n += 1
	if final_ready():
		n += 1
	return n


func final_ready() -> bool:
	return not bool(_st().final) and (_st().claimed as Array).size() >= COUNT


func _give(r: Dictionary) -> Array:
	var got: Array = []
	if r.has("gems"):
		gm.add_gems(int(r.gems))
		got.append(["gems", int(r.gems)])
	if r.has("chest"):
		gm.inventory.add("chest_%d" % int(r.chest), 1)
		got.append(["chest_%d" % int(r.chest), 1])
	if r.has("shards"):
		gm.relics.add_shards(int(r.shards))
		got.append(["shards", int(r.shards)])
	if r.has("seals"):
		gm.mercs.add_seals(int(r.seals))
		got.append(["seals", int(r.seals)])
	return got


func claim(i: int) -> Array:
	if i < 0 or i >= COUNT or not done(i) or claimed(i):
		return []
	_st().claimed.append(i)
	var got := _give(GOAL_REWARDS[i])
	gm.season.add_xp(15)
	gm.changed.emit("weekly")
	return got


func claim_final() -> Array:
	if not final_ready():
		return []
	_st().final = true
	var got := _give(FINAL_REWARD)
	gm.changed.emit("weekly")
	return got


static func reward_text(r: Dictionary) -> String:
	var p: Array = []
	if r.has("gems"):
		p.append("%d żarokr." % int(r.gems))
	if r.has("chest"):
		p.append(LootManager.CHEST_NAMES[int(r.chest)])
	if r.has("shards"):
		p.append("%d odłamków relikwii" % int(r.shards))
	if r.has("seals"):
		p.append("%d× Pieczęć Przebudzenia" % int(r.seals))
	return ", ".join(PackedStringArray(p))


## Dni do nowego tygodnia (poniedziałek).
static func days_left() -> int:
	return 7 - (int(floor(Time.get_unix_time_from_system() / 86400.0 + 3.0)) % 7)
