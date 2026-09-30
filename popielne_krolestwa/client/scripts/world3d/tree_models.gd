class_name TreeModels
extends RefCounted
## Realistyczne drzewa: pnie i gałęzie jako rury z teksturą kory, korony z kart liści
## (tekstury z przezroczystością), igły świerków, liście palm, zwisające gałązki wierzb.
## Siatki są generowane raz (pamięć podręczna) i rysowane jako MultiMesh – setki drzew tanio.
##
## Rodzaje: oak, birch, pine, palm, willow, dead, cactus. `variant` – kilka wariantów kształtu.
## far = true – uproszczona wersja do dalekiego świata (mniej kart, maska załadowanych kawałków).

const TEX_BARK := preload("res://assets/textures/bark.png")
const TEX_BARK_N := preload("res://assets/textures/bark_n.png")
const TEX_LEAVES := preload("res://assets/textures/leaves.png")
const TEX_PINE := preload("res://assets/textures/pine_branch.png")
const TEX_PALM := preload("res://assets/textures/palm_frond.png")
const TEX_GRASS := preload("res://assets/textures/grass.png")
const SH_BARK := preload("res://shaders/nature_bark.gdshader")
const SH_LEAVES := preload("res://shaders/nature_leaves.gdshader")
const SH_GRASS := preload("res://shaders/grass.gdshader")

const VARIANTS := 3
const BARK := Color(0.36, 0.28, 0.2, 1.0)

static var _cache := {}
static var _mats := {}


## Materiał (wspólny dla wszystkich drzew danego rodzaju): bark, leaves, pine, palm, grass.
static func material(kind: String, far := false) -> ShaderMaterial:
	var key := kind + ("_far" if far else "")
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	match kind:
		"bark":
			m.shader = SH_BARK
			m.set_shader_parameter("bark_tex", TEX_BARK)
			m.set_shader_parameter("bark_normal", TEX_BARK_N)
		"grass":
			m.shader = SH_GRASS
			m.set_shader_parameter("grass_tex", TEX_GRASS)
		_:
			m.shader = SH_LEAVES
			m.set_shader_parameter("leaf_tex", {"leaves": TEX_LEAVES, "pine": TEX_PINE, "palm": TEX_PALM}[kind])
			if kind == "pine":
				m.set_shader_parameter("flutter", 0.3)
			if kind == "palm":
				m.set_shader_parameter("alpha_cut", 0.4)
	if far:
		m.set_shader_parameter("use_mask", true)
	_mats[key] = m
	return m


## Materiały dalekiego świata (FarWorld ustawia na nich maskę załadowanych kawałków).
static func far_materials() -> Array:
	var out := []
	for k in ["bark", "leaves", "pine", "palm"]:
		out.append(material(k, true))
	return out


static func mesh(kind: String, variant: int, far := false) -> ArrayMesh:
	var key := "%s_%d_%s" % [kind, variant, far]
	if _cache.has(key):
		return _cache[key]
	var b := _Builder.new()
	b.rng.seed = hash(kind) + variant * 977 + 13
	b.far = far
	match kind:
		"oak":
			_oak(b)
		"autumn":
			_oak(b)
		"birch":
			_birch(b)
		"pine":
			_pine(b, 0.0)
		"pine_snow":
			_pine(b, 0.7)
		"palm":
			_palm(b)
		"willow":
			_willow(b)
		"dead":
			_dead(b, Color(0.2, 0.17, 0.15, 1.0))
		"cactus":
			_cactus(b)
		_:
			_oak(b)
	var leaf_kind := "pine" if kind.begins_with("pine") else ("palm" if kind == "palm" else "leaves")
	var m := b.commit(material("bark", far), material(leaf_kind, far))
	_cache[key] = m
	return m


## Kępa trawy: trzy skrzyżowane karty.
static func grass_mesh() -> ArrayMesh:
	if _cache.has("grass"):
		return _cache["grass"]
	var b := _Builder.new()
	for i in 3:
		var a := PI * i / 3.0 + 0.3
		var r := Vector3(cos(a), 0, sin(a)) * 0.38
		var up := Vector3(0, 0.5, 0)
		b.leaf_quad(-r, r, r + up, -r + up, [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP], Color(1, 1, 1, 0), Rect2(0, 0, 1, 1))
	var m := ArrayMesh.new()
	b.commit_leaves_into(m, material("grass"))
	_cache["grass"] = m
	return m


# ============================================================================
# Kształty drzew
# ============================================================================

static func _crown(b: _Builder, center: Vector3, radius: Vector3, clusters: int, cards: int, size: float, col: Color) -> void:
	var rng := b.rng
	var pts: Array[Vector3] = [center + Vector3(0, radius.y * 0.6, 0)]
	for i in clusters - 1:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.9), rng.randf_range(-1, 1)).normalized()
		pts.append(center + Vector3(d.x * radius.x, d.y * radius.y, d.z * radius.z) * rng.randf_range(0.55, 1.0))
	for p in pts:
		for j in cards:
			var out := (p - center)
			out = out.normalized() if out.length() > 0.01 else Vector3.UP
			var n := (out + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.5, 0.9), rng.randf_range(-0.9, 0.9))).normalized()
			var s := size * rng.randf_range(0.8, 1.15)
			var shade := clampf(0.92 + (p.y - center.y) / maxf(radius.y, 0.1) * 0.15 + out.dot(Vector3(0.3, 0, 0.3)) * 0.1, 0.75, 1.25)
			b.leaf_card(p, n, s, center, Color(shade, shade, shade, col.a))


static func _oak(b: _Builder) -> void:
	var rng := b.rng
	var h := rng.randf_range(2.1, 2.7)
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var top := Vector3(0, h * 0.72, 0) + lean
	b.tube([Vector3.ZERO, Vector3(0, h * 0.4, 0) + lean * 0.5, top], [0.17, 0.12, 0.07], 5 if b.far else 8, BARK)
	if not b.far:
		for i in 4:
			var a := TAU * i / 4.0 + rng.randf() * 0.8
			var start := Vector3(0, h * rng.randf_range(0.42, 0.6), 0) + lean * 0.6
			var end := start + Vector3(cos(a) * 0.75, rng.randf_range(0.35, 0.6), sin(a) * 0.75)
			b.tube([start, end], [0.06, 0.025], 5, BARK)
	var c := Vector3(0, h * 0.95, 0) + lean
	if b.far:
		_crown(b, c, Vector3(1.0, 0.65, 1.0), 4, 1, 2.1, Color(1, 1, 1, 0))
	else:
		_crown(b, c, Vector3(1.05, 0.72, 1.05), 11, 3, 1.05, Color(1, 1, 1, 0))


static func _birch(b: _Builder) -> void:
	var rng := b.rng
	var h := rng.randf_range(2.8, 3.4)
	var white := Color(0.88, 0.86, 0.82, 0.3)
	b.tube([Vector3.ZERO, Vector3(0.05, h * 0.5, 0), Vector3(0.02, h * 0.95, 0.04)], [0.1, 0.07, 0.03], 4 if b.far else 7, white)
	var clusters := 3 if b.far else 7
	for i in clusters:
		var t := float(i) / maxf(clusters - 1, 1)
		var p := Vector3(rng.randf_range(-0.35, 0.35), h * (0.5 + t * 0.5), rng.randf_range(-0.35, 0.35))
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		b.leaf_card(p, n, (1.5 if b.far else 1.05) * (1.1 - t * 0.3), Vector3(0, h * 0.75, 0), Color(1.05, 1.1, 0.95, 0))
		if not b.far:
			b.leaf_card(p + Vector3(0, 0.1, 0), n.cross(Vector3.UP).normalized() + Vector3(0, 0.4, 0), 0.9, Vector3(0, h * 0.75, 0), Color(1.1, 1.15, 1.0, 0))


static func _pine(b: _Builder, snow: float) -> void:
	var rng := b.rng
	var h := rng.randf_range(3.4, 4.3)
	b.tube([Vector3.ZERO, Vector3(0, h * 0.5, 0), Vector3(0, h, 0)], [0.15, 0.09, 0.02], 4 if b.far else 7, BARK * Color(0.8, 0.75, 0.72, 1.0))
	var levels := 4 if b.far else 8
	var per := 4 if b.far else 6
	for i in levels:
		var t := float(i) / (levels - 1)
		var y := 0.75 + (h - 1.05) * t
		var ln := lerpf(1.45, 0.35, t) * rng.randf_range(0.9, 1.1)
		var off := rng.randf() * TAU
		var shade := lerpf(0.72, 1.05, t)
		for j in per:
			var a := off + TAU * j / per + rng.randf_range(-0.2, 0.2)
			var d := Vector3(cos(a), -lerpf(0.35, 0.15, t), sin(a)).normalized()
			var base := Vector3(0, y, 0) + d * 0.04
			var tip := base + d * ln
			var side := d.cross(Vector3.UP).normalized() * ln * 0.36
			side = side.rotated(d, rng.randf_range(-0.35, 0.35))
			var n := (Vector3.UP * 0.5 + d * 0.6).normalized()
			b.leaf_quad(base - side * 0.35, base + side * 0.35, tip + side, tip - side, [n, n, n, n], Color(shade, shade, shade, snow), Rect2(0, 0, 1, 1), true)
	# Wierzchołek: dwie skrzyżowane pionowe karty.
	for k in 2:
		var s := Vector3(cos(k * PI / 2), 0, sin(k * PI / 2)) * 0.22
		var yb := h - 0.75
		var n2 := Vector3.UP
		b.leaf_quad(Vector3(0, yb, 0) - s, Vector3(0, yb, 0) + s, Vector3(0, h + 0.15, 0) + s * 0.2, Vector3(0, h + 0.15, 0) - s * 0.2, [n2, n2, n2, n2], Color(1.05, 1.05, 1.05, snow), Rect2(0, 0, 1, 1), true)


static func _palm(b: _Builder) -> void:
	var rng := b.rng
	var h := rng.randf_range(2.8, 3.5)
	var bend := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var pts: Array = []
	var radii: Array = []
	var segs := 4 if b.far else 7
	for i in segs + 1:
		var t := float(i) / segs
		pts.append(Vector3(0, h * t, 0) + bend * t * t)
		radii.append(lerpf(0.14, 0.09, t))
	b.tube(pts, radii, 5 if b.far else 7, Color(0.5, 0.42, 0.3, 0.8))
	var top: Vector3 = pts[pts.size() - 1]
	var fronds := 6 if b.far else 9
	for i in fronds:
		var a := TAU * i / fronds + rng.randf_range(-0.15, 0.15)
		var d := Vector3(cos(a), 0, sin(a))
		var side := d.cross(Vector3.UP).normalized() * 0.32
		var mid := top + d * 0.8 + Vector3(0, 0.25, 0)
		var tip := top + d * 1.6 + Vector3(0, -0.35, 0)
		var n := (Vector3.UP + d * 0.3).normalized()
		b.leaf_quad(top - side * 0.3, top + side * 0.3, mid + side, mid - side, [n, n, n, n], Color(1, 1, 1, 0), Rect2(0, 0.5, 1, 0.5), true)
		b.leaf_quad(mid - side, mid + side, tip + side * 0.4, tip - side * 0.4, [n, n, n, n], Color(1, 1, 1, 0), Rect2(0, 0, 1, 0.5), true)


static func _willow(b: _Builder) -> void:
	var rng := b.rng
	var h := rng.randf_range(2.0, 2.4)
	b.tube([Vector3.ZERO, Vector3(0.1, h * 0.5, 0), Vector3(0, h, 0.05)], [0.2, 0.15, 0.09], 5 if b.far else 8, BARK * Color(0.75, 0.72, 0.6, 1.0))
	var c := Vector3(0, h + 0.3, 0)
	_crown(b, c, Vector3(1.2, 0.5, 1.2), 3 if b.far else 9, 1 if b.far else 3, 1.5 if b.far else 1.05, Color(1, 1, 1, 0))
	var strands := 6 if b.far else 14
	for i in strands:
		var a := TAU * i / strands + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		var r := rng.randf_range(0.9, 1.3)
		var top := c + d * r + Vector3(0, -0.1, 0)
		var bottom := top + Vector3(0, -rng.randf_range(1.1, 1.6), 0) + d * 0.15
		var side := d.cross(Vector3.UP).normalized() * 0.35
		b.leaf_quad(top - side, top + side, bottom + side * 0.6, bottom - side * 0.6, [d, d, d, d], Color(0.85, 0.95, 0.75, 0), Rect2(0.3, 0.1, 0.4, 0.8), true)


static func _dead(b: _Builder, col: Color) -> void:
	var rng := b.rng
	var h := rng.randf_range(1.9, 2.6)
	b.tube([Vector3.ZERO, Vector3(0.05, h * 0.55, 0), Vector3(-0.05, h, 0.05)], [0.15, 0.1, 0.03], 4 if b.far else 7, col)
	var count := 2 if b.far else 5
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.7
		var start := Vector3(0, h * rng.randf_range(0.4, 0.8), 0)
		var mid := start + Vector3(cos(a) * 0.5, rng.randf_range(0.2, 0.45), sin(a) * 0.5)
		var end := mid + Vector3(cos(a + 0.5) * 0.35, rng.randf_range(0.15, 0.35), sin(a + 0.5) * 0.35)
		b.tube([start, mid, end], [0.06, 0.035, 0.01], 4, col)


static func _cactus(b: _Builder) -> void:
	var rng := b.rng
	var green := Color(0.34, 0.52, 0.26, 0.2)
	var h := rng.randf_range(1.2, 1.7)
	b.tube([Vector3.ZERO, Vector3(0, h * 0.5, 0), Vector3(0, h, 0)], [0.2, 0.19, 0.12], 8, green)
	for s in [-1, 1]:
		var y := rng.randf_range(0.4, 0.8)
		var p0 := Vector3(0, y, 0)
		var p1 := Vector3(s * 0.38, y + 0.05, 0)
		var p2 := Vector3(s * 0.42, y + rng.randf_range(0.4, 0.6), 0)
		b.tube([p0, p1, p2], [0.1, 0.1, 0.07], 6, green)


# ============================================================================
# Budowniczy siatki drzewa (dwie powierzchnie: kora i liście)
# ============================================================================

class _Builder:
	var rng := RandomNumberGenerator.new()
	var far := false
	var bv := PackedVector3Array()
	var bn := PackedVector3Array()
	var bu := PackedVector2Array()
	var bc := PackedColorArray()
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lu := PackedVector2Array()
	var lc := PackedColorArray()

	## Rura wzdłuż łamanej (pień, gałąź) z gładkimi normalnymi i UV kory.
	func tube(pts: Array, radii: Array, sides: int, col: Color) -> void:
		var rings: Array = []
		var vacc := 0.0
		for i in pts.size():
			var p: Vector3 = pts[i]
			var dir: Vector3
			if i == 0:
				dir = (pts[1] - pts[0]).normalized()
			elif i == pts.size() - 1:
				dir = (pts[i] - pts[i - 1]).normalized()
			else:
				dir = (pts[i + 1] - pts[i - 1]).normalized()
			var ref := Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.FORWARD
			var u := dir.cross(ref).normalized()
			var v := dir.cross(u).normalized()
			if i > 0:
				vacc += (pts[i] - pts[i - 1]).length()
			var ring: Array = []
			for j in sides + 1:
				var a := TAU * j / sides
				var off := (u * cos(a) + v * sin(a))
				ring.append([p + off * float(radii[i]), off, Vector2(float(j) / sides * 2.0, vacc * 0.7)])
			rings.append(ring)
		for i in rings.size() - 1:
			for j in sides:
				var a: Array = rings[i][j]
				var b: Array = rings[i][j + 1]
				var c: Array = rings[i + 1][j + 1]
				var d: Array = rings[i + 1][j]
				for q in [a, c, b, a, d, c]:
					bv.append(q[0])
					bn.append(q[1])
					bu.append(q[2])
					bc.append(col)

	## Karta liści skierowana w stronę `n`, środek `p`, rozmiar `s`; normalne kuliste od `center`.
	func leaf_card(p: Vector3, n: Vector3, s: float, center: Vector3, col: Color) -> void:
		n = n.normalized()
		var ref := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
		var r := n.cross(ref).normalized().rotated(n, rng.randf() * TAU) * s * 0.5
		var u := n.cross(r).normalized() * s * 0.5
		var corners := [p - r - u, p + r - u, p + r + u, p - r + u]
		var norms := []
		for c in corners:
			norms.append(((c - center).normalized() + Vector3.UP * 0.35).normalized())
		leaf_quad(corners[0], corners[1], corners[2], corners[3], norms, col, Rect2(0, 0, 1, 1))

	## Czworokąt liści a-b-c-d; UV: a,b = dół prostokąta (v = 1), c,d = góra (v = 0).
	func leaf_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, norms: Array, col: Color, uv: Rect2, _branch := false) -> void:
		var uvs := [Vector2(uv.position.x, uv.end.y), Vector2(uv.end.x, uv.end.y), Vector2(uv.end.x, uv.position.y), Vector2(uv.position.x, uv.position.y)]
		var pts := [a, b, c, d]
		for i in [0, 2, 1, 0, 3, 2]:
			lv.append(pts[i])
			ln.append(norms[i])
			lu.append(uvs[i])
			lc.append(col)

	func commit(bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
		var m := ArrayMesh.new()
		if not bv.is_empty():
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = bv
			arr[Mesh.ARRAY_NORMAL] = bn
			arr[Mesh.ARRAY_TEX_UV] = bu
			arr[Mesh.ARRAY_COLOR] = bc
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(m.get_surface_count() - 1, bark_mat)
		commit_leaves_into(m, leaf_mat)
		return m

	func commit_leaves_into(m: ArrayMesh, leaf_mat: Material) -> void:
		if lv.is_empty():
			return
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = lv
		arr[Mesh.ARRAY_NORMAL] = ln
		arr[Mesh.ARRAY_TEX_UV] = lu
		arr[Mesh.ARRAY_COLOR] = lc
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, leaf_mat)
