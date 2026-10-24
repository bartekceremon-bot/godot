extends Node
## Wycieczka wizualna (tylko build testowy, ?tour=1): ustawia kolejne ekrany
## i zapisuje nazwę kroku w window.__tour, aby Playwright mógł zrobić zrzut.

const WORLD := preload("res://scenes/world.tscn")

var world: Node
var step_time := 2.2


func _ready() -> void:
	GameState.saving_enabled = false
	Audio.unlock()
	var cid := "tkacz"
	var q: Variant = JavaScriptBridge.eval("window.location.search", true) if OS.has_feature("web") else ""
	for c in Data.class_order:
		if str(q).contains("class=" + c):
			cid = c
	GameState.new_game(cid)
	GameState.set_flag("intro_seen_world")
	world = WORLD.instantiate()
	get_tree().root.add_child(world)
	await _secs(1.5)
	var part := "all"
	for p in ["puzzles", "menus", "areas", "boss", "idle", "rest"]:
		if str(q).contains("part=" + p):
			part = p
	if part == "idle":
		# Test sterowania: świat bez automatyki, gracz z nietykalnością, żeby test był powtarzalny.
		GameState.saving_enabled = false
		World.current.hero.invuln = 9999.0
		JavaScriptBridge.eval("window.__tour = 'idle_ready'", true)
		while true:
			await _secs(0.5)
			JavaScriptBridge.eval("window.__pos = %s" % JSON.stringify([World.current.hero.global_position.x, World.current.hero.global_position.y, World.current.hero.cooldowns["attack"], World.current.hero.attack_anim, get_tree().paused, World.current.touch._joy_index, World.current.touch.visible, Settings.touch_active, [World.current.hero.touch_move.x, World.current.hero.touch_move.y], [World.current.touch._joy_center.x, World.current.touch._joy_center.y]]), true)
	await _mark("world_start")
	if part == "rest":
		for mid in ["m_echa", "m_kruk", "m_haslo", "m_fakty"]:
			World.current.open_mission(mid)
			await _secs(0.6)
			await _mark("puzzle_" + mid)
			World.current.puzzle._close()
		for tab in ["map", "hero", "settings", "save"]:
			World.current.open_menu(tab)
			await _secs(0.6)
			await _mark("menu_" + tab)
			World.current.menu.close_menu()
		World.current.open_class_change()
		await _secs(0.6)
		await _mark("class_change")
		World.current.info.close_panel()
	if part in ["all", "puzzles"]:
		await _puzzles()
	if part in ["all", "menus"]:
		await _menus()
	if part in ["all", "areas"]:
		await _areas()
	if part in ["all", "boss"]:
		await _boss_and_finale()
	_mark_done()


func _puzzles() -> void:
	for mid in ["m_most", "m_portal", "m_ogrodnik", "m_uprawnienia", "m_redakcja", "m_echa", "m_kruk", "m_haslo", "m_fakty"]:
		World.current.open_mission(mid)
		await _secs(0.6)
		await _mark("puzzle_" + mid)
		World.current.puzzle.engine.check()
		World.current.puzzle._check()
		await _secs(0.4)
		await _mark("puzzle_" + mid + "_error")
		World.current.puzzle.autosolve()
		await _secs(0.4)
		await _mark("puzzle_" + mid + "_ok")
		World.current.puzzle._close()
		await _secs(0.3)


func _menus() -> void:
	for tab in ["journal", "items", "map", "hero", "settings", "save"]:
		World.current.open_menu(tab)
		await _secs(0.6)
		await _mark("menu_" + tab)
		World.current.menu.close_menu()
		await _secs(0.2)
	World.current.open_class_change()
	await _secs(0.6)
	await _mark("class_change")
	World.current.info.close_panel()


func _areas() -> void:
	for f in ["lamp_lit", "frag_jasnosc", "frag_logika", "bridge_ogrod", "portal_ogrod"]:
		GameState.set_flag(f)
	for a in [["ogrod", "start"], ["ogrod", "szklarnia"], ["warsztat", "start"], ["warsztat", "cp_ws_b"], ["archiwum", "start"], ["archiwum", "cp_ar_c"]]:
		await _go(a[0], a[1])
		await _secs(1.0)
		await _mark("area_%s_%s" % [a[0], a[1]])


func _boss_and_finale() -> void:
	for f in ["echa_done", "kruk_done", "haslo_done", "fakty_done"]:
		GameState.set_flag(f)
	await _go("archiwum", "cp_ar_c")
	var boss: Node = World.current.area.boss
	World.current.hero.global_position = boss.global_position + Vector2(0, 140)
	await _secs(0.8)
	_close()
	await _secs(2.5)
	await _mark("boss_fight")
	boss.take_damage(boss.max_hp * 0.36, boss.global_position)
	await _secs(0.5)
	_close()
	await _secs(1.5)
	await _mark("boss_illusion")
	World.current.hero.invuln = 99.0
	# Finał
	GameState.add_item("frag_jasnosc")
	GameState.add_item("frag_logika")
	GameState.add_item("frag_prawda")
	await _go("latarnia", "start")
	World.current.hero.global_position = Vector2(0, -20)
	await _secs(0.8)
	await _mark("hub_tower")
	World.current.use_pedestal()
	await _secs(0.5)
	World.current.dialog._finish()
	await _secs(1.2)
	await _mark("finale_1")
	await _secs(3.0)
	await _mark("finale_2")


func _go(area: String, spawn: String) -> void:
	World.current.travel(area, spawn)
	var waited := 0.0
	while (World.area_id() != area or World.current._travelling) and waited < 30.0:
		await _secs(0.2)
		waited += 0.2
	await _secs(0.5)
	_close()


func _close() -> void:
	var w: Node = World.current
	if w.dialog.visible:
		w.dialog._finish()
	if w.info.visible:
		w.info.close_panel()
	get_tree().paused = false


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _mark(name: String) -> void:
	print("TOUR ", name)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__tour = %s; window.__tourAck = false;" % JSON.stringify(name), true)
		# Czekamy, aż Playwright zrobi zrzut (maks. 6 s).
		var waited := 0.0
		while waited < 6.0:
			await _secs(0.1)
			waited += 0.1
			if str(JavaScriptBridge.eval("window.__tourAck === true ? 1 : 0", true)) == "1":
				break


func _mark_done() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__tour = '__done__';", true)
