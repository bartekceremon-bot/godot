extends Control
## Minimapa (jak w Tibii): kolorowy podgląd okolicy, gracz w środku, kropki istot.

const VIEW := 40  # kafelków w szerokości
const PAD := VIEW / 2
const COLORS := {
	".": Color("3d6a30"), ",": Color("7f5a3d"), "s": Color("bfa575"), "a": Color("3a3436"),
	"f": Color("63606b"), "x": Color("a69e90"), "~": Color("275a82"), "T": Color("1f4424"),
	"r": Color("5a5660"), "#": Color("22202a"), "D": Color("8a6a3a"), "M": Color("b83a2a"),
	"K": Color("8a8a92"), "W": Color("8a6a3a"), "P": Color("c8481e"),
}

var center := Vector2i.ZERO
## [[Vector2i, Color], ...]
var dots: Array = []
var _tex: ImageTexture


func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(GameData.map_w + PAD * 2, GameData.map_h + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color("0c0a0c"))
	for y in GameData.map_h:
		var row: String = GameData.map_rows[y]
		for x in GameData.map_w:
			var c: Color = COLORS.get(row[x], Color.MAGENTA)
			# Odcień strefy ryzyka.
			var z := GameData.zone_at(x, y)
			if z == "r":
				c = c.lerp(Color(0.8, 0.15, 0.1), 0.35)
			elif z == "y":
				c = c.lerp(Color(0.85, 0.7, 0.2), 0.25)
			img.set_pixel(x + PAD, y + PAD, c)
	_tex = ImageTexture.create_from_image(img)


func update_view(my_pos: Vector2i, entity_dots: Array) -> void:
	center = my_pos
	dots = entity_dots
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_texture_rect_region(_tex, r, Rect2(Vector2(center) + Vector2(PAD, PAD) - Vector2(VIEW, VIEW) / 2.0, Vector2(VIEW, VIEW)))
	var k := r.size.x / VIEW
	for d in dots:
		var p: Vector2 = (Vector2(d[0] - center) + Vector2(VIEW, VIEW) / 2.0) * k + r.position
		if r.has_point(p):
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), d[1])
	var mid := r.position + r.size / 2.0
	draw_rect(Rect2(mid - Vector2(2.5, 2.5), Vector2(5, 5)), Color.WHITE)
	draw_rect(Rect2(mid - Vector2(2.5, 2.5), Vector2(5, 5)), Color.BLACK, false, 1.0)
	# Rama.
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("b47e40"), false, 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1520"), false, 1.0)
