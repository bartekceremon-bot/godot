extends Node2D
## Wszystko, z czym gracz może wejść w interakcję. Rodzaj ustala pole "kind".

var kind := "npc"
var def: Dictionary = {}
var id := ""
var radius := 70.0
var t := 0.0
var anim := 0.0             # pomocnicza animacja (np. otwieranie skrzyni)
var talking := false
var reveal := 0.0           # sekrety: widoczność
var _was_active := false


func setup(k: String, d: Dictionary) -> void:
	kind = k
	def = d
	id = str(d.get("id", d.get("mission", "")))
	radius = float(d.get("radius", 80 if kind != "portal" else 90))
	add_to_group("interactable")
	match kind:
		"chest":
			anim = 1.0 if GameState.in_list("chests", id) else 0.0
		"secret":
			if GameState.in_list("secrets", id):
				queue_free()
		"class_spot":
			anim = 1.0 if GameState.in_list("secrets", id) else 0.0
		"checkpoint":
			anim = 1.0 if GameState.data["checkpoint"].get("spawn", "") == id and GameState.data["checkpoint"].get("area", "") == World.area_id() else 0.0
	_was_active = is_active()


func is_active() -> bool:
	match kind:
		"portal", "station", "npc", "pedestal", "altar":
			return GameState.flags_met(def.get("requires", ""))
		"chest":
			return anim < 1.0
		"secret":
			return reveal > 0.6
		"class_spot":
			return anim < 1.0
	return true


func prompt() -> String:
	match kind:
		"npc": return "Porozmawiaj: " + str(def.get("name", ""))
		"station":
			var m := Data.get_mission(id)
			return ("Powtórz: " if GameState.is_mission_done(id) else "Zadanie: ") + str(m.get("title", ""))
		"chest": return "Otwórz skrzynię"
		"portal": return "Przejdź: " + Data.area_name(def.get("target", ""))
		"checkpoint": return "Zapal Kamień Iskry"
		"pedestal": return "Ołtarz Iskry"
		"altar": return "Zmień klasę"
		"secret": return "Zbadaj błysk"
		"class_spot": return str(def.get("prompt", "Zbadaj"))
		"lore", "clue": return "Przeczytaj: " + str(def.get("title", "tablica"))
	return "Użyj"


func interact(player: Node) -> void:
	var w := World.current
	match kind:
		"npc":
			talking = true
			w.start_npc_dialog(self)
		"station":
			w.open_mission(id)
		"chest":
			_open_chest()
		"portal":
			w.travel(def.get("target", "latarnia"), def.get("spawn", "start"))
		"checkpoint":
			GameState.set_checkpoint(World.area_id(), id)
			GameState.refill()
			GameState.save_game()
			Audio.play("checkpoint")
			w.burst(global_position + Vector2(0, -30), Art.TEAL, 26)
			w.toast("Kamień Iskry zapalony. Postęp zapisany, zdrowie odnowione.", "info")
			for other in get_tree().get_nodes_in_group("interactable"):
				if other.kind == "checkpoint":
					other.anim = 0.0
					other.queue_redraw()
			anim = 1.0
		"pedestal":
			w.use_pedestal()
		"altar":
			w.open_class_change()
		"secret":
			GameState.mark_list("secrets", id)
			_give(def.get("loot", {}), int(def.get("xp", 15)))
			w.blik_say(str(def.get("text", "Sekret! Dobrze, że się rozejrzałeś.")), "cheer")
			w.burst(global_position, Art.GOLD, 20)
			queue_free()
		"class_spot":
			_class_spot(player)
		"lore", "clue":
			w.show_lore(str(def.get("title", "")), str(def.get("text", "")))


func _open_chest() -> void:
	if anim >= 1.0:
		return
	GameState.mark_list("chests", id)
	Audio.play("chest")
	var tw := create_tween()
	tw.tween_property(self, "anim", 1.0, 0.25 if Settings.reduced_motion else 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		World.current.burst(global_position + Vector2(0, -20), Art.GOLD, 22)
		_give(def.get("loot", {}), int(def.get("xp", 15)))
		GameState.save_game())


func _give(loot: Dictionary, xp: int) -> void:
	for item in loot:
		GameState.add_item(item, int(loot[item]))
	if xp > 0:
		GameState.add_xp(xp)
		World.current.float_text(global_position + Vector2(0, -60), "+%d PD" % xp, Art.GOLD)


func _class_spot(_player: Node) -> void:
	var need: String = def.get("class", "")
	var w := World.current
	if GameState.class_id() != need:
		var cname: String = Data.get_class_def(need).get("name", need)
		w.blik_say("To miejsce zareaguje na klasę %s. Możesz tu wrócić po zmianie klasy przy Latarni — to tylko dodatkowa nagroda, nic ważnego Cię nie ominie." % cname, "thinking")
		return
	GameState.mark_list("secrets", id)
	Audio.play("skill")
	var tw := create_tween()
	tw.tween_property(self, "anim", 1.0, 0.6)
	w.blik_say(str(def.get("text", "Twoja klasa świetnie sobie tu radzi!")), "happy")
	w.burst(global_position + Vector2(0, -20), Data.col(Art.palette(need)["glow"]), 24)
	_give(def.get("loot", {}), int(def.get("xp", 20)))


func _process(delta: float) -> void:
	t += delta
	if kind == "secret":
		var p := World.player()
		if p:
			var r := 110.0
			if GameState.class_id() == "tropiciel":
				r = 300.0 + (60.0 if GameState.level() >= 5 else 0.0)
			var target := 1.0 if global_position.distance_to(p.global_position) < r else 0.0
			reveal = move_toward(reveal, target, delta * 2.0)
	var active := is_active()
	if active != _was_active:
		_was_active = active
		if kind == "portal" and active:
			Audio.play("portal")
	if kind == "portal" and active:
		var p := World.player()
		if p and global_position.distance_to(p.global_position) < 34.0 and not World.current.busy():
			interact(p)
	queue_redraw()


func _draw() -> void:
	match kind:
		"npc": Art.npc(self, def.get("look", "lumi"), t, talking)
		"station": _draw_station()
		"chest": _draw_chest()
		"portal": _draw_portal()
		"checkpoint": _draw_checkpoint()
		"pedestal": _draw_pedestal()
		"altar": _draw_altar()
		"secret": _draw_secret()
		"class_spot": _draw_class_spot()
		"lore", "clue": _draw_lore()


func _draw_station() -> void:
	var done := GameState.is_mission_done(id)
	var active := is_active()
	Art.shadow(self, Vector2(0, 2), 28, 9)
	Art.poly(self, PackedVector2Array([Vector2(-24, 0), Vector2(24, 0), Vector2(16, -30), Vector2(-16, -30)]), Color("#3b4a44"))
	Art.poly(self, Art.rrect(Rect2(-20, -36, 40, 10), 3), Color("#5d6a73"))
	var col := Art.GOLD if done else (Art.TEAL if active else Color("#5a6a66"))
	var h := -60.0 + sin(t * 2.0) * 4.0
	Art.glow(self, Vector2(0, h), 34, Color(col, 0.45))
	Art.poly(self, PackedVector2Array([Vector2(0, h - 16), Vector2(11, h), Vector2(0, h + 16), Vector2(-11, h)]), Color(col, 0.9), Art.INK, 2.0)
	if done:
		draw_polyline(PackedVector2Array([Vector2(-5, h), Vector2(-1, h + 5), Vector2(6, h - 6)]), Art.INK, 2.5, true)
	else:
		Art.rune(self, Vector2(0, h), 4.0, Art.INK, id.length(), 1.8)
	if active and not done:
		# Zachęcający pierścień na ziemi.
		var r := 30.0 + fmod(t * 20.0, 20.0)
		draw_arc(Vector2(0, 0), r, 0, TAU, 32, Color(Art.TEAL, 1.0 - (r - 30.0) / 20.0), 2.0, true)


func _draw_chest() -> void:
	Art.shadow(self, Vector2(0, 2), 22, 8)
	var gold = def.get("rare", false)
	var body := Color("#8a5a2b") if not gold else Color("#5b3a8a")
	Art.poly(self, Art.rrect(Rect2(-20, -24, 40, 24), 4), body)
	draw_rect(Rect2(-20, -16, 40, 3), Art.GOLD)
	var open := anim
	var lid_y := -24.0 - open * 14.0
	var lid := PackedVector2Array([Vector2(-21, lid_y), Vector2(21, lid_y), Vector2(18, lid_y - 12 + open * 4), Vector2(-18, lid_y - 12 + open * 4)])
	if open > 0.1:
		Art.glow(self, Vector2(0, -26), 30 * open, Color(Art.GOLD, 0.6 * open))
	Art.poly(self, lid, body.lightened(0.1))
	Art.circle(self, Vector2(0, -16), 3.5, Art.GOLD, Art.INK, 1.2)
	if open < 0.05:
		var s := 0.5 + 0.5 * sin(t * 3.0)
		Art.poly(self, Art.star(Vector2(16, -38), 4 + s * 2, 1.5, 4), Color(Art.GOLD, 0.8), Color(0, 0, 0, 0))


func _draw_portal() -> void:
	var active := is_active()
	var col := Data.col(def.get("color", "#3fd1c1"))
	if not active:
		col = Color("#5a6a66")
	Art.shadow(self, Vector2(0, 4), 46, 14)
	Art.oval(self, Vector2(0, 0), 46, 16, Color("#3b4a44"))
	var c := Vector2(0, -58)
	if active:
		Art.glow(self, c, 80, Color(col, 0.35))
		draw_colored_polygon(Art.ellipse(c, 34, 50, 26), Color(col, 0.35))
		for i in 3:
			var r := fmod(t * 0.6 + i / 3.0, 1.0)
			draw_arc(c, 34 * r, 0, TAU, 24, Color(Art.CREAM, (1.0 - r) * 0.8), 2.0, true)
		for i in 6:
			var a := t * 1.5 + i * TAU / 6
			draw_circle(c + Vector2(cos(a) * 38, sin(a) * 54), 3, Color(Art.GOLD, 0.9))
	# Kamienny łuk
	var arc := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		arc.append(c + Vector2(cos(a) * 44, sin(a) * 62))
	draw_polyline(arc, Art.INK, 16.0, true)
	draw_polyline(arc, Color("#cbbf9f"), 11.0, true)
	for side in [-1.0, 1.0]:
		Art.poly(self, Art.rrect(Rect2(Vector2(side * 44 - 8, -58), Vector2(16, 60)), 3), Color("#cbbf9f"))
	Art.circle(self, c + Vector2(0, -62), 7, col if active else Color("#4a5a55"), Art.INK, 2.0)


func _draw_checkpoint() -> void:
	Art.shadow(self, Vector2(0, 2), 20, 7)
	Art.poly(self, PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(10, -44), Vector2(0, -54), Vector2(-10, -44)]), Color("#8d8a7a"))
	var on := anim
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	Art.glow(self, Vector2(0, -30), 30 + on * 20, Color(Art.TEAL, 0.15 + on * 0.35 * pulse))
	Art.rune(self, Vector2(0, -28), 6.0, Art.TEAL if on > 0.5 else Color("#5a6a66"), 3, 2.5)


func _draw_pedestal() -> void:
	Art.shadow(self, Vector2(0, 2), 36, 12)
	Art.poly(self, Art.rrect(Rect2(-34, -20, 68, 22), 6), Color("#cbbf9f"))
	Art.poly(self, Art.rrect(Rect2(-26, -34, 52, 16), 5), Color("#e3d8bb"))
	var frags := ["frag_jasnosc", "frag_logika", "frag_prawda"]
	var cols := [Color("#ffd86b"), Art.TEAL, Color("#c89bff")]
	for i in 3:
		var p := Vector2(-18 + i * 18, -42)
		var placed := GameState.has_flag("placed_" + frags[i])
		if placed:
			Art.glow(self, p, 20, Color(cols[i], 0.6))
		Art.poly(self, PackedVector2Array([p + Vector2(0, -10), p + Vector2(6, 0), p + Vector2(0, 10), p + Vector2(-6, 0)]), cols[i] if placed else Color("#5a6a66"), Art.INK, 1.5)


func _draw_altar() -> void:
	Art.shadow(self, Vector2(0, 2), 30, 10)
	Art.poly(self, Art.rrect(Rect2(-28, -26, 56, 28), 6), Color("#3b4a44"))
	var ids := ["tkacz", "mechanik", "tropiciel", "straznik"]
	for i in 4:
		var a := t * 0.8 + i * TAU / 4
		var p := Vector2(cos(a) * 22, -50 + sin(a) * 8)
		var c: Color = Art.palette(ids[i])["main"]
		Art.circle(self, p, 6, c, Art.INK, 1.5)
	Art.glow(self, Vector2(0, -50), 30, Color(Art.CREAM, 0.25))


func _draw_secret() -> void:
	if reveal <= 0.01:
		return
	var s := 0.6 + 0.4 * sin(t * 4.0)
	Art.glow(self, Vector2(0, -10), 30 * reveal, Color(Art.GOLD, 0.5 * reveal))
	Art.poly(self, Art.star(Vector2(0, -12), 9 * s * reveal + 2, 3, 4, t), Color(Art.CREAM, reveal), Color(0, 0, 0, 0))


func _draw_class_spot() -> void:
	var need: String = def.get("class", "tkacz")
	var p: Dictionary = Art.palette(need)
	var done := anim
	Art.shadow(self, Vector2(0, 2), 24, 8)
	match need:
		"tkacz":
			Art.poly(self, PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(12, -40), Vector2(-12, -40)]), Color("#6a6577"))
			Art.rune(self, Vector2(0, -22), 8.0, p.glow if done > 0.5 else Color(p.glow, 0.35 + 0.2 * sin(t * 2.0)), 0, 2.5)
		"mechanik":
			Art.poly(self, Art.rrect(Rect2(-22, -30, 44, 30), 5), Color("#5d6a73"))
			draw_line(Vector2(-12, -20), Vector2(10, -12), Art.DANGER if done < 0.5 else p.glow, 3.0)
			draw_circle(Vector2(14, -22), 5, p.glow if done > 0.5 else Color("#6b6b6b"))
		"tropiciel":
			for i in 4:
				var q := Vector2(-18 + i * 12, -4 - (i % 2) * 6)
				draw_colored_polygon(Art.ellipse(q, 3.5, 5, 10), Color(p.glow, 0.25 + done * 0.6 + 0.15 * sin(t * 3.0 + i)))
		_:
			Art.poly(self, Art.rrect(Rect2(-20, -34, 40, 34), 8), Color("#2b3550"))
			Art.circle(self, Vector2(0, -18), 10, p.acc if done > 0.5 else Color("#6b7380"), Art.INK, 2.0)
			Art.poly(self, Art.star(Vector2(0, -18), 6, 2.5, 4), p.main, Color(0, 0, 0, 0))
	if done > 0.5:
		Art.glow(self, Vector2(0, -20), 26, Color(p.glow, 0.3))


func _draw_lore() -> void:
	Art.shadow(self, Vector2(0, 2), 20, 7)
	Art.poly(self, PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(16, -44), Vector2(0, -50), Vector2(-16, -44)]), Color("#a9a08a"))
	for i in 3:
		draw_line(Vector2(-10, -38 + i * 9), Vector2(10, -38 + i * 9), Color("#6e665a"), 2.0)
	Art.glow(self, Vector2(0, -24), 22, Color(Art.TEAL, 0.15 + 0.1 * sin(t * 2.0)))
