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
