extends Node
## Symulacja balansu: chciwy bot gra N godzin (klika 4×/s przez pierwsze `active_min` minut każdej
## godziny, potem tylko idle), kupuje najtańsze ulepszenia i drukuje postęp.
## godot --headless --path . res://tests/balance_sim.tscn -- --hours=4

var hours := 4.0
var tap_rate := 4.0
var active_min := 20.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hours="):
			hours = float(a.substr(8))
		if a.begins_with("--active="):
			active_min = float(a.substr(9))
	var g: IdleGame = Idle
	g.save.path = "user://sim_idle.save"
	g.save.delete_save()
	g.start()
	g.save.path = "user://sim_idle_x.save"
	var dt := 0.1
	var t := 0.0
	var next_print := 0.0
	var tap_acc := 0.0
	var buy_t := 0.0
	var marks := [1, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480, 600]
	var mi := 0
	var s := g.s
	for id in ["heal", "fireball", "lightning", "haste"]:
		s.auto_spells[id] = true
	print("min  etap maks  poz  złoto      DPS        klik     najemn. bossy  czary")
	while t < hours * 3600.0:
		var minute_in_hour := fmod(t / 60.0, 60.0)
		if minute_in_hour < active_min:
			tap_acc += tap_rate * dt
			while tap_acc >= 1.0:
				tap_acc -= 1.0
				g.combat.tap()
		g.tick(dt)
		t += dt
		buy_t += dt
		if buy_t >= 2.0:
			buy_t = 0.0
			_spend(g)
		if mi < marks.size() and t >= marks[mi] * 60.0:
			var mercs := 0
			for k in s.mercs:
				mercs += int(s.mercs[k])
			print("%4d  %4d %4d %4d  %-9s  %-9s  %-8s %6d %5d  %d" % [marks[mi], int(s.stage), int(s.max_stage), int(s.level),
				IdleDB.fmt(float(s.gold)), IdleDB.fmt(g.stats.dps), IdleDB.fmt(g.stats.click), mercs, int(s.stats.bosses), g.spells.known().size()])
			mi += 1
	print("koniec: popiół do zdobycia %d, ekwipunek: %s" % [g.prestige.ash_gain(), ", ".join(PackedStringArray(g.equipment.model_equipment()))])
	g.save.delete_save()
	get_tree().quit(0)


## Chciwe wydawanie: najlepszy stosunek DPS/koszt wśród najemników, trening, czary, ulepszenia, zadania.
func _spend(g: IdleGame) -> void:
	var s := g.s
	for i in s.quests.tasks.size():
		g.quests.claim_task(i)
	for id in s.quests.active.keys():
		g.quests.claim(str(id))
	for r in range(1, 6):
		while g.inventory.count("chest_%d" % r) > 0:
			g.loot.open_chest(r)
	g.equipment.equip_best()
	for id in g.db.spell_order:
		if g.spells.can_learn(str(id)):
			g.spells.learn(str(id))
			s.auto_spells[str(id)] = true
	for guard in 40:
		var best_id := ""
		var best_ratio := 0.0
		var best_cost := 0.0
		for d in g.mercs.visible_list():
			var id := str(d.id)
			var c := g.mercs.cost(id, 1)
			var gain := g.mercs.dps(id, g.mercs.level(id) + 1) - g.mercs.dps(id)
			var ratio := gain / c
			if ratio > best_ratio:
				best_ratio = ratio
				best_id = id
				best_cost = c
		var tc := g.mercs.train_cost(1)
		if tc <= float(s.gold) and (g.stats.dps < g.stats.click * 2.0 or tc < best_cost * 0.2):
			g.mercs.buy_train(1)
			continue
		if best_id != "" and best_cost <= float(s.gold):
			g.mercs.buy(best_id, 1)
		else:
			break
	for slot in IdleDB.SLOTS:
		var it := g.equipment.equipped(slot)
		if not it.is_empty() and g.equipment.can_upgrade(it) and float(g.equipment.upgrade_cost(it).gold) < float(s.gold) * 0.3:
			g.equipment.upgrade(int(it.uid))
	# Rzemiosło: rafinacja i najlepsza broń tieru.
	for kind in IdleDB.MATERIAL_KINDS:
		var t := g.progression.loot_tier(int(s.max_stage))
		g.crafting.craft("refine_%s_t%d" % [kind, 1], 5)
