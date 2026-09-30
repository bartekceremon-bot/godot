class_name WorldMapPanel
extends WindowPanel
## Mapa świata: cała kraina w kolorach krain, strefy ryzyka, miasta z nazwami, obeliski terytoriów,
## nazwy krain i pozycja gracza. Otwierana dotknięciem minimapy.

var game: Node
var _view: Control
var _tex: ImageTexture
var _labels: Array = []
var _t := 0.0


func _init() -> void:
	super("Mapa świata", Vector2(0, 0))
	_tex = ImageTexture.create_from_image(MapImage.build())
	_view = Control.new()
	_view.custom_minimum_size = Vector2(560, 560)
	_view.draw.connect(_draw_map)
	content.add_child(_view)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	for z in ["g", "y", "r", "b"]:
		var l := UiTheme.label("■ " + str(GameData.ZONE_NAMES[z]).replace("Strefa ", ""), 16, GameData.ZONE_COLORS[z])
		legend.add_child(l)
	content.add_child(legend)
	_compute_labels()


## Nazwy krain w środkach ciężkości ich obszarów.
func _compute_labels() -> void:
	var sums := {}
	for y in range(0, GameData.map_h, 3):
		for x in range(0, GameData.map_w, 3):
			var b := GameData.biome_at(x, y)
			if not sums.has(b):
				sums[b] = [0.0, 0.0, 0]
			sums[b][0] += x
			sums[b][1] += y
			sums[b][2] += 1
	for b in sums:
		var s: Array = sums[b]
		if s[2] < 30 or b == "m":
			continue
		_labels.append([Vector2(s[0] / s[2], s[1] / s[2]), GameData.BIOME_NAMES.get(b, "")])


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_view.queue_redraw()


func _draw_map() -> void:
	var size := _view.size
	var k := minf(size.x / GameData.map_w, size.y / GameData.map_h)
	var off := (size - Vector2(GameData.map_w, GameData.map_h) * k) / 2.0
	_view.draw_texture_rect(_tex, Rect2(off, Vector2(GameData.map_w, GameData.map_h) * k), false)
	var font := ThemeDB.fallback_font
	for l in _labels:
		var p: Vector2 = off + l[0] * k
		_text(font, p, str(l[1]), 15, Color(1, 0.95, 0.8, 0.85))
	for t in GameData.territories:
		var p := off + Vector2(float(t.x) + 0.5, float(t.y) + 0.5) * k
		_view.draw_circle(p, 5.0, Color(0.1, 0.05, 0.1))
		_view.draw_circle(p, 3.5, Color(1.0, 0.45, 0.9))
	for c in GameData.cities:
		var p := off + Vector2(float(c.temple.x) + 0.5, float(c.temple.y) + 0.5) * k
		_view.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(1, 0.9, 0.5))
		_view.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color.BLACK, false, 1.5)
		_text(font, p + Vector2(0, -12), str(c.name), 18, Color(1, 0.92, 0.6))
	_text(font, off + Vector2(112, 100) * k, "Świątynia Ognia", 14, Color(1, 0.6, 0.3))
	if game and game.me:
		var pp: Vector2 = off + (Vector2(game.my_pos) + Vector2(0.5, 0.5)) * k
		var pulse := 5.0 + sin(_t * 6.0) * 1.5
		_view.draw_circle(pp, pulse + 2.0, Color.BLACK)
		_view.draw_circle(pp, pulse, Color(0.5, 0.85, 1.0))
	_view.draw_rect(Rect2(off, Vector2(GameData.map_w, GameData.map_h) * k), Color("b47e40"), false, 2.0)


func _text(font: Font, pos: Vector2, text: String, size: int, col: Color) -> void:
	var w := 240.0
	var p := pos - Vector2(w / 2.0, 0)
	_view.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 5, Color(0, 0, 0, 0.85))
	_view.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
