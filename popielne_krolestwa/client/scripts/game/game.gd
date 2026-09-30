extends Node3D
## Scena gry 3D: świat low-poly, istoty, loot, efekty, kamera, słońce i pora dnia, sterowanie
## oraz obsługa pakietów serwera.
##
## Ruch własnej postaci jest PRZEWIDYWANY po stronie klienta (natychmiastowa reakcja),
## ale serwer ma ostatnie słowo – przy odrzuceniu kroku przysyła "pos" i klient się koryguje.

const Hud := preload("res://scripts/ui/hud.gd")

## Cykl dnia i nocy (sekundy czasu rzeczywistego) – wspólny dla wszystkich graczy.
const DAY_CYCLE := 1440.0
const TAP_MAX_MOVE := 24.0
## Kamera: przybliżenie steruje jednocześnie odległością i kątem – przy zbliżeniu kamera schodzi
## nisko za plecy bohatera (widać horyzont i niebo), przy oddaleniu patrzy z góry jak w Albionie.
const ZOOM_MIN := 0.45
const ZOOM_MAX := 1.5
const CAM_PITCH := Vector2(10.0, 58.0)
const CAM_DIST := Vector2(7.6, 14.5)
const CAM_FOV := Vector2(56.0, 40.0)
const SKY_SHADER := preload("res://shaders/sky_world.gdshader")
## Barwy nieba: [zenit, horyzont] w dzień, o zmierzchu i w nocy.
const SKY_DAY := [Color(0.2, 0.42, 0.8), Color(0.64, 0.78, 0.92)]
const SKY_DUSK := [Color(0.24, 0.26, 0.5), Color(1.0, 0.58, 0.36)]
const SKY_NIGHT := [Color(0.015, 0.025, 0.07), Color(0.07, 0.09, 0.17)]
## Kody kierunków z protokołu: N, E, S, W, NE, SE, SW, NW.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]
## Nastrój stref: kolor mgły/powietrza.
const ZONE_FOG := {"g": Color(0.66, 0.74, 0.8), "y": Color(0.8, 0.72, 0.55), "r": Color(0.46, 0.3, 0.26), "b": Color(0.3, 0.16, 0.14)}
## Kolor powietrza krain (mgła w oddali).
const BIOME_FOG := {"m": Color(0.66, 0.74, 0.8), "f": Color(0.5, 0.62, 0.6), "s": Color(0.82, 0.88, 0.95), "r": Color(0.62, 0.66, 0.72),
	"d": Color(0.9, 0.8, 0.62), "w": Color(0.48, 0.55, 0.42), "a": Color(0.34, 0.2, 0.18)}

var hud: Hud
var world: WorldBuilder
var fx: Fx3D
var ground: GroundItems3D
var overlay: Overlay2D
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var creatures: Node3D
var _ash: CPUParticles3D
var _embers: CPUParticles3D
var _snow: CPUParticles3D
var _dust: CPUParticles3D
var _fireflies: CPUParticles3D
var _rain: CPUParticles3D
## Pogoda (wspólna dla wszystkich: cykl co 7 minut): 0..1 deszcz, 0..1 burza, błysk pioruna.
var _rain_amt := 0.0
var _storm := 0.0
var _flash := 0.0
var _next_flash := 0.0
var weather := "clear"
var _biome := ""
var _shake := 0.0
var _zoom := 0.55
var sky_mat := ShaderMaterial.new()
## 0 = dzień, 1 = pełna noc.
var night := 0.0
var _night_ready := false
var _fog_col := ZONE_FOG["g"]
var _recent_deaths: Dictionary = {}

## id -> Entity3D
var entities: Dictionary = {}
var me: Entity3D = null
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
var _touches: Dictionary = {}
var _pinch_dist := 0.0


func _ready() -> void:
	_setup_scene()
	hud = Hud.new()
	hud.game = self
	hud.layer = 2
	add_child(hud)
	_build_map()
	me = _create_entity(GameData.my_id)
	me.is_me = true
	me.kind = "p"
	me.display_name = GameData.my_name
	apply_effects()
	Net.message.connect(_on_message)


## Środowisko, słońce, kamera, warstwy świata.
func _setup_scene() -> void:
	env = Environment.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_sky_affect = 0.12
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = ZONE_FOG["g"]
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 300.0
	env.fog_depth_curve = 1.6
	env.fog_density = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)
	camera = Camera3D.new()
	_zoom = clampf(Config.cam_zoom, ZOOM_MIN, ZOOM_MAX)
	camera.fov = 45.0
	camera.near = 0.3
	camera.far = 560.0
	add_child(camera)
	camera.make_current()
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	ground = GroundItems3D.new()
	add_child(ground)
	creatures = Node3D.new()
	creatures.name = "Creatures"
	add_child(creatures)
	fx = Fx3D.new()
	add_child(fx)
	var ol := CanvasLayer.new()
	ol.layer = 1
	add_child(ol)
	overlay = Overlay2D.new()
	overlay.camera = camera
	overlay.entities = entities
	ol.add_child(overlay)
	fx.overlay = overlay
	ground.overlay = overlay
	_ash = _make_weather(Color(0.6, 0.58, 0.57), 60, -0.5, 0.03)
	_embers = _make_weather(Color(1.0, 0.45, 0.12), 30, 0.6, 0.03)
	_embers.amount = 30
	_snow = _make_weather(Color(1.0, 1.0, 1.0), 160, -1.0, 0.035)
	_snow.gravity = Vector3(0.15, -0.35, 0.05)
	_dust = _make_weather(Color(0.92, 0.8, 0.58), 70, 0.0, 0.025)
	_dust.direction = Vector3(1, 0.05, 0.2)
	_dust.initial_velocity_min = 1.2
	_dust.initial_velocity_max = 2.4
	_dust.gravity = Vector3.ZERO
	_fireflies = _make_weather(Color(0.75, 1.0, 0.4), 40, 0.1, 0.03)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.05
	_fireflies.initial_velocity_max = 0.25
	_fireflies.spread = 180
	_fireflies.emission_box_extents = Vector3(10, 1.0, 8)
	_rain = _make_rain()


## Opadający popiół i unoszący się żar wokół kamery.
func _make_weather(col: Color, amount: int, vy: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 2.5, 9)
	p.direction = Vector3(0.3, vy, 0.1)
	p.spread = 30
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0.1, vy * 0.3, 0)
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 4
	sm.rings = 2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if vy > 0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 3.0
	sm.material = m
	p.mesh = sm
	p.local_coords = false
	add_child(p)
	return p


## Deszcz: smugi kropli spadające wokół kamery.
func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 900
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16, 0.5, 16)
	p.direction = Vector3(0.15, -1, 0.05)
	p.spread = 3
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 20.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.55, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.78, 0.9, 0.42)
	bm.material = m
	p.mesh = bm
	p.local_coords = false
	p.emitting = false
	p.visible = false
	add_child(p)
	return p


## Stan pogody ze wspólnego zegara: bezchmurnie / deszcz / burza (argumenty testowe: --rain, --storm, --clear).
func _weather_state() -> String:
	var args := OS.get_cmdline_user_args()
	for w in ["rain", "storm", "clear"]:
		if "--" + w in args:
			return w
	var slot := int(Time.get_unix_time_from_system() / 420.0)
	var r := RandomNumberGenerator.new()
	r.seed = slot * 7919 + 17
	var v := r.randf()
	return "clear" if v < 0.55 else ("rain" if v < 0.82 else "storm")


func _update_rain(delta: float) -> void:
	weather = _weather_state()
	var dry := _biome in ["d", "a"]
	var want_rain := 0.0 if weather == "clear" or dry else (1.0 if weather == "storm" else 0.7)
	var want_storm := 1.0 if weather == "storm" and not dry else 0.0
	var forced := "--rain" in OS.get_cmdline_user_args() or "--storm" in OS.get_cmdline_user_args()
	_rain_amt = want_rain if forced else move_toward(_rain_amt, want_rain, delta * 0.08)
	_storm = want_storm if forced else move_toward(_storm, want_storm, delta * 0.08)
	var snowy := _biome == "s"
	var show_rain := Config.effects and _rain_amt > 0.05 and not snowy
	_rain.emitting = show_rain
	_rain.visible = show_rain
	if show_rain:
		var want := int(roundf(clampf(_rain_amt, 0.2, 1.0) * 5.0)) * 180
		if _rain.amount != want:
			_rain.amount = want
		_rain.position = camera.position + (me.position - camera.position) * 0.6 + Vector3(0, 9, 0)
	var wet := clampf(_rain_amt * 1.3, 0.0, 1.0) * (0.0 if snowy else 1.0)
	world.mat_ground.set_shader_parameter("wet", wet)
	world.mat_object.set_shader_parameter("wet", wet)
	# Pioruny w czasie burzy.
	var now := Time.get_ticks_msec() / 1000.0
	if _storm > 0.6 and now > _next_flash:
		_next_flash = now + randf_range(5.0, 14.0)
		_flash = 1.0
		var delay := randf_range(0.4, 1.6)
		get_tree().create_timer(delay).timeout.connect(func(): Sfx.play("thunder"))
	_flash = maxf(0.0, _flash - delta * 3.5)
	var f := _flash * (0.6 + 0.4 * sin(now * 60.0))
	sky_mat.set_shader_parameter("flash", f)
	sky_mat.set_shader_parameter("storm", clampf(_storm * 0.7 + _rain_amt * 0.45, 0.0, 1.0))
	hud.set_weather(weather if not dry or weather == "clear" else "clear", _rain_amt)


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
			if not GameData.WALKABLE.contains(row[x]):
				_astar.set_point_solid(Vector2i(x, y), true)
	var start: Dictionary = GameData.cities[0].temple if not GameData.cities.is_empty() else {"x": 48, "y": 46}
	world.build(Vector2i(int(start.x), int(start.y)))


## Włącza/wyłącza efekty (cząsteczki, cienie, poświata) – ustawienie w menu.
func apply_effects() -> void:
	var on := Config.effects
	sun.shadow_enabled = on
	env.glow_enabled = on
	world.set_effects(on)
	_update_weather()


func _create_entity(id: int) -> Entity3D:
	var e := Entity3D.new()
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
			_update_zone()
		"stats":
			stats = msg
			step_ms = int(msg.step)
			_set_target(int(msg.target))
			me.gathering = int(msg.get("gather", 0)) != 0
			hud.update_stats(msg)
		"npc_dialog":
			_talking_npc = int(msg.id)
			if entities.has(_talking_npc):
				me.face_tile(entities[_talking_npc].tile)
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
				_fx_animate(f)
		"chat":
			hud.add_chat("[color=#f0e070]%s:[/color] %s" % [msg.from, _escape(str(msg.text))])
			if entities.has(int(msg.id)):
				var e: Entity3D = entities[int(msg.id)]
				overlay.say(e.position, str(msg.from), str(msg.text))
		"sys":
			hud.add_chat("[color=#a0d0ff]%s[/color]" % _escape(str(msg.text)))
		"online":
			hud.show_online(msg.list)
		"died":
			hud.show_death(msg)
			Sfx.play("death")
		"cd":
			hud.ability_cooldown(str(msg.id), float(msg.ms) / 1000.0)
		"sfx":
			Sfx.play(str(msg.k))


func _on_snapshot(msg: Dictionary) -> void:
	var seen := {}
	for e in msg.e:
		var id := int(e.i)
		seen[id] = true
		var view: Entity3D = entities.get(id)
		if view == null:
			view = _create_entity(id)
		view.apply(e, id == GameData.my_id)
	var now := Time.get_ticks_msec()
	for id in entities.keys():
		if not seen.has(id) and id != GameData.my_id and id > 0:
			var e: Entity3D = entities[id]
			var died: bool = now - int(_recent_deaths.get(e.tile, -100000)) < 1500
			e.vanish(died)
			entities.erase(id)
	ground.set_items(msg.g)
	_set_target(target_id)
	_update_labels()
	_update_minimap()


## Animacje ataku wywnioskowane z efektów (serwer nie wysyła osobnego pakietu „atak”).
func _fx_animate(f: Dictionary) -> void:
	var k := str(f.k)
	var t := Vector2i(int(f.x), int(f.y))
	match k:
		"num", "miss", "block":
			if k == "num" and f.c != "dmg":
				return
			if k == "num":
				_on_damage(t)
			# Trafiono nasz cel – to my atakujemy (wręcz).
			if entities.has(target_id) and entities[target_id].tile == t and _dist(t, my_pos) <= 1:
				me.face_tile(t)
				me.play_attack()
			# Trafiono nas – atakują sąsiednie potwory.
			if t == my_pos:
				for id in entities:
					var e: Entity3D = entities[id]
					if e.kind == "m" and _dist(e.tile, my_pos) <= 1:
						e.face_tile(my_pos)
						e.play_attack()
		"shot", "bolt":
			var src := t
			var dst := Vector2i(int(f.tx), int(f.ty))
			for id in entities:
				var e: Entity3D = entities[id]
				if e.tile == src and e.kind != "r":
					e.face_tile(dst)
					e.play_attack("bow")
					break
		"death":
			_recent_deaths[t] = Time.get_ticks_msec()
		"gather":
			me.play_attack("melee")


var _zone := ""


## Wejście do innej strefy: duży komunikat na środku ekranu.
func _update_zone() -> void:
	var z := GameData.zone_at(my_pos.x, my_pos.y)
	var b := GameData.biome_at(my_pos.x, my_pos.y)
	var city := GameData.city_at(my_pos.x, my_pos.y)
	hud.set_region(str(city.name) if not city.is_empty() else str(GameData.BIOME_NAMES.get(b, "")))
	if b != _biome:
		var first_b := _biome == ""
		_biome = b
		if not first_b:
			hud.add_chat("[color=#d8c890]— %s —[/color]" % GameData.BIOME_NAMES.get(b, ""))
		_update_weather()
	if z == _zone:
		return
	var first := _zone == ""
	_zone = z
	hud.set_zone(z, not first)
	_update_weather()


func _update_weather() -> void:
	var on := Config.effects
	var b := _biome
	var danger := _zone == "r" or _zone == "b" or b == "a"
	_set_particles(_ash, on and (danger or b == "a"), 110 if (_zone == "b" or b == "a") else 50)
	_set_particles(_embers, on and (_zone == "b" or b == "a"), 30)
	_set_particles(_snow, on and b == "s", 160)
	_set_particles(_dust, on and b == "d", 70)
	_set_particles(_fireflies, on and (b == "w" or b == "f") and night > 0.4, 40)


func _set_particles(p: CPUParticles3D, active: bool, amount: int) -> void:
	p.emitting = active
	p.visible = active
	if active and p.amount != amount:
		p.amount = amount


func _update_minimap() -> void:
	var dots := []
	for id in entities:
		var e: Entity3D = entities[id]
		if e.is_me or e.kind == "r":
			continue
		var col := Color(0.4, 1, 0.4)
		if e.kind == "m":
			col = Color(1, 0.3, 0.25)
		elif e.kind == "p" and e.skull != "":
			col = Color(1, 0.1, 0.6)
		elif e.kind == "n":
			col = Color(1, 0.85, 0.3)
		dots.append([e.tile, col])
	hud.minimap.update_view(my_pos, dots)


## Nazwy złóż widoczne tylko w pobliżu; okna NPC zamykane po odejściu od NPC.
func _update_labels() -> void:
	for id in entities:
		var e: Entity3D = entities[id]
		if e.kind == "r":
			e.show_label = _dist(e.tile, my_pos) <= 3
	if _talking_npc != 0:
		var n: Entity3D = entities.get(_talking_npc)
		if n == null or _dist(n.tile, my_pos) > 3:
			_talking_npc = 0
			hud.close_npc_windows()


## Trafienie: błysk istoty na kafelku, wstrząs kamery gdy trafiono nas.
func _on_damage(t: Vector2i) -> void:
	for id in entities:
		var e: Entity3D = entities[id]
		if e.tile == t and e.kind != "r":
			e.flash()
	if t == my_pos:
		_shake = 0.25


func _set_target(id: int) -> void:
	if entities.has(target_id):
		entities[target_id].targeted = false
	target_id = id
	if entities.has(id):
		entities[id].targeted = true


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
	if entities.has(id):
		me.face_tile(entities[id].tile)


## Przycisk „Atak”: wybiera najbliższego potwora (kolejne naciśnięcia – następnego).
func attack_nearest() -> void:
	var monsters: Array = []
	for id in entities:
		var e: Entity3D = entities[id]
		if e.kind == "m":
			monsters.append(e)
	if monsters.is_empty():
		hud.add_chat("[color=#a0a0a0]Brak potworów w pobliżu.[/color]")
		return
	monsters.sort_custom(func(a, b): return _dist(a.tile, my_pos) < _dist(b.tile, my_pos))
	var pick: Entity3D = monsters[0]
	if target_id != 0 and monsters.size() > 1 and pick.id == target_id:
		pick = monsters[1]
	Net.send({"t": "attack", "id": pick.id})
	_set_target(pick.id)
	me.face_tile(pick.tile)


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ============================================================================
# Sterowanie: dotyk (tap-to-move / atak / podnoszenie), szczypanie (zoom), joystick, klawiatura
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start[event.index] = event.position
			_touches[event.index] = event.position
			if _touches.size() == 2:
				_pinch_dist = _touches.values()[0].distance_to(_touches.values()[1])
		else:
			_touches.erase(event.index)
			if _touch_start.has(event.index):
				var start: Vector2 = _touch_start[event.index]
				_touch_start.erase(event.index)
				if start.distance_to(event.position) < TAP_MAX_MOVE and _touches.is_empty() and _pinch_dist == 0.0:
					_on_tap(_screen_to_tile(event.position))
			if _touches.is_empty():
				_pinch_dist = 0.0
	elif event is InputEventScreenDrag and _touches.size() >= 2:
		_touches[event.index] = event.position
		var d: float = _touches.values()[0].distance_to(_touches.values()[1])
		if _pinch_dist > 0.0:
			_set_zoom(_zoom * _pinch_dist / maxf(d, 1.0))
		_pinch_dist = d
	elif event is InputEventMagnifyGesture:
		_set_zoom(_zoom / event.factor)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom * 1.1)


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	Config.cam_zoom = _zoom


var _zoom_saved := 0.0


## Parametry kamery dla bieżącego przybliżenia: [przesunięcie, punkt patrzenia względem postaci, fov].
func _cam_params() -> Array:
	var t := clampf((_zoom - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN), 0.0, 1.0)
	var pitch := deg_to_rad(lerpf(CAM_PITCH.x, CAM_PITCH.y, t))
	var dist := lerpf(CAM_DIST.x, CAM_DIST.y, t)
	var offset := Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	# Nisko – patrz nad głowę i przed siebie (bohater w dolnej części ekranu, widać horyzont).
	var look := Vector3(0.0, lerpf(1.7, 0.5, t), -lerpf(3.5, 0.0, t))
	return [offset, look, lerpf(CAM_FOV.x, CAM_FOV.y, t)]


## Kafelek pod punktem ekranu: najpierw istoty (ich sylwetki), potem teren.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var best := -1
	var best_d := 42.0
	for id in entities:
		var e: Entity3D = entities[id]
		if e.is_me:
			continue
		var h := 0.5 if e.kind != "r" else 0.4
		var sp := camera.unproject_position(e.global_position + Vector3(0, h, 0))
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = id
	if best >= 0:
		return entities[best].tile
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return my_pos
	var t := -from.y / dir.y
	var hit := from + dir * t
	return Vector2i(floori(hit.x), floori(hit.z))


func _on_tap(tile: Vector2i) -> void:
	fx.tap_marker(tile)
	_pending_action = {}
	# 1. Potwór na kafelku -> atak (drugi tap – przerwanie ataku).
	for id in entities:
		var e: Entity3D = entities[id]
		if e.kind == "m" and e.tile == tile:
			attack(id)
			return
	# 1a. Inny gracz -> atak (PvP; serwer sprawdza strefę i zasady).
	for id in entities:
		var e: Entity3D = entities[id]
		if e.kind == "p" and not e.is_me and e.tile == tile:
			attack(id)
			return
	# 1b. NPC -> rozmowa (podejdź, jeśli daleko).
	for id in entities:
		var e: Entity3D = entities[id]
		if e.kind == "n" and e.tile == tile:
			_pending_action = {"type": "npc", "id": id, "tile": tile, "range": 3}
			if _dist(tile, my_pos) > 3:
				_path = _find_path(tile, true)
			return
	# 1c. Złoże surowca -> zbieraj (podejdź na sąsiednie pole).
	for id in entities:
		var e: Entity3D = entities[id]
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
		var e: Entity3D = entities[id]
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
	_update_camera(delta)
	_update_day_night(delta)
	_update_rain(delta)
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
			me.face_tile(a.tile)
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


func _update_camera(delta: float) -> void:
	var cp := _cam_params()
	var focus := me.position
	var look: Vector3 = focus + cp[1]
	var want: Vector3 = look + cp[0]
	if camera.position == Vector3.ZERO:
		camera.position = want
	camera.position = camera.position.lerp(want, minf(1.0, delta * 10.0))
	camera.look_at(camera.position - cp[0], Vector3.UP)
	camera.fov = lerpf(camera.fov, cp[2], minf(1.0, delta * 8.0))
	# Zapis przybliżenia co jakiś czas (bez zapisu przy każdym ruchu kółkiem).
	if absf(_zoom - _zoom_saved) > 0.01:
		_zoom_saved = _zoom
		Config.save_settings()
	if _shake > 0.0:
		_shake -= delta
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.08 * (_shake / 0.25)
	world.focus = me.tile
	RenderingServer.global_shader_parameter_set("player_pos", me.position)
	_ash.position = me.position + Vector3(0, 4.0, 0)
	_embers.position = me.position + Vector3(0, 0.5, 0)
	_snow.position = me.position + Vector3(0, 5.0, 0)
	_dust.position = me.position + Vector3(-4.0, 0.6, 0)
	_fireflies.position = me.position + Vector3(0, 0.8, 0)
	# Mgła dopasowana do strefy (płynnie).
	var want_fog: Color = BIOME_FOG.get(_biome, BIOME_FOG["m"])
	if _zone == "y":
		want_fog = want_fog.lerp(ZONE_FOG["y"], 0.2)
	elif _zone == "r":
		want_fog = want_fog.lerp(ZONE_FOG["r"], 0.35)
	elif _zone == "b":
		want_fog = ZONE_FOG["b"]
	_fog_col = _fog_col.lerp(want_fog, minf(1.0, delta * 1.5))


## Automatyczne podchodzenie do celu (wręcz: na sąsiednie pole, łuk: na zasięg strzału).
func _chase_target() -> void:
	if target_id == 0 or not entities.has(target_id):
		return
	var t: Entity3D = entities[target_id]
	var weapon_range := 1
	var weapon = hud.equipped("weapon")
	if weapon:
		weapon_range = int(GameData.item_def(str(weapon.item)).get("range", 1))
	if _dist(t.tile, my_pos) <= weapon_range:
		if not me.is_moving():
			me.face_tile(t.tile)
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
			var e: Entity3D = entities[id]
			if (e.kind == "m" or e.kind == "n") and e.tile == dest:
				free = false
				break
	var dir := _facing(step)
	if not free:
		me.dir = dir
		me.face_tile(dest)
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
	_update_zone()
	return true


static func _facing(step: Vector2i) -> int:
	if absi(step.x) > absi(step.y):
		return 1 if step.x > 0 else 3
	return 2 if step.y > 0 else 0


## Pora dnia z zegara (wspólna dla wszystkich): długi dzień, zmierzch, noc, świt.
func _update_day_night(_delta: float) -> void:
	var t := fmod(Time.get_unix_time_from_system(), DAY_CYCLE) / DAY_CYCLE
	hud.set_clock(t)
	# 0.00–0.60 dzień, 0.60–0.70 zmierzch, 0.70–0.92 noc, 0.92–1.00 świt.
	var n := 0.0
	if t > 0.6 and t <= 0.7:
		n = (t - 0.6) / 0.1
	elif t > 0.7 and t <= 0.92:
		n = 1.0
	elif t > 0.92:
		n = 1.0 - (t - 0.92) / 0.08
	n = smoothstep(0.0, 1.0, n)
	# Podgląd pory dnia (testy / zrzuty): argument --night, --dusk albo --day.
	var args := OS.get_cmdline_user_args()
	if "--night" in args:
		n = 1.0
	elif "--dusk" in args:
		n = 0.45
	elif "--day" in args:
		n = 0.0
	night = n
	var dusk := clampf(1.0 - absf(n - 0.4) / 0.4, 0.0, 1.0)
	var deep := clampf(n * 1.6 - 0.6, 0.0, 1.0)
	# Słońce: biało-złote w dzień, pomarańczowe o zmierzchu, chłodny księżyc w nocy.
	var sun_col := Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.66, 0.42), dusk).lerp(Color(0.55, 0.62, 1.0), deep)
	sun.light_color = sun_col
	sun.light_energy = lerpf(lerpf(1.05, 0.8, dusk), 0.25, deep) * (1.0 - 0.55 * _rain_amt) + _flash * 2.5
	sun.rotation_degrees = Vector3(lerpf(-52.0, -28.0, dusk * (1.0 - deep)), -38.0 + dusk * 25.0, 0)
	env.ambient_light_color = Color(0.62, 0.66, 0.78).lerp(Color(0.7, 0.6, 0.6), dusk).lerp(Color(0.22, 0.27, 0.5), deep)
	env.ambient_light_energy = lerpf(0.42, 0.4, deep)
	# Niebo: gradient pory dnia zabarwiony powietrzem krainy/strefy; mgła = barwa horyzontu.
	var zen: Color = SKY_DAY[0].lerp(SKY_DUSK[0], dusk).lerp(SKY_NIGHT[0], deep)
	var hor: Color = SKY_DAY[1].lerp(SKY_DUSK[1], dusk).lerp(SKY_NIGHT[1], deep)
	var tint := _fog_col
	var hostile := 0.0
	if _zone == "r":
		hostile = 0.35
	elif _zone == "b" or _biome == "a":
		hostile = 0.75
	hor = hor.lerp(tint, 0.2 * (1.0 - deep) + hostile * 0.4)
	zen = zen.lerp(Color(0.3, 0.2, 0.2).lerp(SKY_NIGHT[0], deep), hostile)
	sky_mat.set_shader_parameter("zenith_color", zen)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor.darkened(0.35))
	sky_mat.set_shader_parameter("sun_color", sun_col)
	sky_mat.set_shader_parameter("night", deep)
	sky_mat.set_shader_parameter("cloud_color", Color(1, 1, 1).lerp(Color(1.0, 0.72, 0.55), dusk).lerp(Color(0.16, 0.18, 0.26), deep).lerp(Color(0.45, 0.36, 0.34), hostile))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.62, 0.66, 0.76).lerp(Color(0.55, 0.36, 0.4), dusk).lerp(Color(0.05, 0.06, 0.1), deep).lerp(Color(0.2, 0.14, 0.13), hostile))
	sky_mat.set_shader_parameter("cloud_cover", lerpf(0.42, 0.8, hostile))
	var grey := Color(0.42, 0.45, 0.5).lerp(Color(0.05, 0.06, 0.09), deep)
	hor = hor.lerp(grey, _rain_amt * 0.75)
	zen = zen.lerp(grey.darkened(0.3), _rain_amt * 0.85)
	sky_mat.set_shader_parameter("zenith_color", zen)
	sky_mat.set_shader_parameter("horizon_color", hor)
	var fog := hor
	env.fog_light_color = fog
	var near_fog := _zone in ["r", "b"] or _biome == "s" or _biome == "w" or _biome == "a"
	env.fog_depth_begin = lerpf(30.0, 14.0, deep) if not near_fog else lerpf(18.0, 10.0, deep)
	env.fog_depth_end = (lerpf(300.0, 160.0, deep) if not near_fog else 140.0) * (1.0 - 0.55 * _rain_amt)
	env.fog_depth_begin *= 1.0 - 0.5 * _rain_amt
	if absf(n - _last_night) > 0.01 or not _night_ready:
		_night_ready = true
		_last_night = n
		world.set_night(n)
		hud.set_time_of_day(n)
		_update_weather()
	if me:
		me.light.visible = n > 0.3 and Config.effects
		me.light.light_energy = 0.9 * n


var _last_night := -1.0


func logout() -> void:
	Net.close()
	Net.disconnected.emit("Wylogowano.")
