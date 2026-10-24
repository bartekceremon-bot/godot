class_name Icons
extends RefCounted
## Wektorowe ikony interfejsu (umiejętności, akcje). Bez emoji i obrazków.


static func draw(ci: CanvasItem, icon: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.1)
	match icon:
		"tkacz_basic":
			Art.rune(ci, c, s * 0.38, col, 0, w)
		"tkacz_skill1":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(-s * 0.1, s * 0.05), c + Vector2(s * 0.05, -s * 0.15), c + Vector2(s * 0.4, s * 0.3)]), col, w, true)
			for p in [c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(s * 0.05, -s * 0.15), c + Vector2(s * 0.4, s * 0.3)]:
				ci.draw_circle(p, s * 0.09, col)
		"tkacz_skill2":
			ci.draw_arc(c, s * 0.38, 0, TAU, 24, col, w, true)
			Art.rune(ci, c, s * 0.18, col, 3, w * 0.8)
		"mechanik_basic":
			ci.draw_arc(c + Vector2(-s * 0.15, 0), s * 0.35, -0.9, 0.9, 12, col, w, true)
			ci.draw_arc(c + Vector2(-s * 0.3, 0), s * 0.3, -0.8, 0.8, 12, Color(col, 0.6), w * 0.7, true)
		"mechanik_skill1":
			ci.draw_circle(c, s * 0.16, col)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.25), c + Vector2(-s * 0.1, -s * 0.05), col, w)
			ci.draw_line(c + Vector2(s * 0.4, -s * 0.25), c + Vector2(s * 0.1, -s * 0.05), col, w)
			ci.draw_line(c + Vector2(-s * 0.5, -s * 0.28), c + Vector2(-s * 0.28, -s * 0.28), col, w)
			ci.draw_line(c + Vector2(s * 0.5, -s * 0.28), c + Vector2(s * 0.28, -s * 0.28), col, w)
		"mechanik_skill2":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, s * 0.35), c + Vector2(s * 0.3, s * 0.35), c + Vector2(s * 0.15, 0), c + Vector2(-s * 0.15, 0)]), col)
			ci.draw_circle(c + Vector2(0, -s * 0.08), s * 0.17, col)
			ci.draw_line(c + Vector2(0, -s * 0.08), c + Vector2(s * 0.4, -s * 0.3), col, w)
		"tropiciel_basic":
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.3), c + Vector2(s * 0.35, -s * 0.25), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, -s * 0.32), c + Vector2(s * 0.15, -s * 0.25), c + Vector2(s * 0.3, -s * 0.05)]), col)
		"tropiciel_skill1":
			ci.draw_arc(c, s * 0.18, 0, TAU, 16, col, w, true)
			ci.draw_arc(c, s * 0.38, -0.6, 0.6, 10, col, w, true)
			ci.draw_arc(c, s * 0.38, PI - 0.6, PI + 0.6, 10, col, w, true)
		"tropiciel_skill2":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.42), c + Vector2(s * 0.2, -s * 0.05), c + Vector2(0, -s * 0.02), c + Vector2(s * 0.1, s * 0.42), c + Vector2(-s * 0.2, s * 0.05), c + Vector2(0, s * 0.02)]), col)
		"straznik_basic":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.35), c + Vector2(s * 0.1, -s * 0.05), col, w * 1.3, true)
			ci.draw_colored_polygon(Art.rrect(Rect2(c + Vector2(-s * 0.05, -s * 0.42), Vector2(s * 0.45, s * 0.28)), 3).duplicate(), col)
		"straznik_skill1":
			ci.draw_arc(c + Vector2(0, s * 0.15), s * 0.4, PI, TAU, 20, col, w, true)
			ci.draw_line(c + Vector2(-s * 0.45, s * 0.15), c + Vector2(s * 0.45, s * 0.15), col, w)
		"straznik_skill2":
			for i in 8:
				var a := TAU * i / 8
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.15, c + Vector2(cos(a), sin(a)) * s * 0.42, col, w, true)
		"dodge":
			ci.draw_arc(c, s * 0.32, -PI * 0.2, PI * 1.2, 18, col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, -s * 0.05), c + Vector2(s * 0.18, -s * 0.12), c + Vector2(s * 0.3, s * 0.12)]).duplicate(), col)
		"interact":
			ci.draw_circle(c, s * 0.12, col)
			ci.draw_arc(c, s * 0.3, 0, TAU, 20, col, w, true)
		"menu":
			for i in 3:
				ci.draw_line(c + Vector2(-s * 0.3, (i - 1) * s * 0.22), c + Vector2(s * 0.3, (i - 1) * s * 0.22), col, w, true)
		"map":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.25), c + Vector2(-s * 0.13, -s * 0.35), c + Vector2(s * 0.13, -s * 0.25), c + Vector2(s * 0.4, -s * 0.35), c + Vector2(s * 0.4, s * 0.3), c + Vector2(s * 0.13, s * 0.4), c + Vector2(-s * 0.13, s * 0.3), c + Vector2(-s * 0.4, s * 0.4), c + Vector2(-s * 0.4, -s * 0.25)]), col, w, true)
		"potion":
			ci.draw_colored_polygon(Art.ellipse(c + Vector2(0, s * 0.1), s * 0.3, s * 0.3), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.38), Vector2(s * 0.2, s * 0.22)), col)
		_:
			ci.draw_circle(c, s * 0.2, col)
