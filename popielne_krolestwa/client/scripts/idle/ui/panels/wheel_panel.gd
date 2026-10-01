class_name WheelPanel
extends IdlePanel
## Koło Żaru: rysowane koło z 8 polami, animowany obrót, darmowy obrót dziennie, obrót za
## reklamę i za żarokryształy, okno szans.

var _dial: WheelDial
var _info: Label
var _result: Label
var _btns: VBoxContainer
var _spinning := false


class WheelDial:
	extends Control
	var angle := 0.0
	var icons: Array = []

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 8.0
		var n := WheelManager.SEGMENTS.size()
		var seg := TAU / n
		draw_circle(c, r + 8.0, Color(0.16, 0.1, 0.06))
		for i in n:
			var a0 := -PI / 2.0 + angle + i * seg
			var pts := PackedVector2Array([c])
			for k in 17:
				var a := a0 + seg * k / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			var col: Color = WheelManager.SEGMENTS[i][3]
			draw_colored_polygon(pts, col.darkened(0.15) if i % 2 == 0 else col)
			draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color(0.2, 0.12, 0.05), 3.0, true)
			var am := a0 + seg / 2.0
			if i < icons.size() and icons[i]:
				var p := c + Vector2(cos(am), sin(am)) * r * 0.66
				var s := r * 0.3
				draw_texture_rect(icons[i], Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		draw_arc(c, r, 0, TAU, 96, Color(1.0, 0.8, 0.4), 5.0, true)
		for k in 16:
			var a := k * TAU / 16.0 + angle * 0.0
			draw_circle(c + Vector2(cos(a), sin(a)) * (r + 4.0), 4.0, Color(1.0, 0.9, 0.6))
		draw_circle(c, r * 0.16, Color(0.25, 0.14, 0.06))
		draw_circle(c, r * 0.12, Color(1.0, 0.7, 0.25))
		# wskaźnik na górze
		var top := Vector2(c.x, c.y - r - 2.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-20, -22), top + Vector2(20, -22), top + Vector2(0, 18)]), Color(1.0, 0.95, 0.85))
		draw_polyline(PackedVector2Array([top + Vector2(-20, -22), top + Vector2(20, -22), top + Vector2(0, 18), top + Vector2(-20, -22)]), Color(0.2, 0.1, 0.05), 3.0, true)


func build() -> void:
	add_child(IdleUI.title("Koło Żaru", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	var box: VBoxContainer = sc[1]
	_info = IdleUI.label("", 18, UiTheme.TEXT, true)
	box.add_child(_info)
	_dial = WheelDial.new()
	_dial.custom_minimum_size = Vector2(420, 420)
	_dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tex := {"gold": IdleUI.ash_tex("ico_gold"), "gold_big": IdleUI.ash_tex("ico_gold"), "gems10": IdleUI.ash_tex("nav_gem"), "gems50": IdleUI.ash_tex("nav_gem"),
		"chest": Sprites.icon("chest"), "rune": load("res://assets/ui/runes/fire.png"), "shards": load("res://assets/ui/modes/shard.png"), "jackpot": load("res://assets/ui/modes/relics.png")}
	for s in WheelManager.SEGMENTS:
		_dial.icons.append(tex.get(str(s[0])))
	box.add_child(_dial)
	_result = IdleUI.label("", 22, IdleUI.GOLD_COL, true)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result)
	_btns = IdleUI.vbox(8)
	box.add_child(_btns)


func refresh() -> void:
	var w := gm.wheel
	_info.text = "Jeden darmowy obrót każdego dnia. Dodatkowy obrót za reklamę (raz dziennie) i do %d obrotów za %d żarokryształów." % [WheelManager.PAID_LIMIT, WheelManager.GEM_COST]
	IdleUI.clear(_btns)
	if w.free_spins() > 0:
		var b := IdleUI.button("Zakręć kołem! (darmowe: %d)" % w.free_spins(), Vector2(0, 92), 28)
		b.pressed.connect(func(): _spin(false))
		b.disabled = _spinning
		_btns.add_child(b)
	else:
		var ad := IdleUI.button("▶ Obejrzyj reklamę: +1 obrót", Vector2(0, 80), 22)
		ad.disabled = _spinning or not gm.premium.ad_available("wheel_spin")
		ad.pressed.connect(func(): ui.ad_reward("wheel_spin", func(): request_refresh()))
		_btns.add_child(ad)
		var gb := IdleUI.button("Zakręć za %d żarokr. (%d / %d dziś)" % [WheelManager.GEM_COST, w.paid_today(), WheelManager.PAID_LIMIT], Vector2(0, 80), 22)
		IdleUI.set_affordable(gb, not _spinning and w.can_spin(true))
		gb.pressed.connect(func(): _spin(true))
		_btns.add_child(gb)
	var ob := IdleUI.button("Szanse", Vector2(0, 64), 19)
	ob.pressed.connect(func(): ui.show_odds("Koło Żaru", gm.wheel.odds()))
	_btns.add_child(ob)


func _spin(use_gems: bool) -> void:
	if _spinning:
		return
	var res := gm.wheel.spin(use_gems)
	if res.is_empty():
		ui.toast_msg("Brak obrotów.", IdleUI.BAD)
		return
	_spinning = true
	_result.text = ""
	request_refresh()
	var n := WheelManager.SEGMENTS.size()
	var seg := TAU / n
	var idx := int(res[0])
	# Środek wylosowanego pola pod wskaźnikiem (+ kilka pełnych obrotów, lekkie przesunięcie).
	var target := -(idx + 0.5) * seg + randf_range(-0.3, 0.3) * seg
	var cur := fposmod(_dial.angle, TAU)
	var dest := cur + 5.0 * TAU + fposmod(target - cur, TAU)
	_dial.angle = cur
	gm.audio.play("click")
	var tw := create_tween()
	tw.tween_method(func(a):
		_dial.angle = a
		_dial.queue_redraw(), cur, dest, 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		_spinning = false
		_result.text = str(res[1])
		gm.audio.play("rare" if idx >= 6 else "coin")
		if idx == n - 1:
			ui.banner("WIELKA WYGRANA!", str(res[1]), IdleUI.GOLD_COL)
		request_refresh())


func on_changed(what: String) -> void:
	if what in ["wheel", "all", "premium"] and not _spinning:
		request_refresh()
