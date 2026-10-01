class_name DreamManager
extends RefCounted
## Sen Popielnika (od etapu 40): tryb roguelike. Kolejne piętra snu z coraz silniejszymi
## zjawami (20 s na piętro); po każdym zwycięstwie wybór 1 z 3 losowych błogosławieństw
## działających do końca snu. Za wynik – Okruchy Snu na stałe ulepszenia (Drzewo Snu).
## Siła zjaw liczona od siły bohatera na początku snu – tryb jest dostępny dla każdego.
## Stan: s.dream = {shards, best, day, free, paid, tree: {id: poziom}, runs}.

const UNLOCK_STAGE := 40
const TIME := 20.0
const HP_GROWTH := 1.25
const PAID_COST := 50
const PAID_LIMIT := 2
## [nazwa, opis] – efekty w damage_mult / taken_mult / crit_bonus itd.
const BLESSINGS := {
	"blade": ["Ostrze Snu", "+60% obrażeń ciosu"],
	"pack": ["Wataha Snu", "+80% obrażeń najemników"],
	"moon": ["Krwawy Księżyc", "+15% szansy krytyka"],
	"fury": ["Żar w Żyłach", "krytyki zadają ×1,5 obrażeń"],
	"clock": ["Klepsydra", "+5 s na każde piętro"],
	"stone": ["Kamienna Skóra", "−35% otrzymywanych obrażeń"],
	"spark": ["Rój Iskier", "czary zadają ×2 obrażenia"],
	"greed": ["Sen o Skarbach", "+50% Okruchów Snu"],
	"echo": ["Echo Ciosu", "20% szansy na podwójny cios"],
	"vision": ["Wizja Smoka", "+30% wszystkich obrażeń"],
}
## Drzewo Snu: [nazwa, opis, maks. poziom, koszt bazowy]
const TREE := {
	"power": ["Siła Snu", "+4% obrażeń na stałe za poziom", 25, 10],
	"gold": ["Złote Sny", "+5% złota na stałe za poziom", 20, 10],
	"time": ["Długi Sen", "+1 s na piętro snu za poziom", 5, 30],
	"start": ["Jasnowidzenie", "+1 błogosławieństwo na start snu za poziom", 3, 60],
}

var gm: IdleGame
var active := false
var floor_n := 0
## Błogosławieństwa bieżącego snu (mogą się powtarzać – kumulują się).
var blessings: Array = []
## Oczekiwanie na wybór błogosławieństwa (3 propozycje).
var choosing := false
var options: Array = []
var last_run: Dictionary = {}
var _power := 1.0
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("dream"):
		gm.s["dream"] = {"shards": 0, "best": 0, "day": "", "free": 1, "paid": 0, "tree": {}, "runs": 0}
	var d: Dictionary = gm.s.dream
	if str(d.day) != DailyManager.today():
		d.day = DailyManager.today()
		d.free = 1
		d.paid = 0
	return d


func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= UNLOCK_STAGE


func shards() -> int:
	return int(_st().shards)


func best() -> int:
	return int(_st().best)


func free_runs() -> int:
	return int(_st().free)


func paid_today() -> int:
	return int(_st().paid)


func tree_level(id: String) -> int:
	return int(_st().tree.get(id, 0))


func tree_cost(id: String) -> int:
	return int(TREE[id][3]) * (tree_level(id) + 1)


func can_upgrade(id: String) -> bool:
	return tree_level(id) < int(TREE[id][2]) and shards() >= tree_cost(id)


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var st := _st()
	st.shards = shards() - tree_cost(id)
	st.tree[id] = tree_level(id) + 1
	gm.stats.mark_dirty()
	gm.changed.emit("dream")
	return true


## Stałe premie Drzewa Snu do PlayerStats (klucze jak runy).
func totals() -> Dictionary:
	var t := {}
	if tree_level("power") > 0:
		t["dmg"] = 0.04 * tree_level("power")
	if tree_level("gold") > 0:
		t["gold"] = 0.05 * tree_level("gold")
	return t


func can_enter(use_gems := false) -> bool:
	if not gm.running or gm.challenge() != null or not unlocked():
		return false
	return free_runs() > 0 or (use_gems and paid_today() < PAID_LIMIT and int(gm.s.gems) >= PAID_COST)


func enter(use_gems := false) -> bool:
	if not can_enter(use_gems):
		return false
	var st := _st()
	if free_runs() > 0:
		st.free = free_runs() - 1
	else:
		gm.spend_gems(PAID_COST)
		st.paid = paid_today() + 1
	st.runs = int(st.runs) + 1
	var s := gm.stats
	_power = maxf(1.0, s.dps + s.click * 5.0)
	active = true
	floor_n = 1
	blessings = []
	choosing = false
	options = []
	gm.combat.heal_full()
	# Jasnowidzenie: błogosławieństwa na start (losowe).
	for i in tree_level("start"):
		blessings.append(_random_blessings(1)[0])
	gm.stats.mark_dirty()
	gm.enemy.spawn()
	gm.changed.emit("dream")
	return true


func floor_hp(f: int) -> float:
	return _power * 0.35 * pow(HP_GROWTH, f - 1)


func floor_time() -> float:
	return TIME + 5.0 * count("clock") + tree_level("time")


func make_enemy() -> Dictionary:
	var regs: Array = gm.db.regions
	var reg: Dictionary = regs[(floor_n - 1) % regs.size()]
	var b: Dictionary = reg.boss if floor_n % 5 == 0 else reg.elite
	var mid := str(b.monster)
	var md := gm.db.monster(mid)
	var hp := floor_hp(floor_n) * (1.5 if floor_n % 5 == 0 else 1.0)
	var e := {"monster": mid, "name": "%s – sen %d" % [str(b.name), floor_n], "look": str(md.get("look", mid)), "max_hp": hp, "hp": hp, "kind": 2,
		"stage": maxi(1, int(gm.s.max_stage) - 10 + floor_n), "time_left": floor_time(), "time_max": floor_time(), "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0,
		"undead": gm.db.undead.has(mid), "challenge": "dream"}
	if choosing:
		e["hold"] = true
		e["frozen"] = 9999.0
	return e


func count(id: String) -> int:
	return blessings.count(id)


func _random_blessings(n: int) -> Array:
	var keys := BLESSINGS.keys()
	var out: Array = []
	while out.size() < n:
		var k: String = keys[_rng.randi() % keys.size()]
		if not out.has(k):
			out.append(k)
	return out


## Mnożnik obrażeń wg źródła ("tap", "auto", "spell", "dot").
func damage_mult(source: String) -> float:
	var m := pow(1.3, count("vision"))
	match source:
		"tap":
			m *= pow(1.6, count("blade"))
		"auto":
			m *= pow(1.8, count("pack"))
		"spell", "dot":
			m *= pow(2.0, count("spark"))
	return m


func crit_bonus() -> float:
	return 0.15 * count("moon")


func crit_mult() -> float:
	return pow(1.5, count("fury"))


func echo_chance() -> float:
	return minf(0.8, 0.2 * count("echo"))


func taken_mult() -> float:
	return pow(0.65, count("stone"))


func on_kill(_e: Dictionary) -> void:
	gm.bestiary.on_kill(str(_e.monster))
	var st := _st()
	if floor_n > best():
		st.best = floor_n
	floor_n += 1
	choosing = true
	options = _random_blessings(3)
	gm.combat.heal(0.4)
	gm.audio.play("levelup")
	gm.changed.emit("dream")


## Wybór błogosławieństwa – następne piętro rusza.
func choose(i: int) -> bool:
	if not choosing or i < 0 or i >= options.size():
		return false
	blessings.append(options[i])
	choosing = false
	options = []
	gm.stats.mark_dirty()
	var e := gm.enemy.cur
	if e.has("hold"):
		e.erase("hold")
		e.frozen = 0.0
	gm.changed.emit("dream")
	return true


func reward_for(floors_cleared: int) -> int:
	var r := floors_cleared * 2 + (10 if floors_cleared >= 10 else 0) + (20 if floors_cleared >= 20 else 0) + (40 if floors_cleared >= 30 else 0)
	return int(round(r * (1.0 + 0.5 * count("greed"))))


func on_fail(reason: String) -> void:
	if not active:
		return
	active = false
	var cleared := floor_n - 1
	var got := reward_for(cleared)
	var st := _st()
	st.shards = shards() + got
	gm.season.add_xp(10 + cleared)
	gm.quests.on_event("dream", 1)
	last_run = {"floors": cleared, "shards": got, "blessings": blessings.duplicate(), "reason": reason}
	choosing = false
	options = []
	blessings = []
	gm.stats.mark_dirty()
	gm.combat.heal_full()
	gm.save.save_game()
	gm.changed.emit("dream")
	gm.toast.emit("Sen Popielnika: %d pięter, +%d Okruchów Snu (%s)" % [cleared, got, reason], Color(0.7, 0.6, 1.0))


func leave() -> void:
	if active:
		on_fail("przebudzenie")
		gm.enemy.spawn()


func hud_text() -> String:
	return "SEN POPIELNIKA  •  piętro %d  •  rekord %d" % [floor_n, best()]
