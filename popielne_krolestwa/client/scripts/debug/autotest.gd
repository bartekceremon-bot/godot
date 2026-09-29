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
		# Rafinacja u Zenona.
		func(): return _tap_entity(game, "n", "Rafinator"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "rafineria"}); return 1.0,
		func(): _craft_first(hud); return 1.0,
		func(): await _shot("06_rafineria"); hud.craft.close_window(); return 0.3,
		# Rynek u Wandy: wystaw pierwszy materiał.
		func(): return _tap_entity(game, "n", "Rynkowa"),
		func(): Net.send({"t": "npc", "id": hud.npc_dialog.npc_id, "word": "rynek"}); return 1.0,
		func(): _sell_first_material(hud); return 1.0,
		func(): hud.market._tab = 4; hud.market._rebuild(); await _shot("07_rynek_moje"); return 0.3,
		func(): hud.market._tab = 2; hud.market._rebuild(); await _shot("08_rynek_wystaw"); hud.market.close_window(); return 0.3,
		# Depozyt u Oskara.
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
		func(): game._on_tap(Vector2i(48, 71)); return 12.0,
		func(): await _shot("02_strefa_zolta"); return 0.3,
		func(): game.attack_nearest(); return 3.0,
		func(): Net.send({"t": "ability", "slot": 1}); return 0.6,
		func(): await _shot("03_umiejetnosc"); return 2.5,
		func(): game._on_tap(Vector2i(48, 84)); return 6.0,
		func(): await _shot("04_strefa_czerwona"); return 0.3,
		func(): hud._toggle(hud._character); await _shot("05_postac"); return 0.3,
	]


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
