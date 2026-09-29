class_name ArtTerrain
## Tekstury terenu 128x128 powtarzalne bez szwów (okres = rozmiar tekstury).
## Shader mapy (world_ground.gdshader) próbkuje je we współrzędnych świata,
## więc teren nie ma widocznej siatki kafelków, a przejścia między typami są miękkie.

const S := 128


static func _wrap(c: ArtLib.Canvas, x: int, y: int, col: Color) -> void:
	c.px(posmod(x, S), posmod(y, S), col)


static func _base(c: ArtLib.Canvas, colors: Array, seed_v: int, lo: float, hi: float, cell: float = 32.0) -> void:
	for y in S:
		for x in S:
			var n := ArtLib.fbm(x, y, S, seed_v, cell, 3)
			c.img.set_pixel(x, y, ArtLib.ramp(colors, lerpf(lo, hi, n), x, y))


static func grass() -> Image:
	var c := ArtLib.canvas(S, S)
	_base(c, ArtLib.GRASS, 11, 0.15, 0.85)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Kępki trawy: ciemna nasada, jasny czubek.
	for i in 420:
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		var hgt := rng.randi_range(2, 4)
		var lean := rng.randi_range(-1, 1)
		for k in hgt:
			var col: Color = ArtLib.GRASS[1] if k == 0 else (ArtLib.GRASS[4] if k == hgt - 1 else ArtLib.GRASS[3])
			_wrap(c, x + (lean if k == hgt - 1 else 0), y - k, col)
	# Rzadkie kwiatki i kamyczki.
	for i in 14:
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		var col: Color = [Color("e8d45a"), Color("d86a6a"), Color("e8e4f0"), Color("9a8ad8")][i % 4]
		_wrap(c, x, y, col)
		_wrap(c, x + 1, y, col.darkened(0.25))
		_wrap(c, x, y + 1, ArtLib.GRASS[1])
	return c.img


static func dirt() -> Image:
	var c := ArtLib.canvas(S, S)
	_base(c, ArtLib.DIRT, 23, 0.2, 0.85, 16.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 150:
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		var light := rng.randf() < 0.5
		_wrap(c, x, y, ArtLib.DIRT[4] if light else ArtLib.DIRT[1])
		if light:
			_wrap(c, x + 1, y, ArtLib.DIRT[3])
			_wrap(c, x, y + 1, ArtLib.DIRT[0])
	return c.img


static func sand() -> Image:
	var c := ArtLib.canvas(S, S)
	for y in S:
		for x in S:
			var n := ArtLib.fbm(x, y, S, 31, 32.0, 2)
			# Zmarszczki piasku wzdłuż wiatru.
			var ripple := sin((y + n * 20.0) * TAU / 8.0) * 0.12
			c.img.set_pixel(x, y, ArtLib.ramp(ArtLib.SAND, 0.25 + n * 0.5 + ripple, x, y))
	return c.img


static func ash() -> Image:
	var c := ArtLib.canvas(S, S)
	_base(c, ArtLib.ASH, 41, 0.1, 0.9, 32.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	# Żarzące się pęknięcia.
	for i in 9:
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		for k in rng.randi_range(4, 10):
			_wrap(c, x, y, ArtLib.EMBER[0] if k % 3 else ArtLib.EMBER[1])
			x += rng.randi_range(-1, 1)
			y += 1 if rng.randf() < 0.6 else 0
			x += 1
	for i in 40:
		_wrap(c, rng.randi_range(0, S - 1), rng.randi_range(0, S - 1), ArtLib.EMBER[2] if i % 5 == 0 else ArtLib.ASH[4])
	return c.img


## Bruk miejski: płyty 16x16 przesunięte co rząd, każda o nieco innym odcieniu.
static func floor_stone() -> Image:
	var c := ArtLib.canvas(S, S)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in S:
		for x in S:
			var row := y / 16
			var off := 8 if row % 2 == 1 else 0
			var sx := posmod(x + off, S) / 16
			var tone := ArtLib._hash(sx, row, 99) * 0.25
			var lx := posmod(x + off, 16)
			var ly := y % 16
			var n := ArtLib.fbm(x, y, S, 51, 8.0, 2)
			var t := 0.35 + tone + (n - 0.5) * 0.25
			if lx == 0 or ly == 0:
				t = 0.05
			elif lx == 1 or ly == 1:
				t += 0.18
			elif lx == 15 or ly == 15:
				t -= 0.15
			c.img.set_pixel(x, y, ArtLib.ramp(ArtLib.STONE, t, x, y))
	# Pęknięcia i mech.
	for i in 12:
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		for k in 4:
			_wrap(c, x + k, y + (k % 2), ArtLib.STONE[1])
	for i in 18:
		_wrap(c, rng.randi_range(0, S - 1), rng.randi_range(0, S - 1), ArtLib.LEAF[2])
	return c.img


## Marmur świątyni: duże płyty w szachownicę, żyłki i złote wstawki.
static func marble() -> Image:
	var c := ArtLib.canvas(S, S)
	for y in S:
		for x in S:
			var checker := ((x / 32) + (y / 32)) % 2
			var vein := absf(sin((x + ArtLib.fbm(x, y, S, 61, 32.0, 3) * 60.0) * 0.18))
			var t := 0.55 + checker * 0.2 - (0.25 if vein < 0.08 else 0.0)
			var lx := x % 32
			var ly := y % 32
			if lx == 0 or ly == 0:
				t = 0.1
			elif lx == 1 or ly == 1:
				t += 0.15
			c.img.set_pixel(x, y, ArtLib.ramp(ArtLib.MARBLE, t, x, y))
			if (lx == 1 or lx == 31) and (ly == 1 or ly == 31):
				c.img.set_pixel(x, y, ArtLib.GOLD[3])
	return c.img


## Woda: klatka `frame` (0–3). Wzór przesuwa się o 32 px na klatkę, więc 4 klatki tworzą pętlę.
static func water(frame: int) -> Image:
	var c := ArtLib.canvas(S, S)
	for y in S:
		for x in S:
			var depth := ArtLib.fbm(x, y, S, 71, 64.0, 2)
			var wave := ArtLib.fbm(x + frame * 32, y, S, 81, 16.0, 2)
			var t := 0.2 + depth * 0.35 + (wave - 0.5) * 0.35
			var col := ArtLib.ramp(ArtLib.WATER, t, x, y)
			# Jasne grzbiety fal.
			if wave > 0.68 and ((x + y + frame) % 3) != 0:
				col = ArtLib.WATER[5]
			c.img.set_pixel(x, y, col)
	return c.img


## Tekstura szumu 64x64 (skala szarości) dla shadera – nieregularne krawędzie przejść.
static func noise_tex() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var n := ArtLib.fbm(x, y, 64, 91, 16.0, 3)
			var m := ArtLib.fbm(x, y, 64, 97, 8.0, 2)
			img.set_pixel(x, y, Color(n, m, ArtLib._hash(x, y, 5), 1.0))
	return img
