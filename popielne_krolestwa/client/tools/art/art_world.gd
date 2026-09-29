class_name ArtWorld
## Obiekty świata: drzewa (64x64), skały, mury 3/4 (32x64), wyposażenie miasta, pochodnia
## oraz złoża surowców T1–T4. Dolna krawędź obiektu = dolna krawędź kafelka.


## Drzewo liściaste/iglaste. style: "oak", "dark", "pine", "birch", "chestnut", "cedar".
static func tree(style: String, seed_v: int) -> Image:
	var c := ArtLib.canvas(64, 64)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	c.soft_shadow(32, 60, 14, 4.0, 0.45)
	var bark := ArtLib.WOOD
	var leaf := ArtLib.LEAF
	match style:
		"dark":
			leaf = [Color("0e2216"), Color("15301c"), Color("1e4226"), Color("2a5830"), Color("3a703c"), Color("4e8a48")]
		"birch":
			bark = [Color("4a4440"), Color("8a857c"), Color("c8c2b4"), Color("e4ded0"), Color("f4f0e6")]
			leaf = [Color("2a4a1e"), Color("3c6628"), Color("548434"), Color("6ea040"), Color("8cba52"), Color("aad26a")]
		"chestnut":
			leaf = [Color("12301a"), Color("1c4422"), Color("285a2a"), Color("357234"), Color("468c3e"), Color("5ea64c")]
		"cedar":
			bark = [Color("2a1410"), Color("4a2218"), Color("6a3222"), Color("8a4630"), Color("a85c3e")]
			leaf = [Color("0e2426"), Color("163634"), Color("1f4a44"), Color("2a6054"), Color("3a7866"), Color("52907a")]
	# Pień.
	c.shaded_rect(29, 42, 6, 19, bark)
	c.px(28, 59, bark[1])
	c.px(35, 60, bark[1])
	if style == "birch":
		for i in 4:
			c.rect(29 + (i % 2) * 3, 45 + i * 4, 2, 1, Color("2a2420"))
	if style == "pine" or style == "cedar":
		# Piętra igliwia (trójkąty) od dołu do góry.
		for i in 5:
			var wy := 46 - i * 8
			var hw := 16 - i * 3 + (4 if style == "cedar" else 0)
			for yy in range(wy - 9, wy + 1):
				var k := float(yy - (wy - 9)) / 10.0
				var half := int(hw * k)
				for xx in range(32 - half, 32 + half + 1):
					var u := float(xx - 32) / maxf(1, half)
					var t := 0.55 - u * 0.35 + (k - 0.5) * -0.3
					c.px(xx, yy, ArtLib.ramp(leaf, t, xx, yy))
	else:
		# Korona z kilku cieniowanych kęp.
		var blobs := [[32, 28, 16, 14], [22, 32, 9, 8], [42, 32, 9, 8], [26, 20, 9, 8], [38, 19, 10, 8], [32, 36, 12, 7]]
		if style == "chestnut":
			blobs = [[32, 26, 19, 16], [20, 32, 10, 9], [44, 32, 10, 9], [32, 14, 12, 8]]
		for b in blobs:
			c.shaded_ellipse(b[0] + rng.randi_range(-1, 1), b[1], b[2], b[3], leaf, rng.randf_range(-0.05, 0.05))
		for i in 40:
			var x := rng.randi_range(18, 46)
			var y := rng.randi_range(12, 40)
			if c.get_px(x, y).a > 0.5 and c.get_px(x, y - 2).a > 0.5:
				c.px(x, y, leaf[5] if y < 26 else leaf[1])
	c.outline()
	return c.img


## Głaz. ash = ciemniejszy (Popielisko).
static func rock(seed_v: int, ash: bool) -> Image:
	var c := ArtLib.canvas(32, 32)
	var ramp_c := ArtLib.STONE if not ash else [Color("1c1a1e"), Color("2a282c"), Color("3a373c"), Color("4c484e"), Color("5e5a60"), Color("726e74")]
	c.soft_shadow(16, 28, 13, 3.5, 0.45)
	c.shaded_ellipse(16, 20, 12, 9, ramp_c)
	c.shaded_ellipse(11 + seed_v % 3, 16, 6, 5, ramp_c, 0.1)
	c.line(12, 21, 18, 24, ramp_c[1])
	if ash:
		c.px(19, 18, ArtLib.EMBER[2])
		c.px(20, 19, ArtLib.EMBER[1])
	c.outline()
	return c.img


## Mur w rzucie 3/4: obraz 32x64, górna połowa = czapka muru wystająca nad kafelek.
## front = true: widoczna ściana czołowa (pod murem nie ma muru).
static func wall(front: bool, variant: int) -> Image:
	var c := ArtLib.canvas(32, 64)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7 + (1 if front else 0)
	var cap_bottom := 30 if front else 64
	# Czapka (góra muru).
	for y in range(16, cap_bottom):
		for x in 32:
			# Czapka z nieregularnych kamieni, ciemniejsza niż bruk, z krawędzią.
			var cell := ArtLib._hash(x / 8, (y - 16) / 6 + (x / 8) % 2, variant) * 0.2
			var t := 0.3 + cell + (ArtLib.fbm(x, y, 32, 3 + variant, 8.0, 2) - 0.5) * 0.15
			if (x % 8 == 0) or ((y - 16 + ((x / 8) % 2) * 3) % 6 == 0):
				t = 0.08
			if y < 18:
				t = 0.8
			c.px(x, y, ArtLib.ramp(ArtLib.STONE, t, x, y))
	if front:
		# Lico z cegieł.
		for y in range(30, 64):
			for x in 32:
				var row := (y - 30) / 6
				var off := 5 if row % 2 else 0
				var bx := (x + off) % 11
				var by := (y - 30) % 6
				var tone := ArtLib._hash((x + off) / 11, row, variant) * 0.22
				var t := 0.34 + tone - float(y - 30) / 34.0 * 0.2
				if bx == 0 or by == 0:
					t = 0.02
				elif by == 1:
					t += 0.12
				c.px(x, y, ArtLib.ramp(ArtLib.STONE, t, x, y))
		c.rect(0, 30, 32, 1, ArtLib.STONE[5])
		c.rect(0, 31, 32, 1, ArtLib.STONE[1])
		c.rect(0, 62, 32, 2, Color(0.05, 0.03, 0.05, 0.5))
	# Mech/zarysowania.
	for i in 4:
		c.px(rng.randi_range(0, 31), rng.randi_range(20, 60), ArtLib.LEAF[2])
	return c.img


static func depot_chest() -> Image:
	var c := ArtLib.canvas(32, 32)
	c.soft_shadow(16, 28, 13, 3.5)
	c.shaded_rect(4, 12, 24, 15, ArtLib.WOOD)
	c.shaded_rect(4, 8, 24, 6, ArtLib.WOOD, 0.15)
	for x in [4, 15, 26]:
		c.rect(x, 8, 2, 19, ArtLib.METALS[2][1])
	c.shaded_rect(14, 13, 4, 5, ArtLib.GOLD)
	c.outline()
	return c.img


static func market_stall() -> Image:
	var c := ArtLib.canvas(32, 64)
	c.soft_shadow(16, 61, 15, 3.5)
	c.shaded_rect(2, 44, 28, 16, ArtLib.WOOD)
	c.rect(2, 44, 28, 2, ArtLib.WOOD[4])
	c.rect(3, 26, 2, 34, ArtLib.WOOD[1])
	c.rect(27, 26, 2, 34, ArtLib.WOOD[1])
	for i in 7:
		var col := Color("b83a2a") if i % 2 == 0 else Color("e8dcc8")
		c.polygon(PackedVector2Array([Vector2(i * 4.6, 22), Vector2(i * 4.6 + 4.6, 22), Vector2(i * 4.6 + 4.6, 32), Vector2(i * 4.6, 32)]), col)
	for i in 7:
		c.ellipse(i * 4.6 + 2.3, 32, 2.3, 1.5, Color("b83a2a") if i % 2 == 0 else Color("e8dcc8"))
	# Towary.
	c.shaded_ellipse(9, 43, 3.5, 2.5, [Color("6a1a10"), Color("a82a1a"), Color("d84a2a"), Color("f07a4a")])
	c.shaded_ellipse(16, 43, 3, 2.5, ArtLib.GOLD)
	c.shaded_ellipse(23, 43, 3.5, 2.5, ArtLib.LEAF)
	c.outline()
	return c.img


static func anvil() -> Image:
	var c := ArtLib.canvas(32, 32)
	c.soft_shadow(16, 28, 12, 3.5)
	c.shaded_rect(12, 19, 8, 9, ArtLib.WOOD)
	c.shaded_rect(8, 13, 16, 6, ArtLib.METALS[3])
	c.polygon(PackedVector2Array([Vector2(24, 13), Vector2(29, 14), Vector2(24, 17)]), ArtLib.METALS[3][2])
	c.rect(8, 13, 16, 1, ArtLib.METALS[3][4])
	c.outline()
	return c.img


static func workbench() -> Image:
	var c := ArtLib.canvas(32, 32)
	c.soft_shadow(16, 28, 14, 3.5)
	c.shaded_rect(3, 12, 26, 7, ArtLib.WOOD, 0.1)
	c.rect(4, 19, 3, 9, ArtLib.WOOD[1])
	c.rect(25, 19, 3, 9, ArtLib.WOOD[1])
	c.shaded_rect(7, 8, 9, 4, [Color("8a8272"), Color("b0a894"), Color("d8d0bc")])
	c.line(19, 7, 25, 10, ArtLib.METALS[2][3])
	c.line(19, 8, 25, 11, ArtLib.WOOD[3])
	c.outline()
	return c.img


static func furnace() -> Image:
	var c := ArtLib.canvas(32, 64)
	c.soft_shadow(16, 61, 14, 3.5)
	c.shaded_rect(4, 30, 24, 31, ArtLib.STONE)
	c.shaded_rect(10, 14, 12, 17, ArtLib.STONE, -0.05)
	c.ellipse(16, 50, 7, 6, Color("1a0e0a"))
	c.shaded_ellipse(16, 52, 5, 3, ArtLib.EMBER)
	c.rect(4, 30, 24, 1, ArtLib.STONE[5])
	c.outline()
	return c.img


## Pochodnia ścienna (ogień dodają cząsteczki i światło w grze).
static func torch() -> Image:
	var c := ArtLib.canvas(32, 32)
	c.shaded_rect(15, 14, 3, 12, ArtLib.WOOD)
	c.shaded_rect(13, 24, 7, 2, ArtLib.METALS[3])
	c.shaded_ellipse(16.5, 11, 3.5, 4.5, ArtLib.EMBER)
	c.shaded_ellipse(16.5, 12, 1.8, 2.5, [ArtLib.EMBER[2], ArtLib.EMBER[3], Color("fff4c0")])
	c.outline()
	return c.img


# ---------------------------------------------------------------------------
# Złoża surowców (wysyłane przez serwer jako istoty "r")
# ---------------------------------------------------------------------------

static func node(kind: String, tier: int) -> Image:
	match kind:
		"wood":
			return tree(["", "birch", "chestnut", "pine", "cedar"][tier], 100 + tier)
		"stone":
			var c := ArtLib.canvas(64, 64)
			var ramps := [[], ArtLib.MARBLE, ArtLib.SAND, [Color("6a6660"), Color("8e8a82"), Color("b2ada4"), Color("d4d0c6"), Color("eeeae0")], [Color("26242a"), Color("3a3840"), Color("555260"), Color("726e7e"), Color("938ea0")]]
			c.soft_shadow(32, 60, 15, 4.0, 0.45)
			c.shaded_ellipse(32, 50, 14, 11, ramps[tier])
			c.shaded_ellipse(25, 44, 7, 6, ramps[tier], 0.1)
			c.shaded_ellipse(40, 47, 6, 5, ramps[tier], -0.05)
			c.line(26, 52, 36, 56, ramps[tier][0])
			c.outline()
			return c.img
		"ore":
			var c := ArtLib.canvas(64, 64)
			var metal: Array = ArtLib.METALS[tier]
			c.soft_shadow(32, 60, 15, 4.0, 0.45)
			c.shaded_ellipse(32, 49, 14, 12, [Color("1a1618"), Color("2a2426"), Color("3c3436"), Color("4e4648"), Color("62585a")])
			c.shaded_ellipse(24, 44, 7, 6, [Color("2a2426"), Color("3c3436"), Color("4e4648"), Color("62585a")])
			var rng := RandomNumberGenerator.new()
			rng.seed = tier
			for i in 9:
				var x := rng.randi_range(22, 42)
				var y := rng.randi_range(40, 57)
				c.shaded_ellipse(x, y, 1.8, 1.4, metal)
				c.px(x - 1, y - 1, metal[4])
			c.outline()
			return c.img
		_:
			var c := ArtLib.canvas(64, 64)
			var rng := RandomNumberGenerator.new()
			rng.seed = 40 + tier
			var stalk: Array = [[], ArtLib.GRASS, [Color("1e3a1c"), Color("2c5226"), Color("3e6c30"), Color("558a3c"), Color("72a84c")], ArtLib.GRASS, [Color("3a1410"), Color("5a2014"), Color("7a2e1a"), Color("a0421e"), Color("c85a24")]][tier]
			var bloom: Color = [Color.WHITE, Color("7a9ae8"), Color("a8c85a"), Color("f4f0e8"), Color("ff8a30")][tier]
			c.soft_shadow(32, 60, 13, 3.5, 0.4)
			for i in 14:
				var x := 22 + i * 1.5 + rng.randi_range(-1, 1)
				var top := 36 + rng.randi_range(0, 10)
				var lean := rng.randi_range(-3, 3)
				c.line(int(x), 60, int(x) + lean, top, stalk[2 + (i % 2)])
				c.shaded_ellipse(x + lean, top, 1.8, 1.8, [bloom.darkened(0.35), bloom, bloom.lightened(0.3)])
			c.outline()
			return c.img
