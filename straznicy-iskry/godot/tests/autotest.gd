extends Node
## Automatyczne przejście całej gry każdą klasą (headless lub w przeglądarce: ?autotest=1).
## Sprawdza: samouczek, wszystkie zadania, osiągalność celów (brak blokad),
## walkę, bossa, śmierć i odrodzenie, finał. Wynik: linie PASS/FAIL i AUTOTEST_RESULT.

const WORLD := preload("res://scenes/world.tscn")
const CELL := 24.0

var fails: Array = []
var passes := 0
var world: Node = null
var log_lines: Array = []


func _ready() -> void:
	GameState.saving_enabled = false
	Audio.unlock()
	await get_tree().process_frame
	var classes: Array = Data.class_order
	var only: String = OS.get_environment("AUTOTEST_CLASS")
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search", true))
		for c in Data.class_order:
			if q.contains("class=" + c):
				only = c
	if only != "":
		classes = [only]
	for cid in classes:
		await _run_class(cid)
	await _test_death()
	_report()


func _ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + what)
	else:
		fails.append(what)
		_log("FAIL " + what)


func _log(s: String) -> void:
	print(s)
	log_lines.append(s)


func _wait(frames := 2) -> void:
	for i in frames:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _start_world() -> void:
	if world:
		world.queue_free()
		await _wait(2)
	get_tree().paused = false
	world = WORLD.instantiate()
	get_tree().root.add_child(world)
	await _wait(3)
	await _secs(0.8)
	_close_overlays()
	await _wait(2)


func _close_overlays() -> void:
	var w: Node = World.current
	if w == null:
		return
	if w.dialog.visible:
		w.dialog._finish()
	if w.info.visible:
		w.info.close_panel()
	if w.menu.visible:
		w.menu.close_menu()
	get_tree().paused = false


func _until(cond: Callable, timeout := 60.0) -> bool:
	## Czeka na warunek zamiast na stały czas (wolne renderowanie w przeglądarce).
	var t := 0.0
	while not cond.call() and t < timeout:
		await _secs(0.1)
		t += 0.1
	return cond.call()


func _settled() -> bool:
	## Wszystkie animacje zmian świata (bramy, mosty, iluzje) zakończone.
	for b in World.current.area.bridges:
		if GameState.flags_met(b.flag) and not b.is_built():
			return false
	for layer in [World.current.area.ground, World.current.area.entities]:
		for c in layer.get_children():
			if c.get("kind") != null and c.get("state") != null and c.get("flag") != null:
				if GameState.flags_met(c.flag) and c.state < 1.0:
					return false
	return true


func _settle() -> void:
	await _until(_settled)
	await _wait(3)


func _travel(area: String, spawn := "start") -> void:
	World.current.travel(area, spawn)
	await _secs(0.2)
	await _until(func() -> bool: return World.area_id() == area and not World.current._travelling)
	await _secs(0.3)
	_close_overlays()
	await _wait(2)
	_ok(World.area_id() == area, "podróż do %s" % area)


func _find(kind: String, id: String) -> Node:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.kind == kind and (id == "" or n.id == id):
			return n
	return null


func _talk(npc_id: String) -> void:
	var n := _find("npc", npc_id)
	_ok(n != null, "NPC %s istnieje" % npc_id)
	if n == null:
		return
	_ok(_reachable(n.global_position), "NPC %s osiągalny" % npc_id)
	World.current.start_npc_dialog(n)
	await _wait(2)
	_ok(World.current.dialog.visible, "dialog z %s otwarty" % npc_id)
	World.current.dialog._finish()
	await _wait(2)
	_close_overlays()


func _mission(mid: String) -> void:
	var st := _find("station", mid)
	_ok(st != null, "stacja %s istnieje" % mid)
	if st == null:
		return
	_ok(st.is_active(), "stacja %s aktywna" % mid)
	_ok(_reachable(st.global_position), "stacja %s osiągalna (brak blokady)" % mid)
	World.current.hero.global_position = st.global_position + Vector2(0, 40)
	await _wait(2)
	World.current.open_mission(mid)
	await _wait(2)
	var pz: Control = World.current.puzzle
	_ok(pz.visible and pz.engine != null, "zadanie %s otwarte" % mid)
	# Pusta/niepoprawna próba nie może przejść i nie odbiera zdrowia.
	var hp_before: float = GameState.hp
	var bad: Dictionary = pz.engine.check()
	_ok(not bad.get("ok", false) and str(bad.get("msg", "")) != "", "zadanie %s odrzuca błędną odpowiedź z wyjaśnieniem" % mid)
	_ok(GameState.hp == hp_before, "błąd w zadaniu %s nie odbiera zdrowia" % mid)
	_ok(pz.autosolve(), "zadanie %s rozwiązywalne" % mid)
	await _wait(1)
	pz._finish_success()
	await _wait(2)
	_ok(GameState.is_mission_done(mid), "zadanie %s zaliczone" % mid)
	await _secs(0.3)
	_close_overlays()


func _kill_all() -> void:
	for e in World.enemies():
		if not e.is_boss:
			e.take_damage(9999.0, e.global_position + Vector2(10, 0))
	await _wait(3)


func _combat_check() -> void:
	## Prawdziwy atak gracza musi zadać obrażenia najbliższemu przeciwnikowi.
	var es := World.enemies()
	if es.is_empty():
		_ok(false, "brak przeciwników do testu walki")
		return
	var e: Node2D = es[0]
	var p: Node2D = World.current.hero
	p.global_position = e.global_position + Vector2(-70, 0)
	await _wait(3)
	_close_overlays()
	e.set_physics_process(false)
	var hp0: float = e.hp
	for i in 40:
		p.aim = (e.global_position - p.global_position).normalized()
		p.cooldowns["attack"] = 0.0
		p.try_attack()
		await get_tree().physics_frame
		if e.hp < hp0:
			break
	e.set_physics_process(true)
	_ok(e.hp < hp0, "atak podstawowy klasy %s rani przeciwnika" % GameState.class_id())
	# Umiejętność 1 (koszt energii, czas odnowienia)
	GameState.energy = GameState.max_energy()
	var en0 := GameState.energy
	p.cooldowns["skill1"] = 0.0
	p.try_skill("skill1")
	_ok(GameState.energy < en0 and p.cooldowns["skill1"] > 0.0, "umiejętność 1 klasy %s zużywa energię i ma odnowienie" % GameState.class_id())


func _run_class(cid: String) -> void:
	_log("=== KLASA: %s ===" % cid)
	GameState.new_game(cid)
	await _start_world()
	_ok(World.area_id() == "latarnia", "start w Latarni")
	_ok(World.current.hero.class_id == cid, "gracz ma klasę %s" % cid)
	# Samouczek
	await _talk("lumi")
	_ok(GameState.has_flag("talked_lumi"), "rozmowa z Lumi ustawia flagę")
	await _combat_check()
	await _kill_all()
	_ok(GameState.has_flag("cleared_tutorial"), "samouczek walki zaliczony")
	await _mission("m_lampa")
	await _wait(5)
	var portal := _find("portal", "p_ogrod")
	_ok(portal != null and portal.is_active(), "portal do Ogrodu aktywny po lampie")
	_ok(_reachable(portal.global_position), "portal do Ogrodu osiągalny")
	# Ogród
	await _travel("ogrod")
	await _talk("fela")
	await _kill_all()
	_ok(not _reachable(Vector2(600, 0)), "druga wyspa Ogrodu zablokowana przed mostem")
	await _mission("m_most")
	await _until(func() -> bool: return World.current.area.bridges[0].is_built())
	await _wait(3)
	_ok(_reachable(Vector2(780, 280)), "most w Ogrodzie prowadzi na drugą wyspę")
	await _mission("m_portal")
	await _wait(5)
	var ps := _find("portal", "p_szklarnia")
	_ok(ps != null and ps.is_active(), "portal do Szklarni aktywny")
	await _travel("ogrod", "szklarnia")
	await _mission("m_ogrodnik")
	_ok(GameState.item_count("frag_jasnosc") == 1, "Fragment Jasności w ekwipunku")
	_ok(GameState.data["level"] >= 2, "poziom >= 2 po Ogrodzie (jest %d)" % GameState.level())
	# Warsztat
	await _travel("latarnia", "from_ogrod")
	var pw := _find("portal", "p_warsztat")
	_ok(pw != null and pw.is_active(), "portal do Warsztatu aktywny")
	await _travel("warsztat")
	await _talk("tosia")
	await _kill_all()
	_ok(not _reachable(Vector2(620, -360)), "druga wyspa Warsztatu zablokowana przed kładką")
	await _mission("m_nawadnianie")
	await _until(func() -> bool: return World.current.area.bridges[0].is_built())
	await _wait(3)
	await _mission("m_przenosnik")
	await _settle()
	await _mission("m_uprawnienia")
	await _settle()
	await _mission("m_redakcja")
	_ok(GameState.item_count("frag_logika") == 1, "Fragment Logiki w ekwipunku")
	# Archiwum
	await _travel("latarnia", "from_warsztat")
	var pa := _find("portal", "p_archiwum")
	_ok(pa != null and pa.is_active(), "portal do Archiwum aktywny")
	await _travel("archiwum")
	await _talk("sowa")
	_ok(GameState.item_count("lupa") == 1, "Lupa Źródeł od Sowińskiego")
	await _kill_all()
	_ok(not _reachable(Vector2(660, 300)), "Sala Kruków zablokowana iluzją")
	await _mission("m_echa")
	await _settle()
	await _mission("m_kruk")
	await _settle()
	await _mission("m_haslo")
	await _settle()
	await _kill_all()
	await _mission("m_fakty")
	await _settle()
	# Boss — przeładowanie obszaru tworzy Miraża (wymaga fakty_done).
	await _travel("archiwum", "cp_ar_c")
	await _kill_all()
	var boss: Node = World.current.area.boss
	_ok(boss != null, "Miraż pojawia się po Regałach Wiedzy")
	_ok(_reachable(boss.global_position), "Sala Luster osiągalna")
	await _boss_fight(boss)
	_ok(GameState.has_flag("boss_defeated"), "Miraż pokonany")
	_ok(GameState.item_count("frag_prawda") == 1, "Fragment Prawdy w ekwipunku")
	var win := _find("portal", "p_ar_win")
	_ok(win != null and win.is_active() and _reachable(win.global_position), "portal powrotny po bossie aktywny i osiągalny")
	# Finał
	await _travel("latarnia", "from_archiwum")
	var ped := _find("pedestal", "")
	_ok(_reachable(ped.global_position), "ołtarz fragmentów osiągalny")
	World.current.use_pedestal()
	await _wait(3)
	_ok(World.current.dialog.visible, "dialog finałowy")
	World.current.dialog._finish()
	await _secs(1.0)
	for c in World.current._ui_layer.get_children():
		if c.has_method("play"):
			c._end()
	await _secs(0.6)
	_close_overlays()
	_ok(GameState.has_flag("lighthouse_restored") and GameState.data["game_complete"], "finał: Latarnia przywrócona")
	_ok(GameState.level() == 5, "poziom 5 osiągnięty (jest %d, PD %d)" % [GameState.level(), GameState.data["xp"]])
	_ok(GameState.data["missions_done"].size() == Data.missions.size(), "wszystkie zadania (%d)" % Data.missions.size())
	# Dalsza eksploracja po zakończeniu
	await _travel("ogrod")
	_ok(not World.current.busy(), "eksploracja po zakończeniu możliwa")
	# Zmiana klasy bez utraty postępu
	var other: String = Data.class_order[(Data.class_order.find(cid) + 1) % 4]
	var done_before: int = GameState.data["missions_done"].size()
	World.current.change_class(other)
	_ok(GameState.class_id() == other and GameState.data["missions_done"].size() == done_before, "zmiana klasy zachowuje postęp")
	_log("Podsumowanie %s: zadania=%d poziom=%d PD=%d" % [cid, done_before, GameState.level(), GameState.data["xp"]])


func _boss_fight(boss: Node) -> void:
	World.current.hero.global_position = boss.global_position + Vector2(0, 260)
	await _secs(0.5)
	_close_overlays()
	await _wait(2)
	_ok(World.current._boss_awake, "Miraż budzi się, gdy gracz wejdzie do sali")
	var guard := 0
	while boss.alive and guard < 80:
		guard += 1
		if boss.illusion:
			var copies: Array = boss._copies.duplicate()
			_ok(copies.size() == 2, "faza iluzji: 2 kopie + prawdziwy")
			_ok(boss._clues.size() == 2, "faza iluzji: 2 Kamienie Prawdy")
			# Każda kopia różni się od prawdziwego co najmniej jedną cechą ze wskazówek.
			for c in copies:
				_ok(c.props != boss.props, "kopia różni się od prawdziwego")
			# Atak obszarowy nie może rozstrzygnąć zagadki za gracza.
			Abilities._burst_damage(boss.global_position, 3000.0, 5.0)
			await _wait(2)
			_ok(boss.illusion and boss._copies.size() == 2, "atak obszarowy nie demaskuje iluzji")
			copies[0].take_damage(10.0, Vector2.ZERO)
			await _wait(2)
			_ok(boss.illusion and boss._copies.size() == 1, "trafienie kopii jej nie myli z prawdziwym")
			boss.take_damage(10.0, Vector2.ZERO)
			await _wait(2)
			_ok(not boss.illusion, "trafienie prawdziwego kończy iluzję")
			await _kill_all()
		else:
			boss.take_damage(90.0, boss.global_position + Vector2(0, 50))
			await _wait(2)
	await _secs(2.0)
	_close_overlays()
	await _wait(2)


func _test_death() -> void:
	_log("=== ŚMIERĆ I ODRODZENIE ===")
	GameState.new_game("straznik")
	GameState.set_flag("intro_seen_world")
	await _start_world()
	await _talk("lumi")
	GameState.set_checkpoint("latarnia", "cp_hub")
	var done: int = GameState.data["missions_done"].size()
	var p: Node = World.current.hero
	p.invuln = 0.0
	p.shield_ready = false
	GameState.hp = 5.0
	p.take_damage(50.0, p.global_position + Vector2(20, 0))
	_ok(p.dead, "gracz pada przy 0 PŻ")
	await _until(func() -> bool: return not p.dead and not World.current._travelling)
	await _secs(0.8)
	_close_overlays()
	await _wait(3)
	_ok(not p.dead and GameState.hp == GameState.max_hp(), "odrodzenie z pełnym zdrowiem")
	_ok(p.global_position.distance_to(World.current.area.spawn_point("cp_hub")) < 40.0, "odrodzenie przy Kamieniu Iskry")
	_ok(GameState.has_flag("talked_lumi"), "flagi fabularne zachowane po porażce")
	_ok(GameState.data["missions_done"].size() == done, "zadania zachowane po porażce (%d/%d)" % [GameState.data["missions_done"].size(), done])
	_ok(int(GameState.data["deaths"]) == 1, "licznik powrotów")


func _reachable(target: Vector2) -> bool:
	## Przeszukiwanie siatki od pozycji gracza z uwzględnieniem kolizji (bramy, rekwizyty, krawędzie).
	var area: Node = World.current.area
	var start: Vector2 = World.current.hero.global_position
	var space := World.current.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.collision_mask = 1
	var seen := {}
	var key := func(p: Vector2) -> Vector2i: return Vector2i(roundi(p.x / CELL), roundi(p.y / CELL))
	var goal: Vector2i = key.call(target)
	var queue: Array = [key.call(start)]
	seen[queue[0]] = true
	var bounds: Rect2 = area.bounds.grow(200)
	var steps := 0
	while not queue.is_empty() and steps < 60000:
		steps += 1
		var c: Vector2i = queue.pop_front()
		if (c - goal).length() <= 2.5:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			var wp := Vector2(n) * CELL
			if not bounds.has_point(wp) or not area.is_walkable(wp):
				continue
			q.transform = Transform2D(0, wp)
			if not space.intersect_shape(q, 1).is_empty():
				continue
			seen[n] = true
			queue.append(n)
	return false


func _report() -> void:
	_log("AUTOTEST_RESULT passes=%d fails=%d" % [passes, fails.size()])
	for f in fails:
		_log("  - " + f)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__autotest = %s" % JSON.stringify({"passes": passes, "fails": fails}), true)
	else:
		get_tree().quit(0 if fails.is_empty() else 1)
