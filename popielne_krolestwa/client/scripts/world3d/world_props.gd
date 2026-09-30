class_name WorldProps
extends RefCounted
## Biblioteka obiektów krajobrazu low-poly: drzewa każdej krainy, domy w trzech stylach,
## mosty, płoty, pola, studnie, fontanny, ruiny, obeliski. Wszystko dopisywane do MeshKit
## (scalane w siatki kawałków świata). `r` – deterministyczna liczba 0..1 dla wariantów.

const WOOD := Color(0.45, 0.3, 0.18)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const STONE := Color(0.56, 0.53, 0.49)
const IRON := Color(0.34, 0.34, 0.37)
const GOLD := Color(0.95, 0.72, 0.25)
const SNOW := Color(0.93, 0.96, 1.0)
const WINDOW := Color(1.0, 0.78, 0.42)


# ============================================================================
# Drzewa
# ============================================================================

static func pine(k: MeshKit, col: Color, snowy := false, tall := 1.0) -> void:
	k.cyl(Vector3.ZERO, 0.08, 0.06, 0.5 * tall, 5, WOOD_DARK)
	for i in 3:
		var y := (0.35 + i * 0.45) * tall
		var r := 0.62 - i * 0.13
		var c := col.lightened(i * 0.06)
		k.cone(Vector3(0, y, 0), r, 0.85 * tall, 7, c, i * 0.45)
		if snowy:
			k.cone(Vector3(0, y + 0.42 * tall, 0), r * 0.52, 0.43 * tall, 7, SNOW, i * 0.45)


static func oak(k: MeshKit, c: Color, big := 1.0) -> void:
	k.cyl(Vector3.ZERO, 0.11 * big, 0.07 * big, 0.8 * big, 6, WOOD)
	k.blob(Vector3(0, 1.15, 0) * big, Vector3(0.62, 0.5, 0.62) * big, c, 3, 7, 0.18, c.lightened(0.1))
	k.blob(Vector3(0.28, 1.45, 0.1) * big, Vector3(0.38, 0.33, 0.38) * big, c.lightened(0.08), 3, 6, 0.15)
	k.blob(Vector3(-0.25, 1.35, -0.15) * big, Vector3(0.36, 0.3, 0.36) * big, c.darkened(0.05), 3, 6, 0.15)


static func birch(k: MeshKit, c: Color) -> void:
	k.cyl(Vector3.ZERO, 0.07, 0.05, 1.4, 6, Color(0.92, 0.9, 0.84))
	for i in 4:
		k.box(Vector3(0, 0.2 + i * 0.3, 0), Vector3(0.15, 0.025, 0.15), Color(0.15, 0.13, 0.12), Vector2(0.95, 0.95))
	k.blob(Vector3(0, 1.45, 0), Vector3(0.42, 0.55, 0.42), c.lightened(0.12), 3, 7, 0.2)


static func dead_tree(k: MeshKit, embers: bool, bark := Color(0.16, 0.13, 0.12)) -> void:
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


## Palma: wygięty pień z segmentów, opadające liście, kokosy.
static func palm(k: MeshKit, r: float) -> void:
	var p := Vector3.ZERO
	var lean := Vector3(0.12 + r * 0.1, 0, 0.05)
	var trunk := Color(0.55, 0.42, 0.28)
	for i in 6:
		var q := p + Vector3(0, 0.33, 0) + lean * (0.3 + i * 0.12)
		k.cyl(p, 0.08 - i * 0.006, 0.075 - i * 0.006, (q - p).length(), 6, trunk.darkened((i % 2) * 0.12), false)
		p = q
	var leaf := Color(0.3, 0.55, 0.2)
	for i in 7:
		var a := i * TAU / 7.0 + r
		var d := Vector3(cos(a), 0, sin(a))
		var mid := p + d * 0.45 + Vector3(0, 0.12, 0)
		var tip := p + d * 0.95 + Vector3(0, -0.28, 0)
		var s := Vector3(-d.z, 0, d.x) * 0.14
		k.blade(p, mid + s, mid - s, leaf)
		k.blade(mid + s, tip, mid - s, leaf.darkened(0.1))
	for i in 3:
		var a := i * TAU / 3.0
		k.blob(p + Vector3(cos(a) * 0.1, -0.08, sin(a) * 0.1), Vector3(0.06, 0.07, 0.06), Color(0.4, 0.28, 0.14), 2, 5, 0.0)


## Kaktus (saguaro) z ramionami.
static func cactus(k: MeshKit, r: float) -> void:
	var c := Color(0.32, 0.55, 0.3)
	var h := 0.9 + r * 0.5
	k.cyl(Vector3.ZERO, 0.13, 0.11, h, 7, c, true, c.lightened(0.1))
	for side in [-1, 1]:
		if side == 1 and r < 0.35:
			continue
		var y := 0.35 + (0.2 if side == 1 else 0.0)
		k.box(Vector3(side * 0.2, y - 0.06, 0), Vector3(0.22, 0.12, 0.12), c)
		k.cyl(Vector3(side * 0.3, y - 0.06, 0), 0.07, 0.06, 0.42, 6, c, true, c.lightened(0.1))
	# Kwiat na szczycie.
	if r > 0.7:
		k.blob(Vector3(0, h + 0.02, 0), Vector3(0.06, 0.04, 0.06), Color(0.95, 0.4, 0.55), 2, 5, 0.0)


## Wierzba bagienna: pień, korona i zwisające pnącza.
static func willow(k: MeshKit, r: float) -> void:
	var bark := Color(0.32, 0.26, 0.18)
	k.cyl(Vector3.ZERO, 0.14, 0.09, 0.9, 6, bark)
	var c := Color(0.36, 0.46, 0.2)
	k.blob(Vector3(0, 1.2, 0), Vector3(0.75, 0.38, 0.75), c, 3, 8, 0.15, c.lightened(0.08))
	for i in 12:
		var a := i * TAU / 12.0 + r
		var top := Vector3(cos(a) * 0.62, 1.05, sin(a) * 0.62)
		var bot := top + Vector3(cos(a) * 0.1, -0.75 - fmod(r * 7.0 + i, 1.0) * 0.3, sin(a) * 0.1)
		var s := Vector3(-sin(a), 0, cos(a)) * 0.07
		k.blade(top - s, top + s, bot, c.darkened(0.08))
	# Korzenie nad wodą.
	for i in 4:
		var a := i * TAU / 4.0 + 0.5
		k.quad(Vector3(cos(a) * 0.1, 0.25, sin(a) * 0.1), Vector3(cos(a) * 0.14, 0.2, sin(a) * 0.14),
			Vector3(cos(a) * 0.38, 0.0, sin(a) * 0.38), Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32), bark)


# ============================================================================
# Domy (trzy style: łąki – szachulec, śniegi – bala z ośnieżonym dachem, pustynia – glina)
# ============================================================================

## Dom na prostokącie kafelków [x0..x1]×[y0..y1]. door: 0=N 1=E 2=S 3=W. style: meadow/snow/desert.
static func house(k: MeshKit, x0: int, y0: int, x1: int, y1: int, door: int, style: String, r: float) -> void:
	var inset := 0.1
	var ax := x0 + inset
	var az := y0 + inset
	var bx := x1 + 1 - inset
	var bz := y1 + 1 - inset
	var wx := bx - ax
	var wz := bz - az
	var cx := (ax + bx) / 2.0
	var cz := (az + bz) / 2.0
	var tall := 1.35 + (0.5 if wx * wz > 11.0 else 0.0)
	k.reset()
	k.jitter = 0.02
	match style:
		"snow":
			# Chata z bali: warstwy pni w dwóch odcieniach.
			var logs := int(tall / 0.2)
			k.tex = 4
			for i in logs:
				var c := Color(0.5, 0.34, 0.2).lerp(Color(0.42, 0.28, 0.16), float(i % 2))
				k.box(Vector3(cx, i * 0.2, cz), Vector3(wx - (0.03 if i % 2 else 0.0), 0.2, wz - (0.0 if i % 2 else 0.03)), c)
			for corner in [Vector3(ax, 0, az), Vector3(bx, 0, az), Vector3(ax, 0, bz), Vector3(bx, 0, bz)]:
				k.box(corner, Vector3(0.14, tall + 0.05, 0.14), Color(0.36, 0.24, 0.14))
			k.tex = 0
		"desert":
			var adobe := Color(0.86, 0.7, 0.5).lerp(Color(0.9, 0.78, 0.6), r)
			k.tex = 5
			k.box(Vector3(cx, 0, cz), Vector3(wx, tall, wz), adobe, Vector2(0.98, 0.98), adobe.lightened(0.05))
			k.tex = 4
			# Belki wystające ze ścian i niski murek na dachu.
			for i in int(wx / 0.6):
				k.box(Vector3(ax + 0.3 + i * 0.6, tall - 0.25, az - 0.08), Vector3(0.08, 0.08, 0.16), WOOD_DARK)
			k.tex = 5
			var par := 0.12
			k.box(Vector3(cx, tall, az + 0.05), Vector3(wx, par, 0.1), adobe.darkened(0.05))
			k.box(Vector3(cx, tall, bz - 0.05), Vector3(wx, par, 0.1), adobe.darkened(0.05))
			k.box(Vector3(ax + 0.05, tall, cz), Vector3(0.1, par, wz), adobe.darkened(0.05))
			k.box(Vector3(bx - 0.05, tall, cz), Vector3(0.1, par, wz), adobe.darkened(0.05))
			# Kopułka na większych domach.
			k.tex = 0
			if wx * wz > 11.0:
				k.blob(Vector3(cx, tall, cz), Vector3(0.6, 0.55, 0.6), Color(0.3, 0.62, 0.66) if r > 0.5 else Color(0.92, 0.88, 0.8), 3, 8, 0.0)
		_:
			# Szachulec: jasny tynk, ciemne belki.
			var plaster := Color(0.93, 0.89, 0.8).lerp(Color(0.88, 0.8, 0.66), r)
			k.tex = 5
			k.box(Vector3(cx, 0, cz), Vector3(wx, tall, wz), plaster)
			k.tex = 2
			k.box(Vector3(cx, 0, cz), Vector3(wx + 0.04, 0.25, wz + 0.04), STONE.darkened(0.1))
			k.tex = 4
			k.box(Vector3(cx, tall * 0.55, cz), Vector3(wx + 0.03, 0.07, wz + 0.03), WOOD_DARK)
			k.box(Vector3(cx, tall - 0.07, cz), Vector3(wx + 0.03, 0.07, wz + 0.03), WOOD_DARK)
			for corner in [Vector3(ax, 0, az), Vector3(bx, 0, az), Vector3(ax, 0, bz), Vector3(bx, 0, bz)]:
				k.box(corner, Vector3(0.1, tall, 0.1), WOOD_DARK)
			# Ukośne belki na dłuższej ścianie.
			for s in [az - 0.012, bz + 0.012]:
				for i in int(wx):
					var x0b := ax + i + 0.15
					k.quad(Vector3(x0b, 0.3, s), Vector3(x0b + 0.07, 0.3, s), Vector3(x0b + 0.77, tall * 0.55, s), Vector3(x0b + 0.7, tall * 0.55, s), WOOD_DARK, Vector3(0, 0, sign(s - cz)))
			k.tex = 0
	k.jitter = 0.0
	_door_and_windows(k, ax, az, bx, bz, tall, door, style)
	if style != "desert":
		_pitched_roof(k, ax, az, bx, bz, tall, style, r)


static func _door_and_windows(k: MeshKit, ax: float, az: float, bx: float, bz: float, tall: float, door: int, style: String) -> void:
	var cx := (ax + bx) / 2.0
	var cz := (az + bz) / 2.0
	var e := 0.015
	# Pozycje ścian: [środek, normalna, długość, oś wzdłuż]
	var walls := [
		[Vector3(cx, 0, az - e), Vector3(0, 0, -1), bx - ax, Vector3(1, 0, 0)],
		[Vector3(bx + e, 0, cz), Vector3(1, 0, 0), bz - az, Vector3(0, 0, 1)],
		[Vector3(cx, 0, bz + e), Vector3(0, 0, 1), bx - ax, Vector3(1, 0, 0)],
		[Vector3(ax - e, 0, cz), Vector3(-1, 0, 0), bz - az, Vector3(0, 0, 1)],
	]
	for i in 4:
		var wdef: Array = walls[i]
		var c: Vector3 = wdef[0]
		var n: Vector3 = wdef[1]
		var length: float = wdef[2]
		var along: Vector3 = wdef[3]
		if i == door:
			var dw := 0.28
			var dh := 0.8
			k.quad(c - along * dw, c + along * dw, c + along * dw + Vector3(0, dh, 0), c - along * dw + Vector3(0, dh, 0), Color(0.28, 0.17, 0.1), n)
			k.quad(c - along * (dw + 0.06) + n * 0.005, c - along * dw + n * 0.005, c - along * dw + Vector3(0, dh + 0.06, 0) + n * 0.005, c - along * (dw + 0.06) + Vector3(0, dh + 0.06, 0) + n * 0.005, WOOD_DARK, n)
			k.quad(c + along * dw + n * 0.005, c + along * (dw + 0.06) + n * 0.005, c + along * (dw + 0.06) + Vector3(0, dh + 0.06, 0) + n * 0.005, c + along * dw + Vector3(0, dh + 0.06, 0) + n * 0.005, WOOD_DARK, n)
			# Daszek nad drzwiami.
			k.box(c + n * 0.15 + Vector3(0, dh + 0.1, 0), Vector3(absf(along.x) * 0.8 + absf(n.x) * 0.3 + 0.01, 0.05, absf(along.z) * 0.8 + absf(n.z) * 0.3 + 0.01), WOOD_DARK)
		# Okna: po bokach drzwi albo na całej ścianie.
		var count := int(length / 1.1)
		for j in count:
			var off := (j - (count - 1) / 2.0) * 1.0
			if i == door and absf(off) < 0.5:
				continue
			var p := c + along * off + Vector3(0, tall * 0.55 + 0.12, 0)
			var s := 0.13
			k.glow = 0.3
			k.quad(p - along * s - Vector3(0, s, 0), p + along * s - Vector3(0, s, 0), p + along * s + Vector3(0, s, 0), p - along * s + Vector3(0, s, 0), WINDOW, n)
			k.glow = 0.0
			var fr := WOOD_DARK if style != "desert" else Color(0.3, 0.45, 0.55)
			k.quad(p - along * (s + 0.04) - Vector3(0, s + 0.03, 0) + n * 0.004, p + along * (s + 0.04) - Vector3(0, s + 0.03, 0) + n * 0.004, p + along * (s + 0.04) - Vector3(0, s, 0) + n * 0.004, p - along * (s + 0.04) - Vector3(0, s, 0) + n * 0.004, fr, n)


static func _pitched_roof(k: MeshKit, ax: float, az: float, bx: float, bz: float, tall: float, style: String, r: float) -> void:
	var o := 0.18
	var along_x := (bx - ax) >= (bz - az)
	var span := (bz - az) if along_x else (bx - ax)
	var rh := span * 0.42 + 0.25
	var col: Color
	if style == "snow":
		col = SNOW
	else:
		col = [Color(0.62, 0.25, 0.17), Color(0.34, 0.36, 0.42), Color(0.5, 0.32, 0.2)][int(r * 2.99)]
	var under := col.darkened(0.35) if style != "snow" else Color(0.4, 0.26, 0.15)
	var y0 := tall
	var roof_tex := 7 if style == "snow" else 3
	if along_x:
		var zc := (az + bz) / 2.0
		var a := Vector3(ax - o, y0 - 0.12, az - o)
		var b := Vector3(bx + o, y0 - 0.12, az - o)
		var c := Vector3(bx + o, y0 + rh, zc)
		var d := Vector3(ax - o, y0 + rh, zc)
		var e := Vector3(ax - o, y0 - 0.12, bz + o)
		var f := Vector3(bx + o, y0 - 0.12, bz + o)
		k.tex = roof_tex
		k.quad(a, b, c, d, col, Vector3(0, 1, -1))
		k.quad(e, d, c, f, col.darkened(0.08), Vector3(0, 1, 1))
		k.tex = 4
		k.quad(a, d, c, b, under, Vector3(0, -1, 0.3))
		k.quad(e, f, c, d, under, Vector3(0, -1, -0.3))
		k.tex = 5 if style != "snow" else 4
		# Szczyty ścian.
		var wc := Color(0.9, 0.86, 0.76) if style != "snow" else Color(0.45, 0.3, 0.18)
		k.tri(Vector3(ax, y0, az), Vector3(ax, y0 + rh - 0.1, zc), Vector3(ax, y0, bz), wc, Vector3(-1, 0, 0))
		k.tri(Vector3(bx, y0, az), Vector3(bx, y0 + rh - 0.1, zc), Vector3(bx, y0, bz), wc, Vector3(1, 0, 0))
		k.tex = roof_tex
		k.box(Vector3((ax + bx) / 2.0, y0 + rh - 0.05, zc), Vector3(bx - ax + 2 * o, 0.07, 0.1), col.darkened(0.2))
		k.tex = 2
		if style != "desert":
			k.box(Vector3(ax + (bx - ax) * 0.72, y0 + rh * 0.4, zc - span * 0.18), Vector3(0.22, rh * 0.8, 0.22), STONE.darkened(0.2))
	else:
		var xc := (ax + bx) / 2.0
		var a := Vector3(ax - o, y0 - 0.12, az - o)
		var b := Vector3(ax - o, y0 - 0.12, bz + o)
		var c := Vector3(xc, y0 + rh, bz + o)
		var d := Vector3(xc, y0 + rh, az - o)
		var e := Vector3(bx + o, y0 - 0.12, az - o)
		var f := Vector3(bx + o, y0 - 0.12, bz + o)
		k.tex = roof_tex
		k.quad(a, b, c, d, col, Vector3(-1, 1, 0))
		k.quad(e, d, c, f, col.darkened(0.08), Vector3(1, 1, 0))
		k.tex = 4
		k.quad(a, d, c, b, under, Vector3(0.3, -1, 0))
		k.quad(e, f, c, d, under, Vector3(-0.3, -1, 0))
		k.tex = 5 if style != "snow" else 4
		var wc := Color(0.9, 0.86, 0.76) if style != "snow" else Color(0.45, 0.3, 0.18)
		k.tri(Vector3(ax, y0, az), Vector3(xc, y0 + rh - 0.1, az), Vector3(bx, y0, az), wc, Vector3(0, 0, -1))
		k.tri(Vector3(ax, y0, bz), Vector3(xc, y0 + rh - 0.1, bz), Vector3(bx, y0, bz), wc, Vector3(0, 0, 1))
		k.tex = roof_tex
		k.box(Vector3(xc, y0 + rh - 0.05, (az + bz) / 2.0), Vector3(0.1, 0.07, bz - az + 2 * o), col.darkened(0.2))
		k.tex = 2
		k.box(Vector3(xc + span * 0.18, y0 + rh * 0.4, az + (bz - az) * 0.3), Vector3(0.22, rh * 0.8, 0.22), STONE.darkened(0.2))
	k.tex = 0


# ============================================================================
# Drobne konstrukcje
# ============================================================================

## Płot: słupek + żerdzie do sąsiadów (wschód, południe).
static func fence(k: MeshKit, c: Vector3, east: bool, south: bool) -> void:
	k.box(c, Vector3(0.08, 0.6, 0.08), WOOD_DARK, Vector2(0.8, 0.8))
	if east:
		for y in [0.22, 0.45]:
			k.box(c + Vector3(0.5, y, 0), Vector3(1.0, 0.05, 0.04), WOOD)
	if south:
		for y in [0.22, 0.45]:
			k.box(c + Vector3(0, y, 0.5), Vector3(0.04, 0.05, 1.0), WOOD)


## Pole uprawne: rzędy kłosów (kołyszą się na wietrze).
static func crops(f: MeshKit, c: Vector3, r: float) -> void:
	var gold := Color(0.86, 0.72, 0.3).lerp(Color(0.7, 0.66, 0.25), r)
	f.sway_base = c.y
	f.sway_height = 0.5
	for row in 3:
		for i in 4:
			var p := c + Vector3(-0.35 + i * 0.23, 0, -0.3 + row * 0.3)
			var s := Vector3(0.04, 0, 0.02)
			f.blade(p - s, p + s, p + Vector3(0.03, 0.42, 0), gold)
			f.blob(p + Vector3(0.03, 0.44, 0), Vector3(0.03, 0.06, 0.03), gold.lightened(0.1), 2, 4, 0.0)
	f.sway_height = 0.0


## Studnia wiejska.
static func well(k: MeshKit, c: Vector3) -> void:
	k.cyl(c, 0.34, 0.34, 0.4, 8, STONE, true, Color(0.2, 0.35, 0.45))
	for side in [-1, 1]:
		k.box(c + Vector3(side * 0.3, 0.4, 0), Vector3(0.06, 0.6, 0.06), WOOD_DARK)
	k.box(c + Vector3(0, 0.98, 0), Vector3(0.75, 0.05, 0.08), WOOD)
	k.quad(c + Vector3(-0.42, 1.0, -0.3), c + Vector3(0.42, 1.0, -0.3), c + Vector3(0.42, 1.2, 0), c + Vector3(-0.42, 1.2, 0), Color(0.55, 0.25, 0.17), Vector3(0, 1, -1))
	k.quad(c + Vector3(-0.42, 1.0, 0.3), c + Vector3(-0.42, 1.2, 0), c + Vector3(0.42, 1.2, 0), c + Vector3(0.42, 1.0, 0.3), Color(0.5, 0.22, 0.15), Vector3(0, 1, 1))
	k.cyl(c + Vector3(0.1, 0.55, 0), 0.07, 0.08, 0.12, 6, WOOD)


## Fontanna miejska (na bloku 2×2): basen, kolumna, woda.
static func fountain(k: MeshKit, c: Vector3, style: String, with_column := true) -> void:
	var st := STONE.lightened(0.15) if style != "desert" else Color(0.86, 0.74, 0.55)
	k.cyl(c, 0.95, 0.95, 0.35, 12, st, true, st.darkened(0.1))
	k.glow = 0.25
	k.cyl(c + Vector3(0, 0.32, 0), 0.82, 0.82, 0.02, 12, Color(0.35, 0.65, 0.8), true, Color(0.4, 0.72, 0.88))
	k.glow = 0.0
	if not with_column:
		return
	k.cyl(c, 0.14, 0.12, 1.0, 8, st)
	k.cyl(c + Vector3(0, 0.95, 0), 0.4, 0.3, 0.1, 10, st.darkened(0.05), true, Color(0.4, 0.72, 0.88))
	k.metal = 1.0
	k.blob(c + Vector3(0, 1.15, 0), Vector3(0.12, 0.12, 0.12), GOLD, 2, 6, 0.0)
	k.metal = 0.0


## Kolumna ruin (czasem złamana), z bębnem leżącym obok.
static func ruin_pillar(k: MeshKit, c: Vector3, r: float, dark := false) -> void:
	var st := Color(0.74, 0.7, 0.62).lerp(Color(0.62, 0.6, 0.56), r)
	if dark:
		st = Color(0.2, 0.17, 0.2).lerp(Color(0.28, 0.22, 0.24), r)
	k.box(c, Vector3(0.62, 0.14, 0.62), st.darkened(0.1))
	var h := 0.5 + r * 1.4
	var segs := int(h / 0.4) + 1
	for i in segs:
		var sh := minf(0.4, h - i * 0.4)
		if sh <= 0.05:
			break
		k.cyl(c + Vector3(0, 0.14 + i * 0.4, 0), 0.22, 0.21, sh - 0.02, 8, st.lerp(Color(0.4, 0.5, 0.3), 0.25 if i == 0 and not dark else 0.0), true, st.lightened(0.05), r * 3.0)
	if r > 0.75:
		k.box(c + Vector3(0, 0.14 + h, 0), Vector3(0.55, 0.12, 0.55), st)
	elif r < 0.3:
		k.xf = Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), c + Vector3(0.45, 0.2, 0.3))
		k.cyl(Vector3.ZERO, 0.2, 0.2, 0.38, 8, st.darkened(0.05))
		k.xf = Transform3D.IDENTITY


## Posadzka ruin: popękane płyty (część brakuje).
static func ruin_floor(k: MeshKit, x: int, y: int, r1: float, r2: float) -> void:
	for i in 4:
		var h := fmod(r1 * 13.0 + i * 0.37 + r2, 1.0)
		if h < 0.2:
			continue
		var ox := 0.25 + (i % 2) * 0.5
		var oz := 0.25 + (i / 2) * 0.5
		var col := Color(0.66, 0.63, 0.56).lerp(Color(0.5, 0.52, 0.44), h)
		k.box(Vector3(x + ox, 0.0, y + oz), Vector3(0.44, 0.04, 0.44), col, Vector2(0.9, 0.9))


## Most: pokład z desek (lub kamienny nad lawą) z balustradą; along_x = przejście wzdłuż X.
static func bridge(k: MeshKit, x: int, y: int, along_x: bool, rail_a: bool, rail_b: bool, stone: bool) -> void:
	var c := Vector3(x + 0.5, 0.0, y + 0.5)
	var plank := Color(0.52, 0.36, 0.22) if not stone else Color(0.3, 0.28, 0.3)
	for i in 4:
		var col := plank.lerp(plank.darkened(0.2), float((x + y + i) % 3) / 3.0)
		if along_x:
			k.box(c + Vector3(-0.375 + i * 0.25, 0.0, 0), Vector3(0.23, 0.07, 1.0), col)
		else:
			k.box(c + Vector3(0, 0.0, -0.375 + i * 0.25), Vector3(1.0, 0.07, 0.23), col)
	# Podpory w wodzie.
	k.box(c + Vector3(0, -0.6, 0), Vector3(0.14, 0.62, 0.14), WOOD_DARK if not stone else Color(0.2, 0.18, 0.2))
	var rail := WOOD if not stone else Color(0.28, 0.26, 0.28)
	for side in [-1, 1]:
		if (side < 0 and not rail_a) or (side > 0 and not rail_b):
			continue
		var off := Vector3(0, 0, side * 0.47) if along_x else Vector3(side * 0.47, 0, 0)
		k.box(c + off, Vector3(0.07, 0.5, 0.07), rail)
		k.box(c + off + Vector3(0, 0.42, 0), Vector3(1.0 if along_x else 0.06, 0.06, 0.06 if along_x else 1.0), rail)


## Postument obelisku terytorium (kryształ rysuje istota z serwera).
static func obelisk_base(k: MeshKit, c: Vector3) -> void:
	var ob := Color(0.12, 0.1, 0.14)
	k.metal = 0.6
	k.cyl(c, 0.62, 0.55, 0.2, 8, ob, true, ob.lightened(0.05), PI / 8.0)
	k.cyl(c + Vector3(0, 0.2, 0), 0.45, 0.4, 0.2, 8, ob.lightened(0.04), true, ob.lightened(0.08), PI / 8.0)
	k.metal = 0.0
	k.glow = 0.8
	for i in 8:
		var a := i * TAU / 8.0 + PI / 8.0
		var p := c + Vector3(cos(a) * 0.56, 0.1, sin(a) * 0.56)
		var n := Vector3(cos(a), 0, sin(a))
		var t := Vector3(-sin(a), 0, cos(a)) * 0.06
		k.quad(p - t - Vector3(0, 0.05, 0) + n * 0.02, p + t - Vector3(0, 0.05, 0) + n * 0.02, p + t + Vector3(0, 0.05, 0) + n * 0.02, p - t + Vector3(0, 0.05, 0) + n * 0.02, Color(1.0, 0.45, 0.12), n)
	k.glow = 0.0


## Kryształy obsydianu / żaru (Popielisko).
static func crystals(k: MeshKit, c: Vector3, r: float, glowing: bool) -> void:
	var col := Color(0.2, 0.12, 0.3) if not glowing else Color(1.0, 0.45, 0.15)
	k.metal = 0.8
	k.glow = 0.7 if glowing else 0.1
	for i in 3:
		var a := i * TAU / 3.0 + r * 5.0
		var p := c + Vector3(cos(a) * 0.12, 0, sin(a) * 0.12)
		k.xf = Transform3D(Basis(Vector3(sin(a), 0, -cos(a)).normalized(), 0.3 + r * 0.3), p)
		k.cone(Vector3.ZERO, 0.07, 0.3 + fmod(r * 3.0 + i * 0.3, 0.3), 5, col)
	k.xf = Transform3D.IDENTITY
	k.metal = 0.0
	k.glow = 0.0


## Trzcina przy wodzie.
static func reeds(f: MeshKit, c: Vector3, r: float) -> void:
	f.sway_base = c.y
	f.sway_height = 0.8
	for i in 6:
		var a := i * 1.3 + r * 6.0
		var p := c + Vector3(cos(a), 0, sin(a)) * (0.12 + fmod(r * 5.0 + i * 0.21, 0.25))
		var hgt := 0.5 + fmod(r * 3.0 + i * 0.17, 0.4)
		f.blade(p - Vector3(0.025, 0, 0), p + Vector3(0.025, 0, 0), p + Vector3(0.04, hgt, 0.02), Color(0.45, 0.55, 0.25))
		if i % 2 == 0:
			f.blob(p + Vector3(0.04, hgt * 0.85, 0.02), Vector3(0.025, 0.07, 0.025), Color(0.4, 0.26, 0.15), 2, 4, 0.0)
	f.sway_height = 0.0


## Paproć (puszcza).
static func fern(f: MeshKit, c: Vector3, r: float) -> void:
	f.sway_base = c.y
	f.sway_height = 0.4
	var g := Color(0.26, 0.48, 0.2)
	for i in 6:
		var a := i * TAU / 6.0 + r * 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var s := Vector3(-d.z, 0, d.x) * 0.06
		f.blade(c - s, c + s, c + d * 0.38 + Vector3(0, 0.22, 0), g.lightened((i % 2) * 0.08))
	f.sway_height = 0.0


## Grzyby.
static func mushrooms(k: MeshKit, c: Vector3, r: float) -> void:
	var cap := Color(0.8, 0.2, 0.15) if r > 0.5 else Color(0.7, 0.55, 0.35)
	for i in 3:
		var p := c + Vector3(cos(i * 2.1 + r) * 0.12, 0, sin(i * 2.1 + r) * 0.12)
		var hh := 0.08 + i * 0.03
		k.cyl(p, 0.02, 0.02, hh, 5, Color(0.92, 0.9, 0.84), false)
		k.cone(p + Vector3(0, hh, 0), 0.07, 0.05, 6, cap)


## Zwalony pień.
static func log_fallen(k: MeshKit, c: Vector3, r: float) -> void:
	k.xf = Transform3D(Basis(Vector3.UP, r * TAU) * Basis(Vector3(0, 0, 1), PI / 2.0), c + Vector3(0.35, 0.12, 0))
	k.cyl(Vector3.ZERO, 0.12, 0.11, 0.75, 6, WOOD, true, Color(0.7, 0.55, 0.35))
	k.xf = Transform3D.IDENTITY


# ============================================================================
# Budowle miast: cytadela, katedra, pomnik
# ============================================================================

## Kolory budowli miasta: [kamień, dach, sztandar].
static func city_palette(style: String) -> Array:
	match style:
		"snow":
			return [Color(0.6, 0.62, 0.66), Color(0.26, 0.3, 0.42), Color(0.18, 0.28, 0.6)]
		"desert":
			return [Color(0.86, 0.72, 0.5), Color(0.25, 0.58, 0.62), Color(0.1, 0.45, 0.55)]
	return [Color(0.62, 0.59, 0.54), Color(0.62, 0.22, 0.14), Color(0.62, 0.1, 0.08)]


## Okrągła wieża z blankami i dachem (stożek; na pustyni kopuła; w śniegach czapa śniegu).
static func round_tower(k: MeshKit, base: Vector3, r: float, h: float, style: String, flag: bool) -> void:
	var pal := city_palette(style)
	var stone: Color = pal[0]
	k.tex = 2
	k.cyl(base, r * 1.08, r, h, 12, stone, true, stone.darkened(0.15))
	k.cyl(base + Vector3(0, h, 0), r * 1.12, r * 1.12, 0.12, 12, stone.darkened(0.05))
	for i in 8:
		var a := TAU * i / 8.0
		k.box(base + Vector3(cos(a) * r * 1.02, h + 0.12, sin(a) * r * 1.02), Vector3(0.16, 0.22, 0.16), stone)
	k.tex = 0
	# Okna-strzelnice (świecą nocą).
	k.glow = 0.5
	for lvl: float in [0.45, 0.7]:
		for i in 4:
			var a := TAU * i / 4.0 + 0.4 + lvl
			var p := base + Vector3(cos(a) * r * 1.01, h * lvl, sin(a) * r * 1.01)
			var t := Vector3(-sin(a), 0, cos(a)) * 0.04
			k.quad(p - t, p + t, p + t + Vector3(0, 0.22, 0), p - t + Vector3(0, 0.22, 0), Color(1.0, 0.78, 0.42), Vector3(cos(a), 0, sin(a)))
	k.glow = 0.0
	var top := base + Vector3(0, h + 0.1, 0)
	if style == "desert":
		k.metal = 0.35
		k.blob(top + Vector3(0, 0.05, 0), Vector3(r * 0.95, r * 1.1, r * 0.95), pal[1], 4, 12, 0.0)
		k.metal = 1.0
		k.cone(top + Vector3(0, r * 1.05, 0), 0.05, 0.35, 5, GOLD)
		k.metal = 0.0
	else:
		k.tex = 3
		k.cone(top, r * 1.15, h * 0.55 + 0.6, 12, pal[1], 0.1)
		k.tex = 0
		if style == "snow":
			k.tex = 7
			k.cone(top + Vector3(0, (h * 0.55 + 0.6) * 0.55, 0), r * 0.52, (h * 0.55 + 0.6) * 0.45, 12, SNOW, 0.1)
			k.tex = 0
		k.metal = 1.0
		k.cone(top + Vector3(0, h * 0.55 + 0.55, 0), 0.04, 0.3, 4, GOLD)
		k.metal = 0.0
	if flag:
		var ft := top + Vector3(0, (h * 0.55 + 0.9) if style != "desert" else r * 1.4, 0)
		k.cyl(ft, 0.02, 0.02, 0.9, 4, WOOD_DARK)
		for f: int in [1, -1]:
			k.quad(ft + Vector3(0, 0.85, 0), ft + Vector3(0.7, 0.8, 0.05 * f), ft + Vector3(0.7, 0.5, 0.05 * f), ft + Vector3(0, 0.5, 0), pal[2], Vector3(0, 0, f))


## Cytadela: donżon z blankami, cztery narożne wieże, brama, sztandary na murach.
static func citadel(k: MeshKit, x0: int, y0: int, x1: int, y1: int, style: String) -> void:
	var pal := city_palette(style)
	var stone: Color = pal[0]
	var ax := x0 + 0.15
	var az := y0 + 0.15
	var bx := x1 + 0.85
	var bz := y1 + 0.85
	var cx := (ax + bx) / 2.0
	var cz := (az + bz) / 2.0
	k.reset()
	k.tex = 2
	# Mur obronny wokół dziedzińca.
	k.box(Vector3(cx, 0, cz), Vector3(bx - ax, 2.0, bz - az), stone.darkened(0.05), Vector2.ONE, stone.darkened(0.25))
	for i in int((bx - ax) / 0.4):
		for z: float in [az + 0.1, bz - 0.1]:
			k.box(Vector3(ax + 0.2 + i * 0.4, 2.0, z), Vector3(0.2, 0.25, 0.2), stone)
	# Donżon.
	var kw := (bx - ax) * 0.46
	var kd := (bz - az) * 0.56
	k.box(Vector3(cx, 0, cz - 0.1), Vector3(kw, 4.2, kd), stone, Vector2.ONE, stone.darkened(0.2))
	for i in int(kw / 0.35):
		for z: float in [cz - 0.1 - kd / 2 + 0.08, cz - 0.1 + kd / 2 - 0.08]:
			k.box(Vector3(cx - kw / 2 + 0.17 + i * 0.35, 4.2, z), Vector3(0.18, 0.28, 0.16), stone)
	k.tex = 0
	# Okna donżonu.
	k.glow = 0.5
	for lvl: float in [1.4, 2.4, 3.3]:
		for i in 3:
			var p := Vector3(cx - kw * 0.3 + i * kw * 0.3, lvl, cz - 0.1 + kd / 2 + 0.01)
			k.quad(p + Vector3(-0.07, 0, 0), p + Vector3(0.07, 0, 0), p + Vector3(0.07, 0.3, 0), p + Vector3(-0.07, 0.3, 0), Color(1.0, 0.78, 0.42), Vector3(0, 0, 1))
	k.glow = 0.0
	# Brama (od południa).
	k.tex = 4
	k.quad(Vector3(cx - 0.35, 0, bz + 0.01), Vector3(cx + 0.35, 0, bz + 0.01), Vector3(cx + 0.35, 1.1, bz + 0.01), Vector3(cx - 0.35, 1.1, bz + 0.01), WOOD_DARK, Vector3(0, 0, 1))
	k.tex = 0
	k.metal = 1.0
	for i in 4:
		k.box(Vector3(cx - 0.3 + i * 0.2, 0.0, bz + 0.02), Vector3(0.03, 1.08, 0.02), IRON)
	k.metal = 0.0
	# Sztandary na murze.
	for sx: float in [ax + 0.5, bx - 0.5]:
		k.quad(Vector3(sx - 0.18, 1.85, bz + 0.02), Vector3(sx + 0.18, 1.85, bz + 0.02), Vector3(sx + 0.18, 0.95, bz + 0.02), Vector3(sx - 0.18, 0.95, bz + 0.02), pal[2], Vector3(0, 0, 1))
		k.tri(Vector3(sx - 0.18, 0.95, bz + 0.02), Vector3(sx + 0.18, 0.95, bz + 0.02), Vector3(sx, 0.75, bz + 0.02), pal[2], Vector3(0, 0, 1))
		k.metal = 1.0
		k.box(Vector3(sx, 1.35, bz + 0.03), Vector3(0.1, 0.1, 0.01), GOLD)
		k.metal = 0.0
	# Wieże narożne i wieża donżonu.
	for c: Vector3 in [Vector3(ax, 0, az), Vector3(bx, 0, az), Vector3(ax, 0, bz), Vector3(bx, 0, bz)]:
		round_tower(k, c, 0.5, 3.0, style, c.z > cz)
	round_tower(k, Vector3(cx + kw * 0.3, 4.1, cz - 0.1 - kd * 0.2), 0.45, 1.6, style, true)


## Katedra: nawa z dachem, przypory, dzwonnica z iglicą, świecąca rozeta.
static func cathedral(k: MeshKit, x0: int, y0: int, x1: int, y1: int, style: String) -> void:
	var pal := city_palette(style)
	var stone: Color = pal[0].lightened(0.08)
	var ax := x0 + 0.2
	var az := y0 + 0.2
	var bx := x1 + 0.8
	var bz := y1 + 0.8
	var cx := (ax + bx) / 2.0
	var cz := (az + bz) / 2.0
	var hgt := 2.6
	k.reset()
	k.tex = 2
	k.box(Vector3(cx, 0, cz), Vector3(bx - ax, hgt, bz - az), stone)
	# Przypory.
	for i in 4:
		var x := ax + 0.4 + i * ((bx - ax) - 0.8) / 3.0
		for z: float in [az - 0.12, bz + 0.12]:
			k.box(Vector3(x, 0, z), Vector3(0.25, hgt * 0.8, 0.25), stone.darkened(0.08), Vector2(0.7, 0.7))
	k.tex = 0
	# Dach nawy (wzdłuż osi X).
	var o := 0.15
	var rh := (bz - az) * 0.55
	var roof: Color = pal[1]
	k.tex = 3 if style != "snow" else 7
	var rc := roof if style != "snow" else SNOW
	k.quad(Vector3(ax - o, hgt, az - o), Vector3(bx + o, hgt, az - o), Vector3(bx + o, hgt + rh, cz), Vector3(ax - o, hgt + rh, cz), rc, Vector3(0, 1, -1))
	k.quad(Vector3(ax - o, hgt, bz + o), Vector3(ax - o, hgt + rh, cz), Vector3(bx + o, hgt + rh, cz), Vector3(bx + o, hgt, bz + o), rc.darkened(0.08), Vector3(0, 1, 1))
	k.tex = 2
	k.tri(Vector3(ax, hgt, az), Vector3(ax, hgt + rh - 0.05, cz), Vector3(ax, hgt, bz), stone, Vector3(-1, 0, 0))
	k.tri(Vector3(bx, hgt, az), Vector3(bx, hgt + rh - 0.05, cz), Vector3(bx, hgt, bz), stone, Vector3(1, 0, 0))
	# Dzwonnica od frontu (południe) z iglicą.
	var tw := 1.1
	var tx := cx
	var tz := bz - tw / 2.0
	k.box(Vector3(tx, 0, tz), Vector3(tw, hgt + 2.4, tw), stone)
	k.tex = 0
	k.glow = 0.3
	for f: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var p := Vector3(tx, hgt + 1.5, tz) + f * (tw / 2 + 0.01)
		var s := Vector3(f.z, 0, f.x) * 0.15
		k.quad(p - s, p + s, p + s + Vector3(0, 0.55, 0), p - s + Vector3(0, 0.55, 0), Color(0.15, 0.12, 0.1), f)
	k.glow = 0.0
	if style == "desert":
		k.metal = 0.35
		k.blob(Vector3(tx, hgt + 2.4, tz), Vector3(0.6, 0.7, 0.6), roof, 4, 12, 0.0)
		k.metal = 0.0
	else:
		k.tex = 3 if style != "snow" else 7
		k.cone(Vector3(tx, hgt + 2.4, tz), tw * 0.75, 2.2, 8, rc)
		k.tex = 0
	k.metal = 1.0
	k.cone(Vector3(tx, hgt + (4.6 if style != "desert" else 3.1), tz), 0.03, 0.45, 4, GOLD)
	k.box(Vector3(tx, hgt + (4.85 if style != "desert" else 3.35), tz), Vector3(0.28, 0.05, 0.05), GOLD)
	k.metal = 0.0
	# Rozeta nad wejściem.
	k.glow = 0.3
	var rp := Vector3(tx, hgt + 0.7, bz + 0.015)
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := TAU * (i + 1) / 12.0
		var col: Color = [Color(0.9, 0.3, 0.25), Color(0.3, 0.5, 0.95), Color(0.95, 0.8, 0.3)][i % 3]
		k.tri(rp, rp + Vector3(cos(a0), sin(a0), 0) * 0.32, rp + Vector3(cos(a1), sin(a1), 0) * 0.32, col, Vector3(0, 0, 1))
	k.glow = 0.0
	k.tex = 4
	k.quad(Vector3(tx - 0.25, 0, bz + 0.012), Vector3(tx + 0.25, 0, bz + 0.012), Vector3(tx + 0.25, 1.0, bz + 0.012), Vector3(tx - 0.25, 1.0, bz + 0.012), WOOD_DARK, Vector3(0, 0, 1))
	k.tex = 0


## Pomnik bohatera z mieczem na postumencie (środek fontanny).
static func statue(k: MeshKit, c: Vector3) -> void:
	var st := Color(0.68, 0.68, 0.66)
	k.reset()
	k.tex = 2
	k.box(c, Vector3(0.5, 0.7, 0.5), st.darkened(0.1), Vector2(0.9, 0.9))
	k.tex = 0
	var b := c + Vector3(0, 0.7, 0)
	k.metal = 0.3
	for side: int in [-1, 1]:
		k.loft([[b + Vector3(side * 0.07, 0, 0), Vector2(0.045, 0.05)], [b + Vector3(side * 0.07, 0.45, 0), Vector2(0.065, 0.07)]], st, 8)
	k.loft([[b + Vector3(0, 0.42, 0), Vector2(0.14, 0.09)], [b + Vector3(0, 0.7, 0), Vector2(0.16, 0.1)], [b + Vector3(0, 0.82, 0), Vector2(0.18, 0.09)], [b + Vector3(0, 0.88, 0), Vector2(0.05, 0.05)]], st, 10)
	k.ellipsoid(b + Vector3(0, 0.97, 0.01), Vector3(0.07, 0.09, 0.08), st, 5, 8)
	# Peleryna.
	k.quad(b + Vector3(-0.16, 0.85, -0.08), b + Vector3(0.16, 0.85, -0.08), b + Vector3(0.22, 0.1, -0.2), b + Vector3(-0.22, 0.1, -0.2), st.darkened(0.1), Vector3(0, 0, -1))
	# Ręka z mieczem wzniesionym do góry.
	k.loft([[b + Vector3(0.2, 0.8, 0), Vector2(0.04, 0.04)], [b + Vector3(0.24, 1.2, 0.02), Vector2(0.035, 0.035)]], st, 6)
	k.loft([[b + Vector3(-0.2, 0.45, 0.02), Vector2(0.035, 0.035)], [b + Vector3(-0.19, 0.8, 0), Vector2(0.04, 0.04)]], st, 6)
	k.metal = 0.6
	k.box(b + Vector3(0.24, 1.2, 0.02), Vector3(0.16, 0.03, 0.04), st.lightened(0.1))
	k.box(b + Vector3(0.24, 1.22, 0.02), Vector3(0.04, 0.7, 0.012), st.lightened(0.15), Vector2(0.4, 1.0))
	k.metal = 0.0
