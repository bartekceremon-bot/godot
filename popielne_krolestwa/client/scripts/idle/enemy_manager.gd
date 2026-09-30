class_name EnemyManager
extends RefCounted
## Aktualny przeciwnik: wybór potwora regionu (bestiariusz MMO), zdrowie, boss z czasem,
## zamrożenie (Mroźna nova), podatność (Klątwa), przejście nadmiaru obrażeń (Meteor).

var gm: IdleGame

## {monster, name, look, max_hp, hp, kind (0/1/2), stage, time_left, time_max, frozen, vuln, vuln_t}
var cur: Dictionary = {}
## Nadmiar obrażeń przechodzący na kolejnych wrogów (Meteor, Łańcuch piorunów).
var carry := 0.0
var carry_hits := 0
## Łańcuch piorunów: stałe obrażenia dla kilku kolejnych wrogów.
var chain_amount := 0.0
var chain_left := 0
var _rng := RandomNumberGenerator.new()
var _boss_attack_t := 0.0


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func alive() -> bool:
	return not cur.is_empty() and float(cur.hp) > 0.0


func is_boss() -> bool:
	return not cur.is_empty() and int(cur.kind) > 0


func spawn() -> void:
	var s := gm.s
	var stage := int(s.stage)
	var pm := gm.progression
	var reg := pm.region(stage)
	var kind := pm.boss_kind(stage)
	if bool(s.farm_mode):
		kind = 0
	var mid := ""
	var name := ""
	if kind == 2:
		mid = str(reg.boss.monster)
		name = str(reg.boss.name)
	elif kind == 1:
		mid = str(reg.elite.monster)
		name = str(reg.elite.name)
	else:
		var list: Array = reg.monsters
		mid = str(list[_rng.randi() % list.size()])
		name = str(gm.db.monster(mid).name)
	var m := gm.db.monster(mid)
	var hp := ProgressionManager.enemy_hp(stage) * ProgressionManager.boss_hp_mult(kind)
	cur = {"monster": mid, "name": name, "look": str(m.get("look", mid)), "max_hp": hp, "hp": hp, "kind": kind,
		"stage": stage, "time_left": gm.db.boss_time, "time_max": gm.db.boss_time, "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0,
		"undead": gm.db.undead.has(mid)}
	_boss_attack_t = 2.0
	gm.combat.clear_dots()
	if kind > 0:
		gm.combat.heal_full()
		gm.boss_started.emit()
		gm.audio.play("boss")
	gm.enemy_spawned.emit()
	# Nadmiar z Meteoru i Łańcuch piorunów – trafiają nowego wroga od razu.
	if chain_left > 0 and chain_amount > 0.0:
		chain_left -= 1
		gm.combat.damage(chain_amount, false, "spell")
	elif carry > 0.0 and carry_hits > 0:
		var c := carry
		carry = 0.0
		carry_hits -= 1
		gm.combat.damage(c, false, "spell", true)


## Zadaje obrażenia; zwraca faktycznie zadane (z podatnością). Zabicie obsługuje CombatManager.
func take(amount: float) -> float:
	if not alive():
		return 0.0
	if float(cur.vuln_t) > 0.0:
		amount *= 1.0 + float(cur.vuln)
	cur.hp = float(cur.hp) - amount
	return amount


func tick(dt: float) -> void:
	if cur.is_empty():
		return
	if float(cur.vuln_t) > 0.0:
		cur.vuln_t = maxf(0.0, float(cur.vuln_t) - dt)
	if not is_boss() or not alive():
		return
	if float(cur.frozen) > 0.0:
		cur.frozen = maxf(0.0, float(cur.frozen) - dt)
		return
	cur.time_left = float(cur.time_left) - dt
	_boss_attack_t -= dt
	if _boss_attack_t <= 0.0:
		_boss_attack_t = 2.0
		gm.combat.boss_attacks(ProgressionManager.boss_hit(int(cur.stage), int(cur.kind)))
	if float(cur.time_left) <= 0.0 and alive():
		fail("Czas minął!")


func fail(reason: String) -> void:
	if cur.is_empty():
		return
	cur.hp = 0.0
	gm.combat.clear_dots()
	gm.progression.on_boss_fail(reason)
	gm.audio.play("fail")
	spawn()


func add_time(sec: float) -> void:
	if is_boss():
		cur.time_left = minf(float(cur.time_max) + 10.0, float(cur.time_left) + sec)


func freeze(sec: float) -> void:
	if is_boss():
		cur.frozen = maxf(float(cur.frozen), sec)


func curse(power: float, sec: float) -> void:
	if alive():
		cur.vuln = power
		cur.vuln_t = sec
