class_name PlayerStats
extends RefCounted
## Statystyki bohatera wyliczane z poziomu, treningu, najemników, ekwipunku, wierzchowców,
## prestiżu, wzmocnień i czarów. Wynik jest buforowany; recalc() po każdej zmianie źródeł.

var gm: IdleGame

var click := 1.0
## Obrażenia na sekundę (z szybkością ataku, bez krytyków).
var dps := 0.0
var merc_dps := 0.0
var crit_chance := 0.05
var crit_mult := 2.0
var atk_speed := 1.0
var dmg_mult := 1.0
var gold_mult := 1.0
var xp_mult := 1.0
var loot_mult := 1.0
var material_mult := 1.0
var max_hp := 100.0
var defense := 0.0
var max_mp := 50.0
var mp_regen := 1.0
var spell_power := 1.0
## Mnożnik obrażeń zadawanych bossom i elitom (talent Pogromca).
var boss_mult := 1.0
var offline_eff := 0.5
var offline_cap_h := 12.0
## Ułamek DPS doliczany do kliknięcia (trening co 10 poziomów).
var click_dps_share := 0.0
## Rozbicie premii (okno postaci).
var parts: Dictionary = {}

var _dirty := true
var _check_t := 0.0


func _init(g: IdleGame) -> void:
	gm = g


func mark_dirty() -> void:
	_dirty = true


func tick(dt: float) -> void:
	# Co sekundę: wygasanie wzmocnień z rzemiosła i sklepu.
	_check_t += dt
	if _check_t >= 1.0:
		_check_t = 0.0
		gm.crafting.active_boosts()
	if _dirty:
		recalc()


func recalc() -> void:
	_dirty = false
	var s := gm.s
	if s.is_empty():
		return
	var level := int(s.level)
	var eq: Dictionary = gm.equipment.totals()
	var mt: Dictionary = gm.mounts.totals()
	var pr: Dictionary = gm.prestige.totals()
	var bo: Dictionary = gm.spells.active_buffs()
	var boost: Dictionary = gm.crafting.active_boosts()
	var tl: Dictionary = gm.talents.totals()
	var ru: Dictionary = gm.runes.totals()
	var pe: Dictionary = gm.pets.totals()
	for k in pe:
		ru[k] = float(ru.get(k, 0.0)) + float(pe[k])
	var best := 1.0 + gm.bestiary.bonus()
	var arch: float = tl.get("archmage", 0.0)

	dmg_mult = (1.0 + 0.02 * (level - 1)) * (1.0 + eq.get("dmg", 0.0)) * (1.0 + mt.get("damage", 0.0)) \
		* (1.0 + pr.get("damage", 0.0)) * (1.0 + boost.get("damage", 0.0)) * (1.0 + bo.get("damage", 0.0)) \
		* (1.0 + tl.get("damage", 0.0) + arch * 0.5) * best * (1.0 + ru.get("dmg", 0.0)) * (1.0 + gm.phoenix.value("flame")) * (2.0 if gm.premium.fury_active() else 1.0)
	merc_dps = gm.mercs.total_dps() * (1.0 + eq.get("merc", 0.0) + tl.get("merc", 0.0) + tl.get("banner", 0.0) + ru.get("merc", 0.0))
	atk_speed = 1.0 + eq.get("speed", 0.0) + pr.get("speed", 0.0) + bo.get("speed", 0.0) + tl.get("speed", 0.0) + ru.get("speed", 0.0)
	boss_mult = 1.0 + tl.get("boss", 0.0)
	dps = merc_dps * dmg_mult * atk_speed
	var train := int(s.train_lvl)
	click_dps_share = minf(0.25, 0.01 * floor(train / 10.0))
	click = (1.0 + train + level + eq.get("click", 0.0)) * dmg_mult * (1.0 + boost.get("click", 0.0) + tl.get("click", 0.0)) + dps * click_dps_share
	crit_chance = minf(0.75, 0.05 + eq.get("crit", 0.0) + pr.get("crit", 0.0) + tl.get("crit", 0.0) + ru.get("crit", 0.0))
	crit_mult = 2.0 + eq.get("critdmg", 0.0) + tl.get("critdmg", 0.0) + ru.get("critdmg", 0.0)
	gold_mult = (1.0 + eq.get("gold", 0.0) + mt.get("gold", 0.0) + pr.get("gold", 0.0) + boost.get("gold", 0.0) + tl.get("gold", 0.0) + tl.get("banner", 0.0) + ru.get("gold", 0.0)) * best * (1.0 + gm.phoenix.value("gold")) * (1.0 + gm.events.bonus("gold")) * (1.0 + float(gm.premium.bonuses().gold)) * (2.0 if gm.premium.fury_active() else 1.0)
	xp_mult = 1.0 + eq.get("xp", 0.0) + mt.get("xp", 0.0) + pr.get("xp", 0.0) + boost.get("xp", 0.0) + tl.get("xp", 0.0) + ru.get("xp", 0.0) + gm.events.bonus("xp")
	loot_mult = 1.0 + pr.get("loot", 0.0) + tl.get("loot", 0.0) + ru.get("loot", 0.0) + gm.events.bonus("loot")
	material_mult = (1.0 + eq.get("materials", 0.0)) * (1.0 + gm.events.bonus("materials"))
	max_hp = 100.0 + 12.0 * level + eq.get("hp", 0.0)
	defense = minf(0.75, eq.get("def", 0.0))
	max_mp = (50.0 + 5.0 * level + eq.get("mp", 0.0)) * (1.0 + tl.get("mp", 0.0))
	mp_regen = 1.0 + max_mp * 0.02
	spell_power = 1.0 + eq.get("spell", 0.0) + tl.get("spell", 0.0) + arch + ru.get("spell", 0.0) + gm.events.bonus("spell")
	offline_eff = minf(2.5, 0.5 + mt.get("offline", 0.0) + pr.get("offline", 0.0) + tl.get("offline", 0.0) + gm.phoenix.value("wings") + float(gm.premium.bonuses().offline))
	offline_cap_h = 12.0 + pr.get("offline_h", 0.0) + 2.0 * gm.phoenix.level("wings")
	parts = {"eq": eq, "mounts": mt, "prestige": pr, "buffs": bo, "boosts": boost, "talents": tl, "bestiary": best, "runes": ru}
	gm.changed.emit("stats")


## Rozkład statystyk do wyświetlenia w oknie postaci: [etykieta, wartość].
func summary() -> Array:
	return [
		["Obrażenia kliknięcia", IdleDB.fmt(click)],
		["Obrażenia na sekundę (DPS)", IdleDB.fmt(dps)],
		["Szansa krytyka", "%d%%" % roundi(crit_chance * 100.0)],
		["Obrażenia krytyczne", "%d%%" % roundi(crit_mult * 100.0)],
		["Szybkość ataku", "%d%%" % roundi(atk_speed * 100.0)],
		["Mnożnik obrażeń", "×%s" % IdleDB.fmt(dmg_mult)],
		["Mnożnik złota", "%d%%" % roundi(gold_mult * 100.0)],
		["Mnożnik doświadczenia", "%d%%" % roundi(xp_mult * 100.0)],
		["Szansa na łup", "%d%%" % roundi(loot_mult * 100.0)],
		["Zdrowie", IdleDB.fmt(max_hp)],
		["Obrona", "%d%%" % roundi(defense * 100.0)],
		["Mana", IdleDB.fmt(max_mp)],
		["Siła czarów", "%d%%" % roundi(spell_power * 100.0)],
		["Postęp offline", "%d%% (maks. %d h)" % [roundi(offline_eff * 100.0), int(offline_cap_h)]],
		["Obrażenia bossom", "%d%%" % roundi(boss_mult * 100.0)],
		["Premia bestiariusza", "+%d%% obrażeń i złota" % gm.bestiary.total_tiers()],
		["Talenty", "%d / %d punktów" % [gm.talents.spent(), gm.talents.earned()]],
	]
