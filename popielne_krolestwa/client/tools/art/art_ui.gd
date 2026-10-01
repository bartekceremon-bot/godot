class_name ArtUI
## Grafiki interfejsu (używane jako StyleBoxTexture / 9-patch w motywie): ramki okien,
## przyciski, sloty, paski życia/many, joystick, ikony HUD.

const PANEL_BG := [Color("140f10"), Color("1c1517"), Color("241c1d"), Color("2c2323")]


static func _frame(c: ArtLib.Canvas, border: Array, inset: int, width: int) -> void:
	# Zewnętrzna ciemna linia, brązowa rama z fazą, wewnętrzna ciemna linia.
	var w := c.w
	var h := c.h
	for i in width:
		var t := 0.8 - float(i) / width * 0.6
		var col: Color = ArtLib.ramp(border, t)
		c.rect(inset + i, inset + i, w - 2 * (inset + i), 1, col.lightened(0.1))
		c.rect(inset + i, h - 1 - inset - i, w - 2 * (inset + i), 1, col.darkened(0.25))
		c.rect(inset + i, inset + i, 1, h - 2 * (inset + i), col)
		c.rect(w - 1 - inset - i, inset + i, 1, h - 2 * (inset + i), col.darkened(0.2))
	var o := ArtLib.OUTLINE
	c.rect(inset - 1, inset - 1, w - 2 * inset + 2, 1, o)
	c.rect(inset - 1, h - inset, w - 2 * inset + 2, 1, o)
	c.rect(inset - 1, inset - 1, 1, h - 2 * inset + 2, o)
	c.rect(w - inset, inset - 1, 1, h - 2 * inset + 2, o)


## Ramka okna 48x48 (marginesy 9-patch: 14 px).
static func panel() -> Image:
	var c := ArtLib.canvas(48, 48)
	for y in 48:
		for x in 48:
			var n := ArtLib.fbm(x, y, 48, 5, 12.0, 2)
			c.px(x, y, ArtLib.ramp(PANEL_BG, 0.3 + n * 0.5, x, y))
	_frame(c, ArtLib.BRONZE, 1, 4)
	# Nity w narożnikach.
	for p in [Vector2(6, 6), Vector2(41, 6), Vector2(6, 41), Vector2(41, 41)]:
		c.shaded_ellipse(p.x, p.y, 2.6, 2.6, ArtLib.GOLD)
	return c.img


## Przycisk 32x32 (marginesy 10 px). state: normal / hover / pressed / disabled.
static func button(state: String) -> Image:
	var c := ArtLib.canvas(32, 32)
	var base := [Color("2c1e16"), Color("3c2a1e"), Color("4e3626"), Color("62452e")]
	if state == "hover":
		base = [Color("3a281c"), Color("4e3626"), Color("664832"), Color("7e5a3c")]
	elif state == "pressed":
		base = [Color("1e140e"), Color("2a1c14"), Color("38261a"), Color("463020")]
	elif state == "disabled":
		base = [Color("1c1818"), Color("242020"), Color("2c2828"), Color("343030")]
	for y in 32:
		for x in 32:
			var t := 0.75 - float(y) / 32.0 * 0.5 + (ArtLib.fbm(x, y, 32, 9, 8.0, 2) - 0.5) * 0.2
			if state == "pressed":
				t = 0.3 + float(y) / 32.0 * 0.3
			c.px(x, y, ArtLib.ramp(base, t, x, y))
	var border: Array = ArtLib.GOLD if state == "hover" else ArtLib.BRONZE
	if state == "disabled":
		border = ArtLib.STONE
	_frame(c, border, 1, 2)
	return c.img


## Slot przedmiotu 40x40 (marginesy 8 px).
static func slot() -> Image:
	var c := ArtLib.canvas(40, 40)
	for y in 40:
		for x in 40:
			var t := 0.25 + float(y) / 40.0 * 0.2
			c.px(x, y, ArtLib.ramp(PANEL_BG, t, x, y))
	_frame(c, [Color("1a1414"), Color("2a2020"), Color("3a2c28"), Color("4a3a32")], 1, 2)
	c.rect(4, 4, 32, 1, Color(0, 0, 0, 0.5))
	return c.img


## Pasek (tło lub wypełnienie) 64x16, marginesy 4 px.
static func bar(kind: String) -> Image:
	var c := ArtLib.canvas(64, 16)
	var ramps := {
		"hp": [Color("4a0c0c"), Color("7a1414"), Color("a82020"), Color("d23a2a"), Color("f26a4a")],
		"mp": [Color("0c1a4a"), Color("142a7a"), Color("1e40a8"), Color("2e5ed2"), Color("5a8af2")],
		"exp": [Color("4a340c"), Color("7a5814"), Color("a87c20"), Color("d2a43a"), Color("f2cc6a")],
		"bg": [Color("0c0808"), Color("140e0e"), Color("1c1414"), Color("241a1a"), Color("2c2020")],
	}
	var r: Array = ramps[kind]
	for y in 16:
		for x in 64:
			var t := 0.85 - absf(float(y) - 5.0) / 11.0 * 0.8
			c.px(x, y, ArtLib.ramp(r, t, x, y))
	if kind == "bg":
		_frame(c, ArtLib.BRONZE, 0, 2)
	return c.img


static func joystick_base() -> Image:
	var c := ArtLib.canvas(220, 220)
	for y in 220:
		for x in 220:
			var d := Vector2(x - 109.5, y - 109.5).length()
			if d <= 108:
				var a := 0.18 + (0.22 if d > 98 else 0.0)
				var col := Color(0.1, 0.07, 0.06, a)
				if d > 100 and d <= 106:
					col = Color(ArtLib.BRONZE[3], 0.55)
				c.px(x, y, col)
	# Strzałki kierunków.
	for i in 4:
		var ang := i * PI / 2.0
		var dirv := Vector2(cos(ang), sin(ang))
		var tip := Vector2(110, 110) + dirv * 90
		var side := Vector2(-dirv.y, dirv.x)
		c.polygon(PackedVector2Array([tip, tip - dirv * 12 + side * 9, tip - dirv * 12 - side * 9]), Color(ArtLib.BRONZE[4], 0.6))
	return c.img


static func joystick_knob() -> Image:
	var c := ArtLib.canvas(96, 96)
	c.shaded_ellipse(48, 48, 44, 44, [Color("3a2414"), Color("5e3c1c"), Color("8a5c2c"), Color("b47e40"), Color("d8a462")])
	c.shaded_ellipse(48, 48, 30, 30, [Color("2c1c10"), Color("4a3018"), Color("6e4a26"), Color("946636")], -0.1)
	var img := c.img
	# Półprzezroczystość całości.
	for y in 96:
		for x in 96:
			var col := img.get_pixel(x, y)
			if col.a > 0:
				img.set_pixel(x, y, Color(col, 0.8))
	return img


## Ikony HUD 32x32.
static func icon(name: String) -> Image:
	var c := ArtLib.canvas(32, 32)
	match name:
		"bag":
			c.shaded_ellipse(16, 19, 11, 10, ArtLib.LEATHERS[1])
			c.shaded_rect(10, 5, 12, 7, ArtLib.LEATHERS[2])
			c.rect(9, 12, 14, 2, ArtLib.LEATHERS[1][0])
			c.shaded_rect(14, 15, 4, 4, ArtLib.GOLD)
		"character":
			c.shaded_ellipse(16, 10, 6, 6, ArtLib.SKIN)
			c.shaded_ellipse(16, 7, 6, 3.5, [Color("2a1a10"), Color("4a2e1a"), Color("6a4428")])
			c.shaded_rect(8, 17, 16, 12, ArtLib.METALS[2])
			c.rect(15, 18, 2, 10, ArtLib.METALS[2][4])
		"specs":
			# Drzewko: pień i trzy świecące węzły.
			c.line(16, 28, 16, 12, ArtLib.WOOD[3])
			c.line(16, 18, 9, 11, ArtLib.WOOD[3])
			c.line(16, 18, 23, 11, ArtLib.WOOD[3])
			for p in [Vector2(9, 9), Vector2(23, 9), Vector2(16, 6)]:
				c.shaded_ellipse(p.x, p.y, 3.8, 3.8, ArtLib.GOLD)
		"people":
			for i in 2:
				var x := 11 + i * 10
				c.shaded_ellipse(x, 11 + i, 4.5, 4.5, ArtLib.SKIN)
				c.shaded_ellipse(x, 23 + i, 7, 6, ArtLib.CLOTHS[2 + i])
		"menu":
			for r in 10:
				var ang := r * TAU / 10.0
				c.shaded_ellipse(16 + cos(ang) * 10, 16 + sin(ang) * 10, 3, 3, ArtLib.METALS[2])
			c.shaded_ellipse(16, 16, 10, 10, ArtLib.METALS[2])
			c.ellipse(16, 16, 4, 4, Color(0, 0, 0, 0))
			c.shaded_ellipse(16, 16, 4, 4, [Color("141014"), Color("241c20")])
		"chat":
			c.shaded_ellipse(16, 14, 13, 10, [Color("8a8272"), Color("b8b0a0"), Color("dcd4c4"), Color("f0ead8")])
			c.polygon(PackedVector2Array([Vector2(8, 20), Vector2(6, 29), Vector2(15, 22)]), Color("b8b0a0"))
		"attack":
			for k in 2:
				var sgn := 1 if k == 0 else -1
				c.line(16 - sgn * 11, 27, 16 + sgn * 10, 5, ArtLib.METALS[2][3])
				c.line(16 - sgn * 10, 27, 16 + sgn * 11, 5, ArtLib.METALS[2][4])
				c.line(16 - sgn * 13, 22, 16 - sgn * 6, 27, ArtLib.GOLD[3])
		"skull_white", "skull_red":
			var bone := ArtLib.BONE if name == "skull_white" else [Color("4a0a0a"), Color("7a1414"), Color("b02020"), Color("d83a2a"), Color("f06a4a")]
			c.shaded_ellipse(16, 13, 11, 10, bone)
			c.shaded_rect(10, 20, 12, 7, bone)
			c.ellipse(11.5, 14, 3, 3.2, Color("140c0e"))
			c.ellipse(20.5, 14, 3, 3.2, Color("140c0e"))
			c.polygon(PackedVector2Array([Vector2(16, 17), Vector2(14, 21), Vector2(18, 21)]), Color("140c0e"))
			for i in 3:
				c.rect(12 + i * 3, 24, 1, 3, Color("140c0e"))
		"heal":
			c.shaded_ellipse(16, 16, 13, 13, [Color("0e2a16"), Color("16401e"), Color("1e5628")])
			c.shaded_rect(13, 6, 6, 20, [Color("2a8a3a"), Color("4ac25a"), Color("8af09a")])
			c.shaded_rect(6, 13, 20, 6, [Color("2a8a3a"), Color("4ac25a"), Color("8af09a")])
	c.outline()
	c.bevel(0.08)
	return c.img


## Miękka kropka do cząsteczek (biała, alfa od środka).
static func soft_dot(size: int = 16) -> Image:
	var c := ArtLib.canvas(size, size)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length() / r
			if d < 1.0:
				c.img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 1.6)))
	return c.img


## Logo gry: płonąca korona nad popiołem. with_bg = okrągłe tło (klasyczna ikona).
static func logo(size: int, with_bg: bool) -> Image:
	var c := ArtLib.canvas(size, size)
	var k := size / 48.0
	var cx := size / 2.0
	if with_bg:
		c.shaded_ellipse(cx, cx, 23 * k, 23 * k, [Color("1a0a06"), Color("2a120a"), Color("3e1c10"), Color("5a2a16")])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var fx := cx + (i - 3) * 4.2 * k
		var h := (10 + rng.randi_range(0, 7)) * k
		c.shaded_ellipse(fx, 20 * k - h * 0.3, 3.2 * k, h * 0.7, ArtLib.EMBER)
		c.shaded_ellipse(fx, 21 * k - h * 0.1, 1.8 * k, h * 0.4, [ArtLib.EMBER[2], ArtLib.EMBER[3], Color("fff4c0")])
	c.shaded_rect(int(cx - 14 * k), int(24 * k), int(28 * k), int(10 * k), ArtLib.GOLD)
	for i in 5:
		c.shaded_ellipse(cx - 14 * k + i * 7 * k, 23 * k, 2.4 * k, 4 * k, ArtLib.GOLD)
	c.rect(int(cx - 14 * k), int(31 * k), int(28 * k), int(2 * k), ArtLib.GOLD[1])
	for i in 3:
		c.shaded_ellipse(cx - 8 * k + i * 8 * k, 28 * k, 1.8 * k, 1.8 * k, [Color("5a0a0a"), Color("a01818"), Color("e04040"), Color("ff9090")])
	c.shaded_ellipse(cx, 38 * k, 17 * k, 4 * k, ArtLib.ASH)
	c.outline()
	return c.img


## Tło ikony adaptacyjnej.
static func icon_background(size: int) -> Image:
	var c := ArtLib.canvas(size, size)
	for y in size:
		for x in size:
			var t := 0.7 - float(y) / size * 0.6 + (ArtLib.fbm(x, y, size, 3, 16.0, 2) - 0.5) * 0.2
			c.px(x, y, ArtLib.ramp([Color("0e0606"), Color("1a0a06"), Color("2a120a"), Color("3e1c10")], t, x, y))
	return c.img
