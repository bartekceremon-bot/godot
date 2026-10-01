class_name CombatManager
extends RefCounted
## Walka: ciosy dotykiem, automatyczne ataki (DPS), krytyki, obrażenia rozłożone w czasie,
## zabicie wroga i nagrody, ataki bossa na bohatera, tarcza (Lodowa zbroja), mikstury.

var gm: IdleGame

var hp := 100.0
var mp := 50.0
var shield := 0.0
var shield_t := 0.0
## Obrażenia rozłożone w czasie: [{dps, t, pct_max}] (pct_max – ułamek maks. zdrowia wroga na s).
var dots: Array = []
var _auto_t := 0.0
var _dot_t := 0.0
var _potion_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func reset_player() -> void:
	hp = gm.stats.max_hp
	mp = gm.stats.max_mp


func heal_full() -> void:
	hp = gm.stats.max_hp


func clear_dots() -> void:
	dots.clear()


## Dotknięcie przeciwnika.
func tap() -> void:
	if not gm.enemy.alive():
		return
	var s := gm.s
	s.stats.taps = int(s.stats.taps) + 1
	gm.quests.on_event("taps", 1)
	var dmg := gm.stats.click * _rng.randf_range(0.92, 1.08)
	var crit := _rng.randf() < gm.stats.crit_chance + (gm.dream.crit_bonus() if gm.dream.active else 0.0) or gm.hero.ult_mults().has("crit")
	gm.hero.add_charge(0.6)
	if crit:
		dmg *= gm.stats.crit_mult
		s.stats.crits = int(s.stats.crits) + 1
		gm.quests.on_event("crits", 1)
	damage(dmg, crit, "tap")
	if gm.dream.active and _rng.randf() < gm.dream.echo_chance():
		damage(dmg, crit, "tap")


func tick(dt: float) -> void:
	var st := gm.stats
	# Regeneracja many (zdrowie odnawia się tylko poza walką z bossem).
	mp = minf(st.max_mp, mp + st.mp_regen * dt)
	if not gm.enemy.is_boss():
		hp = minf(st.max_hp, hp + st.max_hp * 0.1 * dt)
	var regen: float = gm.spells.active_buffs().get("regen", 0.0)
	if regen > 0.0:
		hp = minf(st.max_hp, hp + st.max_hp * regen * dt)
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0:
			shield = 0.0
	_potion_cd = maxf(0.0, _potion_cd - dt)
	if not gm.enemy.alive():
		return
	# Automatyczne ataki najemników i bohatera: do 5 trafień na sekundę.
	if st.dps > 0.0:
		var interval := 1.0 / clampf(st.atk_speed, 0.5, 5.0)
		_auto_t += dt
		var guard := 0
		while _auto_t >= interval and gm.enemy.alive() and guard < 50:
			_auto_t -= interval
			guard += 1
			var dmg := st.dps * interval
			var crit := _rng.randf() < st.crit_chance
			if crit:
				dmg *= st.crit_mult
			damage(dmg, crit, "auto")
	# Obrażenia w czasie – co 0,25 s.
	if not dots.is_empty():
		_dot_t += dt
		while _dot_t >= 0.25 and gm.enemy.alive():
			_dot_t -= 0.25
			var total := 0.0
			for d in dots:
				total += float(d.dps) * 0.25 + float(gm.enemy.cur.max_hp) * float(d.pct_max) * 0.25
				d.t = float(d.t) - 0.25
			dots = dots.filter(func(d): return float(d.t) > 0.0)
			if total > 0.0:
				damage(total, false, "dot")
	# Automatyczne picie mikstury w walce z bossem.
	if gm.enemy.is_boss() and bool(gm.s.settings.get("auto_potion", true)) and hp < st.max_hp * 0.35 and _potion_cd <= 0.0:
		drink_best_hp()


## Zadaje obrażenia bieżącemu wrogowi i obsługuje zabicie.
func damage(amount: float, crit: bool, source: String, overflow := false) -> void:
	if not gm.enemy.alive() or amount <= 0.0 or gm.enemy.cur.has("hold"):
		return
	if gm.dream.active:
		amount *= gm.dream.damage_mult(source) * (gm.dream.crit_mult() if crit else 1.0)
	var before := float(gm.enemy.cur.hp)
	var dealt := gm.enemy.take(amount)
	gm.enemy_hit.emit(dealt, crit, source)
	if not gm.enemy.alive():
		if overflow:
			gm.enemy.carry = maxf(0.0, dealt - before)
		kill()


func kill() -> void:
	var e := gm.enemy.cur
	if e.has("raid"):
		gm.raid.on_end("boss pokonany!")
		clear_dots()
		gm.enemy.spawn()
		return
	if e.has("challenge"):
		clear_dots()
		var ch = gm.challenge()
		if ch != null:
			ch.on_kill(e)
		gm.enemy.spawn()
		return
	if e.has("tower"):
		# Wieża: bez złota i etapów – nagroda piętra i od razu wyżej.
		gm.bestiary.on_kill(str(e.monster))
		clear_dots()
		gm.enemy_killed.emit({"name": e.name, "monster": e.monster, "gold": 0.0, "xp": 0.0, "boss": 2, "gems": 0})
		gm.tower.on_win()
		gm.enemy.spawn()
		return
	var s := gm.s
	var kind := int(e.kind)
	var stage := int(e.stage)
	gm.hero.add_charge(3.0 + kind * 7.0)
	var lant := gm.festival.on_kill(kind)
	if lant > 0 and kind > 0:
		gm.notify("+%d Żarne Lampiony" % lant, Color(1.0, 0.6, 0.25))
	var st := gm.stats
	var gold := ProgressionManager.gold_for(stage) * ProgressionManager.boss_hp_mult(kind) * st.gold_mult
	var xp := ProgressionManager.xp_for(stage) * (1.0 + kind * 4.0) * st.xp_mult
	s.stats.kills = int(s.stats.kills) + 1
	gm.add_gold(gold)
	gm.progression.add_xp(xp)
	var gems := gm.loot.roll_gems(kind)
	if gems > 0:
		gm.add_gems(gems)
	var info := {"name": e.name, "monster": e.monster, "gold": gold, "xp": xp, "boss": kind, "gems": gems}
	gm.quests.on_kill(str(e.monster))
	gm.bestiary.on_kill(str(e.monster))
	gm.quests.on_event("kills", 1)
	gm.season.on_kill()
	if kind > 0:
		gm.season.add_xp(3 * kind)
	gm.loot.on_kill(e)
	clear_dots()
	gm.enemy_killed.emit(info)
	if kind > 0:
		gm.boss_defeated.emit(info)
		gm.progression.on_boss_kill(kind)
	else:
		gm.progression.on_normal_kill()
	gm.enemy.spawn()


func boss_attacks(raw: float) -> void:
	var dmg := raw * (1.0 - gm.stats.defense) * (gm.dream.taken_mult() if gm.dream.active else 1.0)
	if shield > 0.0:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	hp -= dmg
	gm.player_hit.emit(dmg)
	if hp <= 0.0:
		hp = 0.0
		gm.enemy.fail("Poległeś w walce!")
		heal_full()


func heal(fraction: float) -> void:
	hp = minf(gm.stats.max_hp, hp + gm.stats.max_hp * fraction)


func add_shield(amount: float, sec: float) -> void:
	shield = maxf(shield, amount)
	shield_t = sec


func add_dot(dps_amount: float, sec: float, pct_max := 0.0) -> void:
	dots.append({"dps": dps_amount, "t": sec, "pct_max": pct_max})


## Mikstury: życia leczą 30%/60% zdrowia, many odnawiają 50%/100% many.
func drink(id: String) -> bool:
	if not gm.inventory.remove(id, 1):
		return false
	match id:
		"hp_potion":
			heal(0.3)
		"great_hp_potion":
			heal(0.6)
		"mp_potion":
			mp = minf(gm.stats.max_mp, mp + gm.stats.max_mp * 0.5)
		"great_mp_potion":
			mp = gm.stats.max_mp
		"meat":
			heal(0.08)
	_potion_cd = 4.0
	gm.audio.play("drink")
	return true


func drink_best_hp() -> bool:
	for id in ["great_hp_potion", "hp_potion", "meat"]:
		if gm.inventory.count(id) > 0:
			return drink(id)
	return false


func drink_best_mp() -> bool:
	for id in ["great_mp_potion", "mp_potion"]:
		if gm.inventory.count(id) > 0:
			return drink(id)
	return false
