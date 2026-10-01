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
	var boss_e: Entity3D = null
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
			continue
		if e.kind == "t":
			var oc := Overlay2D.guild_color(e.owner_tag) if e.owner_tag != "" else Color(0.85, 0.8, 0.9)
			_text(font, sp + Vector2(0, -14), e.display_name, 16, oc)
			if e.hp_pct > 0:
				var cc := Overlay2D.guild_color(e.capturer_tag)
				draw_rect(Rect2(sp.x - 41, sp.y - 8, 82, 8), Color(0, 0, 0, 0.8))
				draw_rect(Rect2(sp.x - 40, sp.y - 7, 80.0 * e.hp_pct / 100.0, 6), cc)
				_text(font, sp + Vector2(0, 14), "przejmuje [%s]" % e.capturer_tag, 13, cc)
			continue
		if e.boss:
			boss_e = e
		var col := Color(0.5, 1, 0.5) if e.kind == "p" else Color(1, 0.86, 0.55)
		if e.kind == "n":
			col = Color(1, 0.9, 0.4)
		if e.is_me:
			col = Color(0.62, 0.86, 1)
		if e.kind == "p" and e.skull == "red":
			col = Color(1, 0.45, 0.45)
		_text(font, sp + Vector2(0, -14), e.display_name, 15, col)
		if e.guild_tag != "":
			_text(font, sp + Vector2(0, -32), "[%s]" % e.guild_tag, 13, Overlay2D.guild_color(e.guild_tag))
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
	if boss_e:
		# Pasek bossa u góry ekranu.
		var bw := 420.0
		var x0 := vs.x / 2.0 - bw / 2.0
		draw_rect(Rect2(x0 - 3, 58, bw + 6, 20), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(x0, 61, bw * boss_e.hp_pct / 100.0, 14), Color(0.8, 0.12, 0.08))
		draw_rect(Rect2(x0, 61, bw * boss_e.hp_pct / 100.0, 5), Color(1.0, 0.45, 0.3))
		_text(font, Vector2(vs.x / 2.0, 52), "— " + boss_e.display_name + " —", 20, Color(1, 0.8, 0.5))
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


## Kolor gildii wyliczany ze skrótu (ten sam u wszystkich graczy).
static func guild_color(tag: String) -> Color:
	if tag == "":
		return Color.WHITE
	return Color.from_hsv(float(absi(hash(tag)) % 360) / 360.0, 0.55, 1.0)
