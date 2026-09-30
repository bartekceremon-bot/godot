class_name FarWorld
extends Node3D
## Daleki świat: cała mapa w niskiej rozdzielczości (teren co 2 pola, woda, lawa, domy, mury, las)
## oraz pierścień wysokich gór za krawędzią świata. Dzięki temu z kamery bohatera widać horyzont,
## odległe miasta i pasma górskie, a nie pustkę za załadowanymi kawałkami.
##
## Nad załadowanymi kawałkami (set_mask) fragmenty są odrzucane w shaderze –
## tam rysuje się pełnoszczegółowy świat z WorldBuilder.

const SHADER := preload("res://shaders/far_lod.gdshader")
const STEP := 2
const RING_STEP := 6
const RING_OUT := 130
const WATER_COL := Color(0.2, 0.42, 0.52)
const SWAMP_COL := Color(0.24, 0.3, 0.2)
const LAVA_COL := Color(0.7, 0.26, 0.08)

var mat := ShaderMaterial.new()
var mat_trees := ShaderMaterial.new()
var _wb: WorldBuilder
var _noise := FastNoiseLite.new()


func _init() -> void:
	mat.shader = SHADER
	mat_trees.shader = SHADER
	mat_trees.set_shader_parameter("by_instance", true)
	_noise.seed = 4242
	_noise.frequency = 0.035
	_noise.fractal_octaves = 4


func build(wb: WorldBuilder) -> void:
	_wb = wb
	_add(_build_terrain())
	_add(_build_ring())
	_add(_build_blocks())
	_build_trees()


## Maska załadowanych kawałków: obraz, w którym piksel (cx - origin_chunk, cy - origin_chunk) = 1.
func set_mask(img: Image, origin: Vector2, span: Vector2) -> void:
	var tex := ImageTexture.create_from_image(img)
	for m in [mat, mat_trees] + TreeModels.far_materials():
		m.set_shader_parameter("chunk_mask", tex)
		m.set_shader_parameter("mask_origin", origin)
		m.set_shader_parameter("mask_span", span)


func _add(k: MeshKit) -> void:
	if k.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Daleki świat zawsze w polu widzenia – bez odrzucania przez AABB kamery.
	mi.extra_cull_margin = 16.0
	add_child(mi)


# ============================================================================
# Teren mapy
# ============================================================================

func _far_height(cx: int, cy: int) -> float:
	var y := _wb.height_at_corner(cx, cy)
	var c := _wb.tile(clampi(cx, -WorldBuilder.BORDER, _wb.w + WorldBuilder.BORDER - 1), clampi(cy, -WorldBuilder.BORDER, _wb.h + WorldBuilder.BORDER - 1))
	if c == "~" or c == "=":
		return WorldBuilder.WATER_Y - 0.02
	if c == "l":
		return WorldBuilder.LAVA_Y - 0.02
	# Odrobinę niżej niż pełny świat – na styku załadowanego obszaru nie migocze.
	return y - 0.06


func _far_color(x: int, y: int, hh: float) -> Color:
	var c := _wb.tile(x, y)
	match c:
		"~", "=":
			return SWAMP_COL if _wb.biome(x, y) == "w" else WATER_COL
		"l":
			return LAVA_COL
		"^", "B":
			return _rock_color(_wb.biome(x, y), hh, 0.0)
		"T":
			return _wb.ground_color(x, y).darkened(0.12)
		"H":
			return Color(0.42, 0.36, 0.3)
	return _wb._tile_color(x, y)


func _rock_color(b: String, hh: float, n: float) -> Color:
	var rock: Color = WorldBuilder.ROCK_COL.get(b, WorldBuilder.ROCK_COL["m"])
	if b == "d":
		var bands := [Color(0.8, 0.52, 0.33), Color(0.86, 0.62, 0.4), Color(0.72, 0.44, 0.3)]
		return bands[int(hh * 1.2 + n * 2.0) % 3]
	var snow_line := 1.2 if b == "s" else (2.6 if b == "r" else 3.4)
	if b == "a":
		snow_line = 999.0
	if hh + n * 1.5 > snow_line:
		return WorldBuilder.SNOW.darkened(0.05)
	return rock.lerp(rock.darkened(0.2), n)


func _build_terrain() -> MeshKit:
	var k := MeshKit.new(7)
	var b := WorldBuilder.BORDER
	var x0 := -b
	var y0 := -b
	var nx := int((_wb.w + 2 * b) / STEP)
	var ny := int((_wb.h + 2 * b) / STEP)
	var hs := PackedFloat32Array()
	hs.resize((nx + 1) * (ny + 1))
	var cs := PackedColorArray()
	cs.resize((nx + 1) * (ny + 1))
	var lava := PackedByteArray()
	lava.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			var cx := x0 + i * STEP
			var cy := y0 + j * STEP
			var hh := _far_height(cx, cy)
			hs[i + j * (nx + 1)] = hh
			# Kolor narożnika = średnia czterech kafelków wokół (płynne przejścia).
			var col := Color(0, 0, 0)
			var lv := 0
			for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				col += _far_color(cx + d.x, cy + d.y, hh)
				if _wb.tile(cx + d.x, cy + d.y) == "l":
					lv += 1
			cs[i + j * (nx + 1)] = col / 4.0
			lava[i + j * (nx + 1)] = lv
	for j in ny:
		for i in nx:
			var cx := x0 + i * STEP
			var cy := y0 + j * STEP
			var ia := i + j * (nx + 1)
			var ib := i + 1 + j * (nx + 1)
			var ic := i + 1 + (j + 1) * (nx + 1)
			var id := i + (j + 1) * (nx + 1)
			var a := Vector3(cx, hs[ia], cy)
			var bb := Vector3(cx + STEP, hs[ib], cy)
			var c := Vector3(cx + STEP, hs[ic], cy + STEP)
			var d := Vector3(cx, hs[id], cy + STEP)
			k.glow = 1.0 if lava[ia] + lava[ib] + lava[ic] + lava[id] >= 8 else 0.0
			# Przekątna naprzemiennie – mniej widoczny „wzór szachownicy”.
			if (i + j) % 2 == 0:
				k.tri_colors(a, bb, c, cs[ia], cs[ib], cs[ic])
				k.tri_colors(a, c, d, cs[ia], cs[ic], cs[id])
			else:
				k.tri_colors(a, bb, d, cs[ia], cs[ib], cs[id])
				k.tri_colors(bb, c, d, cs[ib], cs[ic], cs[id])
	k.glow = 0.0
	return k


# ============================================================================
# Pierścień gór za krawędzią świata
# ============================================================================

func _ring_height(x: float, y: float) -> float:
	var b := float(WorldBuilder.BORDER)
	var dx := maxf(-b - x, x - (_wb.w + b))
	var dy := maxf(-b - y, y - (_wb.h + b))
	var d := maxf(maxf(dx, dy), 0.0)
	if dx > 0 and dy > 0:
		d = Vector2(dx, dy).length()
	var n := _noise.get_noise_2d(x, y) * 0.5 + 0.5
	var ridge := 1.0 - absf(_noise.get_noise_2d(x * 1.9 + 50.0, y * 1.9 - 20.0))
	var base := 4.2 + d * (0.12 + n * 0.22)
	var peaks := ridge * ridge * minf(d, 50.0) * 0.32
	var hh := minf(base + peaks, 34.0)
	# Wnętrze nakładki (pod pełną mapą) – nisko, zakryte.
	if d <= 0.0:
		var inside := minf(minf(x + b, _wb.w + b - x), minf(y + b, _wb.h + b - y))
		hh = 3.6 - inside * 0.3
	return hh


func _build_ring() -> MeshKit:
	var k := MeshKit.new(9)
	var b := WorldBuilder.BORDER
	var lo := -b - RING_OUT
	var hi_x := _wb.w + b + RING_OUT
	var hi_y := _wb.h + b + RING_OUT
	var inner := Rect2(-b + RING_STEP, -b + RING_STEP, _wb.w + 2 * b - 2 * RING_STEP, _wb.h + 2 * b - 2 * RING_STEP)
	var y := lo
	while y < hi_y:
		var x := lo
		while x < hi_x:
			var cell := Rect2(x, y, RING_STEP, RING_STEP)
			if inner.encloses(cell):
				x += RING_STEP
				continue
			var p := [Vector3(x, 0, y), Vector3(x + RING_STEP, 0, y), Vector3(x + RING_STEP, 0, y + RING_STEP), Vector3(x, 0, y + RING_STEP)]
			for q in 4:
				p[q].y = _ring_height(p[q].x, p[q].z)
			var mx := clampi(x + RING_STEP / 2, 0, _wb.w - 1)
			var my := clampi(y + RING_STEP / 2, 0, _wb.h - 1)
			var bi := _wb.biome(mx, my)
			var t1: Array = [p[0], p[1], p[2]]
			var t2: Array = [p[0], p[2], p[3]]
			for t in [t1, t2]:
				var hh: float = (t[0].y + t[1].y + t[2].y) / 3.0
				var nrm: Vector3 = (t[2] - t[0]).cross(t[1] - t[0]).normalized()
				var steep := clampf(1.0 - absf(nrm.y), 0.0, 1.0)
				var col := _rock_color(bi, hh * 0.28, steep)
				if absf(nrm.y) > 0.93 and hh < 9.0 and bi in ["m", "f", "r", "w"]:
					col = _wb.ground_color(mx, my).lerp(col, 0.4)
				k.tri(t[0], t[1], t[2], col, Vector3.UP)
			x += RING_STEP
		y += RING_STEP
	return k


# ============================================================================
# Domy, mury, wieże (bryły widoczne z daleka)
# ============================================================================

func _build_blocks() -> MeshKit:
	var k := MeshKit.new(11)
	for key in _wb._houses:
		var hs: Array = _wb._houses[key]
		var x0: int = hs[0]
		var y0: int = hs[1]
		var x1: int = hs[2]
		var y1: int = hs[3]
		var b := _wb.biome(x0, y0)
		var lm: String = _wb.landmark_at(hs)
		if lm != "":
			# Cytadele i katedry widoczne z daleka w pełnej postaci (wyróżniają miasta na horyzoncie).
			var st := "snow" if b == "s" else ("desert" if b == "d" else "meadow")
			if lm == "citadel":
				WorldProps.citadel(k, x0, y0, x1, y1, st)
			else:
				WorldProps.cathedral(k, x0, y0, x1, y1, st)
			k.reset()
			continue
		var wall := Color(0.86, 0.8, 0.68)
		var roof := Color(0.62, 0.22, 0.14)
		if b == "s":
			wall = Color(0.5, 0.34, 0.2)
			roof = Color(0.35, 0.36, 0.42)
		elif b == "d":
			wall = Color(0.86, 0.7, 0.5)
			roof = wall.lightened(0.06)
		var wx := x1 - x0 + 0.8
		var wz := y1 - y0 + 0.8
		var c := Vector3((x0 + x1 + 1) / 2.0, _wb.ground_y(x0, y0) - 0.05, (y0 + y1 + 1) / 2.0)
		k.box(c, Vector3(wx, 1.5, wz), wall)
		if b == "d":
			continue
		var top := c + Vector3(0, 1.5, 0)
		var hx := wx / 2.0 + 0.1
		var hz := wz / 2.0 + 0.1
		var ridge := 0.9
		if wx >= wz:
			k.quad(top + Vector3(-hx, 0, -hz), top + Vector3(hx, 0, -hz), top + Vector3(hx, ridge, 0), top + Vector3(-hx, ridge, 0), roof, Vector3(0, 1, -1))
			k.quad(top + Vector3(-hx, 0, hz), top + Vector3(-hx, ridge, 0), top + Vector3(hx, ridge, 0), top + Vector3(hx, 0, hz), roof.darkened(0.12), Vector3(0, 1, 1))
		else:
			k.quad(top + Vector3(-hx, 0, -hz), top + Vector3(0, ridge, -hz), top + Vector3(0, ridge, hz), top + Vector3(-hx, 0, hz), roof, Vector3(-1, 1, 0))
			k.quad(top + Vector3(hx, 0, -hz), top + Vector3(hx, 0, hz), top + Vector3(0, ridge, hz), top + Vector3(0, ridge, -hz), roof.darkened(0.12), Vector3(1, 1, 0))
	# Mury miast i wioskowe palisady.
	for y in _wb.h:
		for x in _wb.w:
			if _wb.tile(x, y) != "#":
				continue
			var cols: Array = _wb._wall_colors(_wb.biome(x, y))
			var c := Vector3(x + 0.5, _wb.ground_y(x, y) - 0.05, y + 0.5)
			k.box(c, Vector3(1.0, 1.7, 1.0), cols[0])
			var corner := int(_wb._is_wall(x - 1, y) or _wb._is_wall(x + 1, y)) + int(_wb._is_wall(x, y - 1) or _wb._is_wall(x, y + 1))
			if corner == 2 and (x + y) % 3 == 0:
				k.box(c, Vector3(1.3, 2.6, 1.3), cols[0].darkened(0.05))
				k.cone(c + Vector3(0, 2.6, 0), 0.95, 1.4, 6, cols[1])
	return k


# ============================================================================
# Las (MultiMesh – po jednej siatce na rodzaj drzewa)
# ============================================================================

func _build_trees() -> void:
	var by_kind := {}
	for y in _wb.h:
		for x in _wb.w:
			if _wb.tile(x, y) != "T":
				continue
			var spec := _wb.tree_spec(x, y)
			var key := "%s:%d" % [spec[0], spec[1]]
			if not by_kind.has(key):
				by_kind[key] = []
			var pos := Vector3(x + 0.5, _wb.ground_y(x, y) - 0.05, y + 0.5)
			by_kind[key].append([Transform3D(Basis(Vector3.UP, spec[4]).scaled(Vector3.ONE * float(spec[3])), pos), spec[2]])
	for key in by_kind:
		var parts: PackedStringArray = key.split(":")
		var list: Array = by_kind[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = TreeModels.mesh(parts[0], int(parts[1]), true)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_custom_data(i, list[i][1])
			mm.set_instance_color(i, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
