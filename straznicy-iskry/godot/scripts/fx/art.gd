class_name Art
extends RefCounted
## Autorska grafika wektorowa rysowana kodem (bez zewnętrznych obrazków).
## Wszystkie postacie mają stopy w punkcie (0, 0) i wysokość ok. 60 px.

const INK := Color("#132a24")
const CREAM := Color("#f5ecd7")
const TEAL := Color("#3fd1c1")
const GOLD := Color("#e8b84a")
const DEEP := Color("#0b231d")
const PANEL := Color("#143a30")
const MIST := Color("#8a5bbf")
const DANGER := Color("#ff5a6e")

static var _glow: Texture2D
## Transformacje składane ręcznie, bo draw_set_transform nie tworzy stosu.
static var _parent := Transform2D.IDENTITY
static var _base := Transform2D.IDENTITY
static var _soft: Texture2D


static func glow_texture() -> Texture2D:
	## Miękka radialna plama światła (używana z mieszaniem addytywnym).
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


static func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.9))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func with_parent(t: Transform2D) -> void:
	_parent = t


static func _tx(ci: CanvasItem, pos: Vector2, rot: float) -> void:
	ci.draw_set_transform_matrix(_base * Transform2D(rot, pos))


static func _reset(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(_base)


# --- Prymitywy -------------------------------------------------------------

static func ellipse(c: Vector2, rx: float, ry: float, n := 20, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline := INK, w := 2.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	if outline.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, w, true)


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, outline := INK, w := 2.0) -> void:
	ci.draw_circle(c, r, fill)
	if outline.a > 0.0:
		ci.draw_arc(c, r, 0, TAU, max(12, int(r * 1.2)), outline, w, true)


static func oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, outline := INK, w := 2.0, rot := 0.0) -> void:
	poly(ci, ellipse(c, rx, ry, 22, rot), fill, outline, w)


static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry := -1.0, a := 0.28) -> void:
	if ry < 0:
		ry = rx * 0.38
	ci.draw_colored_polygon(ellipse(c, rx, ry, 18), Color(0, 0.02, 0.02, a))


static func rrect(r: Rect2, rad: float, seg := 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = min(rad, min(r.size.x, r.size.y) * 0.5)
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI / 2],
		[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
		[r.position + Vector2(rad, r.size.y - rad), PI / 2],
		[r.position + Vector2(rad, rad), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI / 2) * i / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 3.0, outline := true) -> void:
	if outline:
		ci.draw_line(a, b, INK, w + 3.0, true)
	ci.draw_line(a, b, col, w, true)


static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, col)


static func star(c: Vector2, r1: float, r2: float, n := 5, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var r := r1 if i % 2 == 0 else r2
		var a := rot - PI / 2 + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func rune(ci: CanvasItem, c: Vector2, s: float, col: Color, kind := 0, w := 2.0) -> void:
	## Proste, czytelne glify run Tkacza.
	match kind % 4:
		0:
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s, s), c + Vector2(0, -s), c + Vector2(s, s), c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.5, 0)]), col, w, true)
		1:
			ci.draw_arc(c, s, 0.3, TAU - 0.3, 14, col, w, true)
			ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, w, true)
		2:
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(-s, s), c + Vector2(s, s)]), col, w, true)
		3:
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)]), col, w, true)
			ci.draw_circle(c, s * 0.25, col)


# --- Bohaterowie -----------------------------------------------------------

## st: {t, walk, moving, aim(Vector2), attack(0..1), hurt(0..1), dodge(0..1), scale}
static func hero(ci: CanvasItem, class_id: String, st: Dictionary) -> void:
	var t: float = st.get("t", 0.0)
	var walk: float = st.get("walk", 0.0)
	var moving: bool = st.get("moving", false)
	var aim: Vector2 = st.get("aim", Vector2.RIGHT)
	var attack: float = st.get("attack", 0.0)
	var dodge: float = st.get("dodge", 0.0)
	var hurt: float = st.get("hurt", 0.0)
	var reduced: bool = st.get("reduced", false)
	var face := -1.0 if aim.x < -0.05 else 1.0
	var breath := sin(t * 2.4) * (0.8 if reduced else 1.6)
	var bob := absf(sin(walk * 2.0)) * -3.0 if moving else breath * 0.5
	var leg := sin(walk * 2.0) * 5.0 if moving else 0.0
	ci.draw_set_transform_matrix(_parent)
	shadow(ci, Vector2(0, 0), 15, 5.5)
	var sq := Vector2(1.0 + dodge * 0.25, 1.0 - dodge * 0.3)
	_base = _parent * Transform2D(dodge * TAU * face, Vector2(face * sq.x, sq.y), 0.0, Vector2(0, bob))
	ci.draw_set_transform_matrix(_base)
	var p := palette(class_id)
	# Nogi
	poly(ci, rrect(Rect2(-8 + leg * 0.4, -12, 6, 12), 3), p.leg)
	poly(ci, rrect(Rect2(2 - leg * 0.4, -12, 6, 12), 3), p.leg)
	match class_id:
		"tkacz": _tkacz(ci, t, breath, attack, aim, face, p, reduced)
		"mechanik": _mechanik(ci, t, breath, attack, aim, face, p, reduced)
		"tropiciel": _tropiciel(ci, t, breath, attack, aim, face, p, reduced, moving, walk)
		_: _straznik(ci, t, breath, attack, aim, face, p, reduced)
	if hurt > 0.0:
		# Krótki błysk po trafieniu.
		ci.draw_circle(Vector2(0, -28), 22, Color(1, 0.4, 0.45, hurt * 0.45))
	ci.draw_set_transform_matrix(_parent)


static func palette(class_id: String) -> Dictionary:
	match class_id:
		"tkacz":
			return {"main": Color("#6b3fa0"), "dark": Color("#47286e"), "acc": GOLD, "skin": Color("#f2c9a0"), "leg": Color("#3a2257"), "glow": Color("#c89bff")}
		"mechanik":
			return {"main": Color("#d98a2b"), "dark": Color("#a35f17"), "acc": Color("#2fc4b2"), "skin": Color("#c98f62"), "leg": Color("#4b3a2a"), "glow": Color("#5ef2e0")}
		"tropiciel":
			return {"main": Color("#3d8f4f"), "dark": Color("#28643a"), "acc": Color("#4aa8e8"), "skin": Color("#e8b98d"), "leg": Color("#2c3d2c"), "glow": Color("#8fe0ff")}
		_:
			return {"main": Color("#27417a"), "dark": Color("#1a2c55"), "acc": Color("#c9d3df"), "skin": Color("#8d5a3b"), "leg": Color("#1d2540"), "glow": Color("#9fc7ff")}


static func _head(ci: CanvasItem, c: Vector2, p: Dictionary, look: float) -> void:
	circle(ci, c, 11.5, p.skin)
	# Oczy patrzą w stronę celowania.
	var e := Vector2(3.5 + look * 1.5, -0.5)
	ci.draw_circle(c + e, 1.8, INK)
	ci.draw_circle(c + e + Vector2(-6, 0), 1.8, INK)
	ci.draw_circle(c + Vector2(4.5, 4), 2.2, Color(1, 0.55, 0.5, 0.35))


static func _tkacz(ci: CanvasItem, t: float, br: float, atk: float, aim: Vector2, face: float, p: Dictionary, reduced: bool) -> void:
	# Szata
	var robe := PackedVector2Array([Vector2(-14, -6), Vector2(14, -6), Vector2(9, -34 - br * 0.3), Vector2(-9, -34 - br * 0.3)])
	poly(ci, robe, p.main)
	poly(ci, PackedVector2Array([Vector2(-14, -6), Vector2(14, -6), Vector2(13, -10), Vector2(-13, -10)]), p.acc, INK, 1.5)
	ci.draw_line(Vector2(0, -32), Vector2(0, -10), p.acc, 2.0, true)
	rune(ci, Vector2(0, -22), 3.5, p.acc, 3, 1.6)
	var hc := Vector2(1, -44 - br * 0.4)
	_head(ci, hc, p, 0.0)
	# Kaptur ze szpicem
	poly(ci, PackedVector2Array([hc + Vector2(-13, 4), hc + Vector2(-12, -8), hc + Vector2(-4, -15), hc + Vector2(-10, -24), hc + Vector2(6, -14), hc + Vector2(13, -4), hc + Vector2(13, 2), hc + Vector2(8, -6), hc + Vector2(-6, -7)]), p.dark)
	ci.draw_arc(hc, 12, PI * 1.05, PI * 1.95, 10, p.acc, 1.6, true)
	# Lewitująca księga
	var ang := aim.angle() if face > 0 else PI - aim.angle()
	var bp := Vector2(18, -30 + sin(t * 2.0) * 3.0) + Vector2(atk * 8, 0)
	_tx(ci, bp, 0.0)
	if not reduced:
		glow(ci, Vector2.ZERO, 18 + atk * 10, Color(p.glow, 0.35 + atk * 0.4))
	poly(ci, rrect(Rect2(-9, -7, 18, 13), 2), Color("#5a2f86"))
	poly(ci, PackedVector2Array([Vector2(-8, -6), Vector2(0, -4), Vector2(8, -6), Vector2(8, 4), Vector2(0, 6), Vector2(-8, 4)]), CREAM, INK, 1.2)
	ci.draw_line(Vector2(0, -4), Vector2(0, 6), INK, 1.0)
	rune(ci, Vector2(-4, 0), 2.0, p.dark, int(t * 2.0), 1.2)
	_reset(ci)
	# Orbitujące runy
	for i in 2:
		var a := t * 1.6 + i * PI
		var rp := Vector2(cos(a) * 20, -24 + sin(a) * 7)
		rune(ci, rp, 2.6, Color(p.glow, 0.85), i + int(t), 1.6)
	var _u := ang


static func _mechanik(ci: CanvasItem, t: float, br: float, atk: float, aim: Vector2, face: float, p: Dictionary, reduced: bool) -> void:
	# Plecak z cewką
	poly(ci, rrect(Rect2(-17, -36, 10, 20), 3), Color("#6b5640"))
	ci.draw_circle(Vector2(-12, -30), 3.5, p.acc)
	if not reduced:
		glow(ci, Vector2(-12, -30), 10 + sin(t * 5.0) * 2.0, Color(p.glow, 0.5))
	# Kurtka
	poly(ci, rrect(Rect2(-11, -34 - br * 0.3, 22, 25), 6), p.main)
	poly(ci, PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(11, -10), Vector2(-11, -10)]), Color("#5b4128"), INK, 1.5)
	ci.draw_circle(Vector2(5, -12), 2.2, GOLD)
	ci.draw_line(Vector2(0, -33), Vector2(0, -15), p.dark, 2.0, true)
	var hc := Vector2(1, -45 - br * 0.4)
	_head(ci, hc, p, 0.0)
	# Włosy i gogle
	poly(ci, PackedVector2Array([hc + Vector2(-12, -2), hc + Vector2(-9, -11), hc + Vector2(0, -14), hc + Vector2(10, -10), hc + Vector2(12, -3), hc + Vector2(4, -7), hc + Vector2(-4, -6)]), Color("#3b2414"))
	ci.draw_line(hc + Vector2(-12, -6), hc + Vector2(12, -6), INK, 3.0)
	circle(ci, hc + Vector2(-3, -7), 4.0, Color("#1f6f6a"), INK, 1.6)
	circle(ci, hc + Vector2(6, -7), 4.0, Color("#1f6f6a"), INK, 1.6)
	ci.draw_circle(hc + Vector2(-4, -8), 1.4, Color(p.glow, 0.9))
	ci.draw_circle(hc + Vector2(5, -8), 1.4, Color(p.glow, 0.9))
	# Klucz energetyczny
	var swing := -1.2 + atk * 2.2
	var hand := Vector2(12, -22)
	_tx(ci, hand, swing)
	line(ci, Vector2.ZERO, Vector2(0, -22), Color("#9aa4ad"), 4.0)
	poly(ci, PackedVector2Array([Vector2(-6, -22), Vector2(-7, -30), Vector2(-2, -27), Vector2(2, -27), Vector2(7, -30), Vector2(6, -22)]), Color("#b8c2cc"))
	ci.draw_circle(Vector2(0, -24), 2.5, p.acc)
	if atk > 0.0 and not reduced:
		glow(ci, Vector2(0, -26), 16, Color(p.glow, atk * 0.8))
	_reset(ci)
	circle(ci, hand, 3.5, p.skin, INK, 1.5)


static func _tropiciel(ci: CanvasItem, t: float, br: float, atk: float, aim: Vector2, face: float, p: Dictionary, reduced: bool, moving: bool, walk: float) -> void:
	# Peleryna
	var flap := sin(t * 3.0 + walk) * (3.0 if moving else 1.2)
	poly(ci, PackedVector2Array([Vector2(-8, -36), Vector2(8, -36), Vector2(4, -6), Vector2(-15 - flap, -4), Vector2(-14, -20)]), p.dark)
	poly(ci, rrect(Rect2(-10, -34 - br * 0.3, 20, 25), 7), p.main)
	ci.draw_line(Vector2(-8, -16), Vector2(9, -14), Color("#6b4a2a"), 3.0, true)
	var hc := Vector2(1, -45 - br * 0.4)
	_head(ci, hc, p, 0.0)
	# Kaptur zaokrąglony
	ci.draw_arc(hc, 12.5, PI * 0.95, PI * 2.05, 16, p.dark, 5.0, true)
	poly(ci, PackedVector2Array([hc + Vector2(-13, 0), hc + Vector2(-16, 8), hc + Vector2(-10, 6)]), p.dark)
	# Szal
	poly(ci, PackedVector2Array([Vector2(-9, -35), Vector2(10, -35), Vector2(9, -30), Vector2(-9, -30)]), p.acc, INK, 1.5)
	poly(ci, PackedVector2Array([Vector2(-8, -33), Vector2(-20 - flap * 2, -28 + flap), Vector2(-18 - flap * 2, -24 + flap), Vector2(-6, -30)]), p.acc, INK, 1.5)
	# Skaner-monokl
	circle(ci, hc + Vector2(5, -1), 3.5, Color(p.glow, 0.6), INK, 1.4)
	if not reduced:
		glow(ci, hc + Vector2(5, -1), 8, Color(p.glow, 0.4 + 0.2 * sin(t * 4.0)))
	# Łuk światła skierowany w cel
	var ang := atan2(aim.y, absf(aim.x))
	var hand := Vector2(10, -24)
	_tx(ci, hand, ang)
	ci.draw_arc(Vector2(-4, 0), 15, -PI * 0.42, PI * 0.42, 12, INK, 5.0, true)
	ci.draw_arc(Vector2(-4, 0), 15, -PI * 0.42, PI * 0.42, 12, Color("#8fd3a0"), 2.5, true)
	var draw_back := -6.0 * atk
	ci.draw_polyline(PackedVector2Array([Vector2(1, -14), Vector2(-4 + draw_back, 0), Vector2(1, 14)]), Color(p.glow, 0.9), 1.2, true)
	if atk > 0.0:
		ci.draw_line(Vector2(-4 + draw_back, 0), Vector2(14, 0), Color(p.glow), 2.0, true)
	_reset(ci)
	circle(ci, hand, 3.5, p.skin, INK, 1.5)


static func _straznik(ci: CanvasItem, t: float, br: float, atk: float, aim: Vector2, face: float, p: Dictionary, reduced: bool) -> void:
	# Pancerz
	poly(ci, rrect(Rect2(-13, -35 - br * 0.3, 26, 27), 7), p.main)
	poly(ci, PackedVector2Array([Vector2(-6, -30), Vector2(6, -30), Vector2(4, -18), Vector2(0, -14), Vector2(-4, -18)]), p.acc, INK, 1.5)
	circle(ci, Vector2(-13, -31), 6.0, p.acc, INK, 1.8)
	circle(ci, Vector2(13, -31), 6.0, p.acc, INK, 1.8)
	var hc := Vector2(1, -46 - br * 0.4)
	_head(ci, hc, p, 0.0)
	# Hełm z pióropuszem
	poly(ci, PackedVector2Array([hc + Vector2(-13, -1), hc + Vector2(-12, -9), hc + Vector2(-5, -14), hc + Vector2(6, -14), hc + Vector2(12, -9), hc + Vector2(13, -1), hc + Vector2(8, -4), hc + Vector2(-8, -4)]), p.acc)
	poly(ci, PackedVector2Array([hc + Vector2(-2, -13), hc + Vector2(-8, -24), hc + Vector2(2, -27), hc + Vector2(4, -14)]), Color("#3a5fb0"))
	# Młot
	var swing := -0.9 + atk * 2.6
	var hand := Vector2(12, -20)
	_tx(ci, hand, swing)
	line(ci, Vector2(0, 4), Vector2(0, -22), Color("#6b4a2a"), 3.5)
	poly(ci, rrect(Rect2(-8, -32, 16, 11), 3), Color("#aeb8c4"))
	ci.draw_line(Vector2(-5, -27), Vector2(5, -27), p.main, 2.0)
	if atk > 0.0 and not reduced:
		glow(ci, Vector2(0, -27), 18, Color(p.glow, atk * 0.8))
	_reset(ci)
	circle(ci, hand, 3.8, p.skin, INK, 1.5)
	# Tarcza na drugim ramieniu
	var sp := Vector2(-14, -20)
	circle(ci, sp, 10.0, Color("#c9d3df"))
	circle(ci, sp, 6.5, p.main, INK, 1.5)
	poly(ci, star(sp, 4.0, 1.8, 4, t * 0.0), p.acc, Color(0, 0, 0, 0))
	if not reduced:
		glow(ci, sp, 14, Color(p.glow, 0.18 + 0.08 * sin(t * 3.0)))


# --- BLIK ------------------------------------------------------------------

static func blik(ci: CanvasItem, t: float, mood: String, talk: float, reduced := false) -> void:
	var bob := sin(t * 3.0) * (1.5 if reduced else 3.5)
	var c := Vector2(0, -34 + bob)
	shadow(ci, Vector2(0, 0), 8, 3, 0.18)
	if not reduced:
		glow(ci, c, 30, Color(TEAL, 0.28))
	# Płomień napędu
	var fl := 5.0 + sin(t * 18.0) * 1.5
	poly(ci, PackedVector2Array([c + Vector2(-4, 9), c + Vector2(4, 9), c + Vector2(0, 9 + fl)]), Color(GOLD, 0.9), Color(0, 0, 0, 0))
	# Antena
	ci.draw_line(c + Vector2(0, -11), c + Vector2(2, -19), INK, 2.0, true)
	ci.draw_circle(c + Vector2(2, -20), 3.0, GOLD)
	if mood == "cheer" or mood == "happy":
		ci.draw_circle(c + Vector2(2, -20), 5.0, Color(GOLD, 0.35))
	# Korpus
	circle(ci, c, 11.5, CREAM)
	ci.draw_arc(c, 11.5, PI * 0.15, PI * 0.85, 10, Color("#d9cdb0"), 3.0, true)
	poly(ci, rrect(Rect2(c + Vector2(-8, -6), Vector2(16, 9)), 4), Color("#16302a"), INK, 1.5)
	var eye := c + Vector2(0, -1.5)
	var ec := TEAL
	match mood:
		"happy", "cheer":
			ci.draw_arc(eye + Vector2(-3, 1.5), 2.5, PI, TAU, 8, ec, 2.0, true)
			ci.draw_arc(eye + Vector2(3, 1.5), 2.5, PI, TAU, 8, ec, 2.0, true)
		"surprised":
			ci.draw_circle(eye, 3.6, ec)
			ci.draw_circle(eye, 1.6, Color("#16302a"))
		"worried":
			ci.draw_line(eye + Vector2(-5, -1), eye + Vector2(-1, 1), ec, 2.0, true)
			ci.draw_line(eye + Vector2(5, -1), eye + Vector2(1, 1), ec, 2.0, true)
		"thinking":
			ci.draw_line(eye + Vector2(-4, 0), eye + Vector2(4, 0), ec, 2.0, true)
			for i in 3:
				ci.draw_circle(c + Vector2(13 + i * 4, -12 - i * 3), 1.2 + i * 0.4, Color(CREAM, 0.8))
		_:
			var blink := fmod(t, 3.7) < 0.12
			if blink:
				ci.draw_line(eye + Vector2(-4, 0), eye + Vector2(4, 0), ec, 2.0)
			else:
				ci.draw_circle(eye + Vector2(-3, 0), 2.0, ec)
				ci.draw_circle(eye + Vector2(3, 0), 2.0, ec)
	if talk > 0.0:
		var m := absf(sin(t * 16.0)) * 1.6
		ci.draw_line(c + Vector2(-2, 5), c + Vector2(2, 5), Color(TEAL, 0.9), 1.0 + m)
	# Uszka-panele
	poly(ci, PackedVector2Array([c + Vector2(-11, -3), c + Vector2(-16, -6), c + Vector2(-15, 2), c + Vector2(-11, 2)]), GOLD, INK, 1.4)
	poly(ci, PackedVector2Array([c + Vector2(11, -3), c + Vector2(16, -6), c + Vector2(15, 2), c + Vector2(11, 2)]), GOLD, INK, 1.4)
	if mood == "cheer" and not reduced:
		for i in 4:
			var a := t * 3.0 + i * PI / 2
			poly(ci, star(c + Vector2(cos(a), sin(a)) * 20, 3.0, 1.2, 4), GOLD, Color(0, 0, 0, 0))


# --- Przeciwnicy ------------------------------------------------------------

## st: {t, tele(0..1), hurt, aim, dying(0..1), fake_flags}
static func enemy(ci: CanvasItem, kind: String, st: Dictionary) -> void:
	match kind:
		"szumik": _szumik(ci, st)
		"zaklocacz": _zaklocacz(ci, st)
		"golem": _golem(ci, st)
		"miraz", "miraz_copy": _miraz(ci, st)
		_: _szumik(ci, st)


static func _szumik(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.get("t", 0.0)
	var tele: float = st.get("tele", 0.0)
	var hurt: float = st.get("hurt", 0.0)
	shadow(ci, Vector2.ZERO, 12, 4, 0.22)
	var c := Vector2(0, -20 + sin(t * 4.0) * 3.0)
	var pts := PackedVector2Array()
	var n := 16
	for i in n:
		var a := TAU * i / n
		var r := 13.0 + sin(a * 3.0 + t * 6.0) * 2.0 + tele * 3.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.9))
	var body := Color("#5b4a7a").lerp(DANGER, tele * 0.6)
	glow(ci, c, 26 + tele * 10, Color(MIST, 0.35 + tele * 0.3))
	poly(ci, pts, body, Color("#2a1f3d"), 2.0)
	ci.draw_circle(c + Vector2(-4, -2), 2.6 + tele, Color("#ff7ad9"))
	ci.draw_circle(c + Vector2(4, -2), 2.6 + tele, Color("#ff7ad9"))
	# Ogonek mgły
	for i in 3:
		ci.draw_circle(c + Vector2(-8 - i * 5, 8 + i * 2 + sin(t * 5.0 + i) * 2), 3.5 - i, Color(MIST, 0.5 - i * 0.12))
	if hurt > 0.0:
		ci.draw_colored_polygon(pts, Color(1, 1, 1, hurt * 0.7))


static func _zaklocacz(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.get("t", 0.0)
	var tele: float = st.get("tele", 0.0)
	var hurt: float = st.get("hurt", 0.0)
	var aim: Vector2 = st.get("aim", Vector2.RIGHT)
	shadow(ci, Vector2.ZERO, 14, 5, 0.22)
	var c := Vector2(0, -30 + sin(t * 2.0) * 4.0)
	glow(ci, c, 30 + tele * 16, Color(Color("#b06bff"), 0.3 + tele * 0.4))
	# Pierścień z pęknięciami
	ci.draw_arc(c, 16, 0, TAU, 24, INK, 7.0, true)
	ci.draw_arc(c, 16, 0, TAU, 24, Color("#7d7f8c"), 4.0, true)
	for i in 3:
		var a := t * 0.8 + i * TAU / 3
		poly(ci, PackedVector2Array([c + Vector2(cos(a), sin(a)) * 13, c + Vector2(cos(a + 0.2), sin(a + 0.2)) * 22, c + Vector2(cos(a - 0.2), sin(a - 0.2)) * 22]), Color("#5c5e6b"), INK, 1.5)
	circle(ci, c, 11, Color("#e9e2ff"))
	var pupil := c + aim.normalized() * 4.0
	ci.draw_circle(pupil, 5.0 + tele * 1.5, Color("#8a2be2").lerp(DANGER, tele))
	ci.draw_circle(pupil, 2.0, INK)
	ci.draw_line(c + Vector2(0, -16), c + Vector2(-3, -26), INK, 2.0)
	ci.draw_circle(c + Vector2(-3, -27), 2.5, Color("#ff7ad9"))
	if hurt > 0.0:
		ci.draw_circle(c, 17, Color(1, 1, 1, hurt * 0.6))


static func _golem(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.get("t", 0.0)
	var tele: float = st.get("tele", 0.0)
	var hurt: float = st.get("hurt", 0.0)
	var moving: bool = st.get("moving", false)
	shadow(ci, Vector2.ZERO, 26, 9, 0.3)
	var step := sin(t * 5.0) * 3.0 if moving else 0.0
	var lift := -tele * 8.0
	poly(ci, rrect(Rect2(-18 + step, -16, 12, 16), 3), Color("#4a4d5c"))
	poly(ci, rrect(Rect2(6 - step, -16, 12, 16), 3), Color("#4a4d5c"))
	var body := rrect(Rect2(-24, -58 + lift * 0.3, 48, 44), 9)
	poly(ci, body, Color("#6b6f82"), INK, 2.5)
	# Pęknięcia z mgłą
	ci.draw_polyline(PackedVector2Array([Vector2(-14, -50), Vector2(-8, -40), Vector2(-14, -30)]), Color(MIST, 0.9), 2.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(12, -52), Vector2(8, -44), Vector2(14, -34)]), Color(MIST, 0.9), 2.0, true)
	var core := Vector2(0, -38 + lift * 0.3)
	glow(ci, core, 20 + tele * 14, Color(Color("#b06bff").lerp(DANGER, tele), 0.6))
	circle(ci, core, 6 + tele * 2, Color("#d6b3ff").lerp(DANGER, tele), INK, 1.5)
	# Głowa i oko-wizjer
	poly(ci, rrect(Rect2(-12, -72 + lift * 0.5, 24, 15), 5), Color("#585c6e"), INK, 2.0)
	ci.draw_line(Vector2(-7, -65 + lift * 0.5), Vector2(7, -65 + lift * 0.5), Color("#ff7ad9").lerp(DANGER, tele), 3.0)
	# Ramiona uniesione przy zapowiedzi ataku
	var arm_y := -48 + lift * 2.0
	poly(ci, rrect(Rect2(-36, arm_y, 12, 26), 5), Color("#5d6173"))
	poly(ci, rrect(Rect2(24, arm_y, 12, 26), 5), Color("#5d6173"))
	if hurt > 0.0:
		ci.draw_colored_polygon(body, Color(1, 1, 1, hurt * 0.6))


static func _miraz(ci: CanvasItem, st: Dictionary) -> void:
	var t: float = st.get("t", 0.0)
	var tele: float = st.get("tele", 0.0)
	var hurt: float = st.get("hurt", 0.0)
	var has_shadow: bool = st.get("shadow", true)
	var blinks: bool = st.get("blinks", true)
	var shimmer: float = st.get("shimmer", 0.0)
	var revealed: float = st.get("revealed", 0.0)
	if has_shadow:
		shadow(ci, Vector2.ZERO, 30, 10, 0.32)
	var c := Vector2(0, -60 + sin(t * 1.6) * 5.0)
	glow(ci, c, 70 + tele * 20, Color(Color("#9b6bff").lerp(DANGER, tele * 0.5), 0.35))
	# Płaszcz z falującym brzegiem
	var pts := PackedVector2Array([c + Vector2(-14, -22)])
	for i in 9:
		var x := -30.0 + i * 7.5
		pts.append(c + Vector2(x, 48 + sin(t * 4.0 + i) * 4.0))
	pts.append(c + Vector2(14, -22))
	var cloak := Color("#3b2a66").lerp(Color("#2a6f7a"), 0.5 + 0.5 * sin(t * 0.7))
	poly(ci, pts, cloak, INK, 2.5)
	# Maska
	var mask := PackedVector2Array([c + Vector2(-13, -38), c + Vector2(13, -38), c + Vector2(11, -20), c + Vector2(0, -10), c + Vector2(-11, -20)])
	poly(ci, mask, Color("#efe6ff"), INK, 2.0)
	var eye_open := true
	if blinks:
		eye_open = fmod(t, 2.2) > 0.18
	var ecol := Color("#ff7ad9").lerp(DANGER, tele)
	if eye_open:
		ci.draw_circle(c + Vector2(-5, -27), 2.8, ecol)
		ci.draw_circle(c + Vector2(5, -27), 2.8, ecol)
	else:
		ci.draw_line(c + Vector2(-8, -27), c + Vector2(-2, -27), ecol, 2.0)
		ci.draw_line(c + Vector2(2, -27), c + Vector2(8, -27), ecol, 2.0)
	# Korona z odłamków lustra
	for i in 5:
		var a := -PI / 2 + (i - 2) * 0.38
		var base := c + Vector2(cos(a), sin(a)) * 18 + Vector2(0, -24)
		poly(ci, PackedVector2Array([base, base + Vector2(cos(a), sin(a)) * 12 + Vector2(-3, 0), base + Vector2(cos(a), sin(a)) * 12 + Vector2(3, 0)]), Color("#bfe9ff"), INK, 1.2)
	# Orbitujące odłamki
	for i in 4:
		var a := t * 1.2 + i * TAU / 4
		var sp := c + Vector2(cos(a) * 46, sin(a) * 18)
		poly(ci, PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(4, 0), sp + Vector2(0, 7), sp + Vector2(-4, 0)]), Color("#bfe9ff", 0.85), INK, 1.2)
	if shimmer > 0.0:
		ci.draw_colored_polygon(pts, Color(0.75, 0.9, 1.0, shimmer * 0.35))
	if revealed > 0.0:
		ci.draw_arc(c + Vector2(0, 8), 52, 0, TAU, 40, Color(GOLD, revealed), 4.0, true)
	if hurt > 0.0:
		ci.draw_colored_polygon(pts, Color(1, 1, 1, hurt * 0.6))


# --- Portrety do dialogów -------------------------------------------------

static func portrait(ci: CanvasItem, who: String, t: float, center: Vector2, s: float) -> void:
	_parent = Transform2D(0.0, Vector2(s, s), 0.0, center)
	ci.draw_set_transform_matrix(_parent)
	match who:
		"blik":
			blik(ci, t, "happy", 1.0)
		"lumi", "fela", "tosia", "sowa", "zarzadca":
			npc(ci, who, t, false)
		"miraz":
			_miraz(ci, {"t": t})
		_:
			if who in ["tkacz", "mechanik", "tropiciel", "straznik"]:
				hero(ci, who, {"t": t})
			else:
				blik(ci, t, "idle", 0.0)
	_parent = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(_parent)


static func npc(ci: CanvasItem, who: String, t: float, talking: bool) -> void:
	var br := sin(t * 2.0) * 1.2
	shadow(ci, Vector2.ZERO, 15, 5.5)
	match who:
		"lumi":
			# Latarniczka: długi płaszcz w kolorze kremu, latarenka.
			poly(ci, PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(10, -36 - br), Vector2(-10, -36 - br)]), Color("#e9dcc0"))
			poly(ci, PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(14, -5), Vector2(-14, -5)]), TEAL, INK, 1.5)
			var hc := Vector2(0, -46 - br)
			circle(ci, hc, 11.5, Color("#d9a27a"))
			ci.draw_arc(hc, 12.5, PI * 0.9, PI * 2.1, 16, Color("#c7c9cf"), 6.0, true)
			poly(ci, PackedVector2Array([hc + Vector2(-12, 0), hc + Vector2(-15, 18), hc + Vector2(-8, 4)]), Color("#c7c9cf"))
			ci.draw_circle(hc + Vector2(-3, 0), 1.6, INK)
			ci.draw_circle(hc + Vector2(4, 0), 1.6, INK)
			ci.draw_line(Vector2(14, -24), Vector2(18, -14), INK, 2.0)
			glow(ci, Vector2(18, -10), 18, Color(GOLD, 0.55 + 0.15 * sin(t * 3.0)))
			poly(ci, rrect(Rect2(14, -16, 9, 11), 2), GOLD, INK, 1.5)
		"fela":
			# Ogrodniczka: kapelusz słomkowy, fartuch.
			poly(ci, rrect(Rect2(-12, -34 - br, 24, 32), 7), Color("#8fbf6a"))
			poly(ci, rrect(Rect2(-8, -26, 16, 20), 3), Color("#e9dcc0"), INK, 1.5)
			var hc := Vector2(0, -44 - br)
			circle(ci, hc, 11, Color("#f0c39a"))
			oval(ci, hc + Vector2(0, -7), 20, 6, Color("#e8c46a"))
			oval(ci, hc + Vector2(0, -11), 10, 6, Color("#e8c46a"))
			ci.draw_circle(hc + Vector2(8, -10), 3, Color("#ff7a8a"))
			ci.draw_circle(hc + Vector2(-3, 1), 1.6, INK)
			ci.draw_circle(hc + Vector2(4, 1), 1.6, INK)
		"tosia":
			# Mechaniczka warsztatu: kombinezon, chusta.
			poly(ci, rrect(Rect2(-12, -34 - br, 24, 32), 6), Color("#3f7f9a"))
			ci.draw_line(Vector2(-6, -32), Vector2(-6, -8), Color("#2b5a6e"), 2.0)
			var hc := Vector2(0, -44 - br)
			circle(ci, hc, 11, Color("#a8704f"))
			poly(ci, PackedVector2Array([hc + Vector2(-12, -2), hc + Vector2(-10, -10), hc + Vector2(10, -10), hc + Vector2(12, -2)]), Color("#e05a4f"))
			ci.draw_circle(hc + Vector2(13, -6), 3, Color("#e05a4f"))
			ci.draw_circle(hc + Vector2(-3, 1), 1.6, INK)
			ci.draw_circle(hc + Vector2(4, 1), 1.6, INK)
			line(ci, Vector2(13, -18), Vector2(20, -4), Color("#9aa4ad"), 3.0)
		"sowa":
			# Archiwista — mądra sowa w okularach.
			oval(ci, Vector2(0, -26 - br), 17, 22, Color("#8a6a4a"))
			oval(ci, Vector2(0, -20 - br), 11, 14, Color("#d9c3a0"), INK, 1.5)
			var hc := Vector2(0, -42 - br)
			circle(ci, hc + Vector2(-6, 0), 6, CREAM, INK, 1.5)
			circle(ci, hc + Vector2(6, 0), 6, CREAM, INK, 1.5)
			ci.draw_circle(hc + Vector2(-6, 0), 2.5, INK)
			ci.draw_circle(hc + Vector2(6, 0), 2.5, INK)
			ci.draw_arc(hc + Vector2(-6, 0), 7.5, 0, TAU, 14, GOLD, 1.5, true)
			ci.draw_arc(hc + Vector2(6, 0), 7.5, 0, TAU, 14, GOLD, 1.5, true)
			poly(ci, PackedVector2Array([hc + Vector2(-3, 6), hc + Vector2(3, 6), hc + Vector2(0, 11)]), GOLD, INK, 1.2)
			poly(ci, PackedVector2Array([hc + Vector2(-14, -6), hc + Vector2(-10, -16), hc + Vector2(-6, -7)]), Color("#8a6a4a"))
			poly(ci, PackedVector2Array([hc + Vector2(14, -6), hc + Vector2(10, -16), hc + Vector2(6, -7)]), Color("#8a6a4a"))
		_:
			# Zarządca mostów i inni mieszkańcy.
			poly(ci, rrect(Rect2(-12, -34 - br, 24, 32), 6), Color("#7a5a9a"))
			var hc := Vector2(0, -44 - br)
			circle(ci, hc, 11, Color("#e0b08a"))
			poly(ci, rrect(Rect2(hc.x - 10, hc.y - 16, 20, 7), 2), INK)
			ci.draw_circle(hc + Vector2(-3, 1), 1.6, INK)
			ci.draw_circle(hc + Vector2(4, 1), 1.6, INK)
	if talking:
		ci.draw_circle(Vector2(0, -68), 3, Color(CREAM, 0.6 + 0.4 * sin(t * 8.0)))
