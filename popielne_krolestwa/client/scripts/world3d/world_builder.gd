class_name WorldBuilder
extends Node3D
## Świat 3D low-poly budowany z mapy kafelków otrzymanej od serwera (1 kafelek = 1 jednostka).
##
## Teren, woda, drzewa, skały, mury i stacje rzemieślnicze są generowane w kodzie i scalane
## w siatki „kawałków” 16×16 kafelków (szybkie rysowanie, odrzucanie poza kamerą).
## Kawałki bliskie graczowi powstają od razu, dalsze – stopniowo w kolejnych klatkach.

const CHUNK := 16
## Pas dekoracyjnego lasu i wzgórz wokół mapy (żeby na krawędziach nie było pustki).
const BORDER := 14
const WATER_Y := -0.13

const MAT_GROUND := preload("res://shaders/lowpoly_ground.gdshader")
const MAT_OBJECT := preload("res://shaders/lowpoly_object.gdshader")
const MAT_FOLIAGE := preload("res://shaders/lowpoly_foliage.gdshader")
const MAT_WATER := preload("res://shaders/lowpoly_water.gdshader")

# Paleta.
const GRASS_G := Color(0.32, 0.5, 0.22)
const GRASS_G2 := Color(0.4, 0.56, 0.24)
const GRASS_Y := Color(0.6, 0.54, 0.28)
const GRASS_R := Color(0.44, 0.31, 0.22)
const DIRT := Color(0.6, 0.46, 0.3)
const SAND := Color(0.86, 0.76, 0.52)
const ASH := Color(0.24, 0.22, 0.22)
const MORTAR := Color(0.3, 0.29, 0.28)
const TEMPLE := Color(0.88, 0.84, 0.76)
const RIVERBED := Color(0.42, 0.4, 0.3)
const STONE := Color(0.56, 0.53, 0.49)
const WOOD := Color(0.45, 0.3, 0.18)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const IRON := Color(0.34, 0.34, 0.37)
const GOLD := Color(0.95, 0.72, 0.25)

var mat_ground := ShaderMaterial.new()
var mat_object := ShaderMaterial.new()
var mat_foliage := ShaderMaterial.new()
var mat_water := ShaderMaterial.new()

var w := 0
var h := 0
var temple := Vector2(48, 46)
## Wysokości narożników kafelków: indeks (x + BORDER) + (y + BORDER) * cw
var _heights := PackedFloat32Array()
var _cw := 0
## Odległość kafelka wody od brzegu (0 = ląd).
var _water_dist := {}
var _noise := FastNoiseLite.new()
var _pending: Array[Vector2i] = []
var _built := {}
## Punkty ognia: [{pos: Vector3, kind: "wall" (pochodnia na wieży) / "brazier" (kosz na słupku) / "hearth" (palenisko)}]
var fire_spots: Array = []
## Kafelek gracza – kolejne kawałki budowane są od najbliższych.
var focus := Vector2i(48, 46)


func _init() -> void:
	mat_ground.shader = MAT_GROUND
	mat_object.shader = MAT_OBJECT
	mat_foliage.shader = MAT_FOLIAGE
	mat_water.shader = MAT_WATER
	_noise.seed = 1337
	_noise.frequency = 0.07


## Przygotowuje dane i buduje kawałki wokół punktu startowego.
func build(start: Vector2i) -> void:
	w = GameData.map_w
	h = GameData.map_h
	var tx := 0.0
	var ty := 0.0
	var n := 0
	for y in h:
		for x in w:
			if GameData.tile_at(x, y) == "x":
				tx += x + 0.5
				ty += y + 0.5
				n += 1
	if n > 0:
		temple = Vector2(tx / n, ty / n)
	_compute_water()
	_compute_heights()
	_find_fire_spots()
	var cx0 := floori(float(-BORDER) / CHUNK)
	var cy0 := cx0
	var cx1 := floori(float(w + BORDER - 1) / CHUNK)
	var cy1 := floori(float(h + BORDER - 1) / CHUNK)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			_pending.append(Vector2i(cx, cy))
	var sc := Vector2(start) / CHUNK
	_pending.sort_custom(func(a, b): return (Vector2(a) + Vector2(0.5, 0.5)).distance_to(sc) < (Vector2(b) + Vector2(0.5, 0.5)).distance_to(sc))
	# Najbliższe kawałki od razu (reszta w _process).
	for i in mini(9, _pending.size()):
		_build_chunk(_pending.pop_front())


## Dalsze kawałki budowane po kawałku w każdej klatce (limit czasu), żeby nie przycinać gry.
const FRAME_BUDGET_MS := 5
var _job: Dictionary = {}


func _process(_delta: float) -> void:
	if _pending.is_empty() and _job.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < FRAME_BUDGET_MS:
		if _job.is_empty():
			if _pending.is_empty():
				break
			var c: Vector2i = _pop_nearest()
			if _built.has(c):
				continue
			_job = _start_chunk(c)
		if _step_chunk(_job):
			_finish_chunk(_job)
			_job = {}



## Najbliższy graczowi kawałek z kolejki.
func _pop_nearest() -> Vector2i:
	var fc := Vector2(focus) / CHUNK - Vector2(0.5, 0.5)
	var best := 0
	var best_d := INF
	for i in _pending.size():
		var d := Vector2(_pending[i]).distance_squared_to(fc)
		if d < best_d:
			best_d = d
			best = i
	var c: Vector2i = _pending[best]
	_pending.remove_at(best)
	return c


func is_complete() -> bool:
	return _pending.is_empty()


# ============================================================================
# Dane pomocnicze
# ============================================================================

## Znak kafelka; poza mapą – „B” (dekoracyjny las/wzgórza).
func tile(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return "B"
	return GameData.tile_at(x, y)


func _hash(x: int, y: int, salt := 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791))


func _rand(x: int, y: int, salt := 0) -> float:
	return float(_hash(x, y, salt) % 10007) / 10007.0


static func _walkable(c: String) -> bool:
	return c in [".", ",", "s", "a", "f", "x"]


static func _flat(c: String) -> bool:
	return c in ["f", "x", "#", "D", "M", "K", "W", "P"]


## Odległość od mapy dla kafelków pasa brzegowego.
func _outside(x: int, y: int) -> int:
	var dx := maxi(maxi(-x, x - (w - 1)), 0)
	var dy := maxi(maxi(-y, y - (h - 1)), 0)
	return maxi(dx, dy)


func _compute_water() -> void:
	var frontier: Array[Vector2i] = []
	for y in h:
		for x in w:
			if tile(x, y) != "~":
				continue
			var shore := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if tile(x + d.x, y + d.y) != "~":
					shore = true
			if shore:
				_water_dist[Vector2i(x, y)] = 1
				frontier.append(Vector2i(x, y))
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		var dv: int = _water_dist[p]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if tile(q.x, q.y) == "~" and not _water_dist.has(q):
				_water_dist[q] = dv + 1
				frontier.append(q)


func _water_d(x: int, y: int) -> int:
	return _water_dist.get(Vector2i(x, y), 0)


func _compute_heights() -> void:
	_cw = w + BORDER * 2 + 1
	var ch := h + BORDER * 2 + 1
	_heights.resize(_cw * ch)
	for cy in range(-BORDER, h + BORDER + 1):
		for cx in range(-BORDER, w + BORDER + 1):
			_heights[(cx + BORDER) + (cy + BORDER) * _cw] = _corner_height(cx, cy)


## Wysokość narożnika (cx, cy) = lewy górny róg kafelka (cx, cy).
func _corner_height(cx: int, cy: int) -> float:
	var walk := false
	var flat := false
	var water := 0
	var outside := 0
	var wd := 0
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var c := tile(cx + d.x, cy + d.y)
		if _walkable(c):
			walk = true
		if _flat(c):
			flat = true
		if c == "~":
			water += 1
			wd = maxi(wd, _water_d(cx + d.x, cy + d.y))
		if c == "B":
			outside = maxi(outside, _outside(cx + d.x, cy + d.y))
	var nz := _noise.get_noise_2d(cx * 1.7, cy * 1.7)
	if flat:
		return 0.0
	if water == 4:
		return -0.35 - minf(wd, 3) * 0.15 + nz * 0.05
	if water > 0:
		return -0.24
	if outside > 0 and not walk:
		var hill := minf(outside, 12.0) * 0.32 + (nz * 0.5 + 0.5) * minf(outside, 5.0) * 0.35
		return hill
	if walk:
		return nz * 0.05
	return nz * 0.12 + 0.02


func height_at_corner(cx: int, cy: int) -> float:
	cx = clampi(cx, -BORDER, w + BORDER)
	cy = clampi(cy, -BORDER, h + BORDER)
	return _heights[(cx + BORDER) + (cy + BORDER) * _cw]


## Wysokość terenu w środku kafelka (do stawiania obiektów).
func ground_y(x: int, y: int) -> float:
	return (height_at_corner(x, y) + height_at_corner(x + 1, y) + height_at_corner(x, y + 1) + height_at_corner(x + 1, y + 1)) / 4.0


## Przesunięcie narożnika w poziomie (organiczne trójkąty poza miastem).
func _corner_jitter(cx: int, cy: int) -> Vector2:
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var c := tile(cx + d.x, cy + d.y)
		if _flat(c) or c == ",":
			return Vector2.ZERO
	return Vector2(_rand(cx, cy, 1) - 0.5, _rand(cx, cy, 2) - 0.5) * 0.34


func _corner_pos(cx: int, cy: int) -> Vector3:
	var j := _corner_jitter(cx, cy)
	return Vector3(cx + j.x, height_at_corner(cx, cy), cy + j.y)


## Kolor trawy zależny od strefy (zielona → złota → wypalona), z łagodnym przejściem.
func grass_color(x: float, y: float) -> Color:
	var d := maxf(absf(x - temple.x), absf(y - temple.y))
	var n := _noise.get_noise_2d(x * 0.8, y * 0.8) * 0.5 + 0.5
	var c := GRASS_G.lerp(GRASS_G2, n)
	c = c.lerp(GRASS_Y.lerp(GRASS_Y.darkened(0.12), n), smoothstep(21.0, 23.5, d))
	c = c.lerp(GRASS_R.lerp(GRASS_R.lightened(0.1), n), smoothstep(33.0, 35.5, d))
	return c


func _tile_color(x: int, y: int) -> Color:
	var c := tile(x, y)
	match c:
		".":
			return grass_color(x, y)
		",":
			return DIRT.lerp(DIRT.darkened(0.15), _rand(x, y, 3))
		"s":
			return SAND
		"a":
			return ASH.lerp(Color(0.3, 0.26, 0.25), _rand(x, y, 4))
		"f", "D", "M", "K", "W", "P":
			return MORTAR
		"x":
			return TEMPLE.darkened(0.25)
		"~":
			return RIVERBED
		"#":
			return MORTAR
		"T":
			return grass_color(x, y).darkened(0.25)
		"r":
			return grass_color(x, y).lerp(Color(0.4, 0.38, 0.35), 0.4)
		"B":
			var hh := ground_y(x, y)
			var fc := grass_color(clampf(x, 0, w - 1), clampf(y, 0, h - 1)).darkened(0.3)
			return fc.lerp(Color(0.42, 0.4, 0.38), smoothstep(2.2, 3.6, hh))
	return GRASS_G


# ============================================================================
# Budowa kawałka
# ============================================================================

func _build_chunk(c: Vector2i) -> void:
	if _built.has(c):
		return
	var job := _start_chunk(c)
	while not _step_chunk(job):
		pass
	_finish_chunk(job)


func _start_chunk(c: Vector2i) -> Dictionary:
	_built[c] = true
	return {
		"c": c, "row": c.y * CHUNK,
		"ground": MeshKit.new(c.x * 7919 + c.y * 104729),
		"objects": MeshKit.new(c.x * 31 + c.y * 17 + 5),
		"foliage": MeshKit.new(c.x * 13 + c.y * 71 + 9),
		"water": MeshKit.new(3),
	}


## Buduje jeden rząd kafelków kawałka; zwraca true, gdy kawałek gotowy.
func _step_chunk(job: Dictionary) -> bool:
	var c: Vector2i = job.c
	var ty: int = job.row
	if ty >= (c.y + 1) * CHUNK:
		return true
	job.row = ty + 1
	if ty < -BORDER or ty >= h + BORDER:
		return false
	for tx in range(c.x * CHUNK, (c.x + 1) * CHUNK):
		if tx < -BORDER or tx >= w + BORDER:
			continue
		_ground_tile(job.ground, tx, ty)
		_tile_details(job.objects, job.foliage, job.ground, tx, ty)
		if _near_water(tx, ty):
			_water_tile(job.water, tx, ty)
	return job.row >= (c.y + 1) * CHUNK


func _finish_chunk(job: Dictionary) -> void:
	_add_mesh(job.ground, mat_ground, false, "Ground")
	_add_mesh(job.objects, mat_object, true, "Objects")
	_add_mesh(job.foliage, mat_foliage, true, "Foliage")
	_add_mesh(job.water, mat_water, false, "Water")


func _add_mesh(kit: MeshKit, mat: Material, shadows: bool, label: String) -> void:
	if kit.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = kit.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ground_tile(k: MeshKit, x: int, y: int) -> void:
	var p00 := _corner_pos(x, y)
	var p10 := _corner_pos(x + 1, y)
	var p01 := _corner_pos(x, y + 1)
	var p11 := _corner_pos(x + 1, y + 1)
	var c := tile(x, y)
	var own := _tile_color(x, y)
	var crisp := c in ["f", "x", ",", "#", "D", "M", "K", "W", "P"]
	k.jitter = 0.035 if crisp else 0.045
	var ember := c == "a"
	# Kolor trójkąta: mieszanka z sąsiadami (miękkie przejścia) albo własny (bruk, droga).
	var col_a := own
	var col_b := own
	if not crisp:
		col_a = own.lerp(_blend_neighbors(x, y, -1), 0.35)
		col_b = own.lerp(_blend_neighbors(x, y, 1), 0.35)
	var flip := _hash(x, y, 7) % 2 == 0
	var tris: Array = [[p00, p10, p11, col_a], [p00, p11, p01, col_b]] if flip else [[p00, p10, p01, col_a], [p10, p11, p01, col_b]]
	for t in tris:
		k.tri(t[0], t[1], t[2], t[3], Vector3.UP)
	k.jitter = 0.0
	if ember and _rand(x, y, 11) < 0.3:
		_ember_crack(k, x, y)


## Żarzące się szczeliny w popiele: cienka łamana linia tuż nad ziemią.
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


## Średni kolor sąsiadów (lewy/górny albo prawy/dolny).
func _blend_neighbors(x: int, y: int, side: int) -> Color:
	var a := _tile_color(x + side, y)
	var b := _tile_color(x, y + side)
	return a.lerp(b, 0.5)


func _near_water(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if tile(x + dx, y + dy) == "~":
				return true
	return false


## Woda: siatka 2×2 na kafelek, kolor R = odległość od brzegu (piana, głębia).
func _water_tile(k: MeshKit, x: int, y: int) -> void:
	var pts := {}
	for sy in 3:
		for sx in 3:
			var fx := x + sx * 0.5
			var fy := y + sy * 0.5
			pts[Vector2i(sx, sy)] = Vector3(fx, WATER_Y, fy)
	for sy in 2:
		for sx in 2:
			var a: Vector3 = pts[Vector2i(sx, sy)]
			var b: Vector3 = pts[Vector2i(sx + 1, sy)]
			var c: Vector3 = pts[Vector2i(sx + 1, sy + 1)]
			var d: Vector3 = pts[Vector2i(sx, sy + 1)]
			for t in [[a, b, c], [a, c, d]]:
				var ctr: Vector3 = (t[0] + t[1] + t[2]) / 3.0
				var wd := _shore_at(ctr.x, ctr.z)
				k.tri(t[0], t[1], t[2], Color(wd, 0, 0), Vector3.UP)


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


# ============================================================================
# Obiekty na kafelkach
# ============================================================================

func _tile_details(obj: MeshKit, fol: MeshKit, gnd: MeshKit, x: int, y: int) -> void:
	var c := tile(x, y)
	var gy := ground_y(x, y)
	var center := Vector3(x + 0.5, gy, y + 0.5)
	match c:
		"T":
			_tree(fol, center + _offset(x, y, 0.18), x, y)
		"r":
			_rock(obj, center, x, y)
		"#":
			_wall(obj, x, y)
		"f":
			_cobbles(gnd, x, y)
		"x":
			_temple_slab(gnd, x, y)
		",":
			_road_pebbles(gnd, x, y)
		"D":
			_cobbles(gnd, x, y)
			_chest(obj, center, x, y)
		"M":
			_cobbles(gnd, x, y)
			_stall(obj, fol, center, x, y)
		"K":
			_cobbles(gnd, x, y)
			_anvil(obj, center)
		"W":
			_cobbles(gnd, x, y)
			_workbench(obj, center)
		"P":
			_cobbles(gnd, x, y)
			_furnace(obj, center)
		".":
			_grass_decor(fol, obj, center, x, y)
		"a":
			if _rand(x, y, 21) < 0.06:
				_rock(obj, center + _offset(x, y, 0.3), x, y, 0.35)
		"s":
			if _rand(x, y, 22) < 0.05:
				obj.reset()
				obj.jitter = 0.05
				obj.blob(center + _offset(x, y, 0.3), Vector3(0.12, 0.07, 0.1), Color(0.75, 0.7, 0.6), 2, 5)
				obj.jitter = 0.0
		"B":
			_border_decor(fol, obj, center, x, y)
	if x == int(temple.x) and y == int(temple.y):
		_rune_circle(gnd, Vector3(temple.x, 0.02, temple.y))


func _offset(x: int, y: int, amount: float) -> Vector3:
	return Vector3(_rand(x, y, 5) - 0.5, 0, _rand(x, y, 6) - 0.5) * amount * 2.0


## Drzewo zależne od strefy: zielone liściaste/iglaste, jesienne, wypalone.
func _tree(k: MeshKit, base: Vector3, x: int, y: int, scale_mul := 1.0) -> void:
	var r := _rand(x, y, 8)
	var d := maxf(absf(x - temple.x), absf(y - temple.y))
	var ash_near := tile(x - 1, y) == "a" or tile(x + 1, y) == "a" or tile(x, y - 1) == "a" or tile(x, y + 1) == "a"
	var s := (0.85 + _rand(x, y, 9) * 0.45) * scale_mul
	var yaw := _rand(x, y, 10) * TAU
	k.xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), base)
	k.sway_base = base.y
	k.sway_height = 2.4 * s
	k.jitter = 0.04
	k.glow = 0.0
	if ash_near or (d > 36 and r < 0.5):
		_dead_tree(k, ash_near)
	elif r < 0.45:
		_pine(k, d)
	else:
		_oak(k, d, r)
	k.reset()
	k.jitter = 0.0


func _leaf_color(d: float, v: float) -> Color:
	var c := Color(0.25, 0.5, 0.2).lerp(Color(0.36, 0.6, 0.22), v)
	c = c.lerp(Color(0.85, 0.55, 0.15).lerp(Color(0.8, 0.35, 0.12), v), smoothstep(21.0, 24.0, d))
	c = c.lerp(Color(0.45, 0.3, 0.18), smoothstep(33.0, 36.0, d))
	return c


func _pine(k: MeshKit, d: float) -> void:
	k.cyl(Vector3.ZERO, 0.08, 0.06, 0.5, 5, WOOD_DARK)
	var c := Color(0.16, 0.36, 0.2).lerp(Color(0.3, 0.3, 0.16), smoothstep(30.0, 38.0, d))
	k.cone(Vector3(0, 0.35, 0), 0.62, 0.9, 7, c)
	k.cone(Vector3(0, 0.8, 0), 0.5, 0.85, 7, c.lightened(0.06), 0.4)
	k.cone(Vector3(0, 1.25, 0), 0.36, 0.8, 7, c.lightened(0.12), 0.9)


func _oak(k: MeshKit, d: float, v: float) -> void:
	k.cyl(Vector3.ZERO, 0.11, 0.07, 0.8, 6, WOOD)
	var c := _leaf_color(d, v)
	k.blob(Vector3(0, 1.15, 0), Vector3(0.62, 0.5, 0.62), c, 3, 7, 0.18, c.lightened(0.1))
	k.blob(Vector3(0.28, 1.45, 0.1), Vector3(0.38, 0.33, 0.38), c.lightened(0.08), 3, 6, 0.15)
	k.blob(Vector3(-0.25, 1.35, -0.15), Vector3(0.36, 0.3, 0.36), c.darkened(0.05), 3, 6, 0.15)


func _dead_tree(k: MeshKit, embers: bool) -> void:
	var bark := Color(0.16, 0.13, 0.12)
	k.cyl(Vector3.ZERO, 0.12, 0.05, 1.3, 5, bark)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		var dir := Vector3(cos(a), 0.9, sin(a)).normalized()
		var p0 := Vector3(0, 0.6 + i * 0.22, 0)
		var p1 := p0 + dir * 0.55
		var side := Vector3(-dir.z, 0, dir.x) * 0.04
		k.quad(p0 - side, p0 + side, p1 + side * 0.3, p1 - side * 0.3, bark)
		k.quad(p0 + side, p0 - side, p1 - side * 0.3, p1 + side * 0.3, bark)
		if embers:
			k.glow = 1.0
			k.blob(p1, Vector3(0.05, 0.05, 0.05), Color(1, 0.4, 0.1), 2, 4, 0.0)
			k.glow = 0.0


func _rock(k: MeshKit, base: Vector3, x: int, y: int, size := 1.0) -> void:
	var ash := tile(x - 1, y) == "a" or tile(x + 1, y) == "a" or tile(x, y + 1) == "a" or tile(x, y) == "a"
	var col := Color(0.5, 0.48, 0.46) if not ash else Color(0.22, 0.2, 0.21)
	k.reset()
	k.jitter = 0.05
	var s := (0.8 + _rand(x, y, 12) * 0.4) * size
	k.place(base, _rand(x, y, 13) * TAU, s)
	k.blob(Vector3(0, 0.22, 0), Vector3(0.46, 0.4, 0.4), col, 3, 6, 0.22, col.lightened(0.12))
	k.blob(Vector3(0.3, 0.12, 0.22), Vector3(0.22, 0.18, 0.2), col.darkened(0.08), 2, 5, 0.2)
	if ash:
		k.glow = 1.0
		k.blob(Vector3(-0.1, 0.42, 0.2), Vector3(0.05, 0.04, 0.05), Color(1, 0.35, 0.08), 2, 4, 0.0)
	k.reset()
	k.jitter = 0.0


func _grass_decor(fol: MeshKit, obj: MeshKit, center: Vector3, x: int, y: int) -> void:
	var r := _rand(x, y, 14)
	var d := maxf(absf(x - temple.x), absf(y - temple.y))
	var gc := grass_color(x, y)
	if r < 0.3:
		fol.reset()
		fol.sway_base = center.y
		fol.sway_height = 0.35
		for i in 4:
			var p := center + Vector3(_rand(x, y, 30 + i) - 0.5, 0, _rand(x, y, 40 + i) - 0.5) * 0.8
			var a := _rand(x, y, 50 + i) * TAU
			var dir := Vector3(cos(a), 0, sin(a)) * 0.06
			var hgt := 0.16 + _rand(x, y, 60 + i) * 0.16
			fol.blade(p - dir, p + dir, p + Vector3(dir.z, hgt, -dir.x) * 1.0 + Vector3(0, hgt * 0.5, 0), gc.lightened(0.08))
	if d < 21.0 and r > 0.93:
		# Kwiaty.
		var fc: Color = [Color(0.95, 0.9, 0.35), Color(0.9, 0.4, 0.5), Color(0.6, 0.55, 0.95), Color(0.98, 0.98, 0.95)][_hash(x, y, 15) % 4]
		obj.reset()
		for i in 3:
			var p := center + Vector3(_rand(x, y, 70 + i) - 0.5, 0, _rand(x, y, 80 + i) - 0.5) * 0.7
			obj.cyl(p, 0.012, 0.012, 0.16, 3, Color(0.3, 0.55, 0.2), false)
			obj.blob(p + Vector3(0, 0.18, 0), Vector3(0.05, 0.035, 0.05), fc, 2, 5, 0.0)
	elif r > 0.975:
		obj.reset()
		obj.jitter = 0.04
		obj.blob(center + _offset(x, y, 0.3), Vector3(0.14, 0.09, 0.12), Color(0.52, 0.5, 0.47), 2, 5, 0.25)
		obj.jitter = 0.0
	elif d >= 21.0 and d < 33.0 and r > 0.9:
		# Suche krzaki w żółtej strefie.
		fol.reset()
		fol.sway_base = center.y
		fol.sway_height = 0.5
		fol.blob(center + Vector3(0, 0.16, 0) + _offset(x, y, 0.25), Vector3(0.24, 0.18, 0.24), Color(0.6, 0.45, 0.18), 2, 6, 0.3)
	elif d >= 33.0 and r > 0.94:
		# Kości w czerwonej strefie.
		obj.reset()
		obj.place(center + _offset(x, y, 0.3), _rand(x, y, 16) * TAU)
		obj.box(Vector3(0, 0, 0), Vector3(0.36, 0.04, 0.05), Color(0.85, 0.82, 0.72))
		obj.blob(Vector3(0.2, 0.05, 0), Vector3(0.06, 0.05, 0.06), Color(0.85, 0.82, 0.72), 2, 5, 0.0)
		obj.blob(Vector3(-0.2, 0.05, 0), Vector3(0.06, 0.05, 0.06), Color(0.85, 0.82, 0.72), 2, 5, 0.0)
		obj.reset()


func _border_decor(fol: MeshKit, obj: MeshKit, center: Vector3, x: int, y: int) -> void:
	var r := _rand(x, y, 17)
	if center.y > 3.0:
		if r < 0.35:
			_rock(obj, center, x, y, 1.6)
		return
	if r < 0.62:
		_tree(fol, center + _offset(x, y, 0.3), x, y, 1.25)
	elif r < 0.72:
		_rock(obj, center, x, y, 1.3)


## Bruk: 2×2 kamienie na kafelek, lekko wypukłe.
func _cobbles(k: MeshKit, x: int, y: int) -> void:
	k.reset()
	k.jitter = 0.05
	for i in 4:
		var ox := 0.25 + (i % 2) * 0.5
		var oz := 0.25 + (i / 2) * 0.5
		var v := _rand(x, y, 90 + i)
		var col := Color(0.52, 0.5, 0.47).lerp(Color(0.44, 0.4, 0.37), v).lerp(Color(0.55, 0.47, 0.38), _rand(x, y, 99 + i) * 0.5)
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
			var p0: Vector3 = c + Vector3(cos(a0), 0.06, sin(a0)) * rr[0]
			var p1: Vector3 = c + Vector3(cos(a1), 0.06, sin(a1)) * rr[0]
			var q0: Vector3 = c + Vector3(cos(a0), 0.06, sin(a0)) * rr[1]
			var q1: Vector3 = c + Vector3(cos(a1), 0.06, sin(a1)) * rr[1]
			p0.y = 0.056
			p1.y = 0.056
			q0.y = 0.056
			q1.y = 0.056
			k.quad(p0, p1, q1, q0, GOLD, Vector3.UP)
	for i in 6:
		var a := TAU * i / 6.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 1.05
		p.y = 0.057
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


# --- Mury -----------------------------------------------------------------------

func _is_wall(x: int, y: int) -> bool:
	return tile(x, y) == "#"


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
	var cx := x + 0.5
	var cz := y + 0.5
	k.reset()
	k.jitter = 0.03
	if corner or gate_side:
		_tower(k, Vector3(cx, 0, cz), x, y)
		k.jitter = 0.0
		return
	var sx := 1.0 if horiz else 0.78
	var sz := 1.0 if vert else 0.78
	if not horiz and not vert:
		sx = 0.9
		sz = 0.9
	# Trzy warstwy kamieni z przesunięciami.
	var hgt := 0.0
	for i in 3:
		var lh := 0.42
		var col := STONE.lerp(STONE.darkened(0.18), _rand(x, y, 100 + i))
		var inset := 0.02 * (i % 2)
		k.box(Vector3(cx, hgt, cz), Vector3(sx - inset, lh, sz - inset), col)
		hgt += lh
	# Blanki.
	var merlon := STONE.lightened(0.05)
	if horiz:
		for i in 2:
			k.box(Vector3(x + 0.25 + i * 0.5, hgt, cz - sz * 0.35), Vector3(0.3, 0.26, 0.12), merlon)
			k.box(Vector3(x + 0.25 + i * 0.5, hgt, cz + sz * 0.35), Vector3(0.3, 0.26, 0.12), merlon)
	else:
		for i in 2:
			k.box(Vector3(cx - sx * 0.35, hgt, y + 0.25 + i * 0.5), Vector3(0.12, 0.26, 0.3), merlon)
			k.box(Vector3(cx + sx * 0.35, hgt, y + 0.25 + i * 0.5), Vector3(0.12, 0.26, 0.3), merlon)
	# Chorągiew na zewnętrznej ścianie co kilka kafelków.
	if horiz and x % 6 == 0:
		var outer := -1.0 if not _walkable(tile(x, y - 1)) and tile(x, y - 1) != "f" else 1.0
		if tile(x, y + 1) in [".", ",", "T", "r", "s"]:
			outer = 1.0
		elif tile(x, y - 1) in [".", ",", "T", "r", "s"]:
			outer = -1.0
		var z := cz + outer * (sz / 2.0 + 0.012)
		var red := Color(0.62, 0.12, 0.1)
		k.jitter = 0.0
		k.quad(Vector3(cx - 0.2, 1.2, z), Vector3(cx + 0.2, 1.2, z), Vector3(cx + 0.2, 0.55, z), Vector3(cx - 0.2, 0.55, z), red, Vector3(0, 0, outer))
		k.tri(Vector3(cx - 0.2, 0.55, z), Vector3(cx + 0.2, 0.55, z), Vector3(cx, 0.4, z), red, Vector3(0, 0, outer))
		k.glow = 0.3
		k.quad(Vector3(cx - 0.07, 0.95, z + outer * 0.003), Vector3(cx + 0.07, 0.95, z + outer * 0.003), Vector3(cx + 0.07, 0.8, z + outer * 0.003), Vector3(cx - 0.07, 0.8, z + outer * 0.003), GOLD, Vector3(0, 0, outer))
		k.glow = 0.0
	k.jitter = 0.0


func _tower(k: MeshKit, base: Vector3, x: int, y: int) -> void:
	var col := STONE.lightened(0.02)
	k.cyl(base, 0.64, 0.6, 1.9, 8, col, true, STONE.darkened(0.1), 0.2)
	# Pierścień blanków.
	for i in 8:
		if i % 2 == 0:
			var a := TAU * i / 8.0 + 0.2
			k.box(base + Vector3(cos(a) * 0.58, 1.9, sin(a) * 0.58), Vector3(0.2, 0.24, 0.2), col.lightened(0.05))
	# Dach.
	var roof := Color(0.55, 0.2, 0.14).lerp(Color(0.45, 0.16, 0.12), _rand(x, y, 110))
	k.cone(base + Vector3(0, 2.1, 0), 0.52, 0.95, 8, roof, 0.2)
	k.glow = 0.0


# --- Stacje i miasto --------------------------------------------------------------

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


func _stall(k: MeshKit, fol: MeshKit, c: Vector3, x: int, y: int) -> void:
	k.reset()
	var cloth: Color = [Color(0.72, 0.16, 0.12), Color(0.2, 0.36, 0.62), Color(0.25, 0.5, 0.25), Color(0.8, 0.55, 0.15)][x % 4]
	var cream := Color(0.92, 0.86, 0.72)
	# Lada.
	k.box(c + Vector3(0, 0, 0.18), Vector3(0.9, 0.5, 0.4), WOOD)
	k.box(c + Vector3(0, 0.5, 0.18), Vector3(0.96, 0.05, 0.46), WOOD_DARK)
	# Słupki.
	for sx in [-0.44, 0.44]:
		for sz in [-0.38, 0.4]:
			k.box(c + Vector3(sx, 0, sz), Vector3(0.06, 1.35 if sz < 0 else 1.1, 0.06), WOOD_DARK)
	# Pasiasty daszek (spadzisty ku przodowi).
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
		# Falbanka.
		k.quad(d, cc, cc + Vector3(0, -0.12, 0), d + Vector3(0, -0.12, 0), col, Vector3(0, 0, 1))
	# Towary: owoce, dzbany.
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
	# Młot.
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


# --- Pochodnie ---------------------------------------------------------------------

func _find_fire_spots() -> void:
	for y in h:
		for x in w:
			var ch := tile(x, y)
			if ch == "#":
				# Wieża przy bramie.
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var g: Vector2i = Vector2i(x, y) + d
					if _walkable(tile(g.x, g.y)) and ((d.y == 0 and _is_wall(x, y - 1) == false and _is_wall(x, y + 1) == false) or (d.x == 0 and not _is_wall(x - 1, y) and not _is_wall(x + 1, y))):
						fire_spots.append({"pos": Vector3(x + 0.5 + d.x * 0.7, 1.35, y + 0.5 + d.y * 0.7), "kind": "wall"})
						break
			elif ch == "P":
				fire_spots.append({"pos": Vector3(x + 0.5, 0.22, y + 0.9), "kind": "hearth"})
			elif ch == "x" and tile(x - 1, y) != "x" and tile(x, y - 1) != "x":
				fire_spots.append({"pos": Vector3(x - 0.5, 0.0, y - 0.5), "kind": "brazier"})
			elif ch == "x" and tile(x + 1, y) != "x" and tile(x, y - 1) != "x":
				fire_spots.append({"pos": Vector3(x + 1.5, 0.0, y - 0.5), "kind": "brazier"})
			elif ch == "x" and tile(x - 1, y) != "x" and tile(x, y + 1) != "x":
				fire_spots.append({"pos": Vector3(x - 0.5, 0.0, y + 1.5), "kind": "brazier"})
			elif ch == "x" and tile(x + 1, y) != "x" and tile(x, y + 1) != "x":
				fire_spots.append({"pos": Vector3(x + 1.5, 0.0, y + 1.5), "kind": "brazier"})
