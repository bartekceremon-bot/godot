class_name WorldBuilder
extends Node3D
## Świat 3D low-poly budowany z mapy kafelków i krain otrzymanych od serwera (1 kafelek = 1 jednostka).
##
## Krainy: łąki, puszcza, śniegi, góry, pustynia, moczary i Popielisko – każda ma własny grunt,
## roślinność, skały i klimat. Góry i mesy wyrastają z kafelków „^” (wysokość rośnie z odległością
## od krawędzi), wokół mapy ciągną się pasma górskie.
##
## Świat jest dzielony na kawałki 16×16 kafelków (scalone siatki). Kawałki wokół gracza są
## budowane w tle z limitem czasu na klatkę, a dalekie zwalniane – duża mapa działa płynnie na telefonie.

const CHUNK := 16
## Pas gór wokół mapy (żeby na krawędziach nie było pustki).
const BORDER := 14
const WATER_Y := -0.13
const LAVA_Y := -0.06
## Promień (w kawałkach) budowania i zwalniania wokół gracza.
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 4
const FRAME_BUDGET_MS := 5

const MAT_GROUND := preload("res://shaders/terrain.gdshader")
const TEX_ALBEDO := preload("res://assets/textures/terrain_albedo.png")
const TEX_NORMAL := preload("res://assets/textures/terrain_normal.png")
## Średnie kolory warstw (assets/textures/terrain_means.txt), siła barwienia kolorem krainy i szorstkość.
const LAYER_MEAN := [Vector3(0.265, 0.415, 0.134), Vector3(0.19, 0.163, 0.086), Vector3(0.394, 0.297, 0.199), Vector3(0.836, 0.711, 0.501),
	Vector3(0.854, 0.887, 0.942), Vector3(0.466, 0.449, 0.41), Vector3(0.49, 0.47, 0.436), Vector3(0.796, 0.761, 0.687), Vector3(0.26, 0.221, 0.132),
	Vector3(0.236, 0.216, 0.206), Vector3(0.104, 0.081, 0.14), Vector3(0.692, 0.824, 0.917), Vector3(0.458, 0.429, 0.379), Vector3(0.442, 0.368, 0.175)]
const LAYER_TINT := [1.0, 0.7, 0.6, 0.8, 0.4, 0.85, 0.12, 0.1, 0.6, 0.7, 0.2, 0.3, 0.4, 0.2]
const LAYER_ROUGH := [0.95, 0.95, 0.95, 0.9, 0.6, 0.85, 0.8, 0.55, 0.45, 0.95, 0.25, 0.15, 0.8, 0.95]
const MAT_OBJECT := preload("res://shaders/lowpoly_object.gdshader")
const MAT_FOLIAGE := preload("res://shaders/lowpoly_foliage.gdshader")
const MAT_WATER := preload("res://shaders/lowpoly_water.gdshader")
const MAT_LAVA := preload("res://shaders/lowpoly_lava.gdshader")

# Paleta gruntów krain.
const GROUND_COL := {
	"m": [Color(0.3, 0.47, 0.21), Color(0.38, 0.53, 0.23)],
	"f": [Color(0.22, 0.4, 0.17), Color(0.3, 0.47, 0.2)],
	"s": [Color(0.86, 0.9, 0.95), Color(0.95, 0.97, 1.0)],
	"r": [Color(0.4, 0.46, 0.3), Color(0.48, 0.5, 0.36)],
	"d": [Color(0.86, 0.72, 0.47), Color(0.92, 0.8, 0.56)],
	"w": [Color(0.3, 0.36, 0.2), Color(0.36, 0.4, 0.22)],
	"a": [Color(0.22, 0.2, 0.2), Color(0.28, 0.24, 0.23)],
}
const ROCK_COL := {
	"m": Color(0.5, 0.47, 0.43), "f": Color(0.46, 0.44, 0.4), "s": Color(0.55, 0.56, 0.6), "r": Color(0.5, 0.49, 0.5),
	"d": Color(0.78, 0.5, 0.32), "w": Color(0.4, 0.4, 0.34), "a": Color(0.17, 0.15, 0.17),
}
const DIRT := Color(0.6, 0.46, 0.3)
const SAND := Color(0.86, 0.76, 0.52)
const MORTAR := Color(0.3, 0.29, 0.28)
const TEMPLE := Color(0.88, 0.84, 0.76)
const RIVERBED := Color(0.42, 0.4, 0.3)
const STONE := Color(0.56, 0.53, 0.49)
const WOOD := Color(0.45, 0.3, 0.18)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const IRON := Color(0.34, 0.34, 0.37)
const GOLD := Color(0.95, 0.72, 0.25)
const SNOW := Color(0.93, 0.96, 1.0)

var mat_ground := ShaderMaterial.new()
var mat_object := ShaderMaterial.new()
var mat_foliage := ShaderMaterial.new()
var mat_water := ShaderMaterial.new()
var mat_lava := ShaderMaterial.new()

var w := 0
var h := 0
## Wysokość kafelków gór (0 = nie góra), indeks (x + BORDER) + (y + BORDER) * _cw.
var _mh := PackedFloat32Array()
## Wysokości narożników kafelków.
var _heights := PackedFloat32Array()
var _cw := 0
var _water_dist := {}
var _noise := FastNoiseLite.new()
## Domy: lewy górny kafelek -> [x0, y0, x1, y1, drzwi]
var _houses := {}
## Kręgi run świątyń (środki) i pochodnie.
var _temples: Array[Vector2] = []
var _fire_spots := {}
## Kawałki: Vector2i -> Node3D
var _chunks := {}
var _queue: Array[Vector2i] = []
var _job: Dictionary = {}
var _check_t := 0.0
## Kafelek gracza – kawałki budowane są wokół niego.
var focus := Vector2i(112, 190)
## Pora dnia (0..1) przekazywana nowym ogniskom.
var night := 0.0
var effects := true
## Cały świat w niskiej rozdzielczości (horyzont).
var far: FarWorld
var _mask_dirty := true
## Drzewa i trawa zbierane podczas budowy kawałka (potem MultiMesh).
var _cur_trees := {}
var _cur_grass: Array = []


func _init() -> void:
	mat_ground.shader = MAT_GROUND
	mat_ground.set_shader_parameter("albedo_tex", TEX_ALBEDO)
	mat_ground.set_shader_parameter("normal_tex", TEX_NORMAL)
	mat_ground.set_shader_parameter("layer_mean", PackedVector3Array(LAYER_MEAN))
	mat_ground.set_shader_parameter("layer_tint", PackedFloat32Array(LAYER_TINT))
	mat_ground.set_shader_parameter("layer_rough", PackedFloat32Array(LAYER_ROUGH))
	mat_object.shader = MAT_OBJECT
	mat_object.set_shader_parameter("textured", true)
	for pair in [["tex_stone", "stone_wall"], ["tex_stone_n", "stone_wall_n"], ["tex_roof", "roof_tiles"], ["tex_roof_n", "roof_tiles_n"],
			["tex_wood", "wood"], ["tex_wood_n", "wood_n"], ["tex_plaster", "plaster"]]:
		mat_object.set_shader_parameter(pair[0], load("res://assets/textures/%s.png" % pair[1]))
	mat_object.set_shader_parameter("terrain_array", TEX_ALBEDO)
	mat_foliage.shader = MAT_FOLIAGE
	mat_water.shader = MAT_WATER
	mat_lava.shader = MAT_LAVA
	_noise.seed = 1337
	_noise.frequency = 0.07


## Przygotowuje dane świata i buduje kawałki wokół punktu startowego.
func build(start: Vector2i) -> void:
	w = GameData.map_w
	h = GameData.map_h
	focus = start
	for c in GameData.cities:
		_temples.append(Vector2(float(c.temple.x) + 1.0, float(c.temple.y) + 0.5))
	_compute_water()
	_compute_mountains()
	_compute_heights()
	_find_houses()
	_find_fire_spots()
	far = FarWorld.new()
	far.name = "FarWorld"
	add_child(far)
	far.build(self)
	# Najbliższe kawałki od razu (reszta w _process).
	var fc := _chunk_of(start)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_build_chunk(fc + Vector2i(dx, dy))


func _chunk_of(t: Vector2i) -> Vector2i:
	return Vector2i(floori(float(t.x) / CHUNK), floori(float(t.y) / CHUNK))


func _chunk_valid(c: Vector2i) -> bool:
	return c.x * CHUNK < w + BORDER and (c.x + 1) * CHUNK > -BORDER and c.y * CHUNK < h + BORDER and (c.y + 1) * CHUNK > -BORDER


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.3
		_update_streaming()
	if _queue.is_empty() and _job.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < FRAME_BUDGET_MS:
		if _job.is_empty():
			if _queue.is_empty():
				break
			var c: Vector2i = _queue.pop_front()
			if _chunks.has(c):
				continue
			_job = _start_chunk(c)
		if _step_chunk(_job):
			_finish_chunk(_job)
			_job = {}


## Kolejka budowy (najbliższe najpierw) i zwalnianie dalekich kawałków.
func _update_streaming() -> void:
	var fc := _chunk_of(focus)
	var want: Array[Vector2i] = []
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var c := fc + Vector2i(dx, dy)
			if _chunk_valid(c) and not _chunks.has(c) and not (not _job.is_empty() and _job.c == c):
				want.append(c)
	want.sort_custom(func(a, b): return (a - fc).length_squared() < (b - fc).length_squared())
	_queue = want
	for c in _chunks.keys():
		var d: Vector2i = c - fc
		if maxi(absi(d.x), absi(d.y)) > UNLOAD_RADIUS:
			_chunks[c].queue_free()
			_chunks.erase(c)
			_mask_dirty = true
	if _mask_dirty:
		_mask_dirty = false
		_update_hole()


## Maska kawałków dla dalekiego świata (tam, gdzie jest pełny świat, daleki jest wycinany).
func _update_hole() -> void:
	if far == null:
		return
	var c0 := _chunk_of(Vector2i(-BORDER, -BORDER))
	var c1 := _chunk_of(Vector2i(w + BORDER - 1, h + BORDER - 1))
	var n := c1 - c0 + Vector2i.ONE
	var img := Image.create(n.x, n.y, false, Image.FORMAT_R8)
	for c in _chunks:
		var p: Vector2i = c - c0
		if p.x >= 0 and p.y >= 0 and p.x < n.x and p.y < n.y:
			img.set_pixel(p.x, p.y, Color(1, 1, 1))
	far.set_mask(img, Vector2(c0 * CHUNK), Vector2(n * CHUNK))


func is_complete() -> bool:
	return _queue.is_empty() and _job.is_empty()


## Ogniska w załadowanych kawałkach (pora dnia, ustawienia efektów).
func fires() -> Array:
	var out := []
	for c in _chunks.values():
		for f in c.get_children():
			if f is Fire3D:
				out.append(f)
	return out


func set_night(n: float) -> void:
	night = n
	for f in fires():
		f.night = n


func set_effects(on: bool) -> void:
	effects = on
	for f in fires():
		f.effects = on


# ============================================================================
# Dane pomocnicze
# ============================================================================

## Znak kafelka; poza mapą – „B” (pasmo gór).
func tile(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "B"
	return GameData.tile_at(x, y)


func biome(x: int, y: int) -> String:
	return GameData.biome_at(clampi(x, 0, w - 1), clampi(y, 0, h - 1))


func zone(x: int, y: int) -> String:
	return GameData.zone_at(clampi(x, 0, w - 1), clampi(y, 0, h - 1))


func _hash(x: int, y: int, salt := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791))


func _rand(x: int, y: int, salt := 0) -> float:
	return float(_hash(x, y, salt) % 10007) / 10007.0


static func _walkable(c: String) -> bool:
	return c in [".", ",", "s", "a", "f", "x", "n", "d", "o", "p", "i", "=", "c"]


static func _flat(c: String) -> bool:
	return c in ["f", "x", "#", "D", "M", "K", "W", "P", "H", "U", "O"]


static func _mountain(c: String) -> bool:
	return c == "^" or c == "B"


func _idx(x: int, y: int) -> int:
	return (clampi(x, -BORDER, w + BORDER - 1) + BORDER) + (clampi(y, -BORDER, h + BORDER - 1) + BORDER) * _cw


func _compute_water() -> void:
	var frontier: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := tile(x, y)
			if c != "~" and c != "=":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var n := tile(x + d.x, y + d.y)
				if n != "~" and n != "=":
					_water_dist[Vector2i(x, y)] = 1
					frontier.append(Vector2i(x, y))
					break
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		var dv: int = _water_dist[p]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			var c := tile(q.x, q.y)
			if (c == "~" or c == "=") and not _water_dist.has(q):
				_water_dist[q] = dv + 1
				frontier.append(q)


func _water_d(x: int, y: int) -> int:
	return _water_dist.get(Vector2i(x, y), 0)


## Góry: wysokość kafelka „^” rośnie z odległością od krawędzi pasma (BFS).
func _compute_mountains() -> void:
	_cw = w + BORDER * 2
	var chh := h + BORDER * 2
	_mh.resize(_cw * chh)
	var dist := PackedInt32Array()
	dist.resize(_cw * chh)
	var frontier: Array[Vector2i] = []
	for y in range(-BORDER, h + BORDER):
		for x in range(-BORDER, w + BORDER):
			var i := (x + BORDER) + (y + BORDER) * _cw
			if not _mountain(tile(x, y)):
				dist[i] = 0
				continue
			dist[i] = 1 << 20
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _mountain(tile(x + d.x, y + d.y)) and x + d.x >= -BORDER and y + d.y >= -BORDER and x + d.x < w + BORDER and y + d.y < h + BORDER:
					dist[i] = 1
					frontier.append(Vector2i(x, y))
					break
	var head := 0
	while head < frontier.size():
		var p: Vector2i = frontier[head]
		head += 1
		var dv: int = dist[(p.x + BORDER) + (p.y + BORDER) * _cw]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < -BORDER or q.y < -BORDER or q.x >= w + BORDER or q.y >= h + BORDER:
				continue
			var qi := (q.x + BORDER) + (q.y + BORDER) * _cw
			if dist[qi] > dv + 1:
				dist[qi] = dv + 1
				frontier.append(q)
	for y in range(-BORDER, h + BORDER):
		for x in range(-BORDER, w + BORDER):
			var i := (x + BORDER) + (y + BORDER) * _cw
			var d: int = mini(dist[i], 30)
			if d == 0:
				_mh[i] = 0.0
				continue
			var b := biome(x, y)
			var nz := _noise.get_noise_2d(x * 2.3, y * 2.3) * 0.5 + 0.5
			match b:
				"d":
					# Mesy: płaskie szczyty i uskoki.
					_mh[i] = 1.0 if d == 1 else (1.9 if d < 4 else 2.7) + nz * 0.12
				"a":
					_mh[i] = minf(0.7 + d * 0.6, 2.4) + nz * 0.5
				_:
					_mh[i] = minf(0.75 + (d - 1) * 0.72, 4.2) + nz * 0.7 * minf(d, 3) / 3.0


func _compute_heights() -> void:
	var chh := h + BORDER * 2 + 1
	var cw1 := _cw + 1
	_heights.resize(cw1 * chh)
	for cy in range(-BORDER, h + BORDER + 1):
		for cx in range(-BORDER, w + BORDER + 1):
			_heights[(cx + BORDER) + (cy + BORDER) * cw1] = _corner_height(cx, cy)


## Wysokość narożnika (cx, cy) = lewy górny róg kafelka (cx, cy).
func _corner_height(cx: int, cy: int) -> float:
	var flat := false
	var water := 0
	var lava := 0
	var mount := 0
	var mh := 99.0
	var wd := 0
	var walk := false
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var x: int = cx + d.x
		var y: int = cy + d.y
		var c := tile(x, y)
		if _flat(c):
			flat = true
		if c == "~" or c == "=":
			water += 1
			wd = maxi(wd, _water_d(x, y))
		if c == "l":
			lava += 1
		if _mountain(c):
			mount += 1
			mh = minf(mh, _mh[_idx(x, y)])
		if _walkable(c) and c != "=":
			walk = true
	var nz := _noise.get_noise_2d(cx * 1.7, cy * 1.7)
	if flat:
		return 0.0
	if mount == 4:
		return mh
	if water == 4:
		return -0.35 - minf(wd, 3) * 0.15 + nz * 0.05
	if water > 0:
		return -0.24
	if lava == 4:
		return -0.28
	if lava > 0:
		return -0.12
	if walk:
		return nz * 0.05
	return nz * 0.1 + 0.02


func height_at_corner(cx: int, cy: int) -> float:
	cx = clampi(cx, -BORDER, w + BORDER)
	cy = clampi(cy, -BORDER, h + BORDER)
	return _heights[(cx + BORDER) + (cy + BORDER) * (_cw + 1)]


## Wysokość terenu w środku kafelka (do stawiania obiektów).
func ground_y(x: int, y: int) -> float:
	return (height_at_corner(x, y) + height_at_corner(x + 1, y) + height_at_corner(x, y + 1) + height_at_corner(x + 1, y + 1)) / 4.0


## Przesunięcie narożnika w poziomie (organiczne trójkąty poza miastem).
func _corner_jitter(cx: int, cy: int) -> Vector2:
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var c := tile(cx + d.x, cy + d.y)
		if _flat(c) or c == "," or c == "=" or c == "p" or c == "c" or c == "F":
			return Vector2.ZERO
	return Vector2(_rand(cx, cy, 1) - 0.5, _rand(cx, cy, 2) - 0.5) * 0.34


func _corner_pos(cx: int, cy: int) -> Vector3:
	var j := _corner_jitter(cx, cy)
	return Vector3(cx + j.x, height_at_corner(cx, cy), cy + j.y)


## Kolor gruntu krainy z odcieniem strefy (żółta – przesuszona, czerwona – spalona).
func ground_color(x: int, y: int) -> Color:
	var b := biome(x, y)
	var pal: Array = GROUND_COL.get(b, GROUND_COL["m"])
	var n := _noise.get_noise_2d(x * 0.8, y * 0.8) * 0.5 + 0.5
	var c: Color = pal[0].lerp(pal[1], n)
	var z := zone(x, y)
	if b in ["m", "f", "r", "w"]:
		if z == "y":
			c = c.lerp(Color(0.6, 0.54, 0.28), 0.32)
		elif z == "r":
			c = c.lerp(Color(0.46, 0.32, 0.22), 0.45)
	elif b == "s" and z == "r":
		c = c.lerp(Color(0.7, 0.68, 0.72), 0.25)
	elif b == "d" and z == "r":
		c = c.lerp(Color(0.78, 0.52, 0.34), 0.3)
	return c


func _tile_color(x: int, y: int) -> Color:
	var c := tile(x, y)
	match c:
		".", "T", "n", "d":
			var g := ground_color(x, y)
			return g.darkened(0.2) if c == "T" else g
		",":
			var b := biome(x, y)
			if b == "s":
				return Color(0.72, 0.68, 0.64).lerp(Color(0.62, 0.56, 0.5), _rand(x, y, 3))
			if b == "d":
				return Color(0.74, 0.58, 0.4).lerp(Color(0.68, 0.52, 0.36), _rand(x, y, 3))
			if b == "a":
				return Color(0.32, 0.27, 0.25)
			return DIRT.lerp(DIRT.darkened(0.15), _rand(x, y, 3))
		"s":
			return SAND
		"a":
			return GROUND_COL["a"][0].lerp(Color(0.3, 0.26, 0.25), _rand(x, y, 4))
		"o":
			return Color(0.1, 0.08, 0.12).lerp(Color(0.16, 0.12, 0.2), _rand(x, y, 4))
		"i":
			return Color(0.7, 0.84, 0.94).lerp(Color(0.8, 0.9, 0.98), _rand(x, y, 4))
		"l":
			return Color(0.18, 0.08, 0.05)
		"p":
			return ground_color(x, y).darkened(0.15)
		"c":
			return Color(0.45, 0.33, 0.2)
		"f", "D", "M", "K", "W", "P", "#", "H", "U":
			return MORTAR
		"x":
			return TEMPLE.darkened(0.25)
		"~", "=":
			return RIVERBED if biome(x, y) != "w" else Color(0.26, 0.24, 0.16)
		"r", "u", "F", "O":
			return ground_color(x, y).lerp(Color(0.4, 0.38, 0.35), 0.3)
		"^", "B":
			return ROCK_COL.get(biome(x, y), ROCK_COL["m"])
	return ground_color(x, y)


# ============================================================================
# Budowa kawałka
# ============================================================================

func _build_chunk(c: Vector2i) -> void:
	if _chunks.has(c) or not _chunk_valid(c):
		return
	var job := _start_chunk(c)
	while not _step_chunk(job):
		pass
	_finish_chunk(job)


func _start_chunk(c: Vector2i) -> Dictionary:
	return {
		"c": c, "row": c.y * CHUNK,
		"ground": _ground_kit(c),
		"corners": {},
		"trees": {},
		"grass": [],
		"objects": MeshKit.new(c.x * 31 + c.y * 17 + 5),
		"foliage": MeshKit.new(c.x * 13 + c.y * 71 + 9),
		"water": MeshKit.new(3),
		"lava": MeshKit.new(4),
	}


func _ground_kit(c: Vector2i) -> MeshKit:
	var k := MeshKit.new(c.x * 7919 + c.y * 104729)
	k.ground = true
	return k


## Buduje jeden rząd kafelków kawałka; zwraca true, gdy kawałek gotowy.
func _step_chunk(job: Dictionary) -> bool:
	var c: Vector2i = job.c
	var ty: int = job.row
	if ty >= (c.y + 1) * CHUNK:
		return true
	job.row = ty + 1
	if ty < -BORDER or ty >= h + BORDER:
		return false
	_cur_trees = job.trees
	_cur_grass = job.grass
	for tx in range(c.x * CHUNK, (c.x + 1) * CHUNK):
		if tx < -BORDER or tx >= w + BORDER:
			continue
		_ground_tile(job.ground, tx, ty, job.corners)
		_tile_details(job.objects, job.foliage, job.ground, tx, ty)
		if _near(tx, ty, "~") or (_near(tx, ty, "=") and not _near(tx, ty, "l") and biome(tx, ty) != "a"):
			_water_tile(job.water, tx, ty)
		if _near(tx, ty, "l"):
			_lava_tile(job.lava, tx, ty)
	return job.row >= (c.y + 1) * CHUNK


func _finish_chunk(job: Dictionary) -> void:
	var node := Node3D.new()
	var c: Vector2i = job.c
	node.name = "Chunk_%d_%d" % [c.x, c.y]
	_add_mesh(node, job.ground, mat_ground, false)
	_add_mesh(node, job.objects, mat_object, true)
	_add_mesh(node, job.foliage, mat_foliage, true)
	_add_mesh(node, job.water, mat_water, false)
	_add_mesh(node, job.lava, mat_lava, false)
	for key in job.trees:
		var parts: PackedStringArray = key.split(":")
		_add_multimesh(node, TreeModels.mesh(parts[0], int(parts[1])), job.trees[key], true)
	if not job.grass.is_empty():
		_add_multimesh(node, TreeModels.grass_mesh(), job.grass, false)
	for spot in _fire_spots.get(c, []):
		var f := Fire3D.new()
		f.kind = spot.kind
		f.position = spot.pos
		f.night = night
		node.add_child(f)
		f.effects = effects
	add_child(node)
	_chunks[c] = node
	_update_hole()


func _add_mesh(parent: Node3D, kit: MeshKit, mat: Material, shadows: bool) -> void:
	if kit.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _add_multimesh(parent: Node3D, mesh: Mesh, list: Array, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	# Bez kolorów instancji tryb zgodności zeruje kolory wierzchołków.
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_custom_data(i, list[i][1])
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func _near(x: int, y: int, ch: String) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if tile(x + dx, y + dy) == ch:
				return true
	return false


## Warstwy tekstur terenu (kolejność = tools/textures/gen_textures.py: LAYERS).
enum { L_GRASS, L_FOREST, L_DIRT, L_SAND, L_SNOW, L_ROCK, L_COBBLE, L_SLAB, L_MUD, L_ASH, L_OBSIDIAN, L_ICE, L_PEBBLES, L_FIELD }
## Pierwszeństwo warstwy w narożniku (droga i bruk „wygrywają” z trawą).
const LAYER_PRIO := [1, 2, 6, 4, 3, 3, 8, 9, 5, 4, 6, 6, 5, 7]
const BIOME_LAYER := {"m": L_GRASS, "f": L_FOREST, "s": L_SNOW, "r": L_GRASS, "d": L_SAND, "w": L_MUD, "a": L_ASH}


func _tile_layer(x: int, y: int) -> int:
	var c := tile(x, y)
	match c:
		"n":
			return L_SNOW
		"d", "s":
			return L_SAND
		"a":
			return L_ASH
		"o", "l":
			return L_OBSIDIAN
		"i":
			return L_ICE
		",":
			return L_ASH if biome(x, y) == "a" else L_DIRT
		"p":
			return L_PEBBLES
		"c":
			return L_FIELD
		"x":
			return L_SLAB
		"f", "D", "M", "K", "W", "P", "#", "H", "U":
			return L_COBBLE
		"~", "=":
			return L_MUD if biome(x, y) == "w" else L_PEBBLES
		"^", "B":
			return L_ROCK
	return BIOME_LAYER.get(biome(x, y), L_GRASS)


func _snow_line(b: String, border: bool) -> float:
	if b == "s":
		return 1.2
	if b == "r" or border:
		return 2.5
	return 99.0


## Narożnik terenu: [warstwa, kolor, normalna] – liczone raz na kawałek (pamięć podręczna w zadaniu).
func _corner_info(cache: Dictionary, cx: int, cy: int) -> Array:
	var key := Vector2i(cx, cy)
	if cache.has(key):
		return cache[key]
	var hh := height_at_corner(cx, cy)
	var best := -1
	var ground_best := -1
	var col := Color(0, 0, 0)
	var mount := false
	var b := biome(cx, cy)
	var border := false
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var x: int = cx + d.x
		var y: int = cy + d.y
		var l := _tile_layer(x, y)
		col += _tile_color(x, y)
		if l == L_ROCK:
			mount = true
			if tile(x, y) == "B":
				border = true
		elif ground_best < 0 or LAYER_PRIO[l] > LAYER_PRIO[ground_best]:
			ground_best = l
		if best < 0 or LAYER_PRIO[l] > LAYER_PRIO[best]:
			best = l
	col /= 4.0
	if mount:
		if hh < 0.3 and ground_best >= 0:
			best = ground_best
		elif hh > _snow_line(b, border):
			best = L_SNOW
			col = SNOW
		else:
			best = L_ROCK
			var rock: Color = ROCK_COL.get(b, ROCK_COL["m"])
			if b == "d":
				var bands := [Color(0.8, 0.52, 0.33), Color(0.86, 0.62, 0.4), Color(0.72, 0.44, 0.3)]
				col = bands[int(hh * 3.0) % 3]
			else:
				col = rock.lerp(rock.darkened(0.15), _rand(cx, cy, 31))
	var n := Vector3(height_at_corner(cx - 1, cy) - height_at_corner(cx + 1, cy), 2.0, height_at_corner(cx, cy - 1) - height_at_corner(cx, cy + 1)).normalized()
	var info := [best, col, n]
	cache[key] = info
	return info


func _ground_tile(k: MeshKit, x: int, y: int, cache: Dictionary) -> void:
	var p00 := _corner_pos(x, y)
	var p10 := _corner_pos(x + 1, y)
	var p01 := _corner_pos(x, y + 1)
	var p11 := _corner_pos(x + 1, y + 1)
	var c := tile(x, y)
	var i00 := _corner_info(cache, x, y)
	var i10 := _corner_info(cache, x + 1, y)
	var i01 := _corner_info(cache, x, y + 1)
	var i11 := _corner_info(cache, x + 1, y + 1)
	var flip := _hash(x, y, 7) % 2 == 0
	var tris: Array = [[p00, p10, p11, i00, i10, i11], [p00, p11, p01, i00, i11, i01]] if flip else [[p00, p10, p01, i00, i10, i01], [p10, p11, p01, i10, i11, i01]]
	for t in tris:
		var ia: Array = t[3]
		var ib: Array = t[4]
		var ic: Array = t[5]
		k.tri_ground([t[0], t[1], t[2]], [ia[2], ib[2], ic[2]], [ia[1], ib[1], ic[1]], Vector3(ia[0], ib[0], ic[0]))
	if c == "a" and _rand(x, y, 11) < 0.3:
		_ember_crack(k, x, y)
	elif c == "i" and _rand(x, y, 12) < 0.35:
		_ice_crack(k, x, y)


## Kolor ściany góry: skała krainy, zielone płaskowyże, śnieżne szczyty, warstwy piaskowca.
func _mountain_color(x: int, y: int, a: Vector3, b: Vector3, c: Vector3) -> Color:
	var bi := biome(x, y)
	var hh := (a.y + b.y + c.y) / 3.0
	var n := (c - a).cross(b - a).normalized()
	var rock: Color = ROCK_COL.get(bi, ROCK_COL["m"])
	if hh < 0.3:
		return ground_color(x, y).lerp(rock, 0.4)
	if bi == "d":
		var band := int(hh * 3.0) % 3
		var bands := [Color(0.8, 0.52, 0.33), Color(0.86, 0.62, 0.4), Color(0.72, 0.44, 0.3)]
		var col: Color = bands[band]
		if n.y > 0.92:
			col = Color(0.88, 0.7, 0.46)
		return col
	if bi == "s" and hh > 1.2:
		return SNOW.darkened(0.05 if n.y < 0.7 else 0.0)
	if (bi == "r" or tile(x, y) == "B") and hh > 2.5:
		return SNOW.darkened(0.04)
	if n.y > 0.9 and bi in ["m", "f", "r", "w"]:
		return ground_color(x, y).lerp(rock, 0.25)
	return rock.lerp(rock.darkened(0.2), clampf(1.0 - n.y, 0.0, 1.0))


func _ember_crack(k: MeshKit, x: int, y: int) -> void:
	k.glow = 1.0
	var p := Vector3(x + 0.2 + _rand(x, y, 12) * 0.6, 0, y + 0.2 + _rand(x, y, 13) * 0.6)
	var a := _rand(x, y, 14) * TAU
	for i in 3:
		a += (_rand(x, y, 15 + i) - 0.5) * 1.6
		var q := p + Vector3(cos(a), 0, sin(a)) * 0.22
		var side := Vector3(-sin(a), 0, cos(a)) * 0.018
		var hp := ground_y(x, y) + 0.015
		k.quad(Vector3(p.x, hp, p.z) - side, Vector3(q.x, hp, q.z) - side, Vector3(q.x, hp, q.z) + side, Vector3(p.x, hp, p.z) + side, Color(1.0, 0.42, 0.12), Vector3.UP)
		p = q
	k.glow = 0.0


func _ice_crack(k: MeshKit, x: int, y: int) -> void:
	var p := Vector3(x + 0.2 + _rand(x, y, 12) * 0.6, 0.012, y + 0.2 + _rand(x, y, 13) * 0.6)
	var a := _rand(x, y, 14) * TAU
	for i in 3:
		a += (_rand(x, y, 15 + i) - 0.5) * 1.8
		var q := p + Vector3(cos(a), 0, sin(a)) * 0.25
		var side := Vector3(-sin(a), 0, cos(a)) * 0.01
		k.quad(p - side, q - side, q + side, p + side, Color(0.95, 0.98, 1.0), Vector3.UP)
		p = q


## Średni kolor sąsiadów (lewy/górny albo prawy/dolny).
func _blend_neighbors(x: int, y: int, side: int) -> Color:
	var a := _tile_color(x + side, y)
	var b := _tile_color(x, y + side)
	return a.lerp(b, 0.5)


## Woda: siatka 2×2 na kafelek, kolor R = odległość od brzegu, G = bagno (mętna woda).
func _water_tile(k: MeshKit, x: int, y: int) -> void:
	var swamp := 1.0 if biome(x, y) == "w" else 0.0
	var pts := {}
	for sy in 3:
		for sx in 3:
			pts[Vector2i(sx, sy)] = Vector3(x + sx * 0.5, WATER_Y, y + sy * 0.5)
	for sy in 2:
		for sx in 2:
			var a: Vector3 = pts[Vector2i(sx, sy)]
			var b: Vector3 = pts[Vector2i(sx + 1, sy)]
			var c: Vector3 = pts[Vector2i(sx + 1, sy + 1)]
			var d: Vector3 = pts[Vector2i(sx, sy + 1)]
			for t in [[a, b, c], [a, c, d]]:
				var ctr: Vector3 = (t[0] + t[1] + t[2]) / 3.0
				k.tri(t[0], t[1], t[2], Color(_shore_at(ctr.x, ctr.z), swamp, 0), Vector3.UP)


## Odległość od brzegu (0..1) dla punktu – interpolowana z odległości kafelków.
func _shore_at(fx: float, fy: float) -> float:
	var x := floori(fx - 0.5)
	var y := floori(fy - 0.5)
	var tx := fx - 0.5 - x
	var ty := fy - 0.5 - y
	var a := float(_water_d(x, y))
	var b := float(_water_d(x + 1, y))
	var c := float(_water_d(x, y + 1))
	var d := float(_water_d(x + 1, y + 1))
	var v := lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
	return clampf((v - 0.4) / 3.0, 0.0, 1.0)


## Lawa: płaska tafla z animowanym shaderem (R = odległość od brzegu).
func _lava_tile(k: MeshKit, x: int, y: int) -> void:
	for sy in 2:
		for sx in 2:
			var a := Vector3(x + sx * 0.5, LAVA_Y, y + sy * 0.5)
			var b := a + Vector3(0.5, 0, 0)
			var c := a + Vector3(0.5, 0, 0.5)
			var d := a + Vector3(0, 0, 0.5)
			var inner := 1.0 if tile(x, y) == "l" else 0.0
			k.tri(a, b, c, Color(inner, 0, 0), Vector3.UP)
			k.tri(a, c, d, Color(inner, 0, 0), Vector3.UP)


# ============================================================================
# Obiekty na kafelkach
# ============================================================================

func _tile_details(obj: MeshKit, fol: MeshKit, gnd: MeshKit, x: int, y: int) -> void:
	var c := tile(x, y)
	var gy := ground_y(x, y)
	var center := Vector3(x + 0.5, gy, y + 0.5)
	var b := biome(x, y)
	match c:
		"T":
			_tree(fol, center + _offset(x, y, 0.18), x, y)
		"r":
			_rock(obj, center, x, y)
		"#":
			_wall(obj, x, y)
		",":
			_road_pebbles(gnd, x, y)
		"D":
			_chest(obj, center, x, y)
		"M":
			_stall(obj, center, x, y)
		"K":
			_anvil(obj, center)
		"W":
			_workbench(obj, center)
		"P":
			_furnace(obj, center)
		"H":
			if _houses.has(Vector2i(x, y)):
				var hd: Array = _houses[Vector2i(x, y)]
				var style := "snow" if b == "s" else ("desert" if b == "d" else "meadow")
				match landmark_at(hd):
					"citadel":
						WorldProps.citadel(obj, hd[0], hd[1], hd[2], hd[3], style)
					"cathedral":
						WorldProps.cathedral(obj, hd[0], hd[1], hd[2], hd[3], style)
					_:
						WorldProps.house(obj, hd[0], hd[1], hd[2], hd[3], hd[4], style, _rand(x, y, 40))
		"U":
			if tile(x + 1, y) == "U" and tile(x, y + 1) == "U" and tile(x - 1, y) != "U" and tile(x, y - 1) != "U":
				obj.reset()
				var in_city := not GameData.city_at(x, y).is_empty()
				WorldProps.fountain(obj, Vector3(x + 1.0, 0.0, y + 1.0), "desert" if b == "d" else "meadow", not in_city)
				if in_city:
					WorldProps.statue(obj, Vector3(x + 1.0, 0.1, y + 1.0))
			elif tile(x + 1, y) != "U" and tile(x - 1, y) != "U" and tile(x, y - 1) != "U" and tile(x, y + 1) != "U":
				obj.reset()
				WorldProps.well(obj, center)
		"F":
			obj.reset()
			WorldProps.fence(obj, center, tile(x + 1, y) == "F", tile(x, y + 1) == "F")
		"c":
			fol.reset()
			WorldProps.crops(fol, center, _rand(x, y, 41))
		"=":
			var along_x := _walkable(tile(x - 1, y)) and tile(x - 1, y) != "~" or _walkable(tile(x + 1, y)) and tile(x + 1, y) != "~"
			along_x = along_x and not (tile(x, y - 1) == "=" and tile(x, y + 1) == "=")
			var ra := not _walkable(tile(x, y - 1)) if along_x else not _walkable(tile(x - 1, y))
			var rb := not _walkable(tile(x, y + 1)) if along_x else not _walkable(tile(x + 1, y))
			obj.reset()
			WorldProps.bridge(obj, x, y, along_x, ra, rb, b == "a" or _near(x, y, "l"))
		"u":
			obj.reset()
			WorldProps.ruin_pillar(obj, center, _rand(x, y, 42), b == "a")
		"p":
			gnd.reset()
			WorldProps.ruin_floor(gnd, x, y, _rand(x, y, 43), _rand(x, y, 44))
		"O":
			obj.reset()
			WorldProps.obelisk_base(obj, center)
		"o":
			if _rand(x, y, 45) < 0.06:
				obj.reset()
				WorldProps.crystals(obj, center + _offset(x, y, 0.3), _rand(x, y, 46), _rand(x, y, 47) < 0.4)
		"^", "B":
			_mountain_decor(obj, fol, center, x, y)
		".", "n", "d", "a", "s":
			_ground_decor(fol, obj, center, x, y)
	for t in _temples:
		if x == int(t.x) and y == int(t.y):
			_rune_circle(gnd, Vector3(t.x, 0.02, t.y))


func _offset(x: int, y: int, amount: float) -> Vector3:
	return Vector3(_rand(x, y, 5) - 0.5, 0, _rand(x, y, 6) - 0.5) * amount * 2.0


## Drzewo na kafelku: [rodzaj, wariant, barwa liści (a = siła), skala, obrót].
func tree_spec(x: int, y: int, scale_mul := 1.0) -> Array:
	var r := _rand(x, y, 8)
	var b := biome(x, y)
	var z := zone(x, y)
	var ash_near := _near(x, y, "a") and b != "a"
	var s := (0.85 + _rand(x, y, 9) * 0.45) * scale_mul
	if b == "f":
		s *= 1.1
	var kind := "oak"
	match b:
		"a":
			kind = "dead"
		"d":
			kind = "palm" if _near(x, y, "~") or _near(x, y, "s") or r < 0.35 else "cactus"
		"s":
			kind = "pine_snow"
		"w":
			kind = "willow" if r < 0.55 else "dead"
		"r":
			kind = "pine"
		"f":
			kind = "pine" if r < 0.5 else "oak"
		_:
			if ash_near:
				kind = "dead"
			elif r < 0.3:
				kind = "pine"
			elif r < 0.45:
				kind = "birch"
	var v := _rand(x, y, 16)
	var tint := Color(0.3, 0.55, 0.2).lerp(Color(0.45, 0.6, 0.2), v)
	tint.a = 0.15
	if kind == "pine" or kind == "pine_snow":
		tint = Color(0.3, 0.3, 0.15, 0.35) if z == "r" else Color(0, 0, 0, 0)
	elif z == "y":
		tint = Color(0.95, 0.62, 0.18).lerp(Color(0.9, 0.4, 0.12), v)
		tint.a = 0.8
	elif z == "r":
		tint = Color(0.55, 0.32, 0.15).lerp(Color(0.45, 0.25, 0.14), v)
		tint.a = 0.75
	return [kind, _hash(x, y, 3) % TreeModels.VARIANTS, tint, s, _rand(x, y, 10) * TAU]


## Drzewo dopasowane do krainy i strefy (instancja MultiMesh w bieżącym kawałku).
func _tree(_k: MeshKit, base: Vector3, x: int, y: int, scale_mul := 1.0) -> void:
	var spec := tree_spec(x, y, scale_mul)
	var key := "%s:%d" % [spec[0], spec[1]]
	if not _cur_trees.has(key):
		_cur_trees[key] = []
	var xf := Transform3D(Basis(Vector3.UP, spec[4]).scaled(Vector3.ONE * float(spec[3])), base)
	_cur_trees[key].append([xf, spec[2]])


## Kępy trawy na kafelku (instancje MultiMesh w bieżącym kawałku).
func _grass(center: Vector3, x: int, y: int, count: int, col: Color) -> void:
	for i in count:
		var p := center + Vector3(_rand(x, y, 130 + i) - 0.5, 0, _rand(x, y, 140 + i) - 0.5) * 0.9
		var s := 0.7 + _rand(x, y, 150 + i) * 0.6
		var xf := Transform3D(Basis(Vector3.UP, _rand(x, y, 160 + i) * TAU).scaled(Vector3(s, s * (0.8 + _rand(x, y, 170 + i) * 0.5), s)), p)
		_cur_grass.append([xf, col])


func _leaf_color(b: String, z: String, v: float) -> Color:
	var c := Color(0.25, 0.5, 0.2).lerp(Color(0.36, 0.6, 0.22), v)
	if b == "f":
		c = Color(0.18, 0.42, 0.16).lerp(Color(0.26, 0.5, 0.2), v)
	if z == "y":
		c = Color(0.85, 0.55, 0.15).lerp(Color(0.8, 0.35, 0.12), v)
	elif z == "r":
		c = Color(0.55, 0.3, 0.16).lerp(Color(0.45, 0.25, 0.15), v)
	return c


func _rock(k: MeshKit, base: Vector3, x: int, y: int, size := 1.0) -> void:
	var b := biome(x, y)
	var col: Color = ROCK_COL.get(b, ROCK_COL["m"])
	if b == "d":
		col = Color(0.72, 0.52, 0.36)
	k.reset()
	k.jitter = 0.05
	k.tex = 6
	var s := (0.8 + _rand(x, y, 12) * 0.4) * size
	k.place(base, _rand(x, y, 13) * TAU, s)
	var top: Color = col.lightened(0.12)
	if b == "s":
		top = SNOW
	elif b in ["m", "f", "w"] and _rand(x, y, 14) < 0.5:
		top = col.lerp(Color(0.35, 0.5, 0.25), 0.5)
	k.blob(Vector3(0, 0.22, 0), Vector3(0.46, 0.4, 0.4), col, 3, 6, 0.22, top)
	k.blob(Vector3(0.3, 0.12, 0.22), Vector3(0.22, 0.18, 0.2), col.darkened(0.08), 2, 5, 0.2)
	if b == "a":
		k.glow = 1.0
		k.blob(Vector3(-0.1, 0.42, 0.2), Vector3(0.05, 0.04, 0.05), Color(1, 0.35, 0.08), 2, 4, 0.0)
	k.reset()
	k.jitter = 0.0


## Drobiazgi gruntu zależne od krainy (trawa, kwiaty, paprocie, trzciny, krzaki, kości…).
func _ground_decor(fol: MeshKit, obj: MeshKit, center: Vector3, x: int, y: int) -> void:
	var r := _rand(x, y, 14)
	var b := biome(x, y)
	var z := zone(x, y)
	var gc := ground_color(x, y)
	fol.reset()
	obj.reset()
	match b:
		"m", "f", "r", "w":
			if b == "w" and _near(x, y, "~") and r < 0.35:
				WorldProps.reeds(fol, center + _offset(x, y, 0.25), r)
				return
			if b != "w" and r < 0.75:
				var gcol := gc.lightened(0.05)
				gcol.a = 0.85
				_grass(center, x, y, 2 if r < 0.4 else 1, gcol)
			if r < (0.4 if b == "f" else 0.3):
				pass
			elif b == "f" and r > 0.9:
				WorldProps.fern(fol, center + _offset(x, y, 0.25), r)
			elif b == "f" and r > 0.86:
				WorldProps.mushrooms(obj, center + _offset(x, y, 0.25), r)
			elif b == "f" and r > 0.84:
				WorldProps.log_fallen(obj, center, r)
			elif z == "g" and b == "m" and r > 0.93:
				var fc: Color = [Color(0.95, 0.9, 0.35), Color(0.9, 0.4, 0.5), Color(0.6, 0.55, 0.95), Color(0.98, 0.98, 0.95)][_hash(x, y, 15) % 4]
				for i in 3:
					var p := center + Vector3(_rand(x, y, 70 + i) - 0.5, 0, _rand(x, y, 80 + i) - 0.5) * 0.7
					obj.cyl(p, 0.012, 0.012, 0.16, 3, Color(0.3, 0.55, 0.2), false)
					obj.blob(p + Vector3(0, 0.18, 0), Vector3(0.05, 0.035, 0.05), fc, 2, 5, 0.0)
			elif r > 0.975:
				obj.jitter = 0.04
				obj.blob(center + _offset(x, y, 0.3), Vector3(0.14, 0.09, 0.12), Color(0.52, 0.5, 0.47), 2, 5, 0.25)
				obj.jitter = 0.0
			elif z == "y" and r > 0.9:
				fol.sway_base = center.y
				fol.sway_height = 0.5
				fol.blob(center + Vector3(0, 0.16, 0) + _offset(x, y, 0.25), Vector3(0.24, 0.18, 0.24), Color(0.6, 0.45, 0.18), 2, 6, 0.3)
				fol.sway_height = 0.0
			elif z == "r" and r > 0.94:
				_bones(obj, center, x, y)
		"s":
			if r < 0.07:
				obj.jitter = 0.03
				obj.blob(center + _offset(x, y, 0.3) + Vector3(0, -0.05, 0), Vector3(0.35, 0.16, 0.3), SNOW, 2, 6, 0.15)
				obj.jitter = 0.0
			elif r > 0.96:
				fol.sway_base = center.y
				fol.sway_height = 0.5
				fol.blob(center + Vector3(0, 0.12, 0) + _offset(x, y, 0.25), Vector3(0.2, 0.14, 0.2), Color(0.3, 0.38, 0.3), 2, 6, 0.3, SNOW)
				fol.sway_height = 0.0
		"d":
			if r < 0.05:
				fol.sway_base = center.y
				fol.sway_height = 0.4
				fol.blob(center + Vector3(0, 0.12, 0) + _offset(x, y, 0.25), Vector3(0.2, 0.13, 0.2), Color(0.62, 0.55, 0.3), 2, 6, 0.35)
				fol.sway_height = 0.0
			elif r > 0.985:
				_bones(obj, center, x, y)
			elif r > 0.95:
				obj.jitter = 0.04
				obj.blob(center + _offset(x, y, 0.3), Vector3(0.14, 0.08, 0.12), Color(0.7, 0.52, 0.36), 2, 5, 0.25)
				obj.jitter = 0.0
		"a":
			if r < 0.04:
				_rock(obj, center + _offset(x, y, 0.3), x, y, 0.35)
			elif r > 0.97:
				_bones(obj, center, x, y)
			elif r > 0.94:
				WorldProps.crystals(obj, center + _offset(x, y, 0.3), r, true)


func _bones(obj: MeshKit, center: Vector3, x: int, y: int) -> void:
	obj.reset()
	obj.place(center + _offset(x, y, 0.3), _rand(x, y, 16) * TAU)
	obj.box(Vector3(0, 0, 0), Vector3(0.36, 0.04, 0.05), Color(0.85, 0.82, 0.72))
	obj.blob(Vector3(0.2, 0.05, 0), Vector3(0.06, 0.05, 0.06), Color(0.85, 0.82, 0.72), 2, 5, 0.0)
	obj.blob(Vector3(-0.2, 0.05, 0), Vector3(0.06, 0.05, 0.06), Color(0.85, 0.82, 0.72), 2, 5, 0.0)
	obj.reset()


## Na zboczach: pojedyncze sosny u podnóża, głazy na grzbietach.
func _mountain_decor(obj: MeshKit, fol: MeshKit, center: Vector3, x: int, y: int) -> void:
	var r := _rand(x, y, 17)
	var b := biome(x, y)
	var mh: float = _mh[_idx(x, y)]
	if mh < 1.3 and b in ["m", "f", "r", "s", "w"] and r < 0.22:
		_tree(fol, center + _offset(x, y, 0.2), x, y, 1.1)
	elif r > 0.93 and b != "d":
		_rock(obj, center, x, y, 1.2)


## Bruk: 2×2 kamienie na kafelek, lekko wypukłe (kolor zależny od miasta).
func _cobbles(k: MeshKit, x: int, y: int) -> void:
	k.reset()
	k.jitter = 0.05
	var b := biome(x, y)
	var c0 := Color(0.52, 0.5, 0.47)
	var c1 := Color(0.44, 0.4, 0.37)
	if b == "d":
		c0 = Color(0.84, 0.7, 0.5)
		c1 = Color(0.76, 0.6, 0.42)
	elif b == "s":
		c0 = Color(0.62, 0.64, 0.68)
		c1 = Color(0.52, 0.54, 0.58)
	for i in 4:
		var ox := 0.25 + (i % 2) * 0.5
		var oz := 0.25 + (i / 2) * 0.5
		var v := _rand(x, y, 90 + i)
		var col := c0.lerp(c1, v)
		if b == "s" and _rand(x, y, 99 + i) < 0.12:
			col = SNOW
		var sz := 0.42 + _rand(x, y, 95 + i) * 0.04
		k.box(Vector3(x + ox, 0.0, y + oz), Vector3(sz, 0.035, sz), col, Vector2(0.9, 0.9))
	k.jitter = 0.0


func _temple_slab(k: MeshKit, x: int, y: int) -> void:
	k.reset()
	k.box(Vector3(x + 0.5, 0.0, y + 0.5), Vector3(0.96, 0.05, 0.96), TEMPLE.lerp(Color(0.95, 0.92, 0.85), _rand(x, y, 19)), Vector2(0.96, 0.96))


func _rune_circle(k: MeshKit, c: Vector3) -> void:
	k.reset()
	k.glow = 0.55
	var seg := 28
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for rr: Array in [[1.25, 1.35], [0.7, 0.76]]:
			var p0 := Vector3(c.x + cos(a0) * rr[0], 0.056, c.z + sin(a0) * rr[0])
			var p1 := Vector3(c.x + cos(a1) * rr[0], 0.056, c.z + sin(a1) * rr[0])
			var q0 := Vector3(c.x + cos(a0) * rr[1], 0.056, c.z + sin(a0) * rr[1])
			var q1 := Vector3(c.x + cos(a1) * rr[1], 0.056, c.z + sin(a1) * rr[1])
			k.quad(p0, p1, q1, q0, GOLD, Vector3.UP)
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(c.x + cos(a) * 1.05, 0.057, c.z + sin(a) * 1.05)
		var t := Vector3(-sin(a), 0, cos(a)) * 0.08
		var rdir := Vector3(cos(a), 0, sin(a)) * 0.12
		k.quad(p - t, p + rdir, p + t, p - rdir, GOLD, Vector3.UP)
	k.glow = 0.0


func _road_pebbles(k: MeshKit, x: int, y: int) -> void:
	if _rand(x, y, 23) > 0.3:
		return
	k.reset()
	k.jitter = 0.05
	for i in 2:
		var p := Vector3(x + 0.2 + _rand(x, y, 24 + i) * 0.6, 0.0, y + 0.2 + _rand(x, y, 26 + i) * 0.6)
		k.blob(p, Vector3(0.06, 0.035, 0.05), Color(0.55, 0.5, 0.45), 2, 5, 0.2)
	k.jitter = 0.0


# --- Mury (styl zależny od krainy miasta) ---------------------------------------

func _is_wall(x: int, y: int) -> bool:
	return tile(x, y) == "#"


func _wall_colors(b: String) -> Array:
	match b:
		"d":
			return [Color(0.84, 0.68, 0.46), Color(0.3, 0.58, 0.62)]
		"s":
			return [Color(0.6, 0.62, 0.66), Color(0.28, 0.32, 0.45)]
	return [STONE, Color(0.55, 0.2, 0.14)]


func _wall(k: MeshKit, x: int, y: int) -> void:
	var l := _is_wall(x - 1, y)
	var r := _is_wall(x + 1, y)
	var u := _is_wall(x, y - 1)
	var d := _is_wall(x, y + 1)
	var horiz := l or r
	var vert := u or d
	var gate_side := (horiz and not vert and (_walkable(tile(x - 1, y)) or _walkable(tile(x + 1, y)))) \
		or (vert and not horiz and (_walkable(tile(x, y - 1)) or _walkable(tile(x, y + 1))))
	var corner := horiz and vert
	var b := biome(x, y)
	var cols := _wall_colors(b)
	var stone: Color = cols[0]
	var cx := x + 0.5
	var cz := y + 0.5
	k.reset()
	k.jitter = 0.03
	k.tex = 2
	if corner or gate_side:
		_tower(k, Vector3(cx, 0, cz), x, y, b)
		k.jitter = 0.0
		return
	var sx := 1.0 if horiz else 0.78
	var sz := 1.0 if vert else 0.78
	if not horiz and not vert:
		sx = 0.9
		sz = 0.9
	var hgt := 0.0
	for i in 3:
		var lh := 0.42
		var col := stone.lerp(stone.darkened(0.18), _rand(x, y, 100 + i))
		var inset := 0.02 * (i % 2)
		k.box(Vector3(cx, hgt, cz), Vector3(sx - inset, lh, sz - inset), col)
		hgt += lh
	var merlon := stone.lightened(0.05)
	var cap: Variant = SNOW if b == "s" else null
	if horiz:
		for i in 2:
			k.box(Vector3(x + 0.25 + i * 0.5, hgt, cz - sz * 0.35), Vector3(0.3, 0.26, 0.12), merlon, Vector2.ONE, cap)
			k.box(Vector3(x + 0.25 + i * 0.5, hgt, cz + sz * 0.35), Vector3(0.3, 0.26, 0.12), merlon, Vector2.ONE, cap)
	else:
		for i in 2:
			k.box(Vector3(cx - sx * 0.35, hgt, y + 0.25 + i * 0.5), Vector3(0.12, 0.26, 0.3), merlon, Vector2.ONE, cap)
			k.box(Vector3(cx + sx * 0.35, hgt, y + 0.25 + i * 0.5), Vector3(0.12, 0.26, 0.3), merlon, Vector2.ONE, cap)
	if b == "s":
		k.box(Vector3(cx, hgt - 0.01, cz), Vector3(sx * 0.5 if horiz else 0.3, 0.04, 0.3 if horiz else sz * 0.5), SNOW)
	# Chorągiew na zewnętrznej ścianie co kilka kafelków (kolor miasta).
	if horiz and x % 6 == 0:
		var outer := 1.0
		if _walkable(tile(x, y + 1)) and tile(x, y + 1) != "f":
			outer = 1.0
		elif _walkable(tile(x, y - 1)) and tile(x, y - 1) != "f":
			outer = -1.0
		else:
			return
		var z := cz + outer * (sz / 2.0 + 0.012)
		k.tex = 0
		var banner: Color = {"d": Color(0.15, 0.45, 0.55), "s": Color(0.2, 0.25, 0.55)}.get(b, Color(0.62, 0.12, 0.1))
		k.jitter = 0.0
		k.quad(Vector3(cx - 0.2, 1.2, z), Vector3(cx + 0.2, 1.2, z), Vector3(cx + 0.2, 0.55, z), Vector3(cx - 0.2, 0.55, z), banner, Vector3(0, 0, outer))
		k.tri(Vector3(cx - 0.2, 0.55, z), Vector3(cx + 0.2, 0.55, z), Vector3(cx, 0.4, z), banner, Vector3(0, 0, outer))
		k.glow = 0.3
		k.quad(Vector3(cx - 0.07, 0.95, z + outer * 0.003), Vector3(cx + 0.07, 0.95, z + outer * 0.003), Vector3(cx + 0.07, 0.8, z + outer * 0.003), Vector3(cx - 0.07, 0.8, z + outer * 0.003), GOLD, Vector3(0, 0, outer))
		k.glow = 0.0
	k.jitter = 0.0


func _tower(k: MeshKit, base: Vector3, x: int, y: int, b: String) -> void:
	var cols := _wall_colors(b)
	var col: Color = cols[0].lightened(0.02)
	k.cyl(base, 0.64, 0.6, 1.9, 8, col, true, col.darkened(0.12), 0.2)
	for i in 8:
		if i % 2 == 0:
			var a := TAU * i / 8.0 + 0.2
			k.box(base + Vector3(cos(a) * 0.58, 1.9, sin(a) * 0.58), Vector3(0.2, 0.24, 0.2), col.lightened(0.05), Vector2.ONE, SNOW if b == "s" else null)
	var roof: Color = cols[1].lerp(cols[1].darkened(0.15), _rand(x, y, 110))
	if b == "d":
		# Kopuła pustynnej wieży.
		k.tex = 0
		k.metal = 0.3
		k.blob(base + Vector3(0, 2.05, 0), Vector3(0.5, 0.55, 0.5), roof, 3, 8, 0.0)
		k.metal = 1.0
		k.cone(base + Vector3(0, 2.55, 0), 0.05, 0.3, 4, GOLD)
		k.metal = 0.0
	else:
		k.tex = 3
		k.cone(base + Vector3(0, 2.1, 0), 0.52, 0.95, 8, roof, 0.2)
		if b == "s":
			k.tex = 7
			k.cone(base + Vector3(0, 2.62, 0), 0.25, 0.43, 8, SNOW, 0.2)
	k.tex = 2


# --- Stacje miasta --------------------------------------------------------------

func _chest(k: MeshKit, c: Vector3, x: int, y: int) -> void:
	k.reset()
	k.place(c, 0.0 if tile(x, y + 1) == "f" else PI)
	k.box(Vector3(0, 0.03, 0), Vector3(0.7, 0.36, 0.48), WOOD)
	k.box(Vector3(0, 0.39, 0), Vector3(0.74, 0.14, 0.52), WOOD_DARK, Vector2(0.9, 0.7))
	k.metal = 1.0
	for i in 2:
		k.box(Vector3(-0.22 + i * 0.44, 0.03, 0), Vector3(0.06, 0.5, 0.53), GOLD.darkened(0.2))
	k.box(Vector3(0, 0.25, 0.25), Vector3(0.1, 0.12, 0.03), GOLD)
	k.reset()


func _stall(k: MeshKit, c: Vector3, x: int, y: int) -> void:
	k.reset()
	var cloth: Color = [Color(0.72, 0.16, 0.12), Color(0.2, 0.36, 0.62), Color(0.25, 0.5, 0.25), Color(0.8, 0.55, 0.15)][x % 4]
	var cream := Color(0.92, 0.86, 0.72)
	k.box(c + Vector3(0, 0, 0.18), Vector3(0.9, 0.5, 0.4), WOOD)
	k.box(c + Vector3(0, 0.5, 0.18), Vector3(0.96, 0.05, 0.46), WOOD_DARK)
	for sx in [-0.44, 0.44]:
		for sz in [-0.38, 0.4]:
			k.box(c + Vector3(sx, 0, sz), Vector3(0.06, 1.35 if sz < 0 else 1.1, 0.06), WOOD_DARK)
	var strips := 6
	for i in strips:
		var x0 := -0.5 + i / float(strips)
		var x1 := x0 + 1.0 / strips
		var col := cloth if i % 2 == 0 else cream
		var a := c + Vector3(x0, 1.38, -0.46)
		var b := c + Vector3(x1, 1.38, -0.46)
		var cc := c + Vector3(x1, 1.1, 0.5)
		var d := c + Vector3(x0, 1.1, 0.5)
		k.quad(a, b, cc, d, col, Vector3(0, 1, 0.3))
		k.quad(a, d, cc, b, col.darkened(0.3), Vector3(0, -1, -0.3))
		k.quad(d, cc, cc + Vector3(0, -0.12, 0), d + Vector3(0, -0.12, 0), col, Vector3(0, 0, 1))
	var goods: Array = [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.45, 0.7, 0.25), Color(0.55, 0.3, 0.6)]
	for i in 5:
		var gc: Color = goods[(x + i) % goods.size()]
		k.blob(c + Vector3(-0.32 + i * 0.16, 0.6, 0.15 + (i % 2) * 0.1), Vector3(0.07, 0.07, 0.07), gc, 2, 5, 0.0)
	k.box(c + Vector3(0.3, 0, -0.1), Vector3(0.24, 0.26, 0.24), WOOD.lightened(0.1))


func _anvil(k: MeshKit, c: Vector3) -> void:
	k.reset()
	k.cyl(c, 0.26, 0.24, 0.32, 7, WOOD)
	k.metal = 0.9
	k.box(c + Vector3(0, 0.32, 0), Vector3(0.18, 0.14, 0.2), IRON)
	k.box(c + Vector3(0, 0.46, 0), Vector3(0.5, 0.12, 0.22), IRON.lightened(0.05))
	k.box(c + Vector3(0.3, 0.49, 0), Vector3(0.14, 0.07, 0.1), IRON, Vector2(0.4, 0.5))
	k.metal = 0.0
	k.box(c + Vector3(-0.35, 0, 0.3), Vector3(0.28, 0.36, 0.28), WOOD_DARK)
	k.box(c + Vector3(-0.05, 0.58, 0.02), Vector3(0.3, 0.03, 0.03), WOOD)
	k.metal = 0.9
	k.box(c + Vector3(-0.2, 0.56, 0.02), Vector3(0.07, 0.08, 0.1), IRON)
	k.reset()


func _workbench(k: MeshKit, c: Vector3) -> void:
	k.reset()
	k.box(c + Vector3(0, 0.46, 0), Vector3(0.94, 0.08, 0.6), WOOD.lightened(0.08))
	for sx in [-0.4, 0.4]:
		for sz in [-0.24, 0.24]:
			k.box(c + Vector3(sx, 0, sz), Vector3(0.07, 0.46, 0.07), WOOD_DARK)
	k.box(c + Vector3(-0.2, 0.54, 0.05), Vector3(0.3, 0.06, 0.18), WOOD.lightened(0.2))
	k.box(c + Vector3(0.22, 0.54, -0.1), Vector3(0.22, 0.02, 0.06), Color(0.85, 0.82, 0.75))
	k.metal = 1.0
	k.box(c + Vector3(0.25, 0.54, 0.12), Vector3(0.2, 0.02, 0.08), IRON.lightened(0.2))
	k.reset()


func _furnace(k: MeshKit, c: Vector3) -> void:
	k.reset()
	k.jitter = 0.04
	k.blob(c + Vector3(0, 0.3, 0), Vector3(0.48, 0.55, 0.46), Color(0.5, 0.42, 0.38), 3, 8, 0.08, Color(0.56, 0.48, 0.42))
	k.cyl(c + Vector3(0.18, 0.6, -0.18), 0.12, 0.1, 0.75, 6, Color(0.42, 0.36, 0.33))
	k.jitter = 0.0
	k.glow = 1.0
	k.quad(c + Vector3(-0.17, 0.08, 0.44), c + Vector3(0.17, 0.08, 0.44), c + Vector3(0.12, 0.34, 0.42), c + Vector3(-0.12, 0.34, 0.42), Color(1.0, 0.45, 0.12), Vector3(0, 0, 1))
	k.reset()


# --- Domy i pochodnie (wyszukiwane raz przy starcie) ------------------------------

## Grupuje kafelki „H” w prostokąty domów i wybiera stronę drzwi (ta z największą liczbą przejść).
func _find_houses() -> void:
	var seen := {}
	for y in h:
		for x in w:
			if tile(x, y) != "H" or seen.has(Vector2i(x, y)):
				continue
			var x1 := x
			while tile(x1 + 1, y) == "H" and not seen.has(Vector2i(x1 + 1, y)):
				x1 += 1
			var y1 := y
			var ok := true
			while ok:
				for xx in range(x, x1 + 1):
					if tile(xx, y1 + 1) != "H" or seen.has(Vector2i(xx, y1 + 1)):
						ok = false
						break
				if ok:
					y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					seen[Vector2i(xx, yy)] = true
			var score := [0, 0, 0, 0]
			for xx in range(x, x1 + 1):
				score[0] += int(_walkable(tile(xx, y - 1)))
				score[2] += int(_walkable(tile(xx, y1 + 1))) + 1
			for yy in range(y, y1 + 1):
				score[3] += int(_walkable(tile(x - 1, yy)))
				score[1] += int(_walkable(tile(x1 + 1, yy)))
			var door := 2
			for i in 4:
				if score[i] > score[door]:
					door = i
			_houses[Vector2i(x, y)] = [x, y, x1, y1, door]


## Wielkie budowle miast: kwartały domów 5×4 po bokach świątyni (lewy – cytadela, prawy – katedra).
func landmark_at(hd: Array) -> String:
	var c := GameData.city_at(int(hd[0]), int(hd[1]))
	if c.is_empty() or int(hd[2]) - int(hd[0]) != 4 or int(hd[3]) - int(hd[1]) != 3:
		return ""
	var lx := int(hd[0]) - int(c.x0)
	var ly := int(hd[1]) - int(c.y0)
	if ly != 5:
		return ""
	if lx == 2:
		return "citadel"
	if lx == 24:
		return "cathedral"
	return ""


func _find_fire_spots() -> void:
	for y in h:
		for x in w:
			var ch := tile(x, y)
			var spot := {}
			if ch == "#":
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var g: Vector2i = Vector2i(x, y) + d
					if _walkable(tile(g.x, g.y)) and ((d.y == 0 and not _is_wall(x, y - 1) and not _is_wall(x, y + 1)) or (d.x == 0 and not _is_wall(x - 1, y) and not _is_wall(x + 1, y))):
						spot = {"pos": Vector3(x + 0.5 + d.x * 0.7, 1.35, y + 0.5 + d.y * 0.7), "kind": "wall"}
						break
			elif ch == "P":
				spot = {"pos": Vector3(x + 0.5, 0.22, y + 0.9), "kind": "hearth"}
			elif ch == "x":
				var corners := [[Vector2i(-1, 0), Vector2i(0, -1), Vector3(-0.5, 0, -0.5)], [Vector2i(1, 0), Vector2i(0, -1), Vector3(1.5, 0, -0.5)],
					[Vector2i(-1, 0), Vector2i(0, 1), Vector3(-0.5, 0, 1.5)], [Vector2i(1, 0), Vector2i(0, 1), Vector3(1.5, 0, 1.5)]]
				for cdef in corners:
					var a: Vector2i = cdef[0]
					var b2: Vector2i = cdef[1]
					if tile(x + a.x, y + a.y) != "x" and tile(x + b2.x, y + b2.y) != "x":
						_add_fire({"pos": Vector3(x, 0, y) + cdef[2], "kind": "brazier"})
				continue
			if not spot.is_empty():
				_add_fire(spot)


func _add_fire(spot: Dictionary) -> void:
	var p: Vector3 = spot.pos
	var c := _chunk_of(Vector2i(floori(p.x), floori(p.z)))
	if not _fire_spots.has(c):
		_fire_spots[c] = []
	_fire_spots[c].append(spot)
