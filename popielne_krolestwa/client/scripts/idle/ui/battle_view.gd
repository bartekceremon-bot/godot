class_name BattleView
extends Node3D
## Scena walki 3D (w SubViewport): diorama regionu (niebo, ziemia, drzewa i skały z WorldProps,
## pogoda), bohater w ekwipunku, najemnicy za nim i przeciwnik – modele Entity3D z gry MMO.
## Efekty czarów z Fx3D. Pozycje na „kafelkach” jak w MMO, żeby efekty trafiały w cel.

const HERO_TILE := Vector2i(-1, 0)
const ENEMY_TILE := Vector2i(1, 0)
## Najemnicy po bokach, między bohaterem a przeciwnikiem (kamera patrzy zza pleców bohatera):
## kafel (do efektów) i dokładne położenie w świecie.
const MERC_TILES := [Vector2i(0, 2), Vector2i(0, 0), Vector2i(1, 2)]
const MERC_POS := [Vector3(-0.2, 0, 2.0), Vector3(0.4, 0, -1.0), Vector3(0.4, 0, 2.7)]
## Bohater stoi na lewo od osi kamery (w lewym dolnym rogu ekranu).
const HERO_POS := Vector3(0.1, 0, -0.3)
## Wysokość przeciwnika w świecie (zwykły / elita / boss) – każdy potwór, od szczura po smoka,
## wypełnia środek ekranu i jest wyraźnie większy od bohatera (stały kadr kamery).
const ENEMY_HEIGHT := [2.6, 3.0, 3.6]
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
var _embers: CPUParticles3D
var _rim: OmniLight3D
var _enemy_h := 3.0
var _smoke: Array = []
var pets: Array = []
var _pet_key := ""
## Chowańce idą obok bohatera (bliżej kamery i lekko w prawo).
const PET_POS := [Vector3(0.9, 0, 0.6), Vector3(-0.2, 0, 1.2)]
var _region_id := ""
var _hero_key := ""
var _merc_key := ""
var _cam_base := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _shake := 0.0
var _t := 0.0
## Ekran tytułowy: kamera powoli okrąża scenę.
var orbit := false
var orbit_focus := Vector3(0.3, 1.3, 0.2)
var orbit_radius := 8.5
var orbit_height := 2.6


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
	# Poświata (bloom) świecących elementów: żar, oczy, czary.
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
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
	camera.fov = 38.0
	camera.current = true
	add_child(camera)
	fx = Fx3D.new()
	add_child(fx)
	_diorama = Node3D.new()
	add_child(_diorama)
	# Żar za przeciwnikiem: pomarańczowe podświetlenie konturu i unoszące się iskry (każdy region).
	_rim = OmniLight3D.new()
	_rim.light_color = Color(1.0, 0.45, 0.15)
	_rim.light_energy = 2.2
	_rim.omni_range = 7.0
	_rim.position = Vector3(3.6, 1.6, 0.2)
	add_child(_rim)
	_embers = _particles(Color(1.0, 0.5, 0.15, 0.95), Vector3(0.3, 0.7, 0), 50, 4.5, 0.028, 1.0)
	_embers.position = Vector3(0.5, 0.0, 0.5)
	add_child(_embers)
	_place_camera(ENEMY_HEIGHT[0])
	camera.position = _cam_base


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	var off := Vector3.ZERO
	if _shake > 0.0:
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.12
	if orbit:
		var a := -0.9 + sin(_t * 0.07) * 0.75
		var p := orbit_focus + Vector3(sin(a) * orbit_radius, orbit_height + sin(_t * 0.23) * 0.3, cos(a) * orbit_radius)
		camera.position = camera.position.lerp(p, minf(1.0, delta * 1.5))
		camera.look_at(orbit_focus, Vector3.UP)
		return
	# Lekkie „oddychanie” kamery.
	camera.position = camera.position.lerp(_cam_base + Vector3(0, sin(_t * 0.4) * 0.03, sin(_t * 0.3) * 0.08), minf(1.0, delta * 3.0)) + off
	_rim.light_energy = 2.0 + sin(_t * 3.1) * 0.25 + sin(_t * 7.3) * 0.12
	camera.look_at(_cam_target, Vector3.UP)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.2)


## Kamera zza pleców bohatera (bohater w lewym dolnym rogu, przeciwnik na środku);
## odsuwa się i unosi dla dużych przeciwników (bossowie).
func _place_camera(enemy_height: float) -> void:
	var h := clampf(enemy_height, 1.5, 9.0)
	var chest := Vector3(1.5, h * 0.22, 0.5)
	_cam_target = chest
	_cam_base = chest + Vector3(-1.0, 0.26, 0.33).normalized() * h * 3.9


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
	# Popielny klimat walki: przygaszone, szarawe światło i gęstsza mgła w każdej krainie.
	env.fog_light_color = hor.lerp(Color(0.42, 0.4, 0.4), 0.5).darkened(0.4)
	env.fog_density = 0.045 if str(reg.weather) == "mist" else (0.035 if hostile else 0.024)
	env.tonemap_exposure = 0.9
	env.ambient_light_energy = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.72
	env.adjustment_contrast = 1.12
	_sun.light_color = Color(1.0, 0.7, 0.5) if hostile else Color(1.0, 0.9, 0.8)
	_sun.light_energy = 0.85 if hostile else 1.0
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
		if _blocks_view(pos):
			continue
		k.place(pos, rng.randf() * TAU, rng.randf_range(0.9, 1.5))
		_prop(k, str(props[i % props.size()]), rng)
		k.reset()
		k.jitter = 0.05
	_ruins(k, reg, rng)
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
	# Słupy dymu nad ruinami (gęstsze w krainach popiołu i ognia).
	for c in _smoke:
		c.queue_free()
	_smoke.clear()
	var hot := str(reg.biome) in ["ash", "fire", "volcano"]
	for pos: Vector3 in [Vector3(8.5, 0.5, -2.8), Vector3(9.5, 0.5, 4.2)] + ([Vector3(7.5, 0.5, 0.8)] if hot else []):
		var sm := _smoke_column(Color(0.16, 0.14, 0.14, 0.42) if hot else Color(0.45, 0.44, 0.44, 0.22))
		sm.position = pos
		add_child(sm)
		_smoke.append(sm)


## Ruiny za przeciwnikiem (jak na projekcie ekranu): wyszczerbione mury z oknami, rozbite wieże,
## gruz; w krainach popiołu i ognia – ciemny kamień z żarzącymi się szczelinami.
func _ruins(k: MeshKit, reg: Dictionary, rng: RandomNumberGenerator) -> void:
	var biome := str(reg.biome)
	var hot := biome in ["ash", "fire", "volcano"]
	var stone := Color(0.46, 0.44, 0.42)
	match biome:
		"desert":
			stone = Color(0.72, 0.6, 0.42)
		"snow":
			stone = Color(0.6, 0.63, 0.68)
		"swamp", "forest":
			stone = Color(0.38, 0.4, 0.36)
	if hot:
		stone = Color(0.2, 0.18, 0.19)
	var count := 7 if hot else 5
	for i in count:
		# Łuk za areną: od lewej do prawej strony kadru, coraz dalej na bokach.
		var t := (float(i) + rng.randf_range(-0.25, 0.25)) / float(count - 1) * 2.0 - 1.0
		var pos := Vector3(7.0 + absf(t) * 1.2 + rng.randf_range(-0.6, 0.9), 0, 1.0 + t * 5.2)
		var yaw := PI / 2.0 + t * 0.5 + rng.randf_range(-0.2, 0.2)
		var sc := rng.randf_range(0.9, 1.3)
		k.place(pos, yaw, sc)
		var col := stone.lerp(stone.darkened(0.3), rng.randf())
		if i % 3 == 1:
			_ruin_tower(k, col, rng, hot)
		else:
			_ruin_wall(k, col, rng, hot)
		k.reset()
	# Gruz i odłamki na arenie i przed murami.
	for i in 14:
		var pos := Vector3(rng.randf_range(3.0, 9.0), 0, rng.randf_range(-5.0, 6.5))
		if _blocks_view(pos) or pos.distance_to(Vector3(1.5, 0, 0.5)) < 2.4:
			continue
		var c := stone.lerp(stone.lightened(0.15), rng.randf())
		k.blob(pos + Vector3(0, 0.12, 0), Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.15, 0.35), rng.randf_range(0.25, 0.5)), c, 2, 5, 0.3)
	k.jitter = 0.05


func _ruin_wall(k: MeshKit, col: Color, rng: RandomNumberGenerator, hot: bool) -> void:
	var cols := rng.randi_range(6, 10)
	var w := 0.55
	var h := rng.randf_range(2.6, 4.2)
	var x0 := -cols * w / 2.0
	var win := rng.randi_range(1, cols - 2)
	for i in cols:
		# Wyszczerbiony szczyt: wysokość opada ku jednemu końcowi i skacze losowo.
		var hi := h * (1.0 - absf(float(i) / cols - 0.35) * 0.9) * rng.randf_range(0.65, 1.05)
		var x := x0 + i * w + w / 2.0
		var c := col.lerp(col.lightened(0.12), rng.randf() * 0.5)
		if i == win or i == win + 1:
			# Okno: dół muru, łuk (nadproże) nad otworem.
			k.box(Vector3(x, 0, 0), Vector3(w, 1.0, 0.5), c)
			if hi > 2.4:
				k.box(Vector3(x, 2.1, 0), Vector3(w, hi - 2.1, 0.5), c)
		else:
			k.box(Vector3(x, 0, 0), Vector3(w, hi, 0.5), c, Vector2(0.9, 0.9))
		if rng.randf() < 0.3:
			k.box(Vector3(x + rng.randf_range(-0.2, 0.2), 0, 0.6), Vector3(0.4, 0.25, 0.35), c.darkened(0.1))
	if hot:
		k.glow = 1.0
		for i in 3:
			var x := x0 + rng.randf_range(0.3, cols * w - 0.3)
			k.box(Vector3(x, 0.05, 0.26), Vector3(0.05, rng.randf_range(0.4, 1.2), 0.02), Color(1.0, 0.45, 0.1))
		k.glow = 0.0


func _ruin_tower(k: MeshKit, col: Color, rng: RandomNumberGenerator, hot: bool) -> void:
	var r := rng.randf_range(0.9, 1.3)
	var h := rng.randf_range(3.5, 5.5)
	k.cyl(Vector3.ZERO, r * 1.05, r, h * 0.6, 10, col, false)
	# Rozbita korona: segmenty różnej wysokości.
	for i in 10:
		var a := TAU * (i + 0.5) / 10.0
		var sh := h * rng.randf_range(0.05, 0.4)
		if rng.randf() < 0.25:
			continue
		k.box(Vector3(cos(a) * r * 0.9, h * 0.6, sin(a) * r * 0.9), Vector3(0.5, sh, 0.5), col.lightened(rng.randf() * 0.1))
	# Okno-strzelnica.
	k.glow = 1.0 if hot else 0.0
	k.box(Vector3(-r * 1.0, h * 0.35, 0), Vector3(0.06, 0.6, 0.22), Color(1.0, 0.5, 0.15) if hot else Color(0.05, 0.05, 0.06))
	k.glow = 0.0


## Unoszący się dym (miękkie, obracające się do kamery plamy).
func _smoke_column(col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = load("res://assets/fx/soft_dot.png")
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	q.material = m
	p.mesh = q
	p.amount = 22
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.direction = Vector3(0.1, 1, 0.05)
	p.spread = 12
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.12, 0.05, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(1, 2.8))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.15, Color(1, 1, 1, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	return p


## Czy obiekt stałby między kamerą a areną (korytarz widoku zza pleców bohatera)?
func _blocks_view(pos: Vector3) -> bool:
	var a := Vector2(-11.5, 4.8)
	var b := Vector2(2.0, 0.5)
	var p := Vector2(pos.x, pos.z)
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t)) < 2.0 + t * 1.8


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
		_ember_blade.call_deferred()
		return
	hero = _entity({"i": 1, "k": "p", "n": "Bohater", "l": "3", "h": 100, "eq": eq}, HERO_TILE, PI / 2.0 - 0.1)
	hero._to = HERO_POS
	hero._from = HERO_POS
	hero.position = HERO_POS
	_ember_blade.call_deferred()


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
		var ent := _entity(e, MERC_TILES[i], PI / 2.0 - 0.15)
		ent.scale = Vector3.ONE * 0.9
		ent._to = MERC_POS[i]
		ent._from = MERC_POS[i]
		ent.position = MERC_POS[i]
		mercs.append(ent)


## Żarzące się ostrze bohatera (jak na projekcie ekranu): poświata wokół broni, światło i iskry.
func _ember_blade() -> void:
	if not hero or not hero.model or not hero.model.parts.has("weapon"):
		return
	var w: Node3D = hero.model.parts["weapon"]
	if w.has_node("ember"):
		return
	var root := Node3D.new()
	root.name = "ember"
	w.add_child(root)
	var bow := hero.model.weapon_kind == "bow"
	var aura := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.7, 0.05) if not bow else Vector3(0.05, 0.9, 0.05)
	aura.mesh = bm
	aura.position = Vector3(0, 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.55)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura.material_override = mat
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(aura)
	var core := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.025, 0.66, 0.02)
	core.mesh = cm
	core.position = Vector3(0, 0.5, 0.0)
	var cmat := mat.duplicate()
	cmat.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	core.material_override = cmat
	root.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 1.4
	light.omni_range = 1.8
	light.position = Vector3(0, 0.5, 0)
	root.add_child(light)
	var sp := _particles(Color(1.0, 0.6, 0.2, 0.95), Vector3(0, 0.5, 0), 14, 0.7, 0.012, 1.0)
	sp.position = Vector3(0, 0.5, 0)
	sp.emission_box_extents = Vector3(0.03, 0.3, 0.03)
	sp.local_coords = false
	root.add_child(sp)


## Aktywne chowańce (wygląd potworów MMO w pomniejszeniu).
func set_pets(looks: Array) -> void:
	var key := ",".join(PackedStringArray(looks))
	if key == _pet_key:
		return
	_pet_key = key
	for p in pets:
		p.queue_free()
	pets.clear()
	for i in mini(2, looks.size()):
		var ent := _entity({"i": 30 + i, "k": "m", "n": "", "l": str(looks[i]), "h": 100}, HERO_TILE, PI / 2.0 - 0.3)
		ent._to = PET_POS[i]
		ent._from = PET_POS[i]
		ent.position = PET_POS[i]
		if ent.model:
			var body := maxf(0.3, ent.label_height - 0.32)
			ent.model.scale *= clampf(0.75 / body, 0.25, 1.2)
		pets.append(ent)


func spawn_enemy(cur: Dictionary) -> void:
	if enemy:
		enemy.vanish(true)
		enemy = null
	var kind := int(cur.kind)
	enemy = _entity({"i": 2, "k": "m", "n": str(cur.name), "l": str(cur.look), "h": 100, "b": 1 if kind > 0 else 0}, ENEMY_TILE, -PI / 2.0 + 0.4)
	# Skala modelu (węzeł skaluje animacja pojawienia się Entity3D).
	var body := maxf(0.3, enemy.label_height - 0.32)
	var h: float = ENEMY_HEIGHT[clampi(kind, 0, 2)]
	var f := clampf(h / body, 0.8, 2.3)
	if enemy.model:
		enemy.model.scale *= f
	_enemy_h = body * f
	_place_camera(h)
	if kind > 0:
		fx.ring(Fx3D.center(ENEMY_TILE.x, ENEMY_TILE.y), Color(1.0, 0.4, 0.15), 0.3, 3.0, 0.8, 0.12)
		shake(0.6)


## Punkt nad przeciwnikiem w pikselach widoku (liczby obrażeń, łup).
func enemy_screen_pos() -> Vector2:
	var p := Fx3D.center(ENEMY_TILE.x, ENEMY_TILE.y) + Vector3(0, 1.0, 0)
	if enemy:
		p.y = _enemy_h * 0.55
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
		elif source == "auto" and not pets.is_empty() and randf() < 0.15:
			var pt: Entity3D = pets[randi() % pets.size()]
			pt.play_attack("melee")
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
