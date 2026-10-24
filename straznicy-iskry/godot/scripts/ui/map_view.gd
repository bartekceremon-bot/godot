extends Control
## Animowana mapa archipelagu Luminara. Odkryte wyspy można odwiedzić od razu.

signal travel_requested(area_id: String)

var t := 0.0
var _hits: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(300, 380)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _layout() -> Dictionary:
	var out := {}
	var map: Dictionary = Data.story.get("map", {})
	var s := size
	var k := minf(s.x / 760.0, s.y / 580.0)
	for id in map:
		var p: Array = map[id]["pos"]
		out[id] = s * 0.5 + Vector2(p[0], p[1]) * k
	return out


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("#0f2a33"))
	for i in 7:
		var y := fposmod(i * 70.0 + t * 6.0, s.y)
		draw_line(Vector2(0, y), Vector2(s.x, y + 20), Color(1, 1, 1, 0.03), 18.0)
	var pos := _layout()
	var map: Dictionary = Data.story.get("map", {})
	var k := minf(s.x / 760.0, s.y / 580.0)
	_hits.clear()
	# Świetlne mosty między wyspami
	for id in map:
		for other in map[id].get("links", []):
			if pos.has(other):
				var lit: bool = id in GameState.data["areas_unlocked"] and other in GameState.data["areas_unlocked"]
				var a: Vector2 = pos[id]
				var b: Vector2 = pos[other]
				draw_line(a, b, Color(Art.GOLD if lit else Color("#3a4a46"), 0.8 if lit else 0.5), 4.0, true)
				if lit and not Settings.reduced_motion:
					var f := fmod(t * 0.3, 1.0)
					draw_circle(a.lerp(b, f), 4, Art.CREAM)
	for id in map:
		var c: Vector2 = pos[id]
		var unlocked: bool = id in GameState.data["areas_unlocked"]
		var visited: bool = id in GameState.data["areas_visited"]
		var col := Data.col(map[id].get("color", "#4f8a4a"))
		var r := 64.0 * k
		var bob := sin(t * 1.2 + c.x * 0.01) * 4.0 * k if not Settings.reduced_motion else 0.0
		var cc := c + Vector2(0, bob)
		# Bryła wyspy
		for i in range(5, 0, -1):
			draw_colored_polygon(Art.ellipse(cc + Vector2(0, i * 5 * k), r, r * 0.55, 22), Color("#5a4232").lerp(Color("#2a1f1a"), i / 5.0))
		draw_colored_polygon(Art.ellipse(cc, r, r * 0.55, 22), col if unlocked else Color("#3a4a46"))
		if not visited:
			draw_colored_polygon(Art.ellipse(cc, r * 1.05, r * 0.6, 22), Color("#6b4a9a", 0.45 + 0.1 * sin(t * 2.0)))
		var name: String = Data.area_name(id)
		var font := get_theme_default_font()
		var fs := int(18 * k * 1.2) + 6
		draw_string_outline(font, cc + Vector2(-110, r * 0.55 + 30 * k + 10), name, HORIZONTAL_ALIGNMENT_CENTER, 220, fs, 5, Art.INK)
		draw_string(font, cc + Vector2(-110, r * 0.55 + 30 * k + 10), name, HORIZONTAL_ALIGNMENT_CENTER, 220, fs, Art.CREAM if unlocked else Color("#8a9a94"))
		var ms := Data.missions_in_area(id)
		if not ms.is_empty():
			var done := 0
			for m in ms:
				if GameState.is_mission_done(m):
					done += 1
			var txt := "Zadania: %d/%d" % [done, ms.size()]
			draw_string(font, cc + Vector2(-110, r * 0.55 + 30 * k + 12 + fs), txt, HORIZONTAL_ALIGNMENT_CENTER, 220, fs - 4, Art.GOLD if done == ms.size() else Color("#b9c9bf"))
		if id == World.area_id():
			var pr := 10.0 + 4.0 * sin(t * 4.0)
			draw_circle(cc + Vector2(0, -r * 0.2), pr, Art.GOLD)
			draw_arc(cc + Vector2(0, -r * 0.2), pr + 6, 0, TAU, 20, Color(Art.GOLD, 0.6), 2.0, true)
		if id == "latarnia":
			draw_rect(Rect2(cc + Vector2(-6, -r * 0.9), Vector2(12, r * 0.7)), Art.CREAM)
			Art.glow(self, cc + Vector2(0, -r * 0.95), 30 * k + 10, Color(Art.GOLD, 0.3 + 0.2 * GameState.fragments()))
		_hits[id] = Rect2(cc - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.4))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in _hits:
			if _hits[id].has_point(event.position):
				if id in GameState.data["areas_unlocked"]:
					travel_requested.emit(id)
				else:
					Audio.play("error", 0.0, -6.0)
				accept_event()
				return
