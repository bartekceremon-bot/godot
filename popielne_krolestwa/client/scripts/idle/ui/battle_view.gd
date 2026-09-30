class_name BattleView
extends Node3D
## Scena walki 3D (w SubViewport): diorama regionu (niebo, ziemia, drzewa i skały z WorldProps,
## pogoda), bohater w ekwipunku, najemnicy za nim i przeciwnik – modele Entity3D z gry MMO.
## Efekty czarów z Fx3D. Pozycje na „kafelkach” jak w MMO, żeby efekty trafiały w cel.

const HERO_TILE := Vector2i(-2, 0)
const ENEMY_TILE := Vector2i(1, 0)
const MERC_TILES := [Vector2i(-3, -1), Vector2i(-2, -2), Vector2i(-4, -2)]
const SKY_SHADER := preload("res://shaders/sky_world.gdshader")

var fx: Fx3D
var camera: Camera3D
var hero: Entity3D
var enemy: Entity3D
var mercs: Array = []
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _diorama: Node3D
var _obj_mat: ShaderMaterial
var _weather: CPUParticles3D
var _region_id := ""
var _hero_key := ""
var _merc_key := ""
var _cam_base := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	_obj_mat = ShaderMaterial.new()
	_obj_mat.shader = Entity3D.OBJECT_SHADER
	_env = WorldEnvironment.new()
	var env := Environment.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_sky_affect = 0.3
	_env.environment = env
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	_sun.light_energy = 1.25
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 22.0
	add_child(_sun)
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.current = true
	add_child(camera)
	fx = Fx3D.new()
	add_child(fx)
	_diorama = Node3D.new()
	add_child(_diorama)
	_cam_target = Vector3(0.1, 0.85, 0.5)
	_cam_base = Vector3(-0.15, 1.9, 5.6)
	_place_camera(1.0)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	var off := Vector3.ZERO
	if _shake > 0.0:
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.12
	# Lekkie „oddychanie” kamery.
	camera.position = camera.position.lerp(_cam_base + Vector3(sin(_t * 0.3) * 0.08, 0, 0), minf(1.0, delta * 3.0)) + off
	camera.look_at(_cam_target, Vector3.UP)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.2)


## Kamera odsuwa się dla dużych przeciwników (bossowie).
func _place_camera(enemy_height: float) -> void:
	var k := clampf(enemy_height / 1.6, 1.0, 2.6)
	_cam_base = Vector3(-0.6 + (k - 1.0) * 0.3, 1.5 + 0.7 * k, 5.6 + 1.8 * k)
	_cam_target = Vector3(-0.35 + (k - 1.0) * 0.3, 0.5 + 0.4 * k, 0.0)


# --- Region -----------------------------------------------------------------------

func set_region(reg: Dictionary) -> void:
	var id := str(reg.id)
	if id == _region_id:
		return
	_region_id = id
	var sky: Array = reg.sky
	var zen := Color.html(str(sky[0]))
	var hor := Color.html(str(sky[1]))
	_sky_mat.set_shader_parameter("zenith_color", zen)
	_sky_mat.set_shader_parameter("horizon_color", hor)
	_sky_mat.set_shader_parameter("ground_color", hor.darkened(0.4))
	_sky_mat.set_shader_parameter("cloud_cover", 0.55 if str(reg.biome) in ["ash", "swamp"] else 0.4)
	var hostile := str(reg.biome) == "ash"
	_sky_mat.set_shader_parameter("cloud_color", Color(0.5, 0.4, 0.38) if hostile else Color(1, 1, 1))
	_sky_mat.set_shader_parameter("cloud_shade", Color(0.2, 0.14, 0.13) if hostile else Color(0.62, 0.66, 0.76))
	var env := _env.environment
	env.fog_light_color = hor
	env.fog_density = 0.03 if str(reg.weather) == "mist" else (0.02 if hostile else 0.012)
	_sun.light_color = Color(1.0, 0.7, 0.5) if hostile else Color(1.0, 0.96, 0.88)
	_sun.light_energy = 0.9 if hostile else 1.25
	_build_diorama(reg)


func _build_diorama(reg: Dictionary) -> void:
	for c in _diorama.get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(reg.id))
	var ground := Color.html(str(reg.ground))
	# Ziemia: dysk z drobną mozaiką barw (low-poly) i wydeptaną areną pośrodku.
	var k := MeshKit.new(7)
	k.jitter = 0.05
	var rings := 7
	var segs := 28
	for r in rings:
		var r0 := pow(float(r) / rings, 1.6) * 28.0
		var r1 := pow(float(r + 1) / rings, 1.6) * 28.0
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var arena := r <= 1
			var col := ground.lerp(ground.darkened(0.25), 0.5) if arena else ground
			col = col.lerp(ground.lightened(0.08), rng.randf() * 0.5)
			var p00 := Vector3(cos(a0) * r0, 0, sin(a0) * r0) + Vector3(0.5, 0, 0.5)
			var p01 := Vector3(cos(a1) * r0, 0, sin(a1) * r0) + Vector3(0.5, 0, 0.5)
			var p10 := Vector3(cos(a0) * r1, 0, sin(a0) * r1) + Vector3(0.5, 0, 0.5)
			var p11 := Vector3(cos(a1) * r1, 0, sin(a1) * r1) + Vector3(0.5, 0, 0.5)
			var h := func(p: Vector3) -> Vector3: return p + Vector3(0, (0.0 if p.length() < 5.0 else rng.randf_range(0.0, 0.25) * p.length() / 10.0), 0)
			k.quad(h.call(p00), h.call(p01), h.call(p11), h.call(p10), col, Vector3.UP)
	# Rośliny i skały: z tyłu i po bokach areny.
	var props: Array = reg.props
	for i in 22:
		var a := rng.randf_range(PI * 1.05, PI * 1.95) if i < 16 else rng.randf_range(-0.6, 0.6) + (PI if i % 2 == 0 else 0.0)
		var d := rng.randf_range(4.2, 11.0)
		var pos := Vector3(cos(a) * d + 0.5, 0, sin(a) * d * 0.9 + 0.5)
		if i >= 16:
			pos = Vector3((1.0 if i % 2 == 0 else -1.0) * rng.randf_range(4.5, 7.5), 0, rng.randf_range(-1.0, 3.0))
		k.place(pos, rng.randf() * TAU, rng.randf_range(0.9, 1.5))
		_prop(k, str(props[i % props.size()]), rng)
		k.reset()
		k.jitter = 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = _obj_mat
	_diorama.add_child(mi)
	# Pogoda regionu.
	if _weather:
		_weather.queue_free()
		_weather = null
	match str(reg.weather):
		"snow":
			_weather = _particles(Color(1, 1, 1, 0.9), Vector3(0, -1.2, 0), 120, 5.0, 0.035)
		"embers":
			_weather = _particles(Color(1.0, 0.5, 0.15, 0.95), Vector3(0.2, 0.6, 0), 60, 4.0, 0.03, 1.0)
		"sand":
			_weather = _particles(Color(0.9, 0.78, 0.5, 0.5), Vector3(2.5, -0.1, 0), 80, 3.0, 0.025)
	if _weather:
		add_child(_weather)


func _prop(k: MeshKit, kind: String, rng: RandomNumberGenerator) -> void:
	match kind:
		"oak":
			WorldProps.oak(k, Color(0.3, 0.5, 0.2).lerp(Color(0.5, 0.55, 0.2), rng.randf() * 0.4), rng.randf_range(1.0, 1.5))
		"birch":
			WorldProps.birch(k, Color(0.45, 0.62, 0.25))
		"pine":
			WorldProps.pine(k, Color(0.14, 0.34, 0.22), false, rng.randf_range(1.2, 1.8))
		"pine_snow":
			WorldProps.pine(k, Color(0.16, 0.32, 0.28), true, rng.randf_range(1.2, 1.8))
		"willow":
			WorldProps.willow(k, rng.randf())
		"dead":
			WorldProps.dead_tree(k, false)
		"dead_ember":
			WorldProps.dead_tree(k, true)
		"palm":
			WorldProps.palm(k, rng.randf())
		"cactus":
			WorldProps.cactus(k, rng.randf())
		"pillar":
			WorldProps.ruin_pillar(k, Vector3.ZERO, rng.randf(), true)
		_:
			var c := Color(0.45, 0.43, 0.42).lerp(Color(0.55, 0.5, 0.45), rng.randf())
			k.blob(Vector3(0, 0.25, 0), Vector3(0.6, 0.4, 0.5) * rng.randf_range(0.6, 1.4), c, 3, 7, 0.25, c.lightened(0.1))


func _particles(col: Color, vel: Vector3, amount: int, life: float, size: float, up := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = Vector3(0.5, 3.5 if up == 0.0 else 0.0, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7, 0.5 if up == 0.0 else 0.1, 4)
	p.direction = vel.normalized()
	p.spread = 15
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3(0, up * 0.4, 0)
	return p


# --- Postacie ----------------------------------------------------------------------

func _entity(e: Dictionary, tile: Vector2i, yaw: float) -> Entity3D:
	var ent := Entity3D.new()
	add_child(ent)
	e["x"] = tile.x
	e["y"] = tile.y
	e["d"] = 2
	e["s"] = 300
	ent.apply(e, false)
	ent._target_yaw = yaw
	ent._yaw = yaw
	return ent


## Bohater w aktualnym ekwipunku (model przebudowywany, gdy zmieni się ekwipunek).
func set_hero(eq: Array) -> void:
	var key := ",".join(PackedStringArray(eq))
	if key == _hero_key and hero:
		return
	_hero_key = key
	if hero:
		hero.equipment = eq
		hero._refresh_model()
		return
	hero = _entity({"i": 1, "k": "p", "n": "Bohater", "l": "3", "h": 100, "eq": eq}, HERO_TILE, PI / 2.0 - 0.45)


## Najemnicy (do 3 najsilniejszych) stoją za bohaterem.
func set_mercs(list: Array) -> void:
	var key := ",".join(PackedStringArray(list.map(func(d): return str(d.id))))
	if key == _merc_key:
		return
	_merc_key = key
	for m in mercs:
		m.queue_free()
	mercs.clear()
	for i in mini(3, list.size()):
		var d: Dictionary = list[i]
		var eq: Array = d.get("eq", [])
		var e := {"i": 10 + i, "k": "m" if not str(d.look).is_valid_int() else "p", "n": str(d.name), "l": str(d.look), "h": 100}
		if eq.size() == 6:
			e["k"] = "p"
			e["eq"] = eq
		var ent := _entity(e, MERC_TILES[i], PI / 2.0 - 0.3)
		ent.scale = Vector3.ONE * 0.9
		mercs.append(ent)


func spawn_enemy(cur: Dictionary) -> void:
	if enemy:
		enemy.vanish(true)
		enemy = null
	var kind := int(cur.kind)
	enemy = _entity({"i": 2, "k": "m", "n": str(cur.name), "l": str(cur.look), "h": 100, "b": 1 if kind > 0 else 0}, ENEMY_TILE, -PI / 2.0 + 0.4)
	if kind == 1 and not Entity3D.LOOK_SCALE.has(str(cur.look)):
		enemy.scale = Vector3.ONE * 0.8
	_place_camera(enemy.label_height * enemy.scale.x)
	if kind > 0:
		fx.ring(Fx3D.center(ENEMY_TILE.x, ENEMY_TILE.y), Color(1.0, 0.4, 0.15), 0.3, 3.0, 0.8, 0.12)
		shake(0.6)


## Punkt nad przeciwnikiem w pikselach widoku (liczby obrażeń, łup).
func enemy_screen_pos() -> Vector2:
	var p := Fx3D.center(ENEMY_TILE.x, ENEMY_TILE.y) + Vector3(0, 1.0, 0)
	if enemy:
		p.y = enemy.label_height * enemy.scale.x * 0.65
	return camera.unproject_position(p)


func hero_screen_pos() -> Vector2:
	return camera.unproject_position(Fx3D.center(HERO_TILE.x, HERO_TILE.y) + Vector3(0, 1.0, 0))


# --- Efekty ------------------------------------------------------------------------

func on_hit(crit: bool, source: String) -> void:
	if not enemy:
		return
	var p := Fx3D.center(ENEMY_TILE.x, ENEMY_TILE.y) + Vector3(0, 0.7, 0)
	if source == "tap" or source == "auto":
		enemy.flash()
		if source == "tap" and hero:
			hero.play_attack("melee")
		elif source == "auto" and not mercs.is_empty() and randf() < 0.5:
			var m: Entity3D = mercs[randi() % mercs.size()]
			m.play_attack("melee")
	if crit:
		fx.burst(p, Color(1.0, 0.75, 0.25), 18, 3.2, -5.0, 0.45, 1.2)
		shake(0.35)
	elif source == "tap":
		fx.burst(p, Color(0.8, 0.1, 0.08), 6, 2.0, -7.0, 0.35)


func on_kill(boss: int) -> void:
	var p := Fx3D.center(ENEMY_TILE.x, ENEMY_TILE.y)
	fx.burst(p + Vector3(0, 0.4, 0), Color(0.5, 0.05, 0.05), 20, 1.8, -6.0, 0.6)
	fx.burst(p + Vector3(0, 0.3, 0), Color(0.3, 0.3, 0.3), 14, 0.8, 1.0, 1.2, 2.0)
	if boss > 0:
		fx.pillar(p, Color(1.0, 0.6, 0.2), 2.0, 1.0, 5.0)
		fx.ring(p, Color(1.0, 0.6, 0.2), 0.5, 5.0, 1.2, 0.12)
		shake(1.0)


func on_level_up() -> void:
	if not hero:
		return
	var p := Fx3D.center(HERO_TILE.x, HERO_TILE.y)
	fx.pillar(p, Color(1.0, 0.85, 0.3), 1.4, 0.55, 3.0)
	fx.ring(p, Color(1, 0.85, 0.3), 0.2, 2.0, 1.0, 0.1)
	fx.burst(p + Vector3(0, 0.5, 0), Color(1, 0.8, 0.3), 30, 3.0, -2.0, 1.1)


## Efekt czaru z gry MMO (Fx3D.spell) między bohaterem a przeciwnikiem.
func on_spell(id: String) -> void:
	if hero:
		hero.play_attack("cast")
	var f := {"s": id, "x": HERO_TILE.x, "y": HERO_TILE.y, "tx": ENEMY_TILE.x, "ty": ENEMY_TILE.y, "r": 1.5}
	match id:
		"heal", "heal_great":
			fx.pillar(Fx3D.center(HERO_TILE.x, HERO_TILE.y), Color(0.4, 1.0, 0.5), 0.9, 0.45, 1.6)
			fx.burst(Fx3D.center(HERO_TILE.x, HERO_TILE.y) + Vector3(0, 0.3, 0), Color(0.5, 1.0, 0.6), 18, 1.4, 1.0, 1.0)
			return
		"chain":
			f["chain"] = [[ENEMY_TILE.x, ENEMY_TILE.y], [ENEMY_TILE.x + 2, ENEMY_TILE.y - 2], [ENEMY_TILE.x + 3, ENEMY_TILE.y + 1]]
		"storm":
			f["ms"] = 5000
		"storm_bolt":
			f = {"s": "storm_hit", "x": ENEMY_TILE.x, "y": ENEMY_TILE.y}
		"poison_cloud":
			f["ms"] = 6000
		"meteor", "firestorm", "frost_nova":
			shake(0.8)
		"ice_armor", "haste":
			f["x"] = HERO_TILE.x
	fx.spell(f)
