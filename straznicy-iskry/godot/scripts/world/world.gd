class_name World
extends Node2D
## Główna scena rozgrywki. Udostępnia innym węzłom wspólne usługi (efekty, UI, podróże).

const AREA := preload("res://scripts/world/area.gd")
const PLAYER := preload("res://scripts/actors/player.gd")
const BLIK := preload("res://scripts/actors/blik.gd")
const FX := preload("res://scripts/fx/fx.gd")
const CLOUDS := preload("res://scripts/world/clouds.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const TOUCH := preload("res://scripts/ui/touch_controls.gd")
const DIALOG := preload("res://scripts/ui/dialog_box.gd")
const PUZZLE := preload("res://scripts/ui/puzzle_panel.gd")
const MENU := preload("res://scripts/ui/pause_menu.gd")
const INFO := preload("res://scripts/ui/info_panel.gd")
const CUTSCENE := preload("res://scripts/ui/cutscene_player.gd")

static var current: World

var area: Node2D
var hero: CharacterBody2D
var blik: Node2D
var camera: Camera2D
var hud: Control
var touch: Control
var dialog: Control
var puzzle: Control
var menu: Control
var info: Control
var motes: CPUParticles2D
var sky: ColorRect
var _clouds: Array = []
var _fog: Array = []
var _enemy_cache: Array = []
var _cache_frame := -1
var _shake := 0.0
var _cam_focus: Variant = null
var _travelling := false
var _boss_awake := false
var _play_acc := 0.0
var _ui_layer: CanvasLayer
var _rotate_hint_shown := false


static func player() -> Node:
	return current.hero if current else null


static func enemies() -> Array:
	if current == null:
		return []
	var f := Engine.get_physics_frames()
	if f != current._cache_frame:
		current._cache_frame = f
		current._enemy_cache = current.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.alive)
	return current._enemy_cache


static func area_id() -> String:
	return current.area.id if current and current.area else ""


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_build_sky()
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	_build_motes()
	_build_ui()
	hero = PLAYER.new()
	hero.died.connect(_on_player_died)
	blik = BLIK.new()
	blik.target = hero
	var cp: Dictionary = GameState.data["checkpoint"]
	_load_area(str(cp.get("area", "latarnia")), str(cp.get("spawn", "start")))
	GameState.leveled_up.connect(_on_level_up)
	GameState.mission_completed.connect(_on_mission_completed)
	GameState.notify.connect(toast)
	GameState.flag_changed.connect(_on_flag)
	Router.focus_lost.connect(_on_focus_lost)
	Router.layout_changed.connect(_on_layout)
	_on_layout(Router.narrow)
	Audio.play_music(area.def.get("music", "explore"))
	if not GameState.persistent_storage:
		toast("Ta przeglądarka nie zapisuje danych na stałe. Postęp może zniknąć po zamknięciu karty — użyj eksportu zapisu w menu.", "warn")
	if not GameState.has_flag("intro_seen_world"):
		GameState.set_flag("intro_seen_world")
		GameState.save_game()
		await get_tree().create_timer(0.6).timeout
		start_dialog("intro_wake")


func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	sky = ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/sky.gdshader")
	sky.material = m
	layer.add_child(sky)
	for i in 2:
		var c: Node2D = CLOUDS.new()
		c.depth = i
		c.z_index = -40 + i
		add_child(c)
		_clouds.append(c)


func _build_motes() -> void:
	motes = CPUParticles2D.new()
	motes.amount = 14 if Settings.low_quality() else 36
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(760, 460)
	motes.direction = Vector2(0.3, -1)
	motes.spread = 40.0
	motes.gravity = Vector2(0, -6)
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 22.0
	motes.scale_amount_min = 0.08
	motes.scale_amount_max = 0.18
	motes.texture = Art.glow_texture()
	motes.material = Art.add_material()
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.9, 0.6, 0))
	g.add_point(0.3, Color(1, 0.9, 0.6, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.4, 1, 0.9, 0))
	motes.color_ramp = g
	motes.z_index = 25
	camera.add_child(motes)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	var theme := UITheme.build()
	hud = HUD.new()
	hud.theme = theme
	# HUD animuje komunikaty także podczas pauzy (dialogi, menu).
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(hud)
	touch = TOUCH.new()
	touch.theme = theme
	_ui_layer.add_child(touch)
	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	for n in ["dialog", "puzzle", "info", "menu"]:
		var c: Control
		match n:
			"dialog": c = DIALOG.new()
			"puzzle": c = PUZZLE.new()
			"info": c = INFO.new()
			"menu": c = MENU.new()
		c.theme = theme
		c.process_mode = Node.PROCESS_MODE_ALWAYS
		top.add_child(c)
		set(n, c)
	puzzle.finished.connect(_on_puzzle_finished)
	dialog.closed.connect(_on_overlay_closed)
	info.closed.connect(_on_overlay_closed)
	menu.closed.connect(_on_overlay_closed)


func _on_layout(narrow: bool) -> void:
	for c in [hud, touch, dialog, puzzle, menu, info]:
		if c and c.has_method("apply_layout"):
			c.apply_layout(narrow)
	var vsz := get_viewport_rect().size
	if vsz.y > vsz.x and not _rotate_hint_shown and hud:
		_rotate_hint_shown = true
		toast("Wskazówka: obróć telefon poziomo, aby widzieć więcej świata. W pionie też możesz grać.", "info")
	if camera:
		var vs := get_viewport_rect().size
		# Na wąskich ekranach lekko oddalamy kamerę, żeby widzieć więcej świata.
		var z := 1.0 if vs.x >= vs.y else 0.8
		if vs.x >= vs.y and vs.y < 600.0:
			z = 0.85
		camera.zoom = Vector2(z, z)


# --- Obszary i podróże -----------------------------------------------------

func _load_area(area_id_: String, spawn: String) -> void:
	if area:
		if hero.get_parent():
			hero.get_parent().remove_child(hero)
		if blik.get_parent():
			blik.get_parent().remove_child(blik)
		area.queue_free()
		for f in _fog:
			f.queue_free()
		_fog.clear()
	_boss_awake = false
	hud.boss_bar(false, 1.0)
	area = AREA.new()
	add_child(area)
	area.build(area_id_)
	GameState.visit_area(area_id_)
	area.entities.add_child(hero)
	area.entities.add_child(blik)
	hero.global_position = area.spawn_point(spawn)
	hero.velocity = Vector2.ZERO
	blik.global_position = hero.global_position + Vector2(-40, 0)
	camera.global_position = hero.global_position
	camera.reset_smoothing()
	var b: Rect2 = area.bounds.grow(260)
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y + 120)
	var sky_def: Dictionary = area.def.get("sky", {})
	var m: ShaderMaterial = sky.material
	m.set_shader_parameter("top", Data.col(sky_def.get("top", "#0f2a33")))
	m.set_shader_parameter("bottom", Data.col(sky_def.get("bottom", "#2a5c60")))
	for c in _clouds:
		c.tint = Data.col(sky_def.get("cloud", "#f5ecd7"))
		c.queue_redraw()
	_spawn_fog()
	hud.set_area_name(area.def.get("name", ""))


func _spawn_fog() -> void:
	var fog: Dictionary = area.def.get("fog", {})
	if fog.is_empty() or GameState.has_flag(fog.get("until", "")):
		return
	var n := int(fog.get("count", 10))
	if Settings.low_quality():
		n = int(n * 0.4)
	for i in n:
		var s := Sprite2D.new()
		s.texture = Art.soft_texture()
		s.modulate = Color(0.55, 0.36, 0.75, 0.22)
		s.scale = Vector2.ONE * randf_range(3.0, 6.0)
		s.position = Vector2(randf_range(area.bounds.position.x, area.bounds.end.x), randf_range(area.bounds.position.y, area.bounds.end.y))
		s.z_index = -5
		s.set_meta("v", Vector2(randf_range(-12, 12), randf_range(-6, 6)))
		add_child(s)
		_fog.append(s)


func travel(target: String, spawn: String) -> void:
	if _travelling or not Data.areas.has(target):
		return
	_travelling = true
	hero.controls_locked = true
	Audio.play("portal")
	await Router.fade_out(0.45)
	_load_area(target, spawn)
	GameState.set_checkpoint(target, spawn)
	GameState.save_game()
	Audio.play_music(area.def.get("music", "explore"))
	await Router.fade_in(0.45)
	hero.controls_locked = false
	_travelling = false
	var enter: String = area.def.get("blik_enter", "")
	if not enter.is_empty() and not GameState.has_flag("blik_enter_" + target):
		GameState.set_flag("blik_enter_" + target)
		blik_say(enter, "surprised")


func _on_player_died() -> void:
	GameState.data["deaths"] = int(GameState.data["deaths"]) + 1
	Audio.play("death")
	hud.show_banner("Mgła Cię otoczyła…", "Wracasz do Kamienia Iskry. Wiedza i zadania zostają z Tobą.")
	await get_tree().create_timer(1.6).timeout
	await Router.fade_out(0.5)
	var cp: Dictionary = GameState.data["checkpoint"]
	_load_area(str(cp["area"]), str(cp["spawn"]))
	GameState.refill()
	hero.revive()
	Audio.play_music(area.def.get("music", "explore"))
	await Router.fade_in(0.5)
	blik_say(Data.blik.get("respawn", "Spokojnie, jestem tu. Spróbuj jeszcze raz — tym razem obserwuj czerwone zapowiedzi ataków."), "worried")


# --- Pętla -----------------------------------------------------------------

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_play_acc += delta
	if _play_acc >= 1.0:
		if OS.has_feature("web"):
			# Pomiar wydajności dostępny dla testów (window.__fps) — bez analityki.
			JavaScriptBridge.eval("window.__fps=%d" % Engine.get_frames_per_second(), true)
		GameState.data["play_time"] = float(GameState.data["play_time"]) + _play_acc
		_play_acc = 0.0
	# Kamera
	var target: Vector2 = hero.global_position + Vector2(0, -30)
	if _boss_awake and area and is_instance_valid(area.boss) and area.boss.alive:
		# W walce z bossem kamera obejmuje gracza i Miraża (oraz jego kopie).
		target = target.lerp(area.boss.global_position + Vector2(0, -60), 0.5) + Vector2(0, -40)
	if _cam_focus != null:
		target = _cam_focus
	camera.global_position = target
	if _shake > 0.0 and Settings.screen_shake and not Settings.reduced_motion:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, delta * 30.0)
	else:
		camera.offset = Vector2.ZERO
		_shake = 0.0
	if area:
		area.grass_material.set_shader_parameter("player_pos", hero.global_position)
		area.check_triggers(hero.global_position)
		if area.boss and is_instance_valid(area.boss) and not _boss_awake and area.boss.alive:
			if hero.global_position.distance_to(area.boss.global_position) < 520.0:
				_wake_boss()
	for f in _fog:
		var v: Vector2 = f.get_meta("v")
		f.position += v * delta
		if not area.bounds.grow(200).has_point(f.position):
			f.position = area.bounds.get_center() + Vector2(randf_range(-400, 400), randf_range(-300, 300))
	hud.update_interact(hero.nearest_interactable())


func _unhandled_input(event: InputEvent) -> void:
	if busy():
		return
	if event.is_action_pressed("pause"):
		open_menu("journal")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		open_menu("map")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		open_menu("journal")
		get_viewport().set_input_as_handled()


func busy() -> bool:
	return dialog.visible or puzzle.visible or menu.visible or info.visible or _travelling or hero.dead


func _pause(on: bool) -> void:
	get_tree().paused = on
	Settings.release_all_actions()
	touch.reset()
	hero.release_inputs()


func _on_overlay_closed() -> void:
	if not (dialog.visible or puzzle.visible or menu.visible or info.visible):
		_pause(false)


func _on_focus_lost() -> void:
	touch.reset()
	hero.release_inputs()
	if not busy() and not hero.dead:
		open_menu("journal")


func open_menu(tab: String) -> void:
	_pause(true)
	menu.open(tab)


# --- Efekty ----------------------------------------------------------------

func add_effect(n: Node2D) -> void:
	area.effects.add_child(n)


func add_enemy(e: Node2D) -> void:
	area.entities.add_child(e)


func add_interactable(n: Node2D) -> void:
	area.entities.add_child(n)


func _fx(kind: String, pos: Vector2, c: Color, s: float, n := 10) -> Node2D:
	var f: Node2D = FX.new()
	var count := n
	if Settings.low_quality() or Settings.reduced_motion:
		count = int(ceil(n * 0.4))
	f.init(kind, pos, c, s, count)
	if area.effects.get_child_count() < 160:
		area.effects.add_child(f)
	else:
		f.free()
		return null
	return f


func burst(pos: Vector2, c: Color, n := 12, s := 60.0) -> void:
	_fx("burst", pos, c, s, n)


func ring(pos: Vector2, c: Color, r: float) -> void:
	_fx("ring", pos, c, r)


func float_text(pos: Vector2, text: String, c: Color) -> void:
	var f := _fx("text", pos, c, 1.0)
	if f:
		f.text = text


func lightning(a: Vector2, b: Vector2, c: Color) -> void:
	var f := _fx("lightning", Vector2.ZERO, c, 1.0)
	if f:
		var pts := PackedVector2Array([a])
		for i in range(1, 6):
			pts.append(a.lerp(b, i / 6.0) + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
		pts.append(b)
		f.points = pts


func slash(pos: Vector2, dir: Vector2, c: Color) -> void:
	var f := _fx("slash", pos - dir * 34.0 + Vector2(0, 24), c, 1.0)
	if f:
		f.dir = dir


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func scan_pulse(pos: Vector2, r: float) -> void:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.kind == "secret" and n.global_position.distance_to(pos) < r:
			n.reveal = 1.0


func clear_enemy_shots(pos: Vector2, r: float) -> void:
	for c in area.effects.get_children():
		if c is PROJECTILE_T and c.team == "enemy" and c.global_position.distance_to(pos) < r:
			c.queue_free()


const PROJECTILE_T := preload("res://scripts/actors/projectile.gd")


func is_walkable(p: Vector2) -> bool:
	return area.is_walkable(p)


func enemy_died(e: Node) -> void:
	if e.tag.is_empty():
		return
	for other in enemies():
		if other != e and other.alive and "tag" in other and other.tag == e.tag:
			return
	GameState.set_flag("cleared_" + e.tag)


func _wake_boss() -> void:
	_boss_awake = true
	area.wake_boss()
	area.boss.defeated.connect(_on_boss_defeated)
	hud.boss_bar(true, 1.0)
	Audio.play_music("boss")
	start_dialog("miraz_intro")


func boss_hp(v: float) -> void:
	hud.boss_bar(v > 0.0, v)


func _on_boss_defeated() -> void:
	hud.boss_bar(false, 0.0)
	GameState.set_flag("boss_defeated")
	GameState.add_item("frag_prawda")
	GameState.save_game()
	Audio.play_music(area.def.get("music", "explore"))
	await get_tree().create_timer(1.4).timeout
	start_dialog("miraz_defeated")


# --- Interfejs i fabuła ----------------------------------------------------

func toast(text: String, kind := "info") -> void:
	hud.toast(text, kind)


func blik_say(text: String, mood := "happy") -> void:
	blik.set_mood(mood, 4.0)
	hud.blik_message(text)
	Audio.play("blik", 0.15, -6.0)


func start_dialog(dialog_id: String, npc: Node = null) -> void:
	var lines: Array = Data.dialogs.get(dialog_id, [])
	if lines.is_empty():
		return
	_pause(true)
	dialog.open(dialog_id, lines, npc)


func start_npc_dialog(npc: Node) -> void:
	var chosen := ""
	for rule in npc.def.get("dialogs", []):
		if GameState.flags_met(rule.get("requires", "")):
			chosen = rule["id"]
			break
	if chosen.is_empty():
		return
	start_dialog(chosen, npc)


func dialog_finished(dialog_id: String) -> void:
	## Wywoływane przez okno dialogu po ostatniej kwestii.
	var actions: Dictionary = Data.dialogs.get("_actions", {}).get(dialog_id, {})
	for f in actions.get("set_flags", []):
		GameState.set_flag(f)
	for a in actions.get("unlock_areas", []):
		GameState.unlock_area(a)
	if actions.has("give"):
		for item in actions["give"]:
			GameState.add_item(item, int(actions["give"][item]))
	if actions.has("blik"):
		blik_say(actions["blik"], actions.get("mood", "happy"))
	if actions.has("travel"):
		travel(actions["travel"][0], actions["travel"][1])
	if actions.get("finale", false):
		_play_finale()
	GameState.save_game()


func run_trigger(tr: Dictionary) -> void:
	if tr.has("dialog"):
		start_dialog(tr["dialog"])
	elif tr.has("blik"):
		blik_say(tr["blik"], tr.get("mood", "happy"))


func open_mission(mission_id: String) -> void:
	var m := Data.get_mission(mission_id)
	if m.is_empty():
		return
	_pause(true)
	puzzle.open(m)


func _on_puzzle_finished(mission_id: String, success: bool) -> void:
	_pause(false)
	if success and not GameState.is_mission_done(mission_id):
		GameState.complete_mission(mission_id)


func _on_mission_completed(mission_id: String) -> void:
	var m := Data.get_mission(mission_id)
	Audio.play("quest")
	hud.show_banner("Zadanie ukończone!", str(m.get("title", "")))
	burst(hero.global_position + Vector2(0, -40), Art.GOLD, 26, 90.0)
	if m.has("focus"):
		# Pokazujemy zmianę w świecie wywołaną rozwiązaniem.
		await get_tree().create_timer(0.4).timeout
		_cam_focus = Vector2(m["focus"][0], m["focus"][1])
		await get_tree().create_timer(1.0 if Settings.reduced_motion else 2.4).timeout
		_cam_focus = null
	if m.has("blik_after"):
		blik_say(m["blik_after"], "cheer")


func _on_flag(f: String) -> void:
	if f.begins_with("cleared_") and area:
		var msg: String = area.def.get("cleared_msgs", {}).get(f, "")
		if not msg.is_empty():
			blik_say(msg, "cheer")
	# Fragment zdobyty → kolejny obszar dostępny.
	var unlocks: Dictionary = Data.story.get("unlocks", {})
	if unlocks.has(f):
		GameState.unlock_area(unlocks[f])
	if f == "frag_jasnosc" or f == "frag_logika" or f == "frag_prawda":
		Audio.play("fragment")
		hud.show_banner("Fragment Iskry!", Data.get_item(f).get("name", ""))


func _on_level_up(lvl: int) -> void:
	Audio.play("levelup")
	var unlock: String = Data.get_class_def(GameState.class_id()).get("path", {}).get(str(lvl), "")
	hud.show_banner("Poziom %d!" % lvl, unlock)
	burst(hero.global_position + Vector2(0, -30), Art.GOLD, 30, 110.0)
	ring(hero.global_position, Art.GOLD, 120.0)
	if lvl == 2:
		blik_say(Data.blik.get("skill2", "Nowa umiejętność! Spróbuj jej teraz."), "cheer")


func show_lore(title: String, text: String) -> void:
	_pause(true)
	info.show_text(title, text)


func open_class_change() -> void:
	_pause(true)
	info.show_class_picker()


func change_class(cid: String) -> void:
	GameState.set_class(cid)
	hero.set_class(cid)
	hud.refresh_skills()
	burst(hero.global_position + Vector2(0, -30), Art.palette(cid)["glow"], 30, 100.0)
	blik_say("Nowa klasa: %s. Poziom, zadania i wiedza zostały z Tobą." % Data.get_class_def(cid).get("name", cid), "cheer")


func use_pedestal() -> void:
	var placed_any := false
	for f in ["frag_jasnosc", "frag_logika", "frag_prawda"]:
		if GameState.item_count(f) > 0:
			GameState.add_item(f, -1)
			GameState.set_flag("placed_" + f)
			placed_any = true
	var count := 0
	for f in ["frag_jasnosc", "frag_logika", "frag_prawda"]:
		if GameState.has_flag("placed_" + f):
			count += 1
	if placed_any:
		Audio.play("fragment")
		burst(hero.global_position + Vector2(0, -60), Art.GOLD, 30, 120.0)
		GameState.save_game()
	if count >= 3 and not GameState.has_flag("lighthouse_restored"):
		start_dialog("finale_ready")
	elif count >= 3:
		blik_say("Latarnia świeci pełnym blaskiem. Zajrzyj do miejsc, których jeszcze nie odkryłeś!", "happy")
	else:
		blik_say("Fragmenty na ołtarzu: %d z 3. Brakujące czekają w kolejnych obszarach." % count, "thinking")


func _play_finale() -> void:
	GameState.set_flag("lighthouse_restored")
	GameState.data["game_complete"] = true
	GameState.add_xp(50)
	GameState.save_game()
	_pause(true)
	Audio.play_music("finale")
	var cs: Control = CUTSCENE.new()
	cs.theme = hud.theme
	cs.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(cs)
	cs.play(Data.story.get("finale", []))
	await cs.finished
	cs.queue_free()
	_pause(false)
	Audio.play_music(area.def.get("music", "explore"))
	for c in area.entities.get_children():
		if c.get("kind") == "tower":
			c.queue_redraw()
	blik_say(Data.blik.get("post_game", "Latarnia znów świeci! Możesz dalej zwiedzać Luminarę i szukać sekretów."), "cheer")
