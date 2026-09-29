extends Node2D
## Scena gry: mapa, istoty, loot, efekty, kamera, sterowanie i obsługa pakietów serwera.
##
## Ruch własnej postaci jest PRZEWIDYWANY po stronie klienta (natychmiastowa reakcja),
## ale serwer ma ostatnie słowo – przy odrzuceniu kroku przysyła "pos" i klient się koryguje.

const EntityView := preload("res://scripts/game/entity_view.gd")
const EntityScene := preload("res://scenes/entity.tscn")
const TorchScene := preload("res://scenes/torch.tscn")
const FxLayer := preload("res://scripts/game/fx_layer.gd")
const GroundLayer := preload("res://scripts/game/ground_layer.gd")
const Hud := preload("res://scripts/ui/hud.gd")

## Identyfikatory terenu dla shadera (world_ground.gdshader).
const TERRAIN := {".": 0, ",": 1, "s": 2, "a": 3, "f": 4, "x": 5, "~": 6}
## Cykl dnia i nocy (sekundy czasu rzeczywistego) – wspólny dla wszystkich graczy.
const DAY_CYCLE := 1440.0
const NIGHT_COLOR := Color(0.34, 0.37, 0.58)

const TS := 32
const TAP_MAX_MOVE := 24.0
## Kody kierunków z protokołu: N, E, S, W, NE, SE, SW, NW.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

@onready var ground_rect: ColorRect = $Ground
@onready var ground: GroundLayer = $GroundItems
@onready var creatures: Node2D = $World
@onready var objects: TileMapLayer = $World/Objects
@onready var fx: FxLayer = $Fx
@onready var night_modulate: CanvasModulate = $Night
@onready var camera: Camera2D = $Camera
var hud: Hud
var _torches: Array = []
var _shake := 0.0
## 0 = dzień, 1 = pełna noc.
var night := 0.0
var _night_ready := false

## id -> EntityView
var entities: Dictionary = {}
var me: EntityView = null
var my_pos := Vector2i.ZERO
var my_dir := 2
var step_ms := 300
var target_id := 0
var stats: Dictionary = {}

var _move_cooldown := 0.0
var _path: Array[Vector2i] = []
var _pending_pickup := 0
## Akcja do wykonania po dojściu: {"type": "gather"/"npc", "id": ...}
var _pending_action: Dictionary = {}
## NPC, z którym trwa rozmowa (okna zamykają się po odejściu).
var _talking_npc := 0
var _astar := AStarGrid2D.new()
var _touch_start: Dictionary = {}


func _ready() -> void:
	camera.make_current()
	hud = Hud.new()
	hud.game = self
	hud.layer = 2
	add_child(hud)
	_build_map()
	apply_effects()
	me = _create_entity(GameData.my_id)
	me.is_me = true
	me.kind = "p"
	me.display_name = GameData.my_name
	Net.message.connect(_on_message)


func _build_map() -> void:
	_astar.region = Rect2i(0, 0, GameData.map_w, GameData.map_h)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	# Mapa typów terenu dla shadera (1 piksel = 1 kafelek).
	var terrain := Image.create(GameData.map_w, GameData.map_h, false, Image.FORMAT_R8)
	for y in GameData.map_h:
		var row: String = GameData.map_rows[y]
		for x in GameData.map_w:
			var ch := row[x]
			terrain.set_pixel(x, y, Color(_terrain_under(ch, x, y) / 255.0, 0, 0))
			if not GameData.WALKABLE.contains(ch):
				_astar.set_point_solid(Vector2i(x, y), true)
			_place_object(ch, x, y)
	var mat := ground_rect.material as ShaderMaterial
	mat.set_shader_parameter("map_tex", ImageTexture.create_from_image(terrain))
	mat.set_shader_parameter("map_size", Vector2(GameData.map_w, GameData.map_h))
	ground_rect.size = Vector2(GameData.map_w, GameData.map_h) * TS
	_place_torches()


## Teren pod obiektem (drzewo stoi na trawie albo popiele, mur na bruku...).
func _terrain_under(ch: String, x: int, y: int) -> int:
	if TERRAIN.has(ch):
		return TERRAIN[ch]
	if ch in ["#", "D", "M", "K", "W", "P"]:
		return 4
	# Drzewa i skały: najczęstszy teren w sąsiedztwie.
	var counts := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := GameData.tile_at(x + dx, y + dy)
			if _is_ground(c):
				counts[c] = counts.get(c, 0) + 1
	var best := "."
	for c in counts:
		if counts[c] > counts.get(best, 0):
			best = c
	return TERRAIN.get(best, 0)


static func _is_ground(c: String) -> bool:
	return c in [".", "a", "s", ","]


func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663))


## Obiekty świata w TileMapLayer (sortowanie Y z postaciami).
func _place_object(ch: String, x: int, y: int) -> void:
	var name := ""
	match ch:
		"T":
			name = "tree_%d" % (_hash(x, y) % 4)
		"r":
			var ash := GameData.tile_at(x - 1, y) == "a" or GameData.tile_at(x + 1, y) == "a" or GameData.tile_at(x, y + 1) == "a"
			name = ("rock_ash_%d" if ash else "rock_%d") % (_hash(x, y) % 2)
		"#":
			var front := GameData.tile_at(x, y + 1) != "#"
			name = ("wall_front_%d" if front else "wall_inner_%d") % (_hash(x, y) % 3)
		"D":
			name = "chest"
		"M":
			name = "stall"
		"K":
			name = "anvil"
		"W":
			name = "workbench"
		"P":
			name = "furnace"
	if name != "":
		objects.set_cell(Vector2i(x, y), 0, Sprites.object_coords(name))


## Pochodnie przy bramach miasta, w narożnikach świątyni i ogień w piecu rafinerii.
func _place_torches() -> void:
	## [pozycja, czy pokazać sprite pochodni]
	var spots: Array = []
	for y in GameData.map_h:
		for x in GameData.map_w:
			var ch := GameData.tile_at(x, y)
			if ch == "#":
				# Mur przy bramie (poziomej lub pionowej).
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var g: Vector2i = Vector2i(x, y) + d
					var gc := GameData.tile_at(g.x, g.y)
					var horizontal: bool = d.y == 0
					var is_gate := GameData.is_walkable(g.x, g.y) and gc != "#"
					if is_gate and horizontal and GameData.tile_at(g.x, g.y - 1) != "#" and GameData.tile_at(g.x, g.y + 1) != "#" \
							and GameData.tile_at(x, y + 1) != "#":
						spots.append([Vector2(x, y) * TS + Vector2(0, -14), true])
						break
			elif ch == "P":
				# Palenisko pieca rafinerii: sam ogień i światło.
				spots.append([Vector2(x, y) * TS + Vector2(-0.5, 14), false])
			elif ch == "x" and GameData.tile_at(x - 1, y) != "x" and GameData.tile_at(x, y - 1) != "x":
				spots.append([Vector2(x - 1, y - 1) * TS, true])
			elif ch == "x" and GameData.tile_at(x + 1, y) != "x" and GameData.tile_at(x, y - 1) != "x":
				spots.append([Vector2(x + 1, y - 1) * TS, true])
	for sp in spots:
		var t := TorchScene.instantiate()
		t.position = sp[0]
		t.show_sprite = sp[1]
		creatures.add_child(t)
		_torches.append(t)


## Włącza/wyłącza efekty (cząsteczki, światła, winieta) – ustawienie w menu.
func apply_effects() -> void:
	var on := Config.effects
	$Camera/Ash.emitting = on
	$Camera/Ash.visible = on
	$Camera/Embers.emitting = on
	$Camera/Embers.visible = on
	$Vignette.visible = on
	for t in _torches:
		t.get_node("Fire").emitting = on
		t.night = night


func _create_entity(id: int) -> EntityView:
	var e: EntityView = EntityScene.instantiate()
	e.id = id
	creatures.add_child(e)
	entities[id] = e
	return e


# ============================================================================
# Pakiety serwera
# ============================================================================

func _on_message(msg: Dictionary) -> void:
	match msg.t:
		"snap":
			_on_snapshot(msg)
		"pos":
			my_pos = Vector2i(int(msg.x), int(msg.y))
			my_dir = int(msg.d)
			me.dir = my_dir
			me.snap_to(my_pos)
			_path.clear()
			_move_cooldown = 0.0
		"stats":
			stats = msg
			step_ms = int(msg.step)
			_set_target(int(msg.target))
			me.gathering = int(msg.get("gather", 0)) != 0
			me.queue_redraw()
			hud.update_stats(msg)
		"npc_dialog":
			_talking_npc = int(msg.id)
			hud.show_npc_dialog(msg)
		"shop":
			hud.show_shop(msg)
		"depot":
			hud.show_depot(msg)
		"market":
			hud.show_market(msg)
		"craft_open":
			hud.show_craft(msg)
		"inv":
			hud.update_inventory(msg)
		"fx":
			for f in msg.l:
				fx.spawn(f)
				_fx_sound(f)
				if f.k == "num" and f.c == "dmg":
					_on_damage(Vector2i(int(f.x), int(f.y)))
		"chat":
			hud.add_chat("[color=#f0e070]%s:[/color] %s" % [msg.from, _escape(str(msg.text))])
			if entities.has(int(msg.id)):
				var e: EntityView = entities[int(msg.id)]
				fx.say(e.tile.x, e.tile.y, str(msg.from), str(msg.text))
		"sys":
			hud.add_chat("[color=#a0d0ff]%s[/color]" % _escape(str(msg.text)))
		"online":
			hud.show_online(msg.list)
		"died":
			hud.show_death(str(msg.by), int(msg.lost))
			Sfx.play("death")
		"sfx":
			Sfx.play(str(msg.k))


func _on_snapshot(msg: Dictionary) -> void:
	var seen := {}
	for e in msg.e:
		var id := int(e.i)
		seen[id] = true
		var view: EntityView = entities.get(id)
		if view == null:
			view = _create_entity(id)
			view.snap_to(Vector2i(int(e.x), int(e.y)))
		view.apply(e, id == GameData.my_id)
	for id in entities.keys():
		if not seen.has(id) and id != GameData.my_id:
			entities[id].vanish()
			entities.erase(id)
	ground.set_items(msg.g)
	_set_target(target_id)
	_update_labels()
	_update_minimap()


func _update_minimap() -> void:
	var dots := []
	for id in entities:
		var e: EntityView = entities[id]
		if e.is_me or e.kind == "r":
			continue
		var col := Color(0.4, 1, 0.4)
		if e.kind == "m":
			col = Color(1, 0.3, 0.25)
		elif e.kind == "n":
			col = Color(1, 0.85, 0.3)
		dots.append([e.tile, col])
	hud.minimap.update_view(my_pos, dots)


## Nazwy złóż widoczne tylko w pobliżu; okna NPC zamykane po odejściu od NPC.
func _update_labels() -> void:
	for id in entities:
		var e: EntityView = entities[id]
		if e.kind == "r":
			var near := _dist(e.tile, my_pos) <= 3
			if near != e.show_label:
				e.show_label = near
				e.queue_redraw()
	if _talking_npc != 0:
		var n: EntityView = entities.get(_talking_npc)
		if n == null or _dist(n.tile, my_pos) > 3:
			_talking_npc = 0
			hud.close_npc_windows()


## Trafienie: błysk istoty na kafelku, wstrząs kamery gdy trafiono nas.
func _on_damage(t: Vector2i) -> void:
	for id in entities:
		var e: EntityView = entities[id]
		if e.tile == t and e.kind != "r":
			e.flash()
	if t == my_pos:
		_shake = 0.25


func _set_target(id: int) -> void:
	if entities.has(target_id):
		entities[target_id].targeted = false
		entities[target_id].queue_redraw()
	target_id = id
	if entities.has(id):
		entities[id].targeted = true
		entities[id].queue_redraw()


func _fx_sound(f: Dictionary) -> void:
	match str(f.k):
		"num":
			if f.c == "dmg":
				Sfx.play("hurt" if int(f.x) == my_pos.x and int(f.y) == my_pos.y else "hit")
		"miss", "block":
			Sfx.play("miss")
		"shot":
			Sfx.play("shot")
		"heal":
			Sfx.play("heal")
		"levelup":
			Sfx.play("levelup")
		"gather":
			Sfx.play("gather")


static func _escape(t: String) -> String:
	return t.replace("[", "[lb]")


# ============================================================================
# Akcje gracza (wywoływane też z HUD)
# ============================================================================

func attack(id: int) -> void:
	if id == target_id:
		id = 0
	Net.send({"t": "attack", "id": id})
	_set_target(id)


## Przycisk „Atak”: wybiera najbliższego potwora (kolejne naciśnięcia – następnego).
func attack_nearest() -> void:
	var monsters: Array = []
	for id in entities:
		var e: EntityView = entities[id]
		if e.kind == "m":
			monsters.append(e)
	if monsters.is_empty():
		hud.add_chat("[color=#a0a0a0]Brak potworów w pobliżu.[/color]")
		return
	monsters.sort_custom(func(a, b): return _dist(a.tile, my_pos) < _dist(b.tile, my_pos))
	var pick: EntityView = monsters[0]
	if target_id != 0 and monsters.size() > 1 and pick.id == target_id:
		pick = monsters[1]
	Net.send({"t": "attack", "id": pick.id})
	_set_target(pick.id)


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ============================================================================
# Sterowanie: dotyk (tap-to-move / atak / podnoszenie), joystick, klawiatura
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start[event.index] = event.position
		elif _touch_start.has(event.index):
			var start: Vector2 = _touch_start[event.index]
			_touch_start.erase(event.index)
			if start.distance_to(event.position) < TAP_MAX_MOVE:
				_on_tap(_screen_to_tile(event.position))


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var world := get_canvas_transform().affine_inverse() * screen_pos
	return Vector2i(floori(world.x / TS), floori(world.y / TS))


func _on_tap(tile: Vector2i) -> void:
	fx.tap_marker(tile)
	_pending_action = {}
	# 1. Potwór na kafelku -> atak (drugi tap – przerwanie ataku).
	for id in entities:
		var e: EntityView = entities[id]
		if e.kind == "m" and e.tile == tile:
			attack(id)
			return
	# 1b. NPC -> rozmowa (podejdź, jeśli daleko).
	for id in entities:
		var e: EntityView = entities[id]
		if e.kind == "n" and e.tile == tile:
			_pending_action = {"type": "npc", "id": id, "tile": tile, "range": 3}
			if _dist(tile, my_pos) > 3:
				_path = _find_path(tile, true)
			return
	# 1c. Złoże surowca -> zbieraj (podejdź na sąsiednie pole).
	for id in entities:
		var e: EntityView = entities[id]
		if e.kind == "r" and e.tile == tile:
			_pending_action = {"type": "gather", "id": id, "tile": tile, "range": 1}
			if _dist(tile, my_pos) > 1 or tile == my_pos:
				_path = _find_path(tile, true)
				if tile == my_pos:
					_path = _step_off()
			return
	# 2. Przedmiot na ziemi -> podnieś (podejdź, jeśli daleko).
	var item_id := ground.item_at(tile)
	if item_id != 0:
		if _dist(tile, my_pos) <= 1:
			Net.send({"t": "pickup", "id": item_id})
		else:
			_pending_pickup = item_id
			_path = _find_path(tile, true)
		return
	# 3. Zwykły kafelek -> idź tam.
	_pending_pickup = 0
	_path = _find_path(tile, false)


## Ścieżka A* (bez pozycji startowej). stop_adjacent: zatrzymaj się obok celu.
func _find_path(to: Vector2i, stop_adjacent: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _astar.region.has_point(to) or not _astar.region.has_point(my_pos):
		return result
	# Potwory traktujemy jako przeszkody na czas liczenia ścieżki.
	var blocked: Array[Vector2i] = []
	for id in entities:
		var e: EntityView = entities[id]
		if (e.kind == "m" or e.kind == "n") and e.tile != to and _astar.region.has_point(e.tile) and not _astar.is_point_solid(e.tile):
			_astar.set_point_solid(e.tile, true)
			blocked.append(e.tile)
	var target_solid := _astar.is_point_solid(to)
	if target_solid:
		_astar.set_point_solid(to, false)
	var path := _astar.get_id_path(my_pos, to)
	if target_solid:
		_astar.set_point_solid(to, true)
	for t in blocked:
		_astar.set_point_solid(t, false)
	for i in range(1, path.size()):
		result.append(path[i])
	if (stop_adjacent or target_solid) and not result.is_empty():
		result.pop_back()
	return result


func _process(delta: float) -> void:
	if me == null:
		return
	camera.position = me.position + Vector2(TS / 2.0, TS / 2.0)
	_update_day_night(delta)
	if _shake > 0.0:
		_shake -= delta
		camera.offset = Vector2(randf_range(-3, 3), randf_range(-3, 3)) * (_shake / 0.25)
	else:
		camera.offset = Vector2.ZERO
	_move_cooldown -= delta
	if _move_cooldown > 0.0:
		return

	var input := hud.joystick_vector()
	if input == Vector2.ZERO:
		input = _keyboard_vector()
	if input.length() > 0.3:
		_path.clear()
		_pending_pickup = 0
		_pending_action = {}
		_try_step(_quantize(input), false)
		return

	if not _path.is_empty():
		var next: Vector2i = _path[0]
		var step := next - my_pos
		if absi(step.x) > 1 or absi(step.y) > 1:
			_path.clear()
			return
		if _try_step(step, true):
			_path.pop_front()
		return

	if not _pending_action.is_empty():
		var a := _pending_action
		_pending_action = {}
		if _dist(a.tile, my_pos) <= int(a.range) and a.tile != my_pos:
			if a.type == "npc":
				Net.send({"t": "npc", "id": a.id, "word": "witaj"})
			else:
				Net.send({"t": "gather", "id": a.id})
		return

	if _pending_pickup != 0:
		if ground.items.has(_pending_pickup):
			var g: Dictionary = ground.items[_pending_pickup]
			if _dist(Vector2i(int(g.x), int(g.y)), my_pos) <= 1:
				Net.send({"t": "pickup", "id": _pending_pickup})
		_pending_pickup = 0
		return

	_chase_target()


## Automatyczne podchodzenie do celu (wręcz: na sąsiednie pole, łuk: na zasięg strzału).
func _chase_target() -> void:
	if target_id == 0 or not entities.has(target_id):
		return
	var t: EntityView = entities[target_id]
	var weapon_range := 1
	var weapon = hud.equipped("weapon")
	if weapon:
		weapon_range = int(GameData.item_def(str(weapon.item)).get("range", 1))
	if _dist(t.tile, my_pos) <= weapon_range:
		return
	var path := _find_path(t.tile, true)
	if not path.is_empty():
		_try_step(path[0] - my_pos, true)


## Strzałki i WASD (do testów na komputerze).
static func _keyboard_vector() -> Vector2:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1
	return v


## Krok na dowolne wolne sąsiednie pole (gdy stoimy na złożu).
func _step_off() -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in DIRS:
		var t := my_pos + d
		if GameData.is_walkable(t.x, t.y):
			r.append(t)
			break
	return r


static func _quantize(v: Vector2) -> Vector2i:
	var idx := int(round(v.angle() / (PI / 4.0))) % 8
	var ang := idx * PI / 4.0
	return Vector2i(int(round(cos(ang))), int(round(sin(ang))))


func _try_step(step: Vector2i, from_path: bool) -> bool:
	if step == Vector2i.ZERO:
		return false
	var dest := my_pos + step
	var free := GameData.is_walkable(dest.x, dest.y)
	if free:
		for id in entities:
			var e: EntityView = entities[id]
			if (e.kind == "m" or e.kind == "n") and e.tile == dest:
				free = false
				break
	var dir := _facing(step)
	if not free:
		me.dir = dir
		me.queue_redraw()
		if from_path:
			# Ścieżka zablokowana (np. przez potwora) – przelicz.
			var goal: Vector2i = _path.back() if not _path.is_empty() else dest
			_path = _find_path(goal, false)
		_move_cooldown = 0.1
		return false
	Net.send({"t": "move", "d": DIRS.find(step)})
	var diagonal := step.x != 0 and step.y != 0
	var dur := step_ms * (1.4 if diagonal else 1.0) / 1000.0
	_move_cooldown = dur
	my_pos = dest
	my_dir = dir
	me.move_to(dest, dur, dir)
	me.gathering = false
	_update_labels()
	_update_minimap()
	return true


static func _facing(step: Vector2i) -> int:
	if absi(step.x) > absi(step.y):
		return 1 if step.x > 0 else 3
	return 2 if step.y > 0 else 0


## Pora dnia z zegara (wspólna dla wszystkich): długi dzień, zmierzch, noc, świt.
func _update_day_night(_delta: float) -> void:
	var t := fmod(Time.get_unix_time_from_system(), DAY_CYCLE) / DAY_CYCLE
	# 0.00–0.60 dzień, 0.60–0.70 zmierzch, 0.70–0.92 noc, 0.92–1.00 świt.
	var n := 0.0
	if t > 0.6 and t <= 0.7:
		n = (t - 0.6) / 0.1
	elif t > 0.7 and t <= 0.92:
		n = 1.0
	elif t > 0.92:
		n = 1.0 - (t - 0.92) / 0.08
	n = smoothstep(0.0, 1.0, n)
	# Podgląd pory dnia (testy / zrzuty): argument --night albo --day.
	if "--night" in OS.get_cmdline_user_args():
		n = 1.0
	elif "--day" in OS.get_cmdline_user_args():
		n = 0.0
	if _night_ready and absf(n - night) < 0.002:
		return
	_night_ready = true
	night = n
	var evening := Color(1.0, 0.82, 0.7)
	var c := Color.WHITE.lerp(evening, clampf(n * 2.0, 0.0, 1.0)).lerp(NIGHT_COLOR, clampf(n * 1.5 - 0.5, 0.0, 1.0))
	night_modulate.color = c
	for tr in _torches:
		tr.night = n
	if me:
		me.light.enabled = n > 0.05 and Config.effects
		me.light.energy = 0.9 * n
	hud.set_time_of_day(n)


func logout() -> void:
	Net.close()
	Net.disconnected.emit("Wylogowano.")
