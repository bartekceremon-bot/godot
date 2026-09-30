class_name MeshKit
extends RefCounted
## Budowniczy siatek low-poly: płaskie cieniowanie (normalna na trójkąt), kolory wierzchołków.
##
## Kanały dodatkowe w UV (czytane przez shadery lowpoly_*):
##   UV.x – metaliczność (obiekty) albo waga kołysania na wietrze (roślinność),
##   UV.y – świecenie (emisja koloru wierzchołka: oczy, ogień, żar).
##
## Wszystkie prymitywy przyjmują bieżącą transformację `xf` – dzięki temu można składać
## modele z przesuniętych i obróconych części i scalać je w jedną siatkę (szybkie rysowanie).

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()

## Transformacja stosowana do dodawanych punktów.
var xf := Transform3D.IDENTITY
## Kanały UV dla kolejnych trójkątów.
var metal := 0.0
var glow := 0.0
## Kołysanie roślin: jeśli sway_height > 0, UV.x = wysokość punktu nad sway_base / sway_height.
var sway_base := 0.0
var sway_height := 0.0
## Losowe odchylenie jasności każdego trójkąta (0 = brak) – typowy „low-poly” wygląd.
var jitter := 0.0
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func is_empty() -> bool:
	return verts.is_empty()


## Trójkąt w przestrzeni lokalnej (przed `xf`). `hint` – przybliżony kierunek „na zewnątrz”
## (w przestrzeni lokalnej); kolejność wierzchołków jest poprawiana automatycznie.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint := Vector3.ZERO) -> void:
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	# Godot: przednia ściana = wierzchołki zgodnie z ruchem wskazówek zegara.
	var n := (wc - wa).cross(wb - wa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if hint != Vector3.ZERO:
		var wh := xf.basis * hint
		if n.dot(wh) < 0.0:
			var t := wb
			wb = wc
			wc = t
			n = -n
	var cc := col
	if jitter > 0.0:
		var j := rng.randf_range(-jitter, jitter)
		cc = Color(clampf(col.r + j, 0, 1), clampf(col.g + j, 0, 1), clampf(col.b + j * 0.8, 0, 1), col.a)
	for p in [wa, wb, wc]:
		verts.append(p)
		norms.append(n)
		cols.append(cc)
		var ux := metal
		if sway_height > 0.0:
			ux = clampf((p.y - sway_base) / sway_height, 0.0, 1.0)
		uvs.append(Vector2(ux, glow))


## Trójkąt z osobnym kolorem w każdym wierzchołku (płynne przejścia, np. daleki teren).
## Wierzchołki podawane w przestrzeni świata, przednia ściana skierowana w górę (hint = UP).
func tri_colors(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.y < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	for i in 3:
		verts.append([a, b, c][i])
		norms.append(n)
		cols.append([ca, cb, cc][i])
		uvs.append(Vector2(metal, glow))


## Czworokąt a-b-c-d (kolejno po obwodzie).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint := Vector3.ZERO) -> void:
	if hint == Vector3.ZERO:
		hint = (c - a).cross(b - a)
	tri(a, b, c, col, hint)
	tri(a, c, d, col, hint)


## Prostopadłościan (opcjonalnie zwężony u góry): środek podstawy `base`, rozmiar `size`,
## `top` – skala górnej ściany (x, z). `top_col` – inny kolor górnej ściany.
func box(base: Vector3, size: Vector3, col: Color, top := Vector2.ONE, top_col = null, skip_bottom := true) -> void:
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	var tx := hx * top.x
	var tz := hz * top.y
	var y0 := base.y
	var y1 := base.y + size.y
	var b := [Vector3(-hx, y0, -hz), Vector3(hx, y0, -hz), Vector3(hx, y0, hz), Vector3(-hx, y0, hz)]
	var t := [Vector3(-tx, y1, -tz), Vector3(tx, y1, -tz), Vector3(tx, y1, tz), Vector3(-tx, y1, tz)]
	var off := Vector3(base.x, 0, base.z)
	for i in 4:
		b[i] += off
		t[i] += off
	var center := off + Vector3(0, (y0 + y1) / 2.0, 0)
	for i in 4:
		var j := (i + 1) % 4
		var fc: Vector3 = (b[i] + b[j] + t[i] + t[j]) / 4.0
		quad(b[i], b[j], t[j], t[i], col, fc - center)
	quad(t[0], t[1], t[2], t[3], top_col if top_col != null else col, Vector3.UP)
	if not skip_bottom:
		quad(b[0], b[1], b[2], b[3], col, Vector3.DOWN)


## Graniastosłup / stożek ścięty: podstawa w `base`, promienie dolny i górny.
func cyl(base: Vector3, r0: float, r1: float, h: float, sides: int, col: Color, cap := true, cap_col = null, rot := 0.0) -> void:
	var top := base + Vector3(0, h, 0)
	for i in sides:
		var a0 := rot + TAU * i / sides
		var a1 := rot + TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := base + d0 * r0
		var p1 := base + d1 * r0
		var q0 := top + d0 * r1
		var q1 := top + d1 * r1
		var hint := (d0 + d1).normalized()
		if r1 < 0.0005:
			tri(p0, p1, top, col, hint + Vector3(0, r0 / maxf(h, 0.01), 0))
		else:
			quad(p0, p1, q1, q0, col, hint)
			if cap:
				tri(top, q0, q1, cap_col if cap_col != null else col, Vector3.UP)


## Stożek.
func cone(base: Vector3, r: float, h: float, sides: int, col: Color, rot := 0.0) -> void:
	cyl(base, r, 0.0, h, sides, col, false, null, rot)


## Bryła „kamienia/kuli” low-poly: spłaszczona kula z losowym zniekształceniem.
func blob(center: Vector3, radius: Vector3, col: Color, rings := 3, sides := 6, noise := 0.18, top_col = null) -> void:
	var pts: Array = []
	for r in rings + 1:
		var row: Array = []
		var phi := PI * r / rings
		for s in sides:
			var theta := TAU * s / sides + (0.5 if r % 2 == 1 else 0.0) * TAU / sides
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var k := 1.0 + (rng.randf_range(-noise, noise) if r > 0 and r < rings else 0.0)
			row.append(center + d * radius * k)
		pts.append(row)
	for r in rings:
		for s in sides:
			var s1 := (s + 1) % sides
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s1]
			var c: Vector3 = pts[r + 1][s1]
			var d: Vector3 = pts[r + 1][s]
			var cc := col
			if top_col != null and r < rings / 2:
				cc = top_col
			var hint := ((a + b + c + d) / 4.0 - center)
			if r == 0:
				tri(a, c, d, cc, hint)
			elif r == rings - 1:
				tri(a, b, c, cc, hint)
			else:
				quad(a, b, c, d, cc, hint)


## Płaski dwustronny trójkąt (liście, trawa, płomienie).
func blade(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (c - a).cross(b - a)
	tri(a, b, c, col, n)
	tri(a, c, b, col, -n)


## Scalona siatka z dodanymi trójkątami.
func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Ustawia transformację: przesunięcie, obrót wokół Y i skala.
func place(pos: Vector3, yaw := 0.0, scale := 1.0) -> void:
	xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos)


func reset() -> void:
	xf = Transform3D.IDENTITY
	metal = 0.0
	glow = 0.0
	sway_height = 0.0
