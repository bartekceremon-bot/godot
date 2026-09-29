class_name ArtCharacters
## Postacie humanoidalne złożone z warstw (paperdoll) – „jesteś tym, co nosisz”.
## Każda warstwa to arkusz 128x128: kolumny = klatki chodu 0–3, wiersze = kierunek N, E, S, W.
## Warstwy o tej samej pozie nakładają się idealnie, bo wszystkie korzystają z funkcji pose().

const N := 0
const E := 1
const S := 2
const W := 3


## Poza dla kierunku i klatki: prostokąty kończyn, dłonie, głowa.
static func pose(dir: int, frame: int) -> Dictionary:
	var step := 0
	if frame == 1:
		step = 1
	elif frame == 3:
		step = -1
	var oy := -1 if step != 0 else 0
	var p := {"dir": dir, "oy": oy, "step": step}
	if dir == S or dir == N:
		p.torso = Rect2i(11, 13 + oy, 10, 9)
		var ly := 21 + oy
		# Noga lewa/prawa (z punktu widzenia obserwatora): krok = jedna dłuższa, druga podniesiona.
		p.leg_a = Rect2i(12, ly, 3, 29 - ly + (1 if step > 0 else 0) - (1 if step < 0 else 0))
		p.leg_b = Rect2i(17, ly, 3, 29 - ly + (1 if step < 0 else 0) - (1 if step > 0 else 0))
		var swing := step
		p.arm_a = Rect2i(8, 14 + oy + swing, 3, 7)
		p.arm_b = Rect2i(21, 14 + oy - swing, 3, 7)
		p.head = Vector2(16, 8 + oy)
		# Prawa ręka postaci: od frontu jest po lewej stronie obrazka, od tyłu po prawej.
		if dir == S:
			p.hand_r = Vector2i(9, p.arm_a.end.y)
			p.hand_l = Vector2i(22, p.arm_b.end.y)
		else:
			p.hand_r = Vector2i(22, p.arm_b.end.y)
			p.hand_l = Vector2i(9, p.arm_a.end.y)
	else:
		# Widok z boku (w prawo); W to lustrzane odbicie E.
		p.torso = Rect2i(12, 13 + oy, 8, 9)
		var ly2 := 21 + oy
		var spread := step * 2
		p.leg_a = Rect2i(14 - spread, ly2, 3, 29 - ly2)
		p.leg_b = Rect2i(15 + spread, ly2, 3, 29 - ly2)
		p.head = Vector2(16.5, 8 + oy)
		# Ramię przednie (prawe) kołysze się do przodu/tyłu.
		p.shoulder = Vector2i(16, 14 + oy)
		p.hand_r = Vector2i(16 + step * 3, 20 + oy)
		p.hand_l = Vector2i(15 - step * 2, 20 + oy)
	return p


## Rysuje pojedynczą klatkę warstwy. drawer: Callable(canvas, pose).
static func sheet(drawer: Callable, outline := true, mirror_west := true) -> Image:
	var out := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for dir in [N, E, S]:
		for f in 4:
			var c := ArtLib.canvas()
			drawer.call(c, pose(dir, f))
			if outline:
				c.outline()
			out.blit_rect(c.img, Rect2i(0, 0, 32, 32), Vector2i(f * 32, dir * 32))
			if dir == E and mirror_west:
				out.blit_rect(c.flipped(), Rect2i(0, 0, 32, 32), Vector2i(f * 32, W * 32))
	return out


static func _limb(c: ArtLib.Canvas, r: Rect2i, colors: Array) -> void:
	c.shaded_rect(r.position.x, r.position.y, r.size.x, r.size.y, colors)


static func _ramp_of(base: Color) -> Array:
	return [base.darkened(0.55), base.darkened(0.3), base, base.lightened(0.2), base.lightened(0.4)]


# ---------------------------------------------------------------------------
# Ciało (skóra, włosy, tunika, spodnie, buty)
# ---------------------------------------------------------------------------

## opts: skin (rampa), hair (kolor), tunic (kolor), pants (kolor), shoes (kolor), bald, bones
static func body(opts: Dictionary) -> Image:
	return sheet(func(c, p): _draw_body(c, p, opts))


static func _draw_body(c: ArtLib.Canvas, p: Dictionary, o: Dictionary) -> void:
	var skin: Array = o.get("skin", ArtLib.SKIN)
	var tunic := _ramp_of(o.get("tunic", ArtLib.OUTFITS[0]))
	var pants := _ramp_of(o.get("pants", Color("3a3044")))
	var shoes := _ramp_of(o.get("shoes", Color("3a2616")))
	var hair: Color = o.get("hair", Color("4a2e1a"))
	var bones: bool = o.get("bones", false)
	var dir: int = p.dir
	if bones:
		tunic = ArtLib.BONE
		pants = ArtLib.BONE
		shoes = ArtLib.BONE
	if dir == E:
		# Ramię tylne (za tułowiem).
		c.line(p.shoulder.x - 1, p.shoulder.y, p.hand_l.x, p.hand_l.y, tunic[1])
		c.line(p.shoulder.x, p.shoulder.y, p.hand_l.x + 1, p.hand_l.y, tunic[1])
		c.px(p.hand_l.x, p.hand_l.y + 1, skin[1])
	# Nogi i buty.
	for leg in [p.leg_a, p.leg_b]:
		var r: Rect2i = leg
		_limb(c, Rect2i(r.position.x, r.position.y, r.size.x, r.size.y - 2), pants)
		_limb(c, Rect2i(r.position.x, r.end.y - 2, r.size.x + (1 if dir == E else 0), 2), shoes)
	# Tułów.
	var t: Rect2i = p.torso
	_limb(c, t, tunic)
	if bones:
		for i in 3:
			c.rect(t.position.x + 1, t.position.y + 2 + i * 2, t.size.x - 2, 1, ArtLib.BONE[1])
		c.rect(t.position.x + t.size.x / 2, t.position.y, 1, t.size.y, ArtLib.BONE[2])
	else:
		c.rect(t.position.x, t.end.y - 2, t.size.x, 1, pants[1])  # pasek
	# Ręce.
	if dir == S or dir == N:
		for arm in [p.arm_a, p.arm_b]:
			var a: Rect2i = arm
			_limb(c, Rect2i(a.position.x, a.position.y, a.size.x, a.size.y - 2), tunic)
			_limb(c, Rect2i(a.position.x, a.end.y - 2, a.size.x, 2), skin)
	# Głowa.
	var hd: Vector2 = p.head
	c.shaded_ellipse(hd.x, hd.y, 5.6, 5.6, skin if not bones else ArtLib.BONE)
	if bones:
		var ey := int(hd.y)
		if dir == S:
			c.rect(int(hd.x) - 3, ey, 2, 2, Color("1a1014"))
			c.rect(int(hd.x) + 1, ey, 2, 2, Color("1a1014"))
			c.px(int(hd.x) - 2, ey, Color("e04020"))
			c.px(int(hd.x) + 2, ey, Color("e04020"))
			c.rect(int(hd.x) - 2, ey + 3, 5, 1, ArtLib.BONE[1])
		elif dir == E:
			c.rect(int(hd.x) + 1, ey, 2, 2, Color("1a1014"))
			c.px(int(hd.x) + 2, ey, Color("e04020"))
	else:
		var hr := _ramp_of(hair)
		if not o.get("bald", false):
			if dir == N:
				c.shaded_ellipse(hd.x, hd.y - 0.5, 5.8, 5.4, hr)
			elif dir == S:
				c.shaded_ellipse(hd.x, hd.y - 3, 5.8, 3.2, hr)
				c.px(int(hd.x) - 5, int(hd.y) - 1, hr[1])
				c.px(int(hd.x) + 4, int(hd.y) - 1, hr[1])
			else:
				c.shaded_ellipse(hd.x - 1.5, hd.y - 2, 5.0, 4.0, hr)
		# Twarz.
		var eye := Color("1c1418")
		if dir == S:
			c.px(int(hd.x) - 3, int(hd.y) + 1, eye)
			c.px(int(hd.x) + 2, int(hd.y) + 1, eye)
			c.px(int(hd.x) - 1, int(hd.y) + 3, skin[1])
		elif dir == E:
			c.px(int(hd.x) + 3, int(hd.y) + 1, eye)
			c.px(int(hd.x) + 5, int(hd.y) + 2, skin[2])
	if dir == E:
		# Ramię przednie – na wierzchu.
		var sh: Vector2i = p.shoulder
		var hn: Vector2i = p.hand_r
		for k in 3:
			c.line(sh.x - 1 + k, sh.y, hn.x - 1 + k, hn.y - 1, tunic[2 if k == 0 else 1])
		c.rect(hn.x - 1, hn.y - 1, 3, 2, skin[2])


# ---------------------------------------------------------------------------
# Pancerze (typ: plate / leather / cloth, tier 1–4)
# ---------------------------------------------------------------------------

static func armor_ramp(type: String, tier: int) -> Array:
	match type:
		"plate":
			return ArtLib.METALS[tier]
		"leather":
			return ArtLib.LEATHERS[tier]
		_:
			return ArtLib.CLOTHS[tier]


static func armor_body(type: String, tier: int) -> Image:
	var r := armor_ramp(type, tier)
	return sheet(func(c, p):
		var t: Rect2i = p.torso
		var body_r := Rect2i(t.position.x - 1, t.position.y - 1, t.size.x + 2, t.size.y + (4 if type == "cloth" else 1))
		_limb(c, body_r, r)
		if type == "plate":
			# Naramienniki i pionowe wzmocnienie.
			if p.dir != E:
				c.shaded_ellipse(t.position.x, t.position.y + 1, 2.8, 2.2, r)
				c.shaded_ellipse(t.end.x - 1, t.position.y + 1, 2.8, 2.2, r)
			else:
				c.shaded_ellipse(p.shoulder.x, p.shoulder.y, 3.0, 2.4, r)
			c.rect(t.position.x + t.size.x / 2, t.position.y + 1, 1, t.size.y - 2, r[4])
		elif type == "leather":
			c.rect(t.position.x - 1, t.end.y - 2, t.size.x + 2, 1, r[0])
			c.px(t.position.x + t.size.x / 2, t.end.y - 2, ArtLib.GOLD[3])
			for i in range(1, t.size.y - 3, 2):
				c.px(t.position.x + 2, t.position.y + i, r[3])
		else:
			c.rect(t.position.x - 1, t.end.y - 3, t.size.x + 2, 1, ArtLib.GOLD[2])
			if p.dir == S:
				c.line(t.position.x + t.size.x / 2, t.position.y, t.position.x + t.size.x / 2, t.end.y + 2, r[1])
		# Rękawy.
		if p.dir == S or p.dir == N:
			for arm in [p.arm_a, p.arm_b]:
				var a: Rect2i = arm
				_limb(c, Rect2i(a.position.x, a.position.y, a.size.x, a.size.y - 2), r)
		else:
			var sh: Vector2i = p.shoulder
			var hn: Vector2i = p.hand_r
			for k in 3:
				c.line(sh.x - 1 + k, sh.y, hn.x - 1 + k, hn.y - 2, r[3 if k == 0 else 2]))


static func armor_legs(type: String, tier: int) -> Image:
	var r := armor_ramp(type, tier)
	return sheet(func(c, p):
		for leg in [p.leg_a, p.leg_b]:
			var l: Rect2i = leg
			_limb(c, Rect2i(l.position.x, l.position.y, l.size.x, l.size.y - 2), r)
			if type == "plate":
				c.px(l.position.x + 1, l.position.y + 3, r[4]))


static func armor_feet(type: String, tier: int) -> Image:
	var r := armor_ramp(type, tier)
	return sheet(func(c, p):
		for leg in [p.leg_a, p.leg_b]:
			var l: Rect2i = leg
			var hgt := 3 if type != "cloth" else 2
			_limb(c, Rect2i(l.position.x, l.end.y - hgt, l.size.x + (1 if p.dir == E else 0), hgt), r)
			if type == "plate":
				c.px(l.position.x, l.end.y - hgt, r[4]))


static func armor_head(type: String, tier: int) -> Image:
	return sheet(_draw_head.bind(type, tier, armor_ramp(type, tier)))


static func _draw_head(c: ArtLib.Canvas, p: Dictionary, type: String, tier: int, r: Array) -> void:
	var hd: Vector2 = p.head
	match type:
		"plate":
			c.shaded_ellipse(hd.x, hd.y - 0.5, 6.4, 6.2, r)
			if p.dir == S:
				c.rect(int(hd.x) - 4, int(hd.y) + 1, 8, 1, Color("140e12"))
				c.rect(int(hd.x), int(hd.y) - 5, 1, 5, r[4])
			elif p.dir == E:
				c.rect(int(hd.x) + 1, int(hd.y) + 1, 5, 1, Color("140e12"))
			# Grzebień hełmu wyższych tierów.
			if tier >= 3:
				c.rect(int(hd.x) - 1, int(hd.y) - 8, 2, 3, ArtLib.CLOTHS[4][3] if tier == 4 else ArtLib.CLOTHS[2][3])
		"leather":
			# Kaptur: zakrywa włosy i boki głowy.
			c.shaded_ellipse(hd.x, hd.y - 1.5, 6.2, 5.0, r)
			if p.dir == S:
				c.rect(int(hd.x) - 6, int(hd.y), 2, 4, r[1])
				c.rect(int(hd.x) + 4, int(hd.y), 2, 4, r[1])
			elif p.dir == N:
				c.shaded_ellipse(hd.x, hd.y, 6.0, 6.0, r)
		_:
			# Spiczasty kaptur maga.
			c.shaded_ellipse(hd.x, hd.y - 2.0, 6.0, 4.2, r)
			var tip := Vector2(hd.x + (3 if p.dir == E else 1), hd.y - 11)
			c.polygon(PackedVector2Array([Vector2(hd.x - 5, hd.y - 3), tip, Vector2(hd.x + 5, hd.y - 3)]), r[2])
			c.px(int(tip.x), int(tip.y) + 1, r[4])


static func shield(tier: int) -> Image:
	var wood := ArtLib.WOOD
	var metal: Array = ArtLib.METALS[tier]
	return sheet(func(c, p):
		var h: Vector2i = p.hand_l
		var cx := h.x + (1 if p.dir == S else -1)
		if p.dir == E:
			cx = h.x - 2
		c.shaded_ellipse(cx, h.y - 2, 4.5, 5.5, wood)
		c.ellipse(cx, h.y - 2, 4.5, 5.5, Color(0, 0, 0, 0))
		c.shaded_ellipse(cx, h.y - 2, 4.5, 5.5, wood)
		c.shaded_ellipse(cx, h.y - 2, 1.6, 1.6, metal)
		for a in 12:
			var ang := a * TAU / 12.0
			c.px(int(cx + cos(ang) * 4.2), int(h.y - 2 + sin(ang) * 5.2), metal[2]))


## Broń w prawej dłoni. kind: sword / axe / mace / bow.
static func weapon(kind: String, tier: int) -> Image:
	return sheet(_draw_weapon.bind(kind, tier))


static func _draw_weapon(c: ArtLib.Canvas, p: Dictionary, kind: String, tier: int) -> void:
	var metal: Array = ArtLib.METALS[tier]
	var wood := ArtLib.WOOD
	var h: Vector2i = p.hand_r
	# Kierunek ostrza: od frontu/tyłu w górę i lekko na zewnątrz, z boku – do przodu i w górę.
	var outward: int = -1 if (p.dir == S) else 1
	var up := Vector2(outward * 0.35, -1.0).normalized()
	if p.dir == E:
		up = Vector2(0.8, -0.6).normalized()
	var hp := Vector2(h.x + 0.5, h.y)
	match kind:
		"sword":
			var tip := hp + up * 13.0
			for k in 2:
				c.line(int(hp.x) + k, int(hp.y - 1), int(tip.x) + k, int(tip.y), metal[3 - k])
			var side := Vector2(-up.y, up.x)
			c.line(int(hp.x - side.x * 2.5), int(hp.y - 1 - side.y * 2.5), int(hp.x + side.x * 2.5), int(hp.y - 1 + side.y * 2.5), ArtLib.GOLD[2])
			c.line(int(hp.x), int(hp.y), int(hp.x - up.x * 2), int(hp.y - up.y * 2), wood[2])
		"axe":
			var top := hp + up * 11.0
			c.line(int(hp.x - up.x * 2), int(hp.y - up.y * 2), int(top.x), int(top.y), wood[3])
			var side := Vector2(-up.y, up.x) * (-1 if p.dir == S else 1)
			c.shaded_ellipse(top.x + side.x * 2.5, top.y + side.y * 2.5 + 1, 3.0, 3.5, metal)
		"mace":
			var top := hp + up * 10.0
			c.line(int(hp.x - up.x * 2), int(hp.y - up.y * 2), int(top.x), int(top.y), wood[3])
			c.shaded_ellipse(top.x, top.y, 3.2, 3.2, metal)
			c.px(int(top.x), int(top.y) - 4, metal[4])
			c.px(int(top.x) - 4, int(top.y), metal[2])
			c.px(int(top.x) + 3, int(top.y), metal[2])
		"bow":
			# Łuk trzymany pionowo przy dłoni.
			var bx := h.x + (-1 if p.dir == S else 1)
			if p.dir == E:
				bx = h.x + 2
			for i in 17:
				var tt := float(i) / 16.0
				var x := int(bx + sin(tt * PI) * 3.0 * (1 if p.dir != S else -1))
				var y := int(h.y - 8 + i)
				c.px(x, y, wood[3])
				c.px(x + (1 if p.dir != S else -1), y, wood[1])
			c.line(bx, h.y - 8, bx, h.y + 8, Color("d8d0c0"))
			if tier >= 2:
				c.px(bx + (2 if p.dir != S else -2), h.y, metal[3])


# ---------------------------------------------------------------------------
# Zwierzęta (widok z boku; E, a W = odbicie). Dla N/S klient używa ostatniego kierunku poziomego.
# ---------------------------------------------------------------------------

static func beast_sheet(drawer: Callable) -> Image:
	var out := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	for f in 4:
		var c := ArtLib.canvas()
		c.soft_shadow(16, 28, 11, 3.0, 0.35)
		drawer.call(c, f)
		c.outline()
		out.blit_rect(c.img, Rect2i(0, 0, 32, 32), Vector2i(f * 32, 0))
		out.blit_rect(c.flipped(), Rect2i(0, 0, 32, 32), Vector2i(f * 32, 32))
	return out


static func _legs(c: ArtLib.Canvas, xs: Array, y: int, hgt: int, frame: int, col: Array) -> void:
	for i in xs.size():
		var phase := (frame + i) % 4
		var dx: int = [0, 1, 0, -1][phase]
		var lift := 1 if phase == 1 else 0
		c.shaded_rect(xs[i] + dx, y, 2, hgt - lift, col)


static func rat() -> Image:
	var fur := [Color("2e2826"), Color("4a403a"), Color("675a50"), Color("857668"), Color("a39482")]
	return beast_sheet(func(c, f):
		var bob := 1 if f % 2 == 1 else 0
		c.line(5, 22, 1, 19 + bob, Color("b07a7a"))
		c.line(6, 23, 2, 20 + bob, Color("8a5a5a"))
		_legs(c, [9, 12, 17, 20], 23, 5, f, fur)
		c.shaded_ellipse(14, 20 + bob, 8.0, 5.0, fur)
		c.shaded_ellipse(23, 19 + bob, 4.5, 3.8, fur)
		c.shaded_ellipse(21, 15 + bob, 2.0, 2.0, [Color("8a5a5a"), Color("c88a8a"), Color("e8aaaa")])
		c.px(25, 18 + bob, Color("100808"))
		c.px(28, 20 + bob, Color("e0a0a0")))


static func boar() -> Image:
	var fur := [Color("1e140e"), Color("33241a"), Color("4a3524"), Color("634832"), Color("7c5c40")]
	return beast_sheet(func(c, f):
		var bob := 1 if f % 2 == 1 else 0
		_legs(c, [7, 11, 18, 22], 22, 7, f, fur)
		c.shaded_ellipse(15, 18 + bob, 10.0, 6.5, fur)
		for i in 6:
			c.px(8 + i * 3, 11 + bob, fur[0])
			c.px(9 + i * 3, 12 + bob, fur[1])
		c.shaded_ellipse(24, 19 + bob, 5.0, 4.5, fur)
		c.shaded_rect(27, 19 + bob, 3, 3, [Color("6a4a3a"), Color("8a6a5a"), Color("a88a78")])
		c.px(25, 17 + bob, Color("100808"))
		c.line(27, 22 + bob, 29, 20 + bob, Color("f0e8d8"))
		c.px(22, 14 + bob, fur[0]))


static func wolf(dark: bool) -> Image:
	var fur := [Color("2a2826"), Color("44403c"), Color("615a54"), Color("817870"), Color("a39a90")]
	var eye := Color("e8c840")
	if dark:
		fur = [Color("140a0a"), Color("2a1210"), Color("451c16"), Color("62281e"), Color("7e3a28")]
		eye = Color("ff9a30")
	return beast_sheet(func(c, f):
		var bob := 1 if f % 2 == 1 else 0
		c.line(4, 13 + bob, 8, 17 + bob, fur[2])
		c.line(3, 12 + bob, 7, 17 + bob, fur[3])
		_legs(c, [8, 11, 18, 21], 21, 8, f, fur)
		c.shaded_ellipse(14, 17 + bob, 9.5, 5.5, fur)
		c.shaded_ellipse(24, 13 + bob, 4.8, 4.3, fur)
		c.shaded_rect(27, 13 + bob, 4, 3, fur)
		c.polygon(PackedVector2Array([Vector2(21, 10 + bob), Vector2(22, 5 + bob), Vector2(24, 10 + bob)]), fur[2])
		c.px(30, 13 + bob, Color("100808"))
		c.px(25, 12 + bob, eye)
		if dark:
			# Żarzące się iskry na grzbiecie.
			for i in 4:
				c.px(9 + i * 3 + (f % 2), 11 + bob - (i % 2), ArtLib.EMBER[2 + (i + f) % 2]))
