extends Node2D
## Statyczne dekoracje (drzewa, skały, kryształy, regały, maszyny...).
## Rysowane raz; animowane tylko te, które tego potrzebują.

const COLLIDE := {
	"tree": 18.0, "pine": 14.0, "rock": 20.0, "crystal": 14.0, "pillar": 16.0, "lamp": 8.0,
	"bookshelf": 26.0, "machine": 30.0, "crate": 16.0, "statue": 20.0, "stump": 12.0,
	"pipe": 12.0, "gear": 22.0, "tower": 70.0, "archive_desk": 24.0, "tank": 24.0,
}
const ANIMATED := ["crystal", "lamp", "machine", "gear", "tower", "flag"]

var kind := "tree"
var s := 1.0
var seed_value := 0
var variant := 0.0
var t := 0.0
var lit := false
# Animacje bez przerysowywania (transformacje i modulacja węzłów potomnych).
var _glow: Sprite2D
var _spin: Node2D
var _beam: Node2D
var _cloth: Node2D


func setup(def: Dictionary) -> void:
	kind = def.get("type", "tree")
	s = float(def.get("scale", 1.0))
	seed_value = int(position.x * 13 + position.y * 7)
	variant = fposmod(seed_value * 0.6180339, 1.0)
	var lit_flag: String = def.get("lit", "")
	lit = GameState.flags_met(lit_flag)
	set_process(kind in ANIMATED)
	if not lit_flag.is_empty():
		GameState.flag_changed.connect(func(f: String) -> void:
			if f == lit_flag:
				lit = true
				queue_redraw())
	if kind == "tower":
		# Latarnia pokazuje postęp (fragmenty, przywrócone światło).
		GameState.flag_changed.connect(func(_f: String) -> void:
			queue_redraw()
			_update_tower_fx())
		GameState.inventory_changed.connect(queue_redraw)
	_build_fx()


func _glow_sprite(pos: Vector2, r: float, col: Color) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Art.glow_texture()
	g.position = pos * s
	g.scale = Vector2.ONE * (r * s * 2.0 / 128.0)
	g.modulate = col
	g.show_behind_parent = true
	add_child(g)
	return g


func _painter(cb: Callable, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos * s
	n.scale = Vector2(s, s)
	n.draw.connect(func() -> void: cb.call(n))
	add_child(n)
	return n


func _build_fx() -> void:
	match kind:
		"crystal":
			_glow = _glow_sprite(Vector2(0, -24), 40, Color(Art.TEAL, 0.3))
		"lamp":
			_glow = _glow_sprite(Vector2(0, -62), 46, Color(Art.GOLD, 0.3))
		"machine":
			_spin = _painter(func(ci: Node2D) -> void: _gear_at(ci, Vector2.ZERO, 14), Vector2(18, -30))
		"gear":
			_spin = _painter(func(ci: Node2D) -> void: _gear_at(ci, Vector2.ZERO, 26), Vector2(0, -30))
		"flag":
			_cloth = _painter(func(ci: Node2D) -> void:
				var pts := PackedVector2Array([Vector2(0, -58), Vector2(32, -56), Vector2(30, -42), Vector2(0, -42)])
				Art.poly(ci, pts, Art.TEAL, Art.INK, 1.5), Vector2.ZERO)
		"tower":
			var lc := Vector2(0, -292)
			_glow = _glow_sprite(lc, 120, Color(Art.GOLD, 0.4))
			_beam = _painter(func(ci: Node2D) -> void:
				ci.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(900, -110), Vector2(900, 110)]), Color(Art.GOLD, 0.12)), lc)
			_update_tower_fx()


func _update_tower_fx() -> void:
	if kind != "tower" or _glow == null:
		return
	var frags := GameState.fragments()
	var restored := GameState.has_flag("lighthouse_restored")
	var power := 0.25 + frags * 0.2 + (0.25 if restored else 0.0)
	_glow.scale = Vector2.ONE * ((80.0 + 60.0 * power) * s * 2.0 / 128.0)
	_glow.modulate = Color(Art.GOLD, 0.25 + 0.35 * power)
	_beam.visible = restored and not Settings.reduced_motion


func collide_radius() -> float:
	return COLLIDE.get(kind, 0.0) * s


func _process(delta: float) -> void:
	t += delta
	if World.current and not World.current.on_screen(global_position, 300.0) and kind != "tower":
		return
	match kind:
		"crystal":
			_glow.modulate.a = 0.25 + 0.15 * (0.5 + 0.5 * sin(t * 2.0 + variant * 6.0))
		"lamp":
			_glow.modulate.a = 0.35 * (0.75 + 0.25 * sin(t * 3.0 + variant * 4.0))
		"machine":
			if lit:
				_spin.rotation = t
		"gear":
			_spin.rotation = t * 0.6
		"flag":
			if not Settings.reduced_motion:
				_cloth.skew = sin(t * 4.0) * 0.12
		"tower":
			if _beam.visible:
				# Promień omiata wyspy (spłaszczony w pionie dla perspektywy).
				var a := t * 0.7
				_beam.rotation = atan2(sin(a) * 0.45, cos(a))
			_glow.modulate.a = clampf(_glow.modulate.a, 0.0, 1.0)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(s, s))
	match kind:
		"tree": _tree()
		"pine": _pine()
		"bush": _bush()
		"rock": _rock()
		"crystal": _crystal()
		"pillar": _pillar()
		"lamp": _lamp()
		"bookshelf": _bookshelf()
		"machine": _machine()
		"crate": _crate()
		"statue": _statue()
		"stump": _stump()
		"mushroom": _mushroom()
		"flowers": _flowers()
		"pipe": _pipe()
		"gear": _gear()
		"sign": _sign()
		"tank": _tank()
		"archive_desk": _desk()
		"tower": _tower()
		"flag": _flag()


func _tree() -> void:
	Art.shadow(self, Vector2(6, 2), 34, 12)
	Art.poly(self, PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(5, -40), Vector2(-5, -40)]), Color("#6e4a2a"))
	var greens := [Color("#2f6b3a"), Color("#3f8a47"), Color("#5aa854")]
	if variant > 0.6:
		greens = [Color("#2a5d4a"), Color("#3b7f63"), Color("#58a07c")]
	var blobs := [[Vector2(0, -62), 30], [Vector2(-20, -48), 22], [Vector2(20, -48), 22], [Vector2(-8, -80), 20], [Vector2(12, -76), 18]]
	for b in blobs:
		Art.circle(self, b[0], b[1], greens[0])
	for b in blobs:
		draw_circle(b[0] + Vector2(-3, -4), b[1] * 0.8, greens[1])
	for b in blobs:
		draw_circle(b[0] + Vector2(-6, -8), b[1] * 0.4, greens[2])
	if variant < 0.3:
		for i in 4:
			draw_circle(Vector2(-18 + i * 12, -60 + (i % 2) * 14), 3, Color("#ffb3c1"))


func _pine() -> void:
	Art.shadow(self, Vector2(4, 2), 24, 9)
	Art.poly(self, Art.rrect(Rect2(-4, -16, 8, 18), 2), Color("#6e4a2a"))
	for i in 3:
		var y := -14.0 - i * 20.0
		var w := 26.0 - i * 6.0
		Art.poly(self, PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(0, y - 34)]), Color("#2c5e44").lightened(i * 0.06))


func _bush() -> void:
	Art.shadow(self, Vector2(2, 2), 22, 7)
	for b in [[Vector2(-10, -12), 13], [Vector2(10, -12), 13], [Vector2(0, -20), 14]]:
		Art.circle(self, b[0], b[1], Color("#3f8a47"))
	draw_circle(Vector2(-3, -24), 6, Color("#5aa854"))
	if variant > 0.5:
		draw_circle(Vector2(6, -16), 3, Color("#ff7a8a"))
		draw_circle(Vector2(-8, -8), 3, Color("#ff7a8a"))


func _rock() -> void:
	Art.shadow(self, Vector2(3, 2), 26, 8)
	var p := PackedVector2Array([Vector2(-24, 0), Vector2(-20, -18), Vector2(-4, -28), Vector2(16, -22), Vector2(24, -4), Vector2(16, 4), Vector2(-10, 5)])
	Art.poly(self, p, Color("#7d8494"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -16), Vector2(-4, -26), Vector2(12, -20), Vector2(-2, -14)]), Color("#9aa1b0"))
	if variant > 0.5:
		draw_circle(Vector2(8, -6), 5, Color("#5aa854", 0.8))


func _crystal() -> void:
	Art.shadow(self, Vector2(2, 2), 18, 6)
	Art.poly(self, PackedVector2Array([Vector2(-8, 0), Vector2(-12, -26), Vector2(0, -48), Vector2(10, -28), Vector2(8, 0)]), Color("#3fd1c1"))
	Art.poly(self, PackedVector2Array([Vector2(6, 0), Vector2(14, -18), Vector2(20, -6), Vector2(14, 2)]), Color("#2aa89b"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -24), Vector2(0, -42), Vector2(2, -24)]), Color(1, 1, 1, 0.5))


func _pillar() -> void:
	Art.shadow(self, Vector2(4, 2), 22, 8)
	var h := 60.0 + variant * 30.0
	Art.poly(self, Art.rrect(Rect2(-18, -10, 36, 12), 3), Color("#cbbf9f"))
	Art.poly(self, Art.rrect(Rect2(-13, -h, 26, h - 8), 3), Color("#e3d8bb"))
	for i in 3:
		draw_line(Vector2(-6 + i * 6, -h + 4), Vector2(-6 + i * 6, -12), Color(0, 0, 0, 0.12), 2.0)
	Art.poly(self, PackedVector2Array([Vector2(-17, -h), Vector2(17, -h), Vector2(13, -h - 10), Vector2(-4, -h - 4), Vector2(-15, -h - 12)]), Color("#cbbf9f"))
	if variant > 0.5:
		draw_polyline(PackedVector2Array([Vector2(-13, -h * 0.6), Vector2(-6, -h * 0.4), Vector2(-12, -h * 0.25)]), Color("#3f8a47"), 3.0, true)


func _lamp() -> void:
	Art.shadow(self, Vector2(2, 2), 12, 5)
	Art.line(self, Vector2(0, 0), Vector2(0, -56), Color("#3b4a44"), 4.0)
	var c := Vector2(0, -62)
	Art.poly(self, Art.rrect(Rect2(c - Vector2(8, 9), Vector2(16, 18)), 3), Color("#f7d77a"), Art.INK, 2.0)
	Art.poly(self, PackedVector2Array([c + Vector2(-11, -9), c + Vector2(11, -9), c + Vector2(0, -18)]), Color("#3b4a44"))


func _bookshelf() -> void:
	Art.shadow(self, Vector2(4, 2), 34, 9)
	Art.poly(self, Art.rrect(Rect2(-32, -78, 64, 80), 4), Color("#5b3a24"))
	var cols := [Color("#c8553d"), Color("#3f7f9a"), Color("#e8b84a"), Color("#6b3fa0"), Color("#3d8f4f"), Color("#f5ecd7")]
	for row in 3:
		var y := -72 + row * 24
		draw_line(Vector2(-28, y + 22), Vector2(28, y + 22), Color("#3a2416"), 3.0)
		var x := -27.0
		var k := int(variant * 10) + row
		while x < 24:
			var w := 5.0 + (k * 3 % 4)
			var hh := 16.0 + (k % 3) * 2
			draw_rect(Rect2(x, y + 22 - hh, w, hh), cols[k % cols.size()].darkened(0.0 if lit else 0.45))
			x += w + 1.5
			k += 1
	if lit:
		Art.glow(self, Vector2(0, -40), 50, Color(Art.GOLD, 0.18))


func _machine() -> void:
	Art.shadow(self, Vector2(4, 2), 40, 12)
	Art.poly(self, Art.rrect(Rect2(-36, -50, 72, 52), 8), Color("#5d6a73"))
	Art.poly(self, Art.rrect(Rect2(-28, -44, 30, 22), 4), Color("#1d3b36"))
	var on := 1.0 if lit else 0.3
	for i in 3:
		draw_rect(Rect2(-24 + i * 9, -38, 6, 8 + i * 3), Color(Art.TEAL, on))
	Art.line(self, Vector2(30, -50), Vector2(30, -66), Color("#7d8a93"), 5.0)
	draw_circle(Vector2(30, -68), 4, Art.GOLD if lit else Color("#7d6a4a"))


func _gear_at(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		var rr := r if i % 2 == 0 else r * 0.78
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	Art.poly(ci, pts, Color("#c9a24a"), Art.INK, 1.5)
	Art.circle(ci, c, r * 0.35, Color("#7d6a4a"), Art.INK, 1.5)


func _gear() -> void:
	Art.shadow(self, Vector2(2, 2), 26, 8)


func _crate() -> void:
	Art.shadow(self, Vector2(3, 2), 20, 7)
	Art.poly(self, Art.rrect(Rect2(-18, -32, 36, 34), 3), Color("#b07a42"))
	draw_line(Vector2(-18, -32), Vector2(18, 2), Color("#7a5228"), 3.0)
	draw_line(Vector2(-18, -15), Vector2(18, -15), Color("#7a5228"), 2.0)


func _statue() -> void:
	Art.shadow(self, Vector2(4, 2), 26, 9)
	Art.poly(self, Art.rrect(Rect2(-22, -16, 44, 18), 3), Color("#a9a08a"))
	Art.poly(self, PackedVector2Array([Vector2(-12, -16), Vector2(12, -16), Vector2(8, -56), Vector2(-8, -56)]), Color("#d6cdb5"))
	Art.circle(self, Vector2(0, -66), 11, Color("#d6cdb5"))
	Art.glow(self, Vector2(0, -66), 22, Color(Art.TEAL, 0.25))


func _stump() -> void:
	Art.shadow(self, Vector2(2, 2), 16, 6)
	Art.poly(self, Art.rrect(Rect2(-14, -16, 28, 18), 5), Color("#7a5230"))
	Art.oval(self, Vector2(0, -16), 14, 5, Color("#c9a070"))


func _mushroom() -> void:
	for i in 3:
		var p := Vector2(-10 + i * 10, -(i % 2) * 6)
		draw_line(p, p + Vector2(0, -10), Color("#efe2c4"), 4.0)
		Art.oval(self, p + Vector2(0, -12), 8 - i, 5, Color("#c8553d"), Art.INK, 1.5)
		draw_circle(p + Vector2(-2, -13), 1.5, Color.WHITE)


func _flowers() -> void:
	var cols := [Color("#ff7a8a"), Color("#e8b84a"), Color("#c89bff"), Color("#f5ecd7")]
	for i in 7:
		var p := Vector2(-24 + i * 8, -(i * 37 % 11))
		draw_line(p, p + Vector2(0, -8), Color("#3f8a47"), 2.0)
		draw_circle(p + Vector2(0, -9), 3.5, cols[(i + int(variant * 4)) % cols.size()])
		draw_circle(p + Vector2(0, -9), 1.2, Art.GOLD)


func _pipe() -> void:
	Art.line(self, Vector2(-30, -10), Vector2(30, -10), Color("#7d8a93"), 10.0)
	for x in [-30, 0, 30]:
		Art.poly(self, Art.rrect(Rect2(x - 4, -18, 8, 16), 2), Color("#5d6a73"))


func _sign() -> void:
	Art.shadow(self, Vector2(2, 2), 14, 5)
	Art.line(self, Vector2(0, 0), Vector2(0, -34), Color("#6e4a2a"), 4.0)
	Art.poly(self, Art.rrect(Rect2(-22, -48, 44, 20), 3), Color("#c9a070"))
	draw_line(Vector2(-14, -40), Vector2(14, -40), Color("#6e4a2a"), 2.0)
	draw_line(Vector2(-14, -35), Vector2(8, -35), Color("#6e4a2a"), 2.0)


func _tank() -> void:
	Art.shadow(self, Vector2(3, 2), 28, 9)
	Art.poly(self, Art.rrect(Rect2(-24, -60, 48, 62), 12), Color("#7d8a93"))
	var fill := 0.85 if lit else 0.2
	draw_rect(Rect2(-16, -50 + 40 * (1.0 - fill), 32, 40 * fill), Color("#3fa6c8", 0.85))
	Art.poly(self, Art.rrect(Rect2(-16, -50, 32, 40), 4), Color(0, 0, 0, 0), Art.INK, 2.0)


func _desk() -> void:
	Art.shadow(self, Vector2(3, 2), 32, 9)
	Art.poly(self, Art.rrect(Rect2(-30, -30, 60, 22), 3), Color("#6e4a2a"))
	Art.poly(self, Art.rrect(Rect2(-26, -10, 8, 12), 2), Color("#5b3a24"))
	Art.poly(self, Art.rrect(Rect2(18, -10, 8, 12), 2), Color("#5b3a24"))
	Art.poly(self, PackedVector2Array([Vector2(-18, -32), Vector2(4, -36), Vector2(6, -30), Vector2(-16, -27)]), Art.CREAM, Art.INK, 1.2)
	draw_circle(Vector2(16, -36), 5, Color(Art.GOLD, 0.9))


func _flag() -> void:
	Art.line(self, Vector2(0, 0), Vector2(0, -60), Color("#6e4a2a"), 3.0)


func _tower() -> void:
	## Latarnia Wiedzy — główny punkt bazy. Światło zależy od postępu.
	var frags := GameState.fragments()
	var restored := GameState.has_flag("lighthouse_restored")
	Art.shadow(self, Vector2(10, 4), 90, 30, 0.3)
	Art.poly(self, Art.rrect(Rect2(-70, -40, 140, 44), 10), Color("#cbbf9f"))
	Art.poly(self, PackedVector2Array([Vector2(-52, -36), Vector2(52, -36), Vector2(36, -250), Vector2(-36, -250)]), Color("#efe6d2"))
	for i in 4:
		var y := -70.0 - i * 48.0
		var w := 50.0 - i * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(w - 2, y - 16), Vector2(-w + 2, y - 16)]), Color("#2d6b5f"))
	Art.poly(self, Art.rrect(Rect2(-14, -36, 28, 40), 12), Color("#5b3a24"))
	Art.poly(self, Art.rrect(Rect2(-46, -262, 92, 16), 4), Color("#3b4a44"))
	# Laterna
	var lc := Vector2(0, -292)
	var power := 0.25 + frags * 0.2 + (0.25 if restored else 0.0)
	var col := Art.GOLD
	Art.poly(self, Art.rrect(Rect2(lc - Vector2(30, 30), Vector2(60, 52)), 8), Color("#1d3b36"))
	Art.circle(self, lc, 16, Color(col, 0.35 + 0.65 * power), Art.INK, 2.0)
	for i in 3:
		var on := i < frags or restored
		var p := lc + Vector2(-20 + i * 20, 26)
		Art.circle(self, p, 5, Art.GOLD if on else Color("#4a5a55"), Art.INK, 1.5)
	Art.poly(self, PackedVector2Array([lc + Vector2(-36, -30), lc + Vector2(36, -30), lc + Vector2(0, -64)]), Color("#c8553d"))
	draw_circle(lc + Vector2(0, -66), 5, Art.GOLD)
