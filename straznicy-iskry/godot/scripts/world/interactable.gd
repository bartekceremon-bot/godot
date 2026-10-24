extends Node2D
## Wszystko, z czym gracz może wejść w interakcję. Rodzaj ustala pole "kind".

var kind := "npc"
var def: Dictionary = {}
var id := ""
var radius := 70.0
var t := 0.0
## Pomocnicza animacja (np. otwieranie skrzyni). Zmiana wymusza przerysowanie.
var anim := 0.0:
	set(v):
		anim = v
		queue_redraw()
		_refresh_fx()
var talking := false:
	set(v):
		talking = v
		if _talk_dot:
			_talk_dot.visible = v
var reveal := 0.0           # sekrety: widoczność
var _was_active := false
var _used := false          # skrzynia / miejsce klasowe już użyte (blokuje podwójną nagrodę)
# Animacje bez przerysowywania: rysunek powstaje raz, a ruch dają transformacje
# węzłów potomnych (na WebGL każde przerysowanie wielokątów jest kosztowne).
var _fx: Node2D             # pływający element (kryształ stacji, gwiazdka skrzyni...)
var _ring: Node2D           # pulsujący pierścień stacji / fale portalu
var _orbit: Node2D          # orbitujące elementy (portal, ołtarz klas)
var _glow: Sprite2D
var _talk_dot: Node2D
var _on_screen := true


func setup(k: String, d: Dictionary) -> void:
	kind = k
	def = d
	id = str(d.get("id", d.get("mission", "")))
	radius = float(d.get("radius", 80 if kind != "portal" else 90))
	add_to_group("interactable")
	match kind:
		"chest":
			_used = GameState.in_list("chests", id)
			anim = 1.0 if _used else 0.0
		"secret":
			if GameState.in_list("secrets", id):
				queue_free()
		"class_spot":
			_used = GameState.in_list("secrets", id)
			anim = 1.0 if _used else 0.0
		"checkpoint":
			anim = 1.0 if GameState.data["checkpoint"].get("spawn", "") == id and GameState.data["checkpoint"].get("area", "") == World.area_id() else 0.0
	_was_active = is_active()
	_build_fx()
	if kind in ["station", "pedestal"]:
		GameState.flag_changed.connect(func(_f: String) -> void:
			queue_redraw()
			_refresh_fx())
		GameState.mission_completed.connect(func(_m: String) -> void: _refresh_fx())


func is_active() -> bool:
	match kind:
		"portal", "station", "npc", "pedestal", "altar":
			return GameState.flags_met(def.get("requires", ""))
		"chest":
			return not _used
		"secret":
			return reveal > 0.6
		"class_spot":
			return not _used
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
	if _used:
		return
	_used = true
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
	if _used:
		return
	_used = true
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
			modulate.a = reveal
	var active := is_active()
	if active != _was_active:
		_was_active = active
		if kind == "portal" and active:
			Audio.play("portal")
		queue_redraw()
		_refresh_fx()
	if kind == "portal" and active:
		var p := World.player()
		if p and global_position.distance_to(p.global_position) < 34.0 and not World.current.busy():
			interact(p)
	_on_screen = World.current == null or World.current.on_screen(global_position, 200.0)
	if _on_screen:
		_animate()


# --- Animacja przez transformacje ------------------------------------------

func _painter(cb: Callable, pos := Vector2.ZERO) -> Node2D:
	## Węzeł, który rysuje się raz (cb dostaje węzeł docelowy) i jest animowany ruchem.
	var n := Node2D.new()
	n.position = pos
	n.draw.connect(func() -> void: cb.call(n))
	add_child(n)
	return n


func _make_glow(pos: Vector2, r: float, col: Color) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Art.glow_texture()
	g.position = pos
	g.scale = Vector2.ONE * (r * 2.0 / 128.0)
	g.modulate = col
	g.show_behind_parent = true
	add_child(g)
	return g


func _build_fx() -> void:
	match kind:
		"npc":
			_talk_dot = _painter(func(ci: Node2D) -> void: ci.draw_circle(Vector2.ZERO, 3, Color(Art.CREAM, 0.9)), Vector2(0, -68))
			_talk_dot.visible = false
		"station":
			_glow = _make_glow(Vector2(0, -60), 34, Color(Art.TEAL, 0.45))
			_fx = _painter(_draw_station_crystal, Vector2(0, -60))
			_ring = _painter(func(ci: Node2D) -> void: ci.draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Art.TEAL, 2.0, true))
		"chest":
			_fx = _painter(func(ci: Node2D) -> void: Art.poly(ci, Art.star(Vector2.ZERO, 6, 1.5, 4), Color(Art.GOLD, 0.8), Color(0, 0, 0, 0)), Vector2(16, -38))
		"portal":
			_glow = _make_glow(Vector2(0, -58), 80, Color(Art.TEAL, 0.35))
			_ring = _painter(func(ci: Node2D) -> void:
				for r in [11.0, 22.0, 33.0]:
					ci.draw_arc(Vector2.ZERO, r, 0.3, TAU - 0.3, 24, Color(Art.CREAM, 0.6), 2.0, true), Vector2(0, -58))
			var squash := Node2D.new()
			squash.position = Vector2(0, -58)
			squash.scale = Vector2(1.0, 54.0 / 38.0)
			add_child(squash)
			_orbit = Node2D.new()
			squash.add_child(_orbit)
			_orbit.draw.connect(func() -> void:
				for i in 6:
					var a := i * TAU / 6
					_orbit.draw_circle(Vector2(cos(a), sin(a)) * 38, 3, Color(Art.GOLD, 0.9)))
		"checkpoint":
			_glow = _make_glow(Vector2(0, -30), 40, Color(Art.TEAL, 0.3))
		"altar":
			_glow = _make_glow(Vector2(0, -50), 30, Color(Art.CREAM, 0.25))
			var squash := Node2D.new()
			squash.position = Vector2(0, -50)
			squash.scale = Vector2(1.0, 0.36)
			add_child(squash)
			_orbit = Node2D.new()
			squash.add_child(_orbit)
			_orbit.draw.connect(func() -> void:
				var ids := ["tkacz", "mechanik", "tropiciel", "straznik"]
				for i in 4:
					var a := i * TAU / 4
					Art.circle(_orbit, Vector2(cos(a), sin(a)) * 22, 6, Art.palette(ids[i])["main"], Art.INK, 1.5))
		"secret":
			_glow = _make_glow(Vector2(0, -10), 30, Color(Art.GOLD, 0.5))
			_fx = _painter(func(ci: Node2D) -> void: Art.poly(ci, Art.star(Vector2.ZERO, 9, 3, 4), Art.CREAM, Color(0, 0, 0, 0)), Vector2(0, -12))
			modulate.a = 0.0
		"lore", "clue":
			_glow = _make_glow(Vector2(0, -24), 22, Color(Art.TEAL if kind == "lore" else Color("#c89bff"), 0.2))
		"class_spot":
			var pal: Dictionary = Art.palette(def.get("class", "tkacz"))
			_glow = _make_glow(Vector2(0, -20), 26, Color(pal["glow"], 0.3))
	_refresh_fx()


func _refresh_fx() -> void:
	## Stan (aktywne, ukończone, otwarte) zmienia wygląd elementów animowanych.
	if not is_inside_tree() and _fx == null and _glow == null:
		return
	var active := is_active()
	match kind:
		"station":
			var done := GameState.is_mission_done(id)
			var col := Art.GOLD if done else (Art.TEAL if active else Color("#5a6a66"))
			if _glow:
				_glow.modulate = Color(col, 0.45)
			if _fx:
				_fx.queue_redraw()
			if _ring:
				_ring.visible = active and not done
		"chest":
			if _fx:
				_fx.visible = anim < 0.05
		"portal":
			for n in [_glow, _ring, _orbit]:
				if n:
					n.visible = active
			if _glow:
				_glow.modulate = Color(Data.col(def.get("color", "#3fd1c1")), 0.35)
		"checkpoint":
			if _glow:
				_glow.modulate = Color(Art.TEAL, 0.15 + anim * 0.3)
		"class_spot":
			if _glow:
				_glow.visible = anim > 0.5


func _animate() -> void:
	var slow := Settings.reduced_motion
	match kind:
		"npc":
			# Oddychanie: delikatne skalowanie w pionie zamiast przerysowania.
			scale = Vector2(1.0, 1.0 + sin(t * 2.0) * (0.008 if slow else 0.02))
			if _talk_dot and talking:
				_talk_dot.modulate.a = 0.6 + 0.4 * sin(t * 8.0)
		"station":
			if _fx:
				var h := sin(t * 2.0) * (1.5 if slow else 4.0)
				_fx.position.y = -60.0 + h
				_glow.position.y = -60.0 + h
			if _ring and _ring.visible:
				var k := fmod(t * 20.0, 20.0) / 20.0
				_ring.scale = Vector2.ONE * (1.0 + k * 0.66)
				_ring.modulate.a = 1.0 - k
		"chest":
			if _fx and _fx.visible:
				_fx.scale = Vector2.ONE * (0.8 + 0.4 * (0.5 + 0.5 * sin(t * 3.0)))
		"portal":
			if _orbit and _orbit.visible:
				_orbit.rotation = t * 1.5
				_ring.rotation = -t * 0.8
				_ring.scale = Vector2.ONE * (1.0 + 0.06 * sin(t * 3.0))
		"checkpoint":
			if _glow and anim > 0.5:
				_glow.modulate.a = 0.25 + 0.2 * sin(t * 3.0)
		"altar":
			if _orbit:
				_orbit.rotation = t * 0.8
		"secret":
			if _fx:
				_fx.rotation = t
				_fx.scale = Vector2.ONE * (0.7 + 0.3 * sin(t * 4.0))
		"lore", "clue":
			if _glow:
				_glow.modulate.a = 0.15 + 0.1 * sin(t * 2.0)


# --- Rysunki statyczne (raz, przy zmianie stanu) ------------------------------

func _draw() -> void:
	match kind:
		"npc": Art.npc(self, def.get("look", "lumi"), 0.0, false)
		"station": _draw_station()
		"chest": _draw_chest()
		"portal": _draw_portal()
		"checkpoint": _draw_checkpoint()
		"pedestal": _draw_pedestal()
		"altar": _draw_altar()
		"secret": pass
		"class_spot": _draw_class_spot()
		"lore", "clue": _draw_lore()


func _draw_station() -> void:
	Art.shadow(self, Vector2(0, 2), 28, 9)
	Art.poly(self, PackedVector2Array([Vector2(-24, 0), Vector2(24, 0), Vector2(16, -30), Vector2(-16, -30)]), Color("#3b4a44"))
	Art.poly(self, Art.rrect(Rect2(-20, -36, 40, 10), 3), Color("#5d6a73"))


func _draw_station_crystal(ci: Node2D) -> void:
	var done := GameState.is_mission_done(id)
	var col := Art.GOLD if done else (Art.TEAL if is_active() else Color("#5a6a66"))
	Art.poly(ci, PackedVector2Array([Vector2(0, -16), Vector2(11, 0), Vector2(0, 16), Vector2(-11, 0)]), Color(col, 0.9), Art.INK, 2.0)
	if done:
		ci.draw_polyline(PackedVector2Array([Vector2(-5, 0), Vector2(-1, 5), Vector2(6, -6)]), Art.INK, 2.5, true)
	else:
		Art.rune(ci, Vector2.ZERO, 4.0, Art.INK, id.length(), 1.8)


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


func _draw_portal() -> void:
	var active := is_active()
	var col := Data.col(def.get("color", "#3fd1c1"))
	if not active:
		col = Color("#5a6a66")
	Art.shadow(self, Vector2(0, 4), 46, 14)
	Art.oval(self, Vector2(0, 0), 46, 16, Color("#3b4a44"))
	var c := Vector2(0, -58)
	if active:
		draw_colored_polygon(Art.ellipse(c, 34, 50, 26), Color(col, 0.35))
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
	Art.rune(self, Vector2(0, -28), 6.0, Art.TEAL if anim > 0.5 else Color("#5a6a66"), 3, 2.5)


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


func _draw_class_spot() -> void:
	var need: String = def.get("class", "tkacz")
	var p: Dictionary = Art.palette(need)
	var done := anim
	Art.shadow(self, Vector2(0, 2), 24, 8)
	match need:
		"tkacz":
			Art.poly(self, PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(12, -40), Vector2(-12, -40)]), Color("#6a6577"))
			Art.rune(self, Vector2(0, -22), 8.0, p.glow if done > 0.5 else Color(p.glow, 0.45), 0, 2.5)
		"mechanik":
			Art.poly(self, Art.rrect(Rect2(-22, -30, 44, 30), 5), Color("#5d6a73"))
			draw_line(Vector2(-12, -20), Vector2(10, -12), Art.DANGER if done < 0.5 else p.glow, 3.0)
			draw_circle(Vector2(14, -22), 5, p.glow if done > 0.5 else Color("#6b6b6b"))
		"tropiciel":
			for i in 4:
				var q := Vector2(-18 + i * 12, -4 - (i % 2) * 6)
				draw_colored_polygon(Art.ellipse(q, 3.5, 5, 10), Color(p.glow, 0.35 + done * 0.6))
		_:
			Art.poly(self, Art.rrect(Rect2(-20, -34, 40, 34), 8), Color("#2b3550"))
			Art.circle(self, Vector2(0, -18), 10, p.acc if done > 0.5 else Color("#6b7380"), Art.INK, 2.0)
			Art.poly(self, Art.star(Vector2(0, -18), 6, 2.5, 4), p.main, Color(0, 0, 0, 0))


func _draw_lore() -> void:
	Art.shadow(self, Vector2(0, 2), 20, 7)
	Art.poly(self, PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(16, -44), Vector2(0, -50), Vector2(-16, -44)]), Color("#a9a08a"))
	for i in 3:
		draw_line(Vector2(-10, -38 + i * 9), Vector2(10, -38 + i * 9), Color("#6e665a"), 2.0)
