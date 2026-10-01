extends Node
## Automatyczny przegląd interfejsu idle ze zrzutami ekranu:
## godot --path . -- --idle-shots=/katalog [--idle-scenario=all]
## Gra startuje na osobnym zapisie testowym, symuluje postęp i odwiedza wszystkie ekrany.

var ui: IdleMain
var dir := ""
var _steps: Array = []
var _wait := 1.0
var _busy := false
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--idle-shots="):
			dir = a.substr(13)
	DirAccess.make_dir_recursive_absolute(dir)
	var g: IdleGame = Idle
	g.save.path = "user://autotest_idle.save"
	g.save.delete_save()
	# Sceny fabuły pokazujemy ręcznie (nie mogą zasłaniać sprawdzanych okien).
	g.story_autotest = true
	_steps = [
		func(): return 4.0,
		func(): print("idle-autotest: menu ", ui._menu_screen.size, " vp ", ui._menu_screen.view.get_viewport().size); await _shot("00_menu"); ui._start_game(); return 1.0,
		func(): await _shot("01_start"); _press("Do boju!"); return 0.5,
		func(): await _expect_no_modal("Do boju!"); return 0.3,
		func(): ui._open_menu(); return 0.5,
		func(): _press("Ustawienia"); return 0.5,
		func(): await _expect_no_modal("menu"); ui.show_tab("fight"); return 0.3,
		func():
			for i in 30:
				g.combat.tap()
			return 1.0,
		func(): await _shot("02_walka"); _progress(g); return 2.0,
		func():
			for i in 12:
				g.combat.tap()
			return 0.4,
		func(): await _shot("03_walka_postep"); ui.show_tab("heroes"); return 0.8,
		func(): await _shot("03b_druzyna"); ui.show_tab("gear"); return 0.8,
		func(): await _shot("04_ekwipunek"); _open_first_item(); return 0.8,
		func(): await _shot("05_przedmiot"); _close_modals(); ui.show_tab("craft"); return 0.8,
		func(): await _shot("06_craft"); ui.show_tab("spells"); return 0.8,
		func(): await _shot("07_czary"); ui.show_tab("quests"); return 0.8,
		func(): await _shot("08_questy"); ui.show_tab("map"); return 0.8,
		func(): await _shot("09_mapa"); ui.show_tab("shop"); return 0.8,
		func(): await _shot("10_sklep"); ui.show_tab("mounts"); return 0.8,
		func(): await _shot("11_stajnia"); ui.show_tab("prestige"); return 0.8,
		func(): await _shot("12_oltarz"); ui.show_tab("achievements"); return 0.8,
		func(): await _shot("12b_osiagniecia"); ui.show_daily(); return 0.8,
		func(): await _shot("12c_codzienna"); _press("Odbierz nagrodę"); return 0.5,
		func(): await _expect_no_modal("Odbierz nagrodę dnia"); ui._open_menu(); return 0.7,
		func(): await _shot("12d_menu"); _press("Talenty"); return 0.8,
		func():
			for id in ["heavy_hand", "heavy_hand", "heavy_hand", "heavy_hand", "hawk_eye", "hawk_eye"]:
				g.talents.learn(id)
			ui._panels["talents"].refresh()
			return 0.5,
		func(): await _shot("12e_talenty"); g.expeditions.start(0, 2); g.expeditions.start(1, 0, ExpeditionManager.now() - 3600.0); ui.show_tab("expeditions"); return 0.8,
		func(): await _shot("12f_wyprawy"); ui.show_tab("bestiary"); return 0.8,
		func(): await _shot("12g_bestiariusz"); ui.show_tab("tower"); return 0.8,
		func(): await _shot("12h_wieza"); _press("Wejdź do Wieży"); return 2.5,
		func():
			await _shot("12i_wieza_walka")
			g.tower.leave()
			g.inventory.add("rune_fire_2", 2)
			g.inventory.add("rune_wind_1", 4)
			g.inventory.add("rune_gold_3", 1)
			g.runes.socket("weapon", 0, "rune_fire_2")
			g.runes.socket("body", 0, "rune_gold_3")
			ui.show_tab("runes")
			return 0.8,
		func(): await _shot("12j_runy"); g.inventory.add("pet_egg", 6); ui.show_tab("pets"); return 0.6,
		func():
			for i in 5:
				g.pets.hatch()
			_press("Wykluj jajo")
			return 1.8,
		func(): await _shot("12k_chowance"); ui.show_tab("raid"); return 0.8,
		func(): await _shot("12l_boss_tygodnia"); _press("Walcz z bossem tygodnia"); return 2.5,
		func(): await _shot("12m_rajd_walka"); g.raid.leave(); ui.show_story("intro:meadow"); return 1.5,
		func(): await _shot("12n_opowiesc"); _close_modals(); g.s.ash_total = 600; g.s.max_stage = 85; ui.show_tab("phoenix"); return 0.8,
		func(): await _shot("12o_feniks"); g.s.skin = ""; ui.show_tab("skins"); return 0.6,
		func(): g.skins.select("guard"); ui._panels["skins"].refresh(); return 1.0,
		func(): await _shot("12p_garderoba"); ui.show_tab("shop"); return 0.8,
		func(): await _shot("12q_skarbiec"); ui.show_odds(LootManager.CHEST_NAMES[4], g.loot.chest_odds(4)); return 0.7,
		func(): await _shot("12r_szanse"); _close_modals(); g.season.add_xp(500); ui.show_tab("season"); return 0.8,
		func(): await _shot("12s_karnet"); g.achievements.remember(); g.s.ach.best_stage = maxi(int(g.s.ach.best_stage), 40); ui.show_tab("dungeon"); return 0.8,
		func(): await _shot("12s1_lochy"); _press("Wejdź"); return 2.0,
		func():
			for i in 4:
				if g.dungeon.active:
					g.combat.damage(float(g.enemy.cur.max_hp) * 2.0, false, "tap")
			return 1.2,
		func(): await _shot("12s2_loch_walka"); g.dungeon.leave(); ui.show_tab("arena"); return 0.8,
		func(): await _shot("12s3_arena"); _press("Walcz"); return 2.0,
		func(): await _shot("12s4_arena_walka"); g.arena.leave(); g.relics.add_shards(40); ui.show_tab("relics"); return 0.8,
		func(): await _shot("12s5_relikwie_przed"); _press("Odkryj relikwię (10 odłamków)"); return 1.0,
		func():
			for i in 3:
				g.relics.pull()
			ui.show_tab("relics")
			return 0.8,
		func(): await _shot("12s6_relikwie"); g.s.erase("wheel"); ui.show_tab("wheel"); return 0.8,
		func(): await _shot("12s7_kolo"); _press("Zakręć kołem!"); return 1.6,
		func(): await _shot("12s8_kolo_obrot"); return 2.6,
		func(): await _shot("12s9_kolo_wynik"); ui.show_tab("gear"); return 0.8,
		func():
			var it: Dictionary = g.inventory.add_gear("sword_t4", 4)
			g.s.gold = float(g.s.gold) + float(g.equipment.enchant_cost(it).gold) * 3.0
			g.equipment.enchant(int(it.uid))
			ui._panels["gear"]._item_popup(it)
			return 0.8,
		func(): await _shot("12s10_zaklecie"); _close_modals(); g.s.ach.best_stage = maxi(int(g.s.ach.best_stage), 30); ui.show_tab("class"); return 0.8,
		func(): await _shot("12s11_klasy"); _press("Wybierz"); return 0.8,
		func():
			g.s.hero_class.charge = ClassManager.CHARGE_MAX
			ui.show_tab("fight")
			return 1.0,
		func(): await _shot("12s12_ult_gotowe"); g.hero.activate(); return 0.6,
		func():
			for i in 15:
				g.combat.tap()
			return 0.5,
		func(): await _shot("12s13_furia"); g.festival.force = 1; g.s.festival = {"lanterns": 640, "total": 640, "bought": {}, "month": FestivalManager.month_id()}; ui.show_tab("festival"); return 0.8,
		func(): await _shot("12s14_festyn"); _press("Kup"); return 0.8,
		func(): await _shot("12s15_festyn_kupiony"); g.festival.force = -1; g.s.mercs[str(g.db.mercs[0].id)] = 120; g.mercs.add_seals(2); ui.show_tab("heroes"); return 0.8,
		func(): await _shot("12s16_przebudzenie"); _press("Przebudź"); return 0.8,
		func(): await _shot("12s17_przebudzony"); g.s.ach.best_stage = maxi(int(g.s.ach.best_stage), 40); g.s.erase("dream"); ui.show_tab("dream"); return 0.8,
		func(): await _shot("12s18_sen"); _press("Zaśnij"); return 1.5,
		func(): g.combat.damage(float(g.enemy.cur.max_hp) * 3.0, false, "tap"); return 1.0,
		func(): await _shot("12s19_sen_wybor"); _close_modals(); g.dream.choose(0); return 1.5,
		func(): await _shot("12s20_sen_pietro2"); g.dream.leave(); ui.show_tab("dream"); return 0.8,
		func(): await _shot("12s21_sen_wynik"); var wg: Array = g.weekly.goals()[0]; g.quests.on_event(str(wg[0]), float(wg[2])); ui.show_tab("weekly"); return 0.8,
		func(): await _shot("12s22_wyzwania"); ui.show_tab("mail"); return 0.8,
		func(): await _shot("12s23_poczta"); ui.show_tab("records"); return 0.8,
		func(): await _shot("12s24_rekordy"); _close_modals(); ui._open_menu(); return 0.8,
		func(): await _shot("12s25_menu_sekcje"); _close_modals(); _garden_setup(); ui.show_tab("garden"); return 0.8,
		func(): await _shot("12s26_ogrod"); _press("Zbierz wszystko"); return 0.6,
		func(): await _shot("12s27_ogrod_zbior"); _scroll_bottom(ui); return 0.6,
		func(): await _shot("12s28_kociol"); _close_modals(); ui.show_tab("fight"); g.s.farm_mode = true; g.goblin.force = true; g.enemy.spawn(); return 1.6,
		func(): await _shot("12s29_goblin"); g.combat.damage(float(g.enemy.cur.max_hp) * 2.0, false, "tap"); return 0.7,
		func(): await _shot("12s30_goblin_lup"); g.s.farm_mode = false; g.mastery.add_xp(g.mastery.current(), 3000); g.mastery.add_xp("bow", 900); ui.show_tab("mastery"); return 0.8,
		func(): await _shot("12s31_mistrzostwo"); g.s.ach.best_stage = maxi(int(g.s.ach.best_stage), 60); g.s.erase("dragon"); g.dragon.take_egg(); ui.show_tab("dragon"); return 0.8,
		func(): await _shot("12s32_smocze_jajo"); g.s.dragon.hatch_at = 0.0; return 0.6,
		func(): _press("Wykluj!"); return 1.0,
		func(): await _shot("12s33_smok_wykluty"); g.s.garden.herbs["dragon_pepper"] = 12; g.dragon.feed_herb("dragon_pepper", -1); ui.show_tab("dragon"); return 0.8,
		func(): await _shot("12s34_smok_panel"); _close_modals(); ui.show_tab("fight"); g.s.farm_mode = true; g.enemy.spawn(); return 1.5,
		func(): g.dragon.tick(DragonManager.BREATH_CD); return 0.25,
		func(): await _shot("12s35_smok_walka"); g.s.farm_mode = false; g.s.erase("stronghold"); g.add_gold(g.stronghold.cost("forge") * 50.0); g.stronghold.build("treasury"); g.s.stronghold.queue[0].done_at = 0.0; g.stronghold.check_done(); g.stronghold.build("forge"); ui.show_tab("stronghold"); return 0.8,
		func(): await _shot("12s36_twierdza"); ui.show_tab("fight"); g.s.farm_mode = false; g.affix.force = ["armored", "regen"]; g.s.stage = 25; g.s.kills_in_stage = 99; g.enemy.spawn(); return 1.2,
		func(): await _shot("12s37_boss_cechy"); g.soul_night.force = 1; g.s.erase("soul_night"); g.soul_night.on_kill(2); g.s.soul_night.flames = 420; g.s.soul_night.total = 420; ui.show_tab("soul_night"); return 0.8,
		func(): await _shot("12s38_noc_dusz"); g.soul_night.force = -1; g.s.rebirths = maxi(int(g.s.rebirths), 3); g.auto.set_enabled("mercs", true); ui.show_tab("auto"); return 0.8,
		func(): await _shot("12s39_kwatermistrz"); g.auto.set_enabled("mercs", false); g.s.stats["best_combo"] = 100; g.titles.check(); ui.show_tab("titles"); return 0.8,
		func(): await _shot("12s40_tytuly"); ui.show_tab("settings"); return 0.8,
		func(): await _shot("12t_ustawienia"); ui.show_tab("fight"); g.s.stage = 10; g.s.kills_in_stage = 0; g.enemy.spawn(); return 2.5,
		func():
			g.combat.mp = 9999.0
			g.spells.cast("fireball")
			return 0.35,
		func(): await _shot("13_boss_czar"); g.spells.cast("meteor"); return 0.9,
		func(): await _shot("14_meteor"); g.s.last_time = Time.get_unix_time_from_system() - 7200.0; ui._show_offline(g.offline.compute_and_apply()); return 2.2,
		func(): await _shot("15_offline"); _press("Odbierz"); return 0.4,
		func(): await _expect_no_modal("Odbierz"); ui.show_tab("gear"); ui._panels["gear"]._tab = "chests"; g.inventory.add("chest_5", 1); ui._panels["gear"].refresh(); return 0.6,
		func(): ui._panels["gear"]._open(5, 1); return 1.2,
		func(): await _shot("16_skrzynia"); _close_modals(); g.s.stage = 51; g.s.max_stage = 60; g.enemy.spawn(); ui.show_tab("fight"); return 2.5,
		func(): await _shot("17_region_popielisko"); g.s.stage = 76; g.s.max_stage = 80; g.enemy.spawn(); return 2.5,
		func(): await _shot("18_zarogniew"); g.s.stage = 34; g.enemy.spawn(); return 2.5,
		func(): await _shot("19_pustynia"); return 0.2,
	]
	# --idle-quick: tylko menu i walka (szybki podgląd układu).
	if "--idle-quick" in OS.get_cmdline_user_args():
		_steps = _steps.slice(0, 12)
	# --idle-dragon: szybki podgląd smoka w walce (ustawienie modelu i zionięcia).
	if "--idle-dragon" in OS.get_cmdline_user_args():
		_steps = _steps.slice(0, 9) + [
			func(): g.s.ach.best_stage = 60; g.s.erase("dragon"); g.dragon.take_egg(); g.s.dragon.hatch_at = 0.0; g.dragon.hatch(); g.changed.emit("dragon"); return 1.5,
			func(): await _shot("d1_smok"); g.dragon.add_xp(5000); g.changed.emit("dragon"); return 1.5,
			func(): g.dragon.tick(DragonManager.BREATH_CD); return 0.2,
			func(): await _shot("d2_smok_zionie"); return 0.2,
		]


## Postęp: złoto, najemnicy, czary, łup – żeby ekrany miały treść.
func _progress(g: IdleGame) -> void:
	g.add_gold(5.0e7)
	g.add_gems(400)
	g.s.level = 50
	for d in g.db.mercs.slice(0, 6):
		g.mercs.buy(str(d.id), 30)
	g.mercs.buy_train(40)
	for id in ["fireball", "lightning", "meteor", "haste", "frost_nova", "ice_armor"]:
		g.spells.learn(id)
	g.s.spell_slots = ["fireball", "meteor", "haste", "heal"]
	g.s.max_stage = 22
	g.s.stage = 22
	for i in 6:
		g.loot.random_gear(22, 1 + i % 5)
	g.inventory.add("ore_t3", 60)
	g.inventory.add("hide_t3", 40)
	g.inventory.add("wood_t3", 40)
	g.inventory.add("meat", 12)
	g.inventory.add("chest_3", 2)
	g.inventory.add("frag_mount_horse", 5)
	g.equipment.equip_best()
	g.quests.refresh()
	g.crafting.check_unlocks()
	g.enemy.spawn()
	g.changed.emit("all")


func _open_first_item() -> void:
	var p: IdleInventoryPanel = ui._panels["gear"]
	var it := Idle.equipment.equipped("weapon")
	if not it.is_empty():
		p._item_popup(it)


## Naciska przycisk o podanym tekście w otwartym oknie (jak palec gracza).
func _garden_setup() -> void:
	var g: IdleGame = ui.gm
	g.s.ach.best_stage = maxi(int(g.s.ach.best_stage), 60)
	g.s.erase("garden")
	var gd := g.garden
	g.add_gold(gd.herb_cost("dragon_pepper") * 4.0)
	gd.plant(0, "ember_root")
	gd.plant(1, "goldbloom")
	gd.plant(2, "frost_lily")
	gd.water(2)
	gd.plant(3, "moon_sage")
	gd.plot(1).ready = GardenManager.now() - 1.0
	gd.plot(3).ready = GardenManager.now() - 1.0
	gd._st().herbs = {"ember_root": 7, "moon_sage": 2, "goldbloom": 3, "frost_lily": 1}
	gd._st().elixirs = {"might": 2}


func _scroll_bottom(n: Node) -> void:
	for c in n.get_children():
		if c is ScrollContainer and c.is_visible_in_tree():
			c.scroll_vertical = 100000
		_scroll_bottom(c)


func _press(text: String) -> void:
	var b := _find_button(ui, text)
	if b == null:
		push_error("idle-autotest: brak przycisku „%s”" % text)
		fails += 1
		return
	b.pressed.emit()


func _find_button(n: Node, text: String) -> Button:
	for c in n.get_children():
		if c is Button and (str(c.text).begins_with(text) or str(c.get_meta("label", "")).begins_with(text)) and c.is_visible_in_tree():
			return c
		var r := _find_button(c, text)
		if r:
			return r
	return null


func _expect_no_modal(what: String) -> void:
	await get_tree().process_frame
	for c in ui._modals:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			var labels: Array = c.find_children("*", "Label", true, false)
			push_error("idle-autotest: okno nie zamknęło się po „%s” (%s)" % [what, str(labels[0].text) if not labels.is_empty() else "?"])
			fails += 1
			return
	print("idle-autotest: okno zamknięte po „%s”" % what)


func _close_modals() -> void:
	for c in ui.get_children():
		if c is ColorRect and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.queue_free()


func _process(delta: float) -> void:
	if _busy:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _steps.is_empty():
		SmartTranslation.dump_missing(dir.path_join("brak_tlumaczen.txt"))
		print("idle-autotest: %s" % ("OK" if fails == 0 else "BŁĘDY: %d" % fails))
		Idle.save.delete_save()
		get_tree().quit(0 if fails == 0 else 1)
		return
	_busy = true
	var step: Callable = _steps.pop_front()
	var w = await step.call()
	_wait = float(w) if w != null else 0.5
	_busy = false


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("idle-autotest: ", name)
