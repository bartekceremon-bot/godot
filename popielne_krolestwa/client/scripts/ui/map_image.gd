class_name MapImage
extends RefCounted
## Obraz całej mapy świata (1 piksel = 1 kafelek) w kolorach krain – wspólny dla minimapy
## i okna mapy świata. Liczony raz po zalogowaniu.

const GROUND := {
	"m": Color("4d7a36"), "f": Color("2f5a28"), "s": Color("dfe6ee"), "r": Color("6a7050"),
	"d": Color("d8b878"), "w": Color("4a5530"), "a": Color("37302f"),
}
const TILE := {
	",": Color("a07a52"), "s": Color("d4c08a"), "~": Color("2f6a9a"), "l": Color("ff6a1a"), "i": Color("b8dcf0"),
	"=": Color("8a5a30"), "#": Color("2a2830"), "H": Color("a84a32"), "f": Color("6e6a70"), "x": Color("c8bda8"),
	"D": Color("8a6a3a"), "M": Color("b83a2a"), "K": Color("8a8a92"), "W": Color("8a6a3a"), "P": Color("c8481e"),
	"U": Color("5aa0d8"), "c": Color("c8a848"), "F": Color("6a4a2a"), "u": Color("b8b0a0"), "p": Color("9a9488"),
	"o": Color("1c1622"), "O": Color("ff40c0"), "r": Color("6a6668"),
}

static var _cache: Image


static func build() -> Image:
	if _cache and _cache.get_width() == GameData.map_w:
		return _cache
	var img := Image.create(GameData.map_w, GameData.map_h, false, Image.FORMAT_RGBA8)
	for y in GameData.map_h:
		var row: String = GameData.map_rows[y]
		for x in GameData.map_w:
			var ch := row[x]
			var b := GameData.biome_at(x, y)
			var g: Color = GROUND.get(b, GROUND["m"])
			var c: Color
			match ch:
				"T":
					c = g.darkened(0.35) if b != "s" else Color("2f5040")
				"^":
					c = Color("8a8078") if b != "s" else Color("f4f8ff")
					if b == "d":
						c = Color("b0744a")
					elif b == "a":
						c = Color("1e1a1e")
				"~":
					c = TILE["~"] if b != "w" else Color("2c3a22")
				".", "n", "d", "a":
					c = g
				_:
					c = TILE.get(ch, g)
			var z := GameData.zone_at(x, y)
			if z == "r":
				c = c.lerp(Color(0.75, 0.2, 0.12), 0.18)
			elif z == "y":
				c = c.lerp(Color(0.85, 0.72, 0.25), 0.1)
			img.set_pixel(x, y, c)
	_cache = img
	return img
