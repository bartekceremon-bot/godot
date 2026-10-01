class_name OfflineProgressManager
extends RefCounted
## Postęp offline: czas poza grą × DPS × skuteczność offline (50% + wielbłąd + Ołtarz Popiołu),
## do limitu godzin. Bohater farmi bieżący etap i przechodzi kolejne zwykłe etapy (bossów nie
## pokonuje bez gracza). Wynik trafia do okna „Witaj ponownie!”.

const MIN_AWAY := 60.0
const MAX_GEAR := 12

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


## Oblicza i przyznaje nagrody. Zwraca raport (pusty, gdy nieobecność była krótka).
func compute_and_apply(now := -1.0) -> Dictionary:
	var s := gm.s
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var away := now - float(s.get("last_time", now))
	s.last_time = now
	if away < MIN_AWAY:
		return {}
	var st := gm.stats
	st.recalc()
	var cap := st.offline_cap_h * 3600.0
	var t := minf(away, cap) * st.offline_eff
	var dps := st.dps
	if dps <= 0.0:
		return {"away": away, "kills": 0, "gold": 0.0, "xp": 0.0, "materials": 0, "items": [], "stages": 0, "note": "Wynajmij najemników, by zdobywać łupy pod twoją nieobecność."}
	var pm := gm.progression
	var stage := int(s.stage)
	# Na etapie bossa – farmienie etapu wcześniej.
	if pm.boss_kind(stage) > 0:
		stage = maxi(1, stage - 1)
	var kills_total := 0
	var gold := 0.0
	var xp := 0.0
	var stages := 0
	var kis := int(s.kills_in_stage)
	var advance := bool(s.auto_progress) and not bool(s.farm_mode)
	var guard := 0
	while t > 0.0 and guard < 500:
		guard += 1
		var per_kill := ProgressionManager.enemy_hp(stage) / dps
		var can_advance := advance and pm.boss_kind(stage + 1) == 0
		var need := gm.db.kills_per_stage - kis if can_advance else 1000000000
		var kills := int(minf(float(need), floor(t / per_kill)))
		if kills <= 0:
			break
		t -= kills * per_kill
		kills_total += kills
		gold += kills * ProgressionManager.gold_for(stage)
		xp += kills * ProgressionManager.xp_for(stage)
		kis += kills
		if can_advance and kis >= gm.db.kills_per_stage:
			stage += 1
			stages += 1
			kis = 0
		else:
			break
	gold *= st.gold_mult
	xp *= st.xp_mult
	# Stan po powrocie.
	if stages > 0:
		s.stage = stage
		s.kills_in_stage = kis
		if stage > int(s.max_stage):
			s.max_stage = stage
	gm.add_gold(gold)
	gm.progression.add_xp(xp)
	s.stats.kills = int(s.stats.kills) + kills_total
	gm.quests.on_event("kills", kills_total)
	# Surowce (oczekiwana liczba) i ekwipunek (losowany, do 12 sztuk).
	var mats := int(kills_total * 0.35 * st.loot_mult * st.material_mult * 1.5)
	var mat_counts := {}
	for i in mini(mats, 40):
		var id := gm.loot.random_material(stage)
		mat_counts[id] = int(mat_counts.get(id, 0)) + maxi(1, mats / 40)
	var mat_total := 0
	for id in mat_counts:
		gm.inventory.add(str(id), int(mat_counts[id]))
		mat_total += int(mat_counts[id])
	var items: Array = []
	var n_gear := mini(MAX_GEAR, int(kills_total * 0.015 * st.loot_mult))
	for i in n_gear:
		var it := gm.loot.random_gear(stage, gm.loot.roll_rarity(0))
		if not it.is_empty():
			items.append(it)
	var gems := int(kills_total * 0.006 * st.loot_mult)
	if gems > 0:
		gm.add_gems(gems)
	return {"away": away, "counted": minf(away, cap), "kills": kills_total, "gold": gold, "xp": xp, "materials": mat_total,
		"items": items, "stages": stages, "gems": gems, "capped": away > cap}
