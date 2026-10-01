class_name RaidManager
extends RefCounted
## Boss tygodnia: co tydzień (od poniedziałku) inny boss regionu o ogromnym zdrowiu. 5 prób
## dziennie po 30 s – obrażenia z wszystkich prób sumują się przez cały tydzień; progi sumy dają
## nagrody (żarokryształy, skrzynie, runy, jaja chowańców). Progi rosną z rekordem etapu.
## Stan: s.raid = {week, damage, claimed, day, attempts}.

const DAILY := 5
const TIME := 30.0
const TIER_MULT := [3.0, 10.0, 30.0, 80.0, 200.0, 500.0]
const REWARDS := [
	{"gems": 20},
	{"chest": 3, "gems": 20},
	{"runes": [0.5, 0.5], "gems": 30},
	{"egg": 1, "gems": 60},
	{"chest": 5, "runes": [0.8], "gems": 80},
	{"egg": 1, "runes": [1.0, 1.0], "gems": 150},
]

var gm: IdleGame
var active := false
var _start_hp := 0.0


func _init(g: IdleGame) -> void:
	gm = g


static func week_id(t := -1.0) -> int:
	var at := Time.get_unix_time_from_system() if t < 0.0 else t
	return int(floor((at / 86400.0 + 3.0) / 7.0))


func _st() -> Dictionary:
	if not gm.s.has("raid"):
		gm.s["raid"] = {"week": -1, "damage": 0.0, "claimed": 0, "day": "", "attempts": DAILY}
	var r: Dictionary = gm.s.raid
	if int(r.week) != week_id():
		r.week = week_id()
		r.damage = 0.0
		r.claimed = 0
	if str(r.day) != DailyManager.today():
		r.day = DailyManager.today()
		r.attempts = DAILY
	return r


func boss() -> Dictionary:
	var regs: Array = gm.db.regions
	return regs[week_id() % regs.size()].boss


func damage() -> float:
	return float(_st().damage)


func attempts() -> int:
	return int(_st().attempts)


func base_hp() -> float:
	return ProgressionManager.enemy_hp(int(gm.achievements.value("best_stage"))) * 12.0


func threshold(i: int) -> float:
	return base_hp() * float(TIER_MULT[i])


func ready_tiers() -> int:
	var n := 0
	for i in TIER_MULT.size():
		if damage() >= threshold(i):
			n = i + 1
	return n - int(_st().claimed)


func enter() -> bool:
	if active or gm.tower.active or attempts() <= 0:
		return false
	_st().attempts = attempts() - 1
	active = true
	gm.combat.heal_full()
	gm.enemy.spawn()
	gm.changed.emit("raid")
	return true


func make_enemy() -> Dictionary:
	var b := boss()
	var md := gm.db.monster(str(b.monster))
	var hp := threshold(TIER_MULT.size() - 1) * 10.0
	_start_hp = hp
	return {"monster": str(b.monster), "name": "%s (boss tygodnia)" % b.name, "look": str(md.get("look", b.monster)), "max_hp": hp, "hp": hp,
		"kind": 2, "stage": int(gm.achievements.value("best_stage")), "time_left": TIME, "time_max": TIME, "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0,
		"undead": gm.db.undead.has(str(b.monster)), "raid": true}


## Koniec próby (czas, porażka, wycofanie): obrażenia dopisane do sumy tygodnia.
func on_end(reason: String) -> float:
	if not active:
		return 0.0
	active = false
	var e := gm.enemy.cur
	var dealt := maxf(0.0, _start_hp - maxf(0.0, float(e.get("hp", _start_hp))))
	_st().damage = damage() + dealt
	gm.season.add_xp(20)
	gm.combat.heal_full()
	gm.save.save_game()
	gm.changed.emit("raid")
	gm.toast.emit("Boss tygodnia: zadano %s obrażeń (%s)" % [IdleDB.fmt(dealt), reason], Color(1.0, 0.6, 0.35))
	return dealt


func leave() -> void:
	if active:
		on_end("wycofano się")
		gm.enemy.spawn()


## Odbiera kolejny próg; zwraca łup.
func claim() -> Array:
	if ready_tiers() <= 0:
		return []
	var i := int(_st().claimed)
	var r: Dictionary = REWARDS[i]
	var got: Array = []
	if r.has("gems"):
		gm.add_gems(int(r.gems))
		got.append(["gems", int(r.gems), 0])
	if r.has("chest"):
		gm.inventory.add("chest_%d" % int(r.chest), 1)
		got.append(["chest_%d" % int(r.chest), 1, int(r.chest)])
	for p in r.get("runes", []):
		var rn := gm.runes.random_rune(float(p))
		gm.inventory.add(rn, 1)
		got.append([rn, 1, 4])
	if r.has("egg"):
		gm.inventory.add("pet_egg", int(r.egg))
		got.append(["pet_egg", int(r.egg), 4])
	_st().claimed = i + 1
	gm.changed.emit("raid")
	return got
