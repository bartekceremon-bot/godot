extends Node2D
## Przedmioty leżące na ziemi (loot). Rysowane pod istotami.

const TS := 32

## id -> {x, y, it, c}
var items: Dictionary = {}


func set_items(list: Array) -> void:
	items.clear()
	for g in list:
		items[int(g.i)] = g
	queue_redraw()


## Zwraca id przedmiotu na kafelku (ostatnio dodany na wierzchu) albo 0.
func item_at(tile: Vector2i) -> int:
	var found := 0
	for id in items:
		var g: Dictionary = items[id]
		if int(g.x) == tile.x and int(g.y) == tile.y:
			found = id
	return found


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for id in items:
		var g: Dictionary = items[id]
		var p := Vector2(int(g.x), int(g.y)) * TS
		var def := GameData.item_def(str(g.it))
		draw_texture(Sprites.item_icon_for(def), p)
		if int(g.c) > 1:
			draw_string_outline(font, p + Vector2(14, 30), str(int(g.c)), HORIZONTAL_ALIGNMENT_RIGHT, 16, 8, 2, Color.BLACK)
			draw_string(font, p + Vector2(14, 30), str(int(g.c)), HORIZONTAL_ALIGNMENT_RIGHT, 16, 8, Color.WHITE)
