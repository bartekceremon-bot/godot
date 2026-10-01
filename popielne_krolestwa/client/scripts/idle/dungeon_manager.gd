class_name DungeonManager
extends RefCounted
## Lochy Żaru: trzy rodzaje lochów z codziennymi kluczami. Wejście = 45 s na pokonanie
## 10 strażników; każdy zabity daje łup rodzaju lochu, pokonanie wszystkich – nagrodę
## końcową (odłamki relikwii) i odblokowanie wyższego poziomu.
## Stan: s.dungeon = {day, keys: {rodzaj: n}, best: {rodzaj: poziom}, clears}.

const TIME := 45.0
const GUARDS := 10
const DAILY_KEYS := 2
const EXTRA_COST := 30
const KINDS := {
	"gold": {"name": "Skarbiec Goblinów", "text": "Dużo złota za każdego strażnika.", "regions": [3, 4], "icon": "gold", "color": Color(1.0, 0.82, 0.3)},
	"gems": {"name": "Kopalnia Żaru", "text": "Żarokryształy i runy.", "regions": [6, 7], "icon": "gem", "color": Color(1.0, 0.45, 0.25)},
	"mats": {"name": "Kuźnia Przodków", "text": "Surowce do rzemiosła i skrzynie.", "regions": [1, 2, 5], "icon": "craft", "color": Color(0.55, 0.85, 1.0)},
}
const ORDER := ["gold", "gems", "mats"]

var gm: IdleGame
var active := false
var kind := ""
var tier := 1
var kills := 0
var _time := TIME
var _rng := RandomNumberGenerator.new()
## Łup bieżącego przejścia: {gold, gems, runes, mats, chests, shards}.
var run: Dictionary = {}
## Podsumowanie ostatniego przejścia (okno wyniku).
var last_run: Dictionary = {}


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("dungeon"):
		gm.s["dungeon"] = {"day": "", "keys": {}, "best": {}, "clears": 0}
	var d: Dictionary = gm.s.dungeon
	if str(d.day) != DailyManager.today():
		d.day = DailyManager.today()
		for k in ORDER:
			d.keys[k] = DAILY_KEYS + int(gm.events.bonus("dungeon"))
	return d


func keys(k: String) -> int:
	return int(_st().keys.get(k, 0))


func total_keys() -> int:
	var n := 0
	for k in ORDER:
		n += keys(k)
	return n


## Najwyższy pokonany poziom lochu (0 – jeszcze żaden).
func best(k: String) -> int:
	return int(_st().best.get(k, 0))


## Najwyższy poziom, do którego można wejść (doświadczeni gracze zaczynają od poziomu polecanego).
func max_tier(k: String) -> int:
	return maxi(best(k) + 1, recommended_tier())


## Lochy otwierają się od etapu 15.
func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= 15


static func tier_stage(t: int) -> int:
	return 5 + t * 5


func guard_hp(t: int) -> float:
	return ProgressionManager.enemy_hp(tier_stage(t)) * 1.6


## Poziom polecany do szybkiego przejścia: ok. 5 etapów poniżej bieżącego postępu.
func recommended_tier() -> int:
	return clampi(int((int(gm.s.max_stage) - 10) / 5), 1, 999)


func can_enter() -> bool:
	return gm.running and gm.challenge() == null and unlocked()


func enter(k: String, t: int, use_gems := false) -> bool:
	if not can_enter() or not KINDS.has(k) or t < 1 or t > max_tier(k):
		return false
	var st := _st()
	if keys(k) > 0:
		st.keys[k] = keys(k) - 1
	elif not (use_gems and gm.spend_gems(EXTRA_COST)):
		return false
	active = true
	kind = k
	tier = t
	kills = 0
	_time = TIME
	run = {"gold": 0.0, "gems": 0, "runes": 0, "mats": 0, "chests": 0, "shards": 0}
	gm.combat.heal_full()
	gm.enemy.spawn()
	gm.changed.emit("dungeon")
	return true


func make_enemy() -> Dictionary:
	var regs: Array = gm.db.regions
	var ri: Array = KINDS[kind].regions
	var reg: Dictionary = regs[int(ri[(tier + kills) % ri.size()]) % regs.size()]
	var last := kills == GUARDS - 1
	var mid := str(reg.elite.monster) if last else str(reg.monsters[_rng.randi() % reg.monsters.size()])
	var md := gm.db.monster(mid)
	var hp := guard_hp(tier) * (3.0 if last else 1.0)
	var nm := "%s – strażnik %d/%d" % [str(md.get("name", mid)), kills + 1, GUARDS]
	return {"monster": mid, "name": nm, "look": str(md.get("look", mid)), "max_hp": hp, "hp": hp, "kind": 1,
		"stage": tier_stage(tier), "time_left": _time, "time_max": TIME, "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0,
		"undead": gm.db.undead.has(mid), "challenge": "dungeon"}


func on_kill(e: Dictionary) -> void:
	_time = maxf(1.0, float(e.get("time_left", _time)))
	kills += 1
	gm.bestiary.on_kill(str(e.monster))
	var stage := tier_stage(tier)
	# Tydzień Lochów: podwójny łup.
	var mult := 1.0 + gm.events.bonus("dungeon")
	match kind:
		"gold":
			var g := ProgressionManager.gold_for(stage) * 30.0 * gm.stats.gold_mult * mult
			gm.add_gold(g)
			run.gold = float(run.gold) + g
		"gems":
			var n := (1 + int(tier / 6)) * int(mult)
			gm.add_gems(n)
			run.gems = int(run.gems) + n
			if _rng.randf() < 0.18:
				gm.inventory.add(gm.runes.random_rune(clampf(tier / 25.0, 0.0, 1.0)), 1)
				run.runes = int(run.runes) + 1
		"mats":
			var n := (3 + int(tier / 2)) * int(mult)
			for i in 2:
				gm.inventory.add(gm.loot.random_material(stage), n)
			run.mats = int(run.mats) + n * 2
			if _rng.randf() < 0.08:
				gm.inventory.add("chest_%d" % clampi(1 + int(tier / 8), 1, 4), 1)
				run.chests = int(run.chests) + 1
	gm.enemy_killed.emit({"name": e.name, "monster": e.monster, "gold": 0.0, "xp": 0.0, "boss": 1, "gems": 0})
	if kills >= GUARDS:
		_finish(true, "loch oczyszczony!")
	else:
		gm.changed.emit("dungeon")


func on_fail(reason: String) -> void:
	_finish(false, reason)


func _finish(cleared: bool, reason: String) -> void:
	if not active:
		return
	active = false
	var st := _st()
	var unlocked_next := false
	if cleared:
		var sh := 2 + int(tier / 10) + (1 if kind == "gems" else 0)
		gm.relics.add_shards(sh)
		run.shards = sh
		st.clears = int(st.clears) + 1
		if tier > best(kind):
			st.best[kind] = tier
			unlocked_next = true
		gm.season.add_xp(15)
		gm.audio.play("levelup")
	else:
		gm.season.add_xp(5)
	gm.quests.on_event("dungeon", 1)
	last_run = run.duplicate()
	last_run.merge({"kind": kind, "tier": tier, "kills": kills, "cleared": cleared, "reason": reason, "next": unlocked_next})
	gm.combat.heal_full()
	gm.save.save_game()
	gm.changed.emit("dungeon")
	var title: String = KINDS[kind].name
	if cleared:
		gm.toast.emit("%s %d: oczyszczony! +%d odłamków relikwii" % [title, tier, int(run.shards)], Color(1.0, 0.8, 0.4))
	else:
		gm.toast.emit("%s %d: %d/%d strażników (%s)" % [title, tier, kills, GUARDS, reason], Color(1.0, 0.6, 0.35))


func leave() -> void:
	if active:
		on_fail("wycofano się")
		gm.enemy.spawn()


func hud_text() -> String:
	return "%s %d  •  strażnicy %d/%d" % [str(KINDS[kind].name).to_upper(), tier, kills, GUARDS]
