extends Node
## Tryb automatycznego testu (dla deweloperów / CI). Włączany argumentami:
##   godot --path client -- --autotest=ws://127.0.0.1:7171,Nazwa,haslo --shots=/tmp/out [--scenario=etap1|etap2]
## Loguje się (rejestruje, gdy konto nie istnieje), wykonuje scenariusz, robi zrzuty ekranu i kończy działanie.

var url := ""
var account := ""
var password := ""
var shots_dir := ""
var scenario := "etap2"
var _mode := "register"
var _steps: Array = []
var _wait := 0.0
var _started := false
var _busy := false
var _t := 0.0


func _ready() -> void:
	if scenario == "login":
		# Tylko zrzut ekranu logowania (scenka 3D w tle).
		await get_tree().create_timer(4.0).timeout
		await _shot("00_logowanie")
		get_tree().quit(0)
		return
	Net.message.connect(_on_message)
	Net.connected.connect(func(): Net.send({"t": _mode, "v": Config.PROTOCOL_VERSION, "name": account, "pass": password}))
	Net.connect_to(url)


func _on_message(msg: Dictionary) -> void:
	if msg.t != "auth_error":
		return
	# Konto już istnieje -> ponowne połączenie i logowanie.
	if _mode == "register":
		_mode = "login"
		Net.connect_to.call_deferred(url)
	else:
		push_error("autotest: " + str(msg.text))
		get_tree().quit(1)


func _game() -> Node:
	for c in get_parent().get_children():
		if c.has_method("attack_nearest"):
			return c
	return null


func _process(delta: float) -> void:
	_t += delta
	var game := _game()
	if game == null:
		if _t > 15.0:
			push_error("autotest: brak logowania")
			get_tree().quit(1)
		return
	if not _started:
		_started = true
		if scenario == "etap1":
			_steps = _scenario_etap1(game)
		elif scenario == "etap4":
			_steps = _scenario_etap4(game)
		elif scenario == "bestiariusz":
			_steps = _scenario_bestiary(game)
		elif scenario == "widoki":
			_steps = _scenario_views(game)
		elif scenario == "bohater":
			_steps = _scenario_hero(game)
		elif scenario == "etap3":
			_steps = _scenario_etap3(game)
		else:
			_steps = _scenario_etap2(game)
		_wait = 1.5
		return
	if _busy:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _steps.is_empty():
		print("autotest: OK, pozycja ", game.my_pos)
		set_process(false)
		get_tree().quit(0)
		return
	_busy = true
	var step: Callable = _steps.pop_front()
	var w = await step.call()
	_wait = float(w) if w != null else 1.5
	_busy = false


# --- Pomocnicze -----------------------------------------------------------------

func _entity(game: Node, kind: String, name_part: String) -> Node:
	var best: Node = null
	for id in game.entities:
		var e = game.entities[id]
		if e.kind == kind and (name_part.is_empty() or str(e.display_name).contains(name_part) or str(e.look).contains(name_part)):
			if best == null or game._dist(e.tile, game.my_pos) < game._dist(best.tile, game.my_pos):
				best = e
	return best


func _tap_entity(game: Node, kind: String, name_part: String) -> float:
	var e := _entity(game, kind, name_part)
	if e == null:
		push_warning("autotest: nie znaleziono %s %s" % [kind, name_part])
		return 0.5
	game._on_tap(e.tile)
	return 1.0 + game._dist(e.tile, game.my_pos) * game.step_ms / 1000.0 * 1.6


func _scenario_etap1(game: Node) -> Array:
	return [
		func(): await _shot("01_miasto"); game._on_tap(game.my_pos + Vector2i(-11, 2)); return 4.5,
		func(): game._on_tap(game.my_pos + Vector2i(-8, -1)); return 4.5,
		func(): game.attack_nearest(); return 4.0,
		func(): await _shot("02_walka"); Net.send({"t": "say", "text": "exura"}); return 1.5,
		func(): game.hud._toggle(game.hud._inventory); await _shot("03_plecak"); return 0.5,
	]


func _scenario_etap2(game: Node) -> Array:
	var hud = game.hud
	return [
		func(): await _shot("01_miasto_npc"); return _tap_entity(game, "n", "Kupiec"),
		func(): await _shot("02_dialog_npc"); Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "handel"}); return 1.0,
		func(): await _shot("03_sklep"); hud.shop.close_window(); hud.npc_dialog.hide(); return 0.3,
		# Zbieractwo: najbliższe złoże T1 za murami.
		func(): return _tap_entity(game, "r", "_1"),
		func(): return 8.0,
		func(): await _shot("04_zbieranie"); return 0.3,
		func(): hud._toggle(hud._inventory); await _shot("05_plecak_surowce"); hud._toggle(hud._inventory); return 0.3,
		# Powrót do miasta i rafinacja u Zenona.
		func(): game._on_tap(Vector2i(int(GameData.cities[0].temple.x), int(GameData.cities[0].temple.y) + 2)); return 3.0 + game._dist(game.my_pos, Vector2i(int(GameData.cities[0].temple.x), int(GameData.cities[0].temple.y))) * game.step_ms / 1000.0 * 1.5,
		func(): return _tap_entity(game, "n", "Rafinator"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "rafineria"}); return 1.0,
		func(): _craft_first(hud); return 1.0,
		func(): await _shot("06_rafineria"); hud.craft.close_window(); hud.npc_dialog.hide(); return 0.3,
		# Rynek u Wandy: wystaw pierwszy materiał.
		func(): game._on_tap(Vector2i(int(GameData.cities[0].temple.x), int(GameData.cities[0].temple.y) + 2)); return 3.0 + game._dist(game.my_pos, Vector2i(int(GameData.cities[0].temple.x), int(GameData.cities[0].temple.y))) * game.step_ms / 1000.0 * 1.5,
		func(): return _tap_entity(game, "n", "Rynkowa"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "rynek"}); return 1.0,
		func(): _sell_first_material(hud); return 1.0,
		func(): hud.market._tab = 4; hud.market._rebuild(); await _shot("07_rynek_moje"); return 0.3,
		func(): hud.market._tab = 2; hud.market._rebuild(); await _shot("08_rynek_wystaw"); hud.market.close_window(); return 0.3,
		# Depozyt u Oskara.
		func(): game._on_tap(Vector2i(int(GameData.cities[0].temple.x), int(GameData.cities[0].temple.y) + 2)); return 3.0 + game._dist(game.my_pos, Vector2i(int(GameData.cities[0].temple.x), int(GameData.cities[0].temple.y))) * game.step_ms / 1000.0 * 1.5,
		func(): return _tap_entity(game, "n", "Bankier"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "depozyt"}); return 1.0,
		func(): Net.send({"t": "depot_put", "slot": _bag_slot(hud, "hp_potion"), "count": 1}); return 1.0,
		func(): await _shot("09_depozyt"); hud.depot.close_window(); hud.npc_dialog.hide(); return 0.3,
		func(): hud._toggle(hud.specs); await _shot("10_specjalizacje"); return 0.3,
	]


## ETAP 3: kapłanka, strefy żółta i czerwona, umiejętności broni.
func _scenario_etap3(game: Node) -> Array:
	var hud = game.hud
	return [
		func(): return _tap_entity(game, "n", "Kapłanka"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "strefy"}); return 1.0,
		func(): await _shot("01_kaplanka"); hud.npc_dialog.hide(); return 0.3,
		# Na południe drogą do żółtej strefy.
		func(): game._on_tap(_zone_tile(game, "y")); return 16.0,
		func(): await _shot("02_strefa_zolta"); return 0.3,
		func(): game.attack_nearest(); return 3.0,
		func(): Net.send({"t": "ability", "slot": 1}); return 0.6,
		func(): await _shot("03_umiejetnosc"); return 2.5,
		func(): game._on_tap(_zone_tile(game, "r")); return 14.0,
		func(): await _shot("04_strefa_czerwona"); return 0.3,
		func(): hud._toggle(hud._character); await _shot("05_postac"); return 0.3,
	]


## Przegląd świata 3D: kamera przelatuje nad jeziorem, Popieliskiem i krawędzią mapy (zrzuty).
func _scenario_views(game: Node) -> Array:
	var spots := [["01_szronogrod", Vector2i(44, 58)], ["02_zlotopiask", Vector2i(180, 58)], ["03_swiatynia_ognia", Vector2i(112, 104)],
		["04_moczary", Vector2i(185, 150)], ["05_puszcza", Vector2i(35, 140)], ["06_gory", Vector2i(112, 40)], ["07_obelisk", Vector2i(130, 124)],
		["08_popielgrod_brama", Vector2i(112, 214)], ["09_wioska", Vector2i(-1, -1)]]
	var steps: Array = []
	# --only=04,05 – tylko wybrane ujęcia (szybsze testy).
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for s in spots:
		if only != "" and not only.split(",").has(str(s[0]).substr(0, 2)):
			continue
		steps.append(func():
			var t: Vector2i = s[1]
			if t.x < 0:
				t = _find_tile("c")
			game.me.snap_to(t)
			game.camera.position = Vector3.ZERO
			return 12.0)
		steps.append(func(): await _shot(s[0]); return 0.1)
	return steps


## ETAP 4: mapa świata, stajnia (wierzchowce), mistrz gildii.
func _scenario_etap4(game: Node) -> Array:
	var hud = game.hud
	return [
		func(): hud._toggle(hud.world_map); return 1.0,
		func(): await _shot("01_mapa_swiata"); hud._toggle(hud.world_map); return 0.3,
		# Stajnia leży w dolnej części miasta – najpierw zejdź w dół, by NPC był w zasięgu wzroku.
		func(): game._on_tap(game.my_pos + Vector2i(4, 9)); return 5.0,
		func(): return _tap_entity(game, "n", "Stajenny"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "handel"}); return 1.0,
		func(): await _shot("02_stajnia"); hud.shop.close_window(); hud.npc_dialog.hide(); return 0.3,
		func(): return _tap_entity(game, "n", "Mistrz gildii"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "terytoria"}); return 1.0,
		func(): await _shot("03_mistrz_gildii"); hud.npc_dialog.hide(); return 0.3,
	]


## Dar bohatera: postać, plecak i jazda na drake'u.
func _scenario_hero(game: Node) -> Array:
	var hud = game.hud
	return [
		func(): await _shot("01_bohater"); hud._toggle(hud._character); return 0.5,
		func(): await _shot("02_postac"); hud._toggle(hud._character); hud._toggle(hud._inventory); return 0.5,
		func(): await _shot("03_plecak"); hud._toggle(hud._inventory); Net.send({"t": "mount"}); return 1.0,
		func(): game._on_tap(game.my_pos + Vector2i(0, 6)); return 3.0,
		func(): await _shot("04_drake"); return 0.3,
	]


## Bestiariusz: modele stworzeń ustawione w rzędach (lokalne istoty tylko do zrzutów).
func _scenario_bestiary(game: Node) -> Array:
	var groups := [
		["01_zwierzeta", ["snow_fox", "scarab", "toad", "scorpion", "snow_wolf", "spider", "bear", "basilisk", "hound", "wolf"]],
		["02_humanoidy", ["bandit", "bandit_archer", "orc", "orc_shaman", "mummy", "zombie", "lizard", "troll", "skeleton", "ash_knight"]],
		["03_potegi", ["yeti", "treant", "golem", "ice_wraith", "fire_elemental", "demon"]],
		["04_bossowie", ["frost_king", "sand_worm", "bog_mother", "ash_dragon"]],
		["05_wierzchowce", ["mount_horse", "mount_elk", "mount_camel", "mount_warwolf", "mount_drake", "obelisk"]],
	]
	var steps: Array = []
	var base := _find_open(Vector2i(112, 160), 16, 10)
	for g in groups:
		steps.append(func():
			for id in game.entities.keys():
				if id < 0:
					game.entities[id].queue_free()
					game.entities.erase(id)
			var looks: Array = g[1]
			var big: bool = g[0] == "04_bossowie"
			var spacing := 5 if big else 3
			var per_row := 4 if big else 5
			for i in looks.size():
				var x: int = base.x + (i % per_row) * spacing - (mini(looks.size(), per_row) - 1) * spacing / 2
				var rows := int(ceil(looks.size() / float(per_row)))
				var y: int = base.y - 2 + (i / per_row) * spacing - (rows - 1) * spacing / 2
				var look: String = looks[i]
				var e := {"i": -(i + 1), "k": "m", "n": look, "x": x, "y": y, "d": 2, "h": 100, "l": look, "s": 0, "b": 1 if big else 0}
				if look.begins_with("mount_"):
					e.k = "p"
					e.l = str(i)
					e["mt"] = look
					e["eq"] = ["plate_head_t5", "plate_body_t5", "plate_legs_t5", "plate_feet_t5", "sword_t6", "shield_t6"]
				elif look == "obelisk":
					e.k = "t"
					e["o"] = "OGN"
				var v = game._create_entity(-(i + 1))
				v.apply(e, false)
			var mounts: bool = g[0] == "05_wierzchowce"
			game.me.snap_to(base + Vector2i(1, 1 if big else 0))
			game._zoom = 1.45 if big else (1.0 if mounts else 1.2)
			game.camera.position = Vector3.ZERO
			return 4.0)
		steps.append(func(): await _shot(g[0]); return 0.1)
	return steps


## Środek wolnego obszaru (same chodliwe kafelki poza drogami) w pobliżu punktu.
func _find_open(near: Vector2i, w: int, h: int) -> Vector2i:
	for r in range(0, 60, 2):
		for dy in range(-r, r + 1, 2):
			for dx in range(-r, r + 1, 2):
				var c := near + Vector2i(dx, dy)
				var ok := true
				for y in range(c.y - h / 2, c.y + h / 2):
					for x in range(c.x - w / 2, c.x + w / 2):
						if not GameData.tile_at(x, y) in [".", ","]:
							ok = false
							break
					if not ok:
						break
				if ok:
					return c
	return near


## Najbliższy chodliwy kafelek w danej strefie (poza strefą ochronną), osiągalny ścieżką.
func _zone_tile(game: Node, z: String) -> Vector2i:
	var p: Vector2i = game.my_pos
	for r in range(1, 90):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := p + Vector2i(dx, dy)
				if GameData.zone_at(t.x, t.y) == z and GameData.is_walkable(t.x, t.y) and not GameData.is_protection_zone(t.x, t.y):
					if not game._find_path(t, false).is_empty():
						return t
	return p


## Pierwszy kafelek danego rodzaju (np. pole uprawne wioski).
func _find_tile(ch: String) -> Vector2i:
	for y in GameData.map_h:
		var row: String = GameData.map_rows[y]
		var x := row.find(ch)
		if x >= 0:
			return Vector2i(x, y + 2)
	return Vector2i(112, 190)


func _bag_slot(hud: Node, item_prefix: String) -> int:
	var bag: Array = hud.bag()
	for i in bag.size():
		if bag[i] is Dictionary and str(bag[i].item).begins_with(item_prefix):
			return i
	return -1


## Rafinuje pierwszy surowiec T1 z plecaka.
func _craft_first(hud: Node) -> void:
	for kind in ["wood", "stone", "ore", "fiber"]:
		if hud.count_item(kind + "_t1") > 0:
			hud.craft._tier = 1
			hud.craft._selected = "refine_%s_t1" % kind
			hud.craft._rebuild()
			Net.send({"t": "craft", "recipe": "refine_%s_t1" % kind, "count": hud.count_item(kind + "_t1")})
			return
	push_warning("autotest: brak surowców do rafinacji")


func _sell_first_material(hud: Node) -> void:
	for prefix in ["planks", "blocks", "bars", "cloth", "wood", "stone", "ore", "fiber"]:
		var slot := _bag_slot(hud, prefix)
		if slot >= 0:
			Net.send({"t": "market_order", "side": "sell", "slot": slot, "count": 1, "price": 9})
			return


func _shot(name: String) -> void:
	if shots_dir.is_empty():
		return
	# Czekamy na narysowanie klatki z aktualnym stanem interfejsu.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [shots_dir, name]
	img.save_png(path)
	print("autotest: zrzut ", path)
