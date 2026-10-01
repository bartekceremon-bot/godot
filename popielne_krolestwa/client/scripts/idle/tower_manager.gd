class_name TowerManager
extends RefCounted
## Wieża Popiołu: niekończące się piętra z bossami ze wszystkich krain. Wejście kosztuje próbę
## (3 dziennie, kolejne za żarokryształy); każde zwycięstwo prowadzi od razu wyżej, porażka
## albo koniec czasu kończy wspinaczkę. Nagrody: żarokryształy za każde piętro, skrzynie co 5,
## punkt talentu co 5 pięter rekordu (TalentManager), slot wyprawy za 10. piętro.
## Stan: s.tower = {best, attempts, day}; w trakcie: active, floor.

const DAILY_ATTEMPTS := 3
const EXTRA_COST := 40
const TIME := 30.0

var gm: IdleGame
var active := false
var floor_n := 0
## Wynik ostatniej wspinaczki (okno podsumowania): {from, to, gems, chests}.
var last_run: Dictionary = {}
var _run_gems := 0
var _run_chests: Array = []
var _from := 0


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("tower"):
		gm.s["tower"] = {"best": 0, "attempts": DAILY_ATTEMPTS, "day": ""}
	var t: Dictionary = gm.s.tower
	if str(t.day) != DailyManager.today():
		t.day = DailyManager.today()
		t.attempts = DAILY_ATTEMPTS
	return t


func best() -> int:
	if not gm.s.has("tower"):
		return 0
	return int(gm.s.tower.best)


func attempts() -> int:
	return int(_st().attempts)


## Etap „odpowiadający” piętru (zdrowie i siła bossa).
static func floor_stage(f: int) -> int:
	return 8 + f * 2


func boss_hp(f: int) -> float:
	return ProgressionManager.enemy_hp(floor_stage(f)) * 14.0


## Potwór piętra: kolejni bossowie i elity krain, w kółko.
func floor_monster(f: int) -> Array:
	var regs: Array = gm.db.regions
	var reg: Dictionary = regs[(f - 1) % regs.size()]
	var b: Dictionary = reg.boss if f % 2 == 0 else reg.elite
	return [str(b.monster), str(b.name)]


func can_enter() -> bool:
	return gm.challenge() == null and gm.running


func enter(use_gems := false) -> bool:
	if not can_enter():
		return false
	var st := _st()
	if int(st.attempts) > 0:
		st.attempts = int(st.attempts) - 1
	elif not (use_gems and gm.spend_gems(EXTRA_COST)):
		return false
	active = true
	_from = best()
	floor_n = best() + 1
	_run_gems = 0
	_run_chests = []
	gm.combat.heal_full()
	gm.enemy.spawn()
	gm.changed.emit("tower")
	return true


## Przeciwnik piętra (wywoływane przez EnemyManager.spawn w trybie wieży).
func make_enemy() -> Dictionary:
	var m := floor_monster(floor_n)
	var md := gm.db.monster(m[0])
	var hp := boss_hp(floor_n)
	return {"monster": m[0], "name": "%s – piętro %d" % [m[1], floor_n], "look": str(md.get("look", m[0])), "max_hp": hp, "hp": hp,
		"kind": 2, "stage": floor_stage(floor_n), "time_left": TIME, "time_max": TIME, "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0,
		"undead": gm.db.undead.has(m[0]), "tower": floor_n}


func on_win() -> void:
	var st := _st()
	var f := floor_n
	var gems := 2 + int(f / 5)
	gm.add_gems(gems)
	_run_gems += gems
	gm.season.add_xp(10)
	gm.quests.on_event("tower", 1)
	if f % 10 == 0:
		gm.mercs.add_seals(1)
		gm.inventory.add("pet_egg", 1)
		gm.notify("Wieża: jajo chowańca!", Color(1.0, 0.85, 0.4))
	if randf() < 0.35:
		var rn := gm.runes.random_rune(f / 60.0)
		gm.inventory.add(rn, 1)
		gm.notify("Wieża: %s!" % RuneManager.rune_name(rn), Color(1.0, 0.7, 0.35))
	if f % 5 == 0:
		var r := clampi(1 + int(f / 10), 1, 5)
		gm.inventory.add("chest_%d" % r, 1)
		_run_chests.append(r)
	if f > int(st.best):
		var old_pts := int(int(st.best) / 5)
		st.best = f
		if int(f / 5) > old_pts:
			gm.notify("Wieża Popiołu: piętro %d – nowy punkt talentu!" % f, Color(1.0, 0.75, 0.3))
			gm.talents.mark_dirty()
	gm.audio.play("levelup")
	floor_n += 1
	gm.combat.heal(0.35)
	gm.changed.emit("tower")


func on_fail(reason: String) -> void:
	active = false
	last_run = {"from": _from, "to": floor_n - 1, "reached": floor_n, "gems": _run_gems, "chests": _run_chests, "reason": reason}
	gm.combat.heal_full()
	gm.save.save_game()
	gm.changed.emit("tower")
	gm.toast.emit("Wieża: koniec wspinaczki na piętrze %d (%s)" % [floor_n, reason], Color(1.0, 0.6, 0.35))


## Ręczne wyjście (zapis wyniku).
func leave() -> void:
	if active:
		on_fail("wycofano się")
		gm.enemy.spawn()
