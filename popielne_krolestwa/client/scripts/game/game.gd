extends Node2D
## Scena gry: mapa, istoty, loot, efekty, kamera, sterowanie i obsługa pakietów serwera.
##
## Ruch własnej postaci jest PRZEWIDYWANY po stronie klienta (natychmiastowa reakcja),
## ale serwer ma ostatnie słowo – przy odrzuceniu kroku przysyła "pos" i klient się koryguje.

const EntityView := preload("res://scripts/game/entity_view.gd")
const FxLayer := preload("res://scripts/game/fx_layer.gd")
const GroundLayer := preload("res://scripts/game/ground_layer.gd")
const Hud := preload("res://scripts/ui/hud.gd")

const TS := 32
const TAP_MAX_MOVE := 24.0
## Kody kierunków z protokołu: N, E, S, W, NE, SE, SW, NW.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var tilemap: TileMapLayer
var ground: GroundLayer
var creatures: Node2D
var fx: FxLayer
var camera: Camera2D
var hud: Hud

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
var _astar := AStarGrid2D.new()
var _touch_start: Dictionary = {}


func _ready() -> void:
	tilemap = TileMapLayer.new()
	tilemap.tile_set = Sprites.tileset()
	add_child(tilemap)
	ground = GroundLayer.new()
	add_child(ground)
	creatures = Node2D.new()
	creatures.y_sort_enabled = true
	add_child(creatures)
	fx = FxLayer.new()
	add_child(fx)
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	add_child(camera)
	camera.make_current()
	hud = Hud.new()
	hud.game = self
	add_child(hud)

	_build_map()
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
	for y in GameData.map_h:
		var row: String = GameData.map_rows[y]
		for x in GameData.map_w:
			var ch := row[x]
			tilemap.set_cell(Vector2i(x, y), 0, Sprites.atlas_coords(ch, x, y))
			if not GameData.WALKABLE.contains(ch):
				_astar.set_point_solid(Vector2i(x, y), true)


func _create_entity(id: int) -> EntityView:
	var e := EntityView.new()
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
			hud.update_stats(msg)
		"inv":
			hud.update_inventory(msg)
		"fx":
			for f in msg.l:
				fx.spawn(f)
				_fx_sound(f)
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
			entities[id].queue_free()
			entities.erase(id)
	ground.set_items(msg.g)
	_set_target(target_id)


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
	# 1. Potwór na kafelku -> atak (drugi tap – przerwanie ataku).
	for id in entities:
		var e: EntityView = entities[id]
		if e.kind == "m" and e.tile == tile:
			attack(id)
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
		if e.kind == "m" and e.tile != to and _astar.region.has_point(e.tile) and not _astar.is_point_solid(e.tile):
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
	_move_cooldown -= delta
	if _move_cooldown > 0.0:
		return

	var input := hud.joystick_vector()
	if input == Vector2.ZERO:
		input = _keyboard_vector()
	if input.length() > 0.3:
		_path.clear()
		_pending_pickup = 0
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
			if e.kind == "m" and e.tile == dest:
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
	return true


static func _facing(step: Vector2i) -> int:
	if absi(step.x) > absi(step.y):
		return 1 if step.x > 0 else 3
	return 2 if step.y > 0 else 0


func logout() -> void:
	Net.close()
	Net.disconnected.emit("Wylogowano.")
