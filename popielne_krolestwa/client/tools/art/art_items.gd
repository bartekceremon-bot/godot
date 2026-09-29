class_name ArtItems
## Ikony przedmiotów 32x32 (z oznaczeniem tieru w rogu, jak w Albionie).

const ICONS := ["wood", "stone", "ore", "fiber", "hide", "planks", "blocks", "bars", "cloth", "leather",
	"sword", "axe", "club", "bow", "shield", "woodaxe", "pickaxe", "sickle",
	"plate_head", "plate_body", "plate_legs", "plate_feet", "leather_head", "leather_body",
	"leather_legs", "leather_feet", "cloth_head", "cloth_body", "cloth_legs", "cloth_feet",
	"gold", "meat", "bone", "hp_potion", "mp_potion", "unknown"]

const TIER_COLORS := [Color.WHITE, Color("8a8a8a"), Color("4f9a3e"), Color("3f6fc0"), Color("9848b8"),
	Color("c8a030"), Color("c05028"), Color("d8d8d8"), Color("202020")]

const DIGITS := {
	1: [".#.", "##.", ".#.", ".#.", "###"], 2: ["##.", "..#", ".#.", "#..", "###"],
	3: ["##.", "..#", ".#.", "..#", "##."], 4: ["#.#", "#.#", "###", "..#", "..#"],
	5: ["###", "#..", "##.", "..#", "##."], 6: [".##", "#..", "##.", "#.#", ".#."],
	7: ["###", "..#", ".#.", ".#.", ".#."], 8: [".#.", "#.#", ".#.", "#.#", ".#."],
}



static func icon(name: String, tier: int) -> Image:
	var c := ArtLib.canvas()
	draw(c, name, tier)
	c.outline()
	c.bevel(0.1)
	badge(c, tier)
	return c.img


## Oznaczenie tieru w lewym górnym rogu.
static func badge(c: ArtLib.Canvas, tier: int) -> void:
	if tier < 1 or tier > 8:
		return
	c.rect(0, 0, 5, 7, TIER_COLORS[tier])
	c.rect(0, 7, 5, 1, ArtLib.OUTLINE)
	c.rect(5, 0, 1, 8, ArtLib.OUTLINE)
	var rows: Array = DIGITS[tier]
	for y in 5:
		for x in 3:
			if rows[y][x] == "#":
				c.px(1 + x, 1 + y, Color.WHITE)


static func draw(c: ArtLib.Canvas, kind: String, tier: int = 0) -> void:
	# Metal i drewno zmieniają kolor z tierem (miedź, cyna, żelazo, tytan).
	var metals := [Color("b8bcc4"), Color("c87a4a"), Color("c8ccd0"), Color("8a8e96"), Color("80c8d8")]
	var steel: Color = metals[clampi(tier, 0, 4)]
	var wood := Color("7a5230")
	var leather := Color("8a5a34")
	var cloths := [Color("c8c0b0"), Color("d8d0c0"), Color("8a7a50"), Color("e0e0e8"), Color("c84a2a")]
	var cloth: Color = cloths[clampi(tier, 0, 4)]
	match kind:
		"wood":
			c.rect(5, 12, 22, 10, Color("7a5230"))
			c.rect(5, 12, 22, 2, Color("9a7248"))
			c.ellipse(26, 17, 3, 5, Color("c8a878"))
			c.ellipse(26, 17, 1.5, 2.5, Color("8a6a40"))
			c.rect(5, 20, 18, 8, Color("6a4424"))
			c.ellipse(23, 24, 3, 4, Color("c8a878"))
		"stone":
			c.ellipse(12, 20, 8, 6, Color("9a968e"))
			c.ellipse(21, 17, 7, 6, Color("b0aca4"))
			c.ellipse(19, 15, 3, 2, Color("d0ccc4"))
		"ore":
			c.ellipse(16, 18, 11, 8, Color("4a4440"))
			for p in [Vector2i(10, 15), Vector2i(17, 20), Vector2i(21, 14), Vector2i(13, 21)]:
				c.rect(p.x, p.y, 3, 3, steel)
		"fiber":
			for i in 7:
				c.line(9 + i * 2, 27, 13 + i, 6, Color("a8b060"))
			c.rect(8, 16, 16, 3, Color("8a5a30"))
		"hide":
			c.ellipse(16, 16, 11, 8, Color("8a6a4a"))
			c.ellipse(16, 16, 7, 5, Color("a08060"))
			c.rect(4, 11, 3, 3, Color("8a6a4a"))
			c.rect(25, 11, 3, 3, Color("8a6a4a"))
			c.rect(6, 21, 3, 3, Color("8a6a4a"))
			c.rect(23, 21, 3, 3, Color("8a6a4a"))
		"planks":
			for i in 3:
				c.rect(4, 8 + i * 6, 24, 5, Color("b08850").darkened(i * 0.1))
				c.rect(4, 8 + i * 6, 24, 1, Color("d0a870"))
		"blocks":
			for i in 3:
				c.rect(5 + (i % 2) * 5, 8 + i * 6, 12, 5, Color("b0aca4"))
				c.rect(18 - (i % 2) * 3, 8 + i * 6, 10, 5, Color("9a968e"))
		"bars":
			for i in 3:
				c.rect(6 + i * 3, 20 - i * 5, 18, 5, steel.darkened(0.1 * i))
				c.rect(6 + i * 3, 20 - i * 5, 18, 1, steel.lightened(0.3))
		"cloth":
			c.rect(6, 10, 20, 14, cloth)
			c.rect(6, 10, 20, 3, cloth.lightened(0.2))
			c.line(6, 17, 25, 17, cloth.darkened(0.2))
			c.ellipse(24, 17, 3, 7, cloth.darkened(0.1))
		"leather":
			c.rect(6, 10, 18, 14, Color("8a5a34"))
			c.ellipse(24, 17, 4, 7, Color("6a4424"))
			c.line(8, 13, 20, 13, Color("a87a4a"))
		"woodaxe":
			c.line(8, 27, 22, 6, wood)
			c.line(9, 27, 23, 6, wood)
			c.rect(18, 5, 9, 7, steel)
			c.rect(24, 4, 3, 9, steel.lightened(0.2))
		"pickaxe":
			c.line(15, 28, 16, 8, wood)
			c.line(16, 28, 17, 8, wood)
			for i in 12:
				c.px(5 + i * 2, 8 + int(abs(i - 5.5) * 0.6), steel)
				c.px(5 + i * 2 + 1, 8 + int(abs(i - 5.5) * 0.6), steel)
		"sickle":
			c.line(12, 28, 12, 18, wood)
			c.line(13, 28, 13, 18, wood)
			for i in 14:
				var a := i / 13.0 * PI
				c.px(int(18 + cos(a) * 8), int(12 - sin(a) * 7), steel)
				c.px(int(18 + cos(a) * 7), int(12 - sin(a) * 6), steel)
		"plate_head", "leather_head", "cloth_head":
			var col := steel if kind.begins_with("plate") else (leather if kind.begins_with("leather") else cloth)
			c.ellipse(16, 16, 10, 9, col)
			c.rect(6, 17, 20, 7, Color(0, 0, 0, 0))
			c.rect(6, 16, 20, 3, col.darkened(0.2))
			if kind.begins_with("plate"):
				c.rect(15, 9, 2, 10, col.darkened(0.3))
		"plate_body", "leather_body", "cloth_body":
			var col := steel if kind.begins_with("plate") else (leather if kind.begins_with("leather") else cloth)
			var h := 22 if kind == "cloth_body" else 19
			c.rect(9, 7, 14, h, col)
			c.rect(5, 8, 5, 8, col.darkened(0.1))
			c.rect(22, 8, 5, 8, col.darkened(0.1))
			c.rect(13, 7, 6, 3, Color(0, 0, 0, 0))
			if kind == "plate_body":
				c.rect(9, 15, 14, 1, col.darkened(0.3))
				c.rect(15, 10, 2, 15, col.lightened(0.2))
		"plate_legs", "leather_legs", "cloth_legs":
			var col := steel if kind.begins_with("plate") else (leather if kind.begins_with("leather") else cloth)
			c.rect(10, 5, 12, 5, col)
			c.rect(10, 10, 5, 17, col)
			c.rect(17, 10, 5, 17, col)
		"plate_feet", "leather_feet", "cloth_feet":
			var col := steel if kind.begins_with("plate") else (leather if kind.begins_with("leather") else cloth)
			c.rect(8, 10, 5, 12, col)
			c.rect(8, 20, 9, 4, col.darkened(0.2))
			c.rect(19, 10, 5, 12, col)
			c.rect(19, 20, 9, 4, col.darkened(0.2))
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
			var liquid := Color("d02a2a") if kind == "hp_potion" else Color("2a5ad0")
			c.rect(14, 5, 4, 5, Color("c0c8d0"))
			c.rect(13, 4, 6, 2, Color("8a5a30"))
			c.ellipse(16, 18, 8, 9, Color("c0c8d0"))
			c.ellipse(16, 19, 7, 7, liquid)
			c.ellipse(13, 16, 2, 2, liquid.lightened(0.4))
		"sword", "ash_sword":
			var blade := steel if kind == "sword" else Color("5a5250")
			c.line(9, 23, 24, 8, blade)
			c.line(10, 23, 25, 8, blade)
			c.line(9, 22, 24, 7, blade.lightened(0.3))
			c.line(6, 20, 12, 26, Color("d4a82a"))
			c.line(5, 26, 8, 23, wood)
			c.line(4, 27, 7, 24, wood)
			if kind == "ash_sword":
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
			var col := leather if kind == "armor" else Color("8a8e96")
			c.rect(9, 7, 14, 19, col)
			c.rect(5, 8, 5, 8, col.darkened(0.1))
			c.rect(22, 8, 5, 8, col.darkened(0.1))
			c.rect(13, 7, 6, 3, Color(0, 0, 0, 0))
			if kind == "chain_armor":
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


