class_name Overlay2D
extends Node2D
## Nakładka 2D nad światem 3D: imiona, paski życia, czaszki, pasek zbierania, liczby obrażeń,
## wypowiedzi z czatu. Pozycje rzutowane z 3D kamerą w każdej klatce (ostry tekst w każdej skali).

var camera: Camera3D
## id -> Entity3D (słownik gry)
var entities: Dictionary = {}
## Aktywne teksty: {pos: Vector3, text, col, t, dur, rise, size}
var _texts: Array[Dictionary] = []
## Przedmioty na ziemi z liczbą sztuk: [[Vector3, int]]
var stacks: Array = []


func float_text(pos: Vector3, text: String, col: Color, dur: float, rise: float, size: int) -> void:
	_texts.append({"pos": pos, "text": text, "col": col, "t": 0.0, "dur": dur, "rise": rise, "size": size})


func say(pos: Vector3, who: String, text: String) -> void:
	float_text(pos + Vector3(0, 1.75, 0), "%s: %s" % [who, text.left(60)], Color(1, 1, 0.55), 3.5, 8.0, 16)


func _process(delta: float) -> void:
	for f in _texts:
		f.t += delta
	_texts = _texts.filter(func(f): return f.t < f.dur)
	queue_redraw()


func _screen(p: Vector3) -> Vector2:
	if camera == null or camera.is_position_behind(p):
		return Vector2(-9999, -9999)
	return camera.unproject_position(p)


func _draw() -> void:
	if camera == null:
		return
	var font := ThemeDB.fallback_font
	var vs := get_viewport_rect().size
	for id in entities:
		var e: Entity3D = entities[id]
		if not is_instance_valid(e):
			continue
		var sp := _screen(e.global_position + Vector3(0, e.label_height, 0))
		if sp.x < -100 or sp.y < -100 or sp.x > vs.x + 100 or sp.y > vs.y + 100:
			continue
		if e.kind == "r":
			if e.show_label:
				_text(font, sp + Vector2(0, -4), e.display_name, 14, Color(0.85, 0.95, 0.8))
			if e.targeted:
				pass
			continue
		var col := Color(0.5, 1, 0.5) if e.kind == "p" else Color(1, 0.86, 0.55)
		if e.kind == "n":
			col = Color(1, 0.9, 0.4)
		if e.is_me:
			col = Color(0.62, 0.86, 1)
		if e.kind == "p" and e.skull == "red":
			col = Color(1, 0.45, 0.45)
		_text(font, sp + Vector2(0, -14), e.display_name, 15, col)
		if e.skull != "":
			var w := font.get_string_size(e.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_texture_rect(Sprites.icon("skull_" + e.skull), Rect2(sp.x - w / 2.0 - 22, sp.y - 30, 18, 18), false)
		if e.kind == "n":
			continue
		var bw := 46.0
		var bar_col := Color(0.25, 0.85, 0.25)
		if e.hp_pct < 60:
			bar_col = Color(0.95, 0.8, 0.15)
		if e.hp_pct < 30:
			bar_col = Color(0.95, 0.2, 0.1)
		draw_rect(Rect2(sp.x - bw / 2.0 - 1, sp.y - 8, bw + 2, 7), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(sp.x - bw / 2.0, sp.y - 7, bw * e.hp_pct / 100.0, 5), bar_col)
		draw_rect(Rect2(sp.x - bw / 2.0, sp.y - 7, bw * e.hp_pct / 100.0, 2), bar_col.lightened(0.35))
		if e.gathering:
			var t := fmod(Time.get_ticks_msec() / 900.0, 1.0)
			draw_rect(Rect2(sp.x - bw / 2.0 - 1, sp.y + 1, bw + 2, 6), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(sp.x - bw / 2.0, sp.y + 2, bw * t, 4), Color(0.5, 0.9, 0.4))
	for s in stacks:
		var sp2 := _screen(s[0])
		_text(font, sp2 + Vector2(10, 6), str(s[1]), 13, Color.WHITE)
	for f in _texts:
		var k: float = f.t / f.dur
		var a := 1.0 - k * k
		var sp3 := _screen(f.pos) - Vector2(0, f.rise * k)
		_text(font, sp3, f.text, f.size, Color(f.col, a), a)


func _text(font: Font, pos: Vector2, text: String, size: int, col: Color, alpha := 1.0) -> void:
	var w := 260.0
	var p := pos - Vector2(w / 2.0, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 5, Color(0, 0, 0, 0.85 * alpha))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
