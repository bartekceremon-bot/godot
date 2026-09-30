extends Node
## Automatyczny przegląd interfejsu idle ze zrzutami ekranu:
## godot --path . -- --idle-shots=/katalog [--idle-scenario=all]
## Gra startuje na osobnym zapisie testowym, symuluje postęp i odwiedza wszystkie ekrany.

var ui: IdleMain
var dir := ""
var _steps: Array = []
var _wait := 1.0
var _busy := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--idle-shots="):
			dir = a.substr(13)
	DirAccess.make_dir_recursive_absolute(dir)
	var g: IdleGame = Idle
	g.save.path = "user://autotest_idle.save"
	g.save.delete_save()
	_steps = [
		func(): await _shot("00_menu"); ui._start_game(); return 1.0,
		func(): await _shot("01_start"); _close_modals(); return 0.5,
		func():
			for i in 30:
				g.combat.tap()
			return 1.0,
		func(): await _shot("02_walka"); _progress(g); return 2.0,
		func():
			for i in 12:
				g.combat.tap()
			return 0.4,
		func(): await _shot("03_walka_postep"); ui.show_tab("gear"); return 0.8,
		func(): await _shot("04_ekwipunek"); _open_first_item(); return 0.8,
		func(): await _shot("05_przedmiot"); _close_modals(); ui.show_tab("craft"); return 0.8,
		func(): await _shot("06_craft"); ui.show_tab("spells"); return 0.8,
		func(): await _shot("07_czary"); ui.show_tab("quests"); return 0.8,
		func(): await _shot("08_questy"); ui.show_tab("map"); return 0.8,
		func(): await _shot("09_mapa"); ui.show_tab("shop"); return 0.8,
		func(): await _shot("10_sklep"); ui.show_tab("mounts"); return 0.8,
		func(): await _shot("11_stajnia"); ui.show_tab("prestige"); return 0.8,
		func(): await _shot("12_oltarz"); ui.show_tab("fight"); g.s.stage = 10; g.s.kills_in_stage = 0; g.enemy.spawn(); return 2.5,
		func():
			g.combat.mp = 9999.0
			g.spells.cast("fireball")
			return 0.35,
		func(): await _shot("13_boss_czar"); g.spells.cast("meteor"); return 0.9,
		func(): await _shot("14_meteor"); g.s.last_time = Time.get_unix_time_from_system() - 7200.0; ui._show_offline(g.offline.compute_and_apply()); return 2.2,
		func(): await _shot("15_offline"); _close_modals(); ui.show_tab("gear"); ui._panels["gear"]._tab = "chests"; g.inventory.add("chest_5", 1); ui._panels["gear"].refresh(); return 0.6,
		func(): ui._panels["gear"]._open(5, 1); return 1.2,
		func(): await _shot("16_skrzynia"); _close_modals(); g.s.stage = 51; g.s.max_stage = 60; g.enemy.spawn(); ui.show_tab("fight"); return 2.5,
		func(): await _shot("17_region_popielisko"); g.s.stage = 76; g.s.max_stage = 80; g.enemy.spawn(); return 2.5,
		func(): await _shot("18_zarogniew"); g.s.stage = 34; g.enemy.spawn(); return 2.5,
		func(): await _shot("19_pustynia"); return 0.2,
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
		print("idle-autotest: OK")
		Idle.save.delete_save()
		get_tree().quit(0)
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
