class_name SpellManager
extends RefCounted
## Czary MMO (5 szkół, 18 czarów) jako umiejętności clickera: odnowienie, koszt many, efekt,
## poziom ulepszenia. Pasek 4 czarów na ekranie walki; automatyczne rzucanie od etapu 10.

const AUTO_CAST_STAGE := 10
const MAX_LEVEL := 20

var gm: IdleGame
## id -> pozostały czas odnowienia (s).
var cooldowns: Dictionary = {}
## Aktywne efekty na bohaterze: {stat: [moc, czas]} (speed, damage, regen).
var buffs: Dictionary = {}
## Nawałnica: pozostałe pioruny i odstęp.
var _storm_left := 0
var _storm_t := 0.0
var _storm_every := 0.5
var _storm_dmg := 0.0
var _auto_t := 0.0


func _init(g: IdleGame) -> void:
	gm = g


func def(id: String) -> Dictionary:
	return gm.db.spells.get(id, {})


func idle_def(id: String) -> Dictionary:
	return gm.db.spells_idle.get(id, {})


func known() -> Array:
	return gm.s.spells.keys()


func is_known(id: String) -> bool:
	return gm.s.spells.has(id)


func level(id: String) -> int:
	return int(gm.s.spells.get(id, 0))


func learn_cost(id: String) -> float:
	var lvl := int(def(id).get("minLevel", 1))
	return ceilf(ProgressionManager.gold_for(maxi(1, lvl)) * 40.0)


func can_learn(id: String) -> bool:
	return not is_known(id) and int(gm.s.level) >= int(def(id).get("minLevel", 1)) and float(gm.s.gold) >= learn_cost(id)


func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	gm.spend_gold(learn_cost(id))
	gm.s.spells[id] = 0
	# Wolne miejsce na pasku – czar trafia tam od razu.
	var slots: Array = gm.s.spell_slots
	var free := slots.find("")
	if free >= 0:
		slots[free] = id
	gm.notify("Nauczono czaru: %s" % def(id).name, Color(0.7, 0.8, 1.0))
	gm.audio.play("levelup")
	gm.quests.refresh()
	gm.changed.emit("spells")
	return true


func upgrade_cost(id: String) -> Dictionary:
	var lvl := level(id)
	return {"gold": ceilf(ProgressionManager.gold_for(int(gm.s.max_stage)) * 15.0 * pow(1.6, lvl)), "gems": (lvl + 1) * 3}


func upgrade(id: String) -> bool:
	if not is_known(id) or level(id) >= MAX_LEVEL:
		return false
	var c := upgrade_cost(id)
	if float(gm.s.gold) < float(c.gold) or int(gm.s.gems) < int(c.gems):
		return false
	gm.spend_gold(float(c.gold))
	gm.spend_gems(int(c.gems))
	gm.s.spells[id] = level(id) + 1
	gm.audio.play("craft")
	gm.changed.emit("spells")
	return true


func cooldown_of(id: String) -> float:
	return _cooldown_of(id) * (1.0 - minf(0.5, float(gm.talents.totals().get("cdr", 0.0))))


func _cooldown_of(id: String) -> float:
	return float(idle_def(id).get("cd", 10)) * maxf(0.5, 1.0 - 0.03 * level(id))


func mana_of(id: String) -> float:
	return float(idle_def(id).get("mana", 20))


## Odnowienie wszystkich czarów (Kataklizm maga).
func reset_cooldowns() -> void:
	cooldowns.clear()
	gm.changed.emit("spells")


func cd_left(id: String) -> float:
	return float(cooldowns.get(id, 0.0))


func can_cast(id: String) -> bool:
	if not is_known(id) or cd_left(id) > 0.0 or gm.combat.mp < mana_of(id):
		return false
	var kind := str(idle_def(id).get("kind", ""))
	if kind in ["heal"] and gm.combat.hp >= gm.stats.max_hp * 0.99:
		return false
	if kind in ["strike", "burn", "dot", "meteor", "chill", "freeze", "chain", "storm", "drain", "curse", "poison"] and not gm.enemy.alive():
		return false
	return true


## Baza obrażeń czaru: kliknięcie + 1 s DPS, × siła czarów i poziom czaru.
func base_damage(id: String) -> float:
	return (gm.stats.click + gm.stats.dps) * gm.stats.spell_power * (1.0 + 0.25 * level(id))


func cast(id: String) -> bool:
	if not can_cast(id):
		return false
	var d := idle_def(id)
	var p := float(d.get("power", 1.0))
	var base := base_damage(id)
	var dur := float(d.get("dur", 0.0))
	gm.combat.mp -= mana_of(id)
	cooldowns[id] = cooldown_of(id)
	var e := gm.enemy
	var lvl_mult := 1.0 + 0.25 * level(id)
	match str(d.kind):
		"heal":
			gm.combat.heal(p * lvl_mult)
		"blessing":
			_buff("damage", p * lvl_mult, dur)
			_buff("regen", 0.05, dur)
		"reset":
			for k in cooldowns:
				if k != id:
					cooldowns[k] = 0.0
		"strike":
			var mult := float(d.get("undead", 1.0)) if bool(e.cur.get("undead", false)) else 1.0
			gm.combat.damage(base * p * mult, false, "spell")
		"burn":
			gm.combat.damage(base * p, false, "spell")
			gm.combat.add_dot(base * float(d.dot), dur)
		"dot":
			gm.combat.add_dot(base * float(d.dot), dur)
		"meteor":
			e.carry_hits = 10
			gm.combat.damage(base * p, true, "spell", true)
		"chill":
			e.add_time(float(d.get("extra", 3)))
			gm.combat.damage(base * p, false, "spell")
		"freeze":
			e.freeze(dur)
			gm.combat.damage(base * p, false, "spell")
		"shield":
			gm.combat.add_shield(gm.stats.max_hp * p * lvl_mult, dur)
		"chain":
			e.chain_amount = base * p
			e.chain_left = int(d.get("extra", 2))
			gm.combat.damage(base * p, false, "spell")
		"storm":
			_storm_left = int(d.get("extra", 10))
			_storm_every = dur / maxf(1.0, _storm_left)
			_storm_t = 0.0
			_storm_dmg = base * p
		"haste":
			_buff("speed", p * lvl_mult, dur)
		"drain":
			gm.combat.damage(base * p, true, "spell")
			gm.combat.heal(float(d.get("extra", 0.3)))
		"curse":
			e.curse(p * lvl_mult, dur)
		"poison":
			gm.combat.add_dot(0.0, dur, p * lvl_mult)
	gm.s.stats.spells = int(gm.s.stats.spells) + 1
	gm.quests.on_event("spells", 1)
	gm.spell_cast.emit(id)
	return true


func _buff(stat: String, power: float, dur: float) -> void:
	buffs[stat] = [power, dur]
	gm.stats.mark_dirty()


## Aktywne efekty czarów do statystyk: {stat: moc}.
func active_buffs() -> Dictionary:
	var out := {}
	for k in buffs:
		out[k] = float(buffs[k][0])
	return out


func auto_enabled() -> bool:
	return int(gm.s.max_stage) >= AUTO_CAST_STAGE


func tick(dt: float) -> void:
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - dt)
	var expired := false
	for k in buffs.keys():
		buffs[k][1] = float(buffs[k][1]) - dt
		if float(buffs[k][1]) <= 0.0:
			buffs.erase(k)
			expired = true
	if expired:
		gm.stats.mark_dirty()
	if _storm_left > 0:
		_storm_t -= dt
		while _storm_t <= 0.0 and _storm_left > 0:
			_storm_t += _storm_every
			_storm_left -= 1
			if gm.enemy.alive():
				gm.combat.damage(_storm_dmg, false, "spell")
				gm.spell_cast.emit("storm_bolt")
	# Automatyczne rzucanie czarów z paska (półautomatyczna gra).
	if auto_enabled():
		_auto_t += dt
		if _auto_t >= 0.5:
			_auto_t = 0.0
			_auto_cast()


func _auto_cast() -> void:
	for id in gm.s.spell_slots:
		if str(id) == "" or not bool(gm.s.auto_spells.get(id, false)):
			continue
		var kind := str(idle_def(str(id)).get("kind", ""))
		# Leczenie tylko przy niskim zdrowiu, reszta – gdy jest cel.
		if kind == "heal" and gm.combat.hp > gm.stats.max_hp * 0.55:
			continue
		if kind in ["shield", "freeze"] and not gm.enemy.is_boss() and not gm.enemy.cur.has("goblin"):
			continue
		if can_cast(str(id)):
			cast(str(id))


func set_slot(index: int, id: String) -> void:
	var slots: Array = gm.s.spell_slots
	var old := slots.find(id)
	if old >= 0:
		slots[old] = ""
	slots[index] = id
	gm.changed.emit("spells")


func toggle_auto(id: String) -> void:
	gm.s.auto_spells[id] = not bool(gm.s.auto_spells.get(id, false))
	gm.changed.emit("spells")
