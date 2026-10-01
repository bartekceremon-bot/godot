extends Control
## Minimapa (jak w Tibii): kolorowy podgląd okolicy, gracz w środku, kropki istot.
## Dotknięcie otwiera mapę świata.

signal opened

const VIEW := 40  # kafelków w szerokości
const PAD := VIEW / 2
var center := Vector2i.ZERO
## [[Vector2i, Color], ...]
var dots: Array = []
var _tex: ImageTexture
const FRAME := preload("res://assets/ui/frame_round.png")


func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Mapa świata"
	var src := MapImage.build()
	var img := Image.create(GameData.map_w + PAD * 2, GameData.map_h + PAD * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color("0c0a0c"))
	img.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(PAD, PAD))
	_tex = ImageTexture.create_from_image(img)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		opened.emit()
		accept_event()


func update_view(my_pos: Vector2i, entity_dots: Array) -> void:
	center = my_pos
	dots = entity_dots
	queue_redraw()


func _draw() -> void:
	# Okrągła mapa (jak na kompasie) w złotej obręczy z nitami.
	var c := size / 2.0
	var rad := size.x / 2.0 - 8.0
	var src_origin := Vector2(center) + Vector2(PAD, PAD) - Vector2(VIEW, VIEW) / 2.0
	var tex_size := Vector2(_tex.get_width(), _tex.get_height())
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var p := c + Vector2(cos(a), sin(a)) * rad
		pts.append(p)
		uvs.append((src_origin + (p - (c - Vector2(rad, rad))) / (rad * 2.0) * VIEW) / tex_size)
	draw_colored_polygon(pts, Color.WHITE, uvs, _tex)
	var k := rad * 2.0 / VIEW
	for d in dots:
		var p: Vector2 = (Vector2(d[0] - center) + Vector2(VIEW, VIEW) / 2.0) * k + c - Vector2(rad, rad)
		if p.distance_to(c) < rad - 2.0:
			draw_circle(p, 2.2, d[1])
	# Gracz: strzałka.
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 5), c + Vector2(0, 2), c + Vector2(-5, 5)]), Color.WHITE)
	draw_texture_rect(FRAME, Rect2(Vector2.ZERO, size), false)
	# Litera północy.
	draw_string(UiTheme.TITLE_FONT, Vector2(c.x - 6, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.6))
