class_name ArtLib
## Biblioteka do proceduralnego pixel artu używana przez generator grafik (tools/build_art.gd).
## Paleta, szum okresowy (bezszwowe tekstury), cieniowanie rampą z ditheringiem Bayera,
## kontury i obróbka obrazów. Wynik zapisywany jest do PNG w res://assets/ – dzięki temu
## grafiki są zwykłymi zasobami Godota (widoczne w edytorze, można je podmienić ręcznie).

# ---------------------------------------------------------------------------
# Paleta (spójna, stonowana – „spalony świat”)
# ---------------------------------------------------------------------------

const OUTLINE := Color("1b1520")
const SHADOW := Color(0.05, 0.03, 0.06, 0.45)

const GRASS := [Color("24401f"), Color("2f5227"), Color("3d6a30"), Color("518539"), Color("6b9f45"), Color("8cb756")]
const DIRT := [Color("3a2718"), Color("4e3522"), Color("664630"), Color("7f5a3d"), Color("98714f")]
const SAND := [Color("8a7450"), Color("a58d62"), Color("bfa575"), Color("d6bd8a"), Color("e8d4a4")]
const ASH := [Color("1f1b1d"), Color("2b2628"), Color("3a3436"), Color("4b4546"), Color("5e5758")]
const EMBER := [Color("8a2a14"), Color("c8481e"), Color("f07a2a"), Color("ffc05a")]
const STONE := [Color("2a2830"), Color("3a3842"), Color("4d4a55"), Color("63606b"), Color("7c7884"), Color("97939e")]
const MARBLE := [Color("6e6860"), Color("8a8378"), Color("a69e90"), Color("c2baa8"), Color("dad3c2")]
const WATER := [Color("10223a"), Color("163252"), Color("1d4468"), Color("275a82"), Color("3a7aa2"), Color("6aa8c8"), Color("b8dce8")]
const WOOD := [Color("2e1c12"), Color("472c1a"), Color("603d24"), Color("7c5232"), Color("9a6c44")]
const LEAF := [Color("16301c"), Color("1f4424"), Color("2c5c2c"), Color("3d7735"), Color("559442"), Color("76b255")]
const SKIN := [Color("6a4030"), Color("94603f"), Color("c08560"), Color("dfab82"), Color("f0caa2")]
const GOLD := [Color("5a3c12"), Color("8a6420"), Color("c09a3a"), Color("e2c460"), Color("f8ec9a")]
const BRONZE := [Color("3a2412"), Color("5e3c1c"), Color("8a5c2c"), Color("b47e40"), Color("dcac66")]
const BONE := [Color("6a6254"), Color("908876"), Color("b6ad98"), Color("d6cebb"), Color("ede7d8")]

## Rampy metali dla tierów T1–T4 (miedź, cyna, żelazo, tytan) – indeks = tier.
const METALS := [
	[Color("3a3a40"), Color("5a5a64"), Color("80808c"), Color("a8a8b4"), Color("d0d0da")],
	[Color("4a2414"), Color("7a3e20"), Color("a8602e"), Color("d08848"), Color("f0b87a")],
	[Color("3e4048"), Color("62666e"), Color("8e939a"), Color("b8bdc2"), Color("e2e6ea")],
	[Color("26262c"), Color("3e3e46"), Color("5a5c66"), Color("80848e"), Color("aab0b8")],
	[Color("123038"), Color("1e5260"), Color("30808e"), Color("58b4c0"), Color("a0e4ec")],
]
## Rampy skóry (materiału) dla tierów.
const LEATHERS := [
	[Color("2e1c12"), Color("4a2e1c"), Color("6a4428"), Color("8c5e38"), Color("aa7a4c")],
	[Color("3a2416"), Color("5a3820"), Color("7a4e2c"), Color("9a683c"), Color("b88452")],
	[Color("2a1c14"), Color("44301e"), Color("5e4428"), Color("7a5a36"), Color("987448")],
	[Color("1e1a1e"), Color("34282c"), Color("4c3a3a"), Color("684e4a"), Color("86665c")],
	[Color("2a0e0e"), Color("481818"), Color("6a2622"), Color("903a2e"), Color("b85a40")],
]
## Rampy płótna dla tierów.
const CLOTHS := [
	[Color("3a3640"), Color("56505c"), Color("767080"), Color("9a94a2"), Color("c0bac6")],
	[Color("4a4436"), Color("6e664e"), Color("948a68"), Color("b8ae86"), Color("dcd2aa")],
	[Color("1a2c4a"), Color("243e66"), Color("325688"), Color("4674aa"), Color("6a98c8")],
	[Color("2e1a40"), Color("44265e"), Color("5e3882"), Color("7c50a8"), Color("a276cc")],
	[Color("4a1410"), Color("721e16"), Color("a0301e"), Color("cc4e2a"), Color("f07a3c")],
]
## Kolory strojów graczy (look 0–7).
const OUTFITS := [
	Color("8e2f2f"), Color("2f5e8e"), Color("3d7a35"), Color("7a5a2a"),
	Color("6a3d8a"), Color("2a7a78"), Color("9a6a1a"), Color("4a4a52"),
]

## Macierz Bayera 4x4 do ditheringu.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Kierunek światła (z góry-lewej, lekko z przodu).
const LIGHT := Vector3(-0.55, -0.7, 0.45)


static func ramp(colors: Array, t: float, x: int = 0, y: int = 0, dither := true) -> Color:
	var n := colors.size()
	var f := clampf(t, 0.0, 0.9999) * n
	if dither:
		f += (BAYER[(y & 3) * 4 + (x & 3)] / 16.0 - 0.5) * 0.9
	return colors[clampi(int(floor(f)), 0, n - 1)]


static func lighten(c: Color, a: float) -> Color:
	return c.lightened(a)


# ---------------------------------------------------------------------------
# Szum okresowy (value noise) – tekstury bez szwów
# ---------------------------------------------------------------------------

static func _hash(x: int, y: int, seed_v: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_v * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Szum wartości o okresie `period` pikseli i komórce `cell` (period % cell == 0).
static func noise(x: float, y: float, cell: float, period: int, seed_v: int) -> float:
	var cells := int(period / cell)
	var gx := x / cell
	var gy := y / cell
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := gx - x0
	var fy := gy - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(posmod(x0, cells), posmod(y0, cells), seed_v)
	var b := _hash(posmod(x0 + 1, cells), posmod(y0, cells), seed_v)
	var c := _hash(posmod(x0, cells), posmod(y0 + 1, cells), seed_v)
	var d := _hash(posmod(x0 + 1, cells), posmod(y0 + 1, cells), seed_v)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Suma oktaw szumu (fbm), wynik 0..1.
static func fbm(x: float, y: float, period: int, seed_v: int, base_cell: float = 32.0, octaves: int = 3) -> float:
	var v := 0.0
	var amp := 0.5
	var cell := base_cell
	var total := 0.0
	for i in octaves:
		v += noise(x, y, cell, period, seed_v + i * 17) * amp
		total += amp
		amp *= 0.5
		cell = maxf(2.0, cell / 2.0)
	return v / total


# ---------------------------------------------------------------------------
# Płótno
# ---------------------------------------------------------------------------

class Canvas:
	var img: Image
	var w: int
	var h: int

	func _init(width: int = 32, height: int = 32) -> void:
		w = width
		h = height
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	func px(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			if c.a >= 0.999:
				img.set_pixel(x, y, c)
			elif c.a > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(c))

	func get_px(x: int, y: int) -> Color:
		if x >= 0 and y >= 0 and x < w and y < h:
			return img.get_pixel(x, y)
		return Color(0, 0, 0, 0)

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				px(xx, yy, c)

	func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
			for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
				var dx := (xx + 0.5 - cx) / rx
				var dy := (yy + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					px(xx, yy, c)

	## Elipsa cieniowana jak kula (światło z góry-lewej), rampa z ditheringiem.
	func shaded_ellipse(cx: float, cy: float, rx: float, ry: float, colors: Array, bias: float = 0.0) -> void:
		var l := ArtLib.LIGHT.normalized()
		for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
			for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
				var nx := (xx + 0.5 - cx) / rx
				var ny := (yy + 0.5 - cy) / ry
				var d := nx * nx + ny * ny
				if d > 1.0:
					continue
				var nz := sqrt(1.0 - d)
				var t := clampf(Vector3(nx, ny, nz).dot(-l) * 0.5 + 0.5 + bias, 0.0, 1.0)
				px(xx, yy, ArtLib.ramp(colors, t, xx, yy))

	## Prostokąt cieniowany jak walec pionowy (np. pień, ramię, noga).
	func shaded_rect(x: int, y: int, rw: int, rh: int, colors: Array, bias: float = 0.0) -> void:
		for yy in range(y, y + rh):
			for xx in range(x, x + rw):
				var u := (xx + 0.5 - x) / rw * 2.0 - 1.0
				var t := clampf(0.55 - u * 0.45 - float(yy - y) / maxf(1, rh) * 0.15 + bias, 0.0, 1.0)
				px(xx, yy, ArtLib.ramp(colors, t, xx, yy))

	func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var dx := absi(x1 - x0)
		var dy := -absi(y1 - y0)
		var sx := 1 if x0 < x1 else -1
		var sy := 1 if y0 < y1 else -1
		var err := dx + dy
		while true:
			px(x0, y0, c)
			if x0 == x1 and y0 == y1:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy

	## Wypełniony wielokąt (reguła parzystości).
	func polygon(points: PackedVector2Array, c: Color) -> void:
		var r := Rect2(points[0], Vector2.ZERO)
		for p in points:
			r = r.expand(p)
		for yy in range(int(r.position.y), int(r.end.y) + 1):
			for xx in range(int(r.position.x), int(r.end.x) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(xx + 0.5, yy + 0.5), points):
					px(xx, yy, c)

	## Ciemny kontur wokół nieprzezroczystych pikseli (4-sąsiedztwo).
	func outline(c: Color = ArtLib.OUTLINE) -> void:
		var src: Image = img.duplicate()
		for yy in h:
			for xx in w:
				if src.get_pixel(xx, yy).a > 0.1:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = xx + d.x
					var ny: int = yy + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.6:
						img.set_pixel(xx, yy, c)
						break

	## Delikatne rozjaśnienie krawędzi od strony światła i przyciemnienie od cienia.
	func bevel(amount: float = 0.12) -> void:
		var src: Image = img.duplicate()
		for yy in h:
			for xx in w:
				var c := src.get_pixel(xx, yy)
				if c.a < 0.6 or c.is_equal_approx(ArtLib.OUTLINE):
					continue
				var up := src.get_pixel(xx, yy - 1) if yy > 0 else Color(0, 0, 0, 0)
				var left := src.get_pixel(xx - 1, yy) if xx > 0 else Color(0, 0, 0, 0)
				var down := src.get_pixel(xx, yy + 1) if yy < h - 1 else Color(0, 0, 0, 0)
				var right := src.get_pixel(xx + 1, yy) if xx < w - 1 else Color(0, 0, 0, 0)
				if up.a < 0.6 or left.a < 0.6:
					img.set_pixel(xx, yy, c.lightened(amount))
				elif down.a < 0.6 or right.a < 0.6:
					img.set_pixel(xx, yy, c.darkened(amount))

	## Miękki cień (elipsa półprzezroczysta z rozmytą krawędzią).
	func soft_shadow(cx: float, cy: float, rx: float, ry: float, alpha: float = 0.4) -> void:
		for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
			for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
				var dx := (xx + 0.5 - cx) / rx
				var dy := (yy + 0.5 - cy) / ry
				var d := dx * dx + dy * dy
				if d <= 1.0:
					px(xx, yy, Color(ArtLib.SHADOW, alpha * (1.0 - d * d)))

	func blit(other: Image, ox: int, oy: int) -> void:
		img.blend_rect(other, Rect2i(0, 0, other.get_width(), other.get_height()), Vector2i(ox, oy))

	func flipped() -> Image:
		var c: Image = img.duplicate()
		c.flip_x()
		return c

	func save(path: String) -> void:
		var err := img.save_png(path)
		if err != OK:
			push_error("Nie można zapisać %s: %s" % [path, error_string(err)])


## Nowe płótno (skrót).
static func canvas(w: int = 32, h: int = 32) -> Canvas:
	return Canvas.new(w, h)
