extends Node
## Proceduralny generator grafiki pixel art 32x32 (placeholdery).
## Wszystko rysowane w kodzie – żadnych zewnętrznych assetów (licencja: własna, CC0).
##
## Udostępnia:
##  - tileset(): TileSet z kafelkami mapy (po 4 warianty na typ),
##  - creature(look, dir, frame): tekstura postaci/potwora,
##  - item_icon(icon): ikona przedmiotu,
##  - icon(name): ikony interfejsu.

const TS := 32
const VARIANTS := 4
## Kolejność typów kafelków w atlasie (wiersz = typ, kolumna = wariant).
const TILE_KINDS := ".,safx#Tr~D"

## Kolory strojów graczy (pole "look" z serwera).
const OUTFITS := [
	Color("8e2f2f"), Color("2f5e8e"), Color("3d7a35"), Color("7a5a2a"),
	Color("6a3d8a"), Color("2a7a78"), Color("9a6a1a"), Color("4a4a4a"),
]

var _cache: Dictionary = {}
var _tileset: TileSet = null


# ============================================================================
# Pomocnicze rysowanie
# ============================================================================

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
			img.set_pixel(x, y, c)

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

	## Tło z szumem (każdy piksel lekko inny – efekt „pixel art”).
	func noise(base: Color, amount: float, rng: RandomNumberGenerator) -> void:
		for yy in h:
			for xx in w:
				var v := rng.randf_range(-amount, amount)
				img.set_pixel(xx, yy, Color(base.r + v, base.g + v, base.b + v, 1.0))

	## Ciemny kontur wokół nieprzezroczystych pikseli.
	func outline(c: Color) -> void:
		var src := img.duplicate()
		for yy in h:
			for xx in w:
				if src.get_pixel(xx, yy).a > 0.1:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = xx + d.x
					var ny: int = yy + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
						img.set_pixel(xx, yy, c)
						break

	func blit(other: Image, ox: int, oy: int) -> void:
		img.blend_rect(other, Rect2i(0, 0, other.get_width(), other.get_height()), Vector2i(ox, oy))

	func flip_x() -> void:
		img.flip_x()

	func texture() -> ImageTexture:
		return ImageTexture.create_from_image(img)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


# ============================================================================
# Kafelki mapy
# ============================================================================

## TileSet zbudowany z atlasu wygenerowanych kafelków. Atlas: kolumna = wariant, wiersz = typ.
func tileset() -> TileSet:
	if _tileset:
		return _tileset
	var atlas := Image.create(TS * VARIANTS, TS * TILE_KINDS.length(), false, Image.FORMAT_RGBA8)
	for k in TILE_KINDS.length():
		for v in VARIANTS:
			var tile := draw_tile(TILE_KINDS[k], v)
			atlas.blit_rect(tile, Rect2i(0, 0, TS, TS), Vector2i(v * TS, k * TS))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas)
	src.texture_region_size = Vector2i(TS, TS)
	for k in TILE_KINDS.length():
		for v in VARIANTS:
			src.create_tile(Vector2i(v, k))
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(TS, TS)
	_tileset.add_source(src, 0)
	return _tileset


## Współrzędne w atlasie dla znaku kafelka – wariant zależy od pozycji (deterministycznie).
func atlas_coords(kind: String, x: int, y: int) -> Vector2i:
	var row := TILE_KINDS.find(kind)
	if row < 0:
		row = 0
	var h := (x * 73856093) ^ (y * 19349663)
	return Vector2i(absi(h) % VARIANTS, row)


func draw_tile(kind: String, variant: int) -> Image:
	var rng := _rng(kind.unicode_at(0) * 100 + variant)
	var c := Canvas.new()
	match kind:
		".":
			_grass(c, rng, variant)
		",":
			c.noise(Color("7a6040"), 0.035, rng)
			for i in 10:
				c.px(rng.randi_range(0, 31), rng.randi_range(0, 31), Color("5c4630"))
				c.px(rng.randi_range(0, 31), rng.randi_range(0, 31), Color("998060"))
		"s":
			c.noise(Color("c8b078"), 0.03, rng)
			for i in 12:
				c.px(rng.randi_range(0, 31), rng.randi_range(0, 31), Color("a89058"))
		"a":
			c.noise(Color("3c3634"), 0.035, rng)
			for i in 8:
				c.px(rng.randi_range(0, 31), rng.randi_range(0, 31), Color("2a2624"))
			for i in 2 + variant:
				c.px(rng.randi_range(0, 31), rng.randi_range(0, 31), Color("e0602a"))
		"f":
			_slabs(c, rng, Color("6e6a66"), Color("4e4a47"))
		"x":
			_slabs(c, rng, Color("a8a298"), Color("7c766e"))
			c.px(15, 15, Color("d4b04a"))
			c.px(16, 16, Color("d4b04a"))
		"#":
			_bricks(c, rng)
		"T":
			_grass(c, rng, variant)
			_tree(c, rng)
		"r":
			_grass(c, rng, variant)
			var base := Color("7a7672")
			c.ellipse(16, 18, 12, 10, base.darkened(0.3))
			c.ellipse(15, 16, 11, 9, base)
			c.ellipse(12, 12, 4, 3, base.lightened(0.25))
		"~":
			c.noise(Color("2a5a8a"), 0.02, rng)
			for i in 5:
				var y := rng.randi_range(2, 29)
				var x := rng.randi_range(0, 22)
				c.line(x, y, x + 6, y, Color("5a8aba"))
		"D":
			_slabs(c, rng, Color("6e6a66"), Color("4e4a47"))
			c.rect(4, 8, 24, 18, Color("6a4424"))
			c.rect(4, 8, 24, 5, Color("8a5a30"))
			c.rect(4, 13, 24, 1, Color("3a2412"))
			c.rect(14, 12, 4, 5, Color("d4b04a"))
		_:
			c.noise(Color.MAGENTA, 0.0, rng)
	return c.img


func _grass(c: Canvas, rng: RandomNumberGenerator, variant: int) -> void:
	c.noise(Color("3a6a2a"), 0.03, rng)
	for i in 14:
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(1, 31)
		c.px(x, y, Color("2c5420"))
		c.px(x, y - 1, Color("4a8034"))
	if variant == 3:
		for i in 3:
			c.px(rng.randi_range(2, 29), rng.randi_range(2, 29), [Color("e0d040"), Color("d05050"), Color("e0e0f0")][i])


func _slabs(c: Canvas, rng: RandomNumberGenerator, base: Color, mortar: Color) -> void:
	c.noise(base, 0.025, rng)
	for i in 32:
		c.px(i, 0, mortar)
		c.px(i, 16, mortar)
		c.px(0, i, mortar)
	for i in 16:
		c.px(16, i, mortar)
		c.px(8, 16 + i, mortar)
		c.px(24, 16 + i, mortar)


func _bricks(c: Canvas, rng: RandomNumberGenerator) -> void:
	c.noise(Color("5e4a42"), 0.04, rng)
	var mortar := Color("2e2420")
	for row in 4:
		var y := row * 8
		for i in 32:
			c.px(i, y, mortar)
		var off := 0 if row % 2 == 0 else 8
		for x in range(off, 32, 16):
			for i in 8:
				c.px(x, y + i, mortar)
	for i in 32:
		c.px(i, 1, Color("7e6a60"))


func _tree(c: Canvas, rng: RandomNumberGenerator) -> void:
	var t := Canvas.new()
	t.rect(14, 20, 5, 10, Color("5a3a1e"))
	t.px(14, 29, Color("3a2412"))
	var leaf := Color("1e4a1a")
	t.ellipse(16, 13, 13, 11, leaf)
	t.ellipse(12, 11, 7, 6, leaf.lightened(0.12))
	t.ellipse(20, 15, 7, 6, leaf.darkened(0.1))
	for i in 14:
		t.px(rng.randi_range(6, 26), rng.randi_range(4, 22), leaf.lightened(0.3))
	t.outline(Color(0.05, 0.1, 0.05, 1))
	c.blit(t.img, 0, 0)


# ============================================================================
# Postacie i potwory
# ============================================================================

## Tekstura istoty. look: "rat"/"wolf"/"skeleton" albo liczba (strój gracza).
## dir: 0=N 1=E 2=S 3=W, frame: 0/1 (animacja chodu).
func creature(look, dir: int, frame: int) -> Texture2D:
	var key := "cr_%s_%d_%d" % [str(look), dir, frame]
	if _cache.has(key):
		return _cache[key]
	var c := Canvas.new()
	match str(look):
		"rat":
			_draw_rat(c, frame)
			if dir == 3:
				c.flip_x()
		"wolf":
			_draw_wolf(c, frame)
			if dir == 3:
				c.flip_x()
		"skeleton":
			_draw_humanoid(c, dir, frame, Color("d8d0bc"), Color("b0a890"), Color("d8d0bc"), Color("3a3634"), true)
		_:
			var outfit: Color = OUTFITS[int(look) % OUTFITS.size()]
			_draw_humanoid(c, dir, frame, Color("e0b090"), outfit, Color("3a3044"), Color("4a2e1a"), false)
	c.outline(Color(0.06, 0.04, 0.04, 1))
	var tex := c.texture()
	_cache[key] = tex
	return tex


func _draw_humanoid(c: Canvas, dir: int, frame: int, skin: Color, torso: Color, legs: Color, hair: Color, skeleton: bool) -> void:
	var step := 1 if frame == 1 else 0
	# Nogi
	c.rect(12, 22, 3, 7 - step, legs)
	c.rect(17, 22, 3, 7, legs)
	c.rect(11, 28 - step, 4, 2, Color("2a1e14") if not skeleton else skin)
	c.rect(17, 28, 4, 2, Color("2a1e14") if not skeleton else skin)
	# Tułów
	c.rect(10, 13, 12, 10, torso)
	c.rect(10, 13, 12, 2, torso.lightened(0.2))
	if skeleton:
		for i in 3:
			c.rect(11, 15 + i * 3, 10, 1, Color("6a6458"))
	else:
		c.rect(10, 21, 12, 1, Color("3a2412"))
	# Ręce
	var arm_off := step
	c.rect(7, 14 + arm_off, 3, 8, torso.darkened(0.15))
	c.rect(22, 14 - arm_off, 3, 8, torso.darkened(0.15))
	c.rect(7, 21 + arm_off, 3, 2, skin)
	c.rect(22, 21 - arm_off, 3, 2, skin)
	# Głowa
	c.ellipse(16, 8, 6, 6, skin)
	var eye := Color("202020") if not skeleton else Color("e04020")
	match dir:
		0:
			c.ellipse(16, 7, 6, 5, hair)
		1:
			c.ellipse(14, 5, 5, 4, hair)
			c.px(19, 8, eye)
		2:
			c.rect(10, 2, 12, 3, hair)
			c.px(14, 8, eye)
			c.px(18, 8, eye)
			if skeleton:
				c.rect(14, 11, 5, 1, Color("6a6458"))
		3:
			c.ellipse(18, 5, 5, 4, hair)
			c.px(13, 8, eye)


func _draw_rat(c: Canvas, frame: int) -> void:
	var body := Color("7a726a")
	c.line(4, 22, 9, 20, Color("d09090"))
	c.line(2, 24, 4, 22, Color("d09090"))
	c.ellipse(15, 21, 8, 5, body)
	c.ellipse(23, 19, 4, 3.5, body.lightened(0.1))
	c.ellipse(21, 15, 2, 2, Color("c89090"))
	c.px(25, 18, Color("101010"))
	c.px(27, 20, Color("e09090"))
	var o := 1 if frame == 1 else 0
	c.rect(10 + o, 25, 2, 3, body.darkened(0.3))
	c.rect(18 - o, 25, 2, 3, body.darkened(0.3))


func _draw_wolf(c: Canvas, frame: int) -> void:
	var fur := Color("6a6258")
	c.line(2, 12, 7, 17, fur.darkened(0.2))
	c.line(3, 12, 8, 17, fur.darkened(0.2))
	c.ellipse(14, 17, 10, 6, fur)
	c.ellipse(13, 19, 8, 3, fur.lightened(0.2))
	c.ellipse(25, 13, 5, 4.5, fur)
	c.rect(28, 13, 3, 3, fur.lightened(0.1))
	c.px(30, 13, Color("101010"))
	c.px(26, 12, Color("e0c040"))
	c.rect(22, 7, 2, 3, fur.darkened(0.2))
	c.rect(25, 7, 2, 3, fur.darkened(0.2))
	var o := 1 if frame == 1 else 0
	for lx in [7 + o, 11 - o, 17 + o, 21 - o]:
		c.rect(lx, 22, 2, 7, fur.darkened(0.25))


# ============================================================================
# Ikony przedmiotów i interfejsu
# ============================================================================

func item_icon(icon: String) -> Texture2D:
	var key := "it_" + icon
	if _cache.has(key):
		return _cache[key]
	var c := Canvas.new()
	_draw_item(c, icon)
	c.outline(Color(0.05, 0.04, 0.04, 1))
	var tex := c.texture()
	_cache[key] = tex
	return tex


func _draw_item(c: Canvas, icon: String) -> void:
	var steel := Color("b8bcc4")
	var wood := Color("7a5230")
	var leather := Color("8a5a34")
	match icon:
		"gold":
			for p in [Vector2(12, 20), Vector2(19, 21), Vector2(15, 15)]:
				c.ellipse(p.x, p.y, 5, 4, Color("d4a82a"))
				c.ellipse(p.x - 1, p.y - 1, 2, 1.5, Color("f8e080"))
		"meat":
			c.ellipse(15, 16, 9, 7, Color("a83a2a"))
			c.ellipse(13, 14, 4, 3, Color("d06050"))
			c.rect(22, 20, 6, 3, Color("f0e8d8"))
		"pelt":
			c.ellipse(16, 16, 11, 8, Color("7a6a58"))
			c.ellipse(16, 16, 7, 5, Color("9a8a74"))
			c.rect(4, 12, 3, 3, Color("7a6a58"))
			c.rect(25, 12, 3, 3, Color("7a6a58"))
		"bone":
			c.line(8, 23, 23, 8, Color("e0dac8"))
			c.line(9, 23, 24, 8, Color("e0dac8"))
			c.ellipse(7, 24, 3, 3, Color("e0dac8"))
			c.ellipse(24, 7, 3, 3, Color("e0dac8"))
		"hp_potion", "mp_potion":
			var liquid := Color("d02a2a") if icon == "hp_potion" else Color("2a5ad0")
			c.rect(14, 5, 4, 5, Color("c0c8d0"))
			c.rect(13, 4, 6, 2, Color("8a5a30"))
			c.ellipse(16, 18, 8, 9, Color("c0c8d0"))
			c.ellipse(16, 19, 7, 7, liquid)
			c.ellipse(13, 16, 2, 2, liquid.lightened(0.4))
		"sword", "ash_sword":
			var blade := steel if icon == "sword" else Color("5a5250")
			if icon == "sword":
				blade = Color("a89a88")
			c.line(9, 23, 24, 8, blade)
			c.line(10, 23, 25, 8, blade)
			c.line(9, 22, 24, 7, blade.lightened(0.3))
			c.line(6, 20, 12, 26, Color("d4a82a"))
			c.line(5, 26, 8, 23, wood)
			c.line(4, 27, 7, 24, wood)
			if icon == "ash_sword":
				c.line(12, 20, 22, 10, Color("e0602a"))
		"axe":
			c.line(8, 26, 20, 8, wood)
			c.line(9, 26, 21, 8, wood)
			c.ellipse(21, 11, 6, 5, steel)
			c.ellipse(23, 11, 3, 4, steel.lightened(0.2))
		"club":
			c.line(8, 26, 18, 12, wood)
			c.line(9, 26, 19, 12, wood)
			c.ellipse(21, 9, 5, 6, wood.lightened(0.1))
			c.px(19, 7, Color("3a2412"))
			c.px(23, 10, Color("3a2412"))
		"bow":
			for i in 22:
				var t := float(i) / 21.0
				var x := int(8 + sin(t * PI) * 10)
				c.px(x, 5 + i, wood)
				c.px(x + 1, 5 + i, wood)
			c.line(8, 5, 8, 26, Color("e0e0d0"))
		"shield":
			c.ellipse(16, 16, 11, 12, wood)
			c.ellipse(16, 16, 9, 10, wood.lightened(0.15))
			c.line(16, 5, 16, 27, Color("5a3a1e"))
			c.ellipse(16, 16, 3, 3, steel)
		"helmet":
			c.ellipse(16, 16, 10, 9, leather)
			c.rect(6, 17, 20, 7, Color(0, 0, 0, 0))
			c.rect(6, 16, 20, 3, leather.darkened(0.2))
		"armor", "chain_armor":
			var col := leather if icon == "armor" else Color("8a8e96")
			c.rect(9, 7, 14, 19, col)
			c.rect(5, 8, 5, 8, col.darkened(0.1))
			c.rect(22, 8, 5, 8, col.darkened(0.1))
			c.rect(13, 7, 6, 3, Color(0, 0, 0, 0))
			if icon == "chain_armor":
				for y in range(10, 25, 2):
					for x in range(10 + (y % 4) / 2, 22, 2):
						c.px(x, y, col.darkened(0.3))
		"legs":
			c.rect(10, 5, 12, 5, leather)
			c.rect(10, 10, 5, 17, leather)
			c.rect(17, 10, 5, 17, leather)
		"boots":
			c.rect(8, 10, 5, 12, leather)
			c.rect(8, 20, 9, 4, leather.darkened(0.2))
			c.rect(19, 10, 5, 12, leather)
			c.rect(19, 20, 9, 4, leather.darkened(0.2))
		"spell_heal":
			c.ellipse(16, 16, 12, 12, Color("1a4a2a"))
			c.rect(13, 7, 6, 18, Color("60e080"))
			c.rect(7, 13, 18, 6, Color("60e080"))
		"attack":
			c.line(7, 25, 25, 7, steel)
			c.line(8, 25, 25, 8, steel)
			c.line(7, 7, 25, 25, steel)
			c.line(7, 8, 24, 25, steel)
			c.line(5, 22, 10, 27, Color("d4a82a"))
			c.line(22, 27, 27, 22, Color("d4a82a"))
		"bag":
			c.ellipse(16, 19, 11, 9, leather)
			c.rect(11, 6, 10, 6, leather.darkened(0.2))
			c.rect(14, 15, 4, 3, Color("d4a82a"))
		_:
			c.rect(8, 8, 16, 16, Color.MAGENTA)


## Ikona interfejsu (np. przycisk plecaka) – korzysta z tego samego generatora.
func icon(name: String) -> Texture2D:
	return item_icon(name)
