extends Node
## Pomiar kosztu CPU logiki gry na klatkę (headless, bez renderowania) w każdym obszarze.

func _ready() -> void:
	GameState.saving_enabled = false
	GameState.new_game("mechanik")
	GameState.set_flag("intro_seen_world")
	var w: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	for i in 30:
		await get_tree().process_frame
	var areas := ["latarnia", "ogrod", "warsztat", "archiwum"]
	var off := OS.get_environment("PERF_OFF")
	if off != "":
		areas = ["ogrod"]
	for area in areas:
		w.travel(area, "start")
		var guard := 0
		while (World.area_id() != area or w._travelling) and guard < 3000:
			guard += 1
			await get_tree().process_frame
		for i in 30:
			await get_tree().process_frame
		if off != "":
			_disable(w, off)
			for i in 5:
				await get_tree().process_frame
		var n := 300
		var worst := 0
		var total := 0
		var tp := 0.0
		var tf := 0.0
		for i in n:
			await get_tree().process_frame
			# Rzeczywisty czas logiki: process + fizyka (bez czekania na limit klatek).
			tp += Performance.get_monitor(Performance.TIME_PROCESS)
			tf += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			var dt := int((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000000.0)
			total += dt
			worst = maxi(worst, dt)
		print("PERF[%s] " % off + "%s: śr. %.2f ms/klatkę, maks. %.2f ms, węzłów %d, przeciwników %d" % [area, total / float(n) / 1000.0, worst / 1000.0, get_tree().get_node_count(), World.enemies().size()] + "  (process %.2f, fizyka %.2f)" % [tp / n * 1000.0, tf / n * 1000.0])
	get_tree().quit()


func _disable(w: Node, what: String) -> void:
	for n in _all(w.area):
		var sc: Script = n.get_script()
		var path := sc.resource_path if sc else ""
		if (what == "inter" and path.ends_with("interactable.gd")) or (what == "prop" and path.ends_with("prop.gd")) \
			or (what == "enemy" and path.ends_with("enemy.gd")) or (what == "canopy" and path.ends_with("canopy.gd")) \
			or (what == "wobj" and path.ends_with("world_object.gd")):
			n.process_mode = Node.PROCESS_MODE_DISABLED
	if what == "grass":
		w.area.grass_layer.visible = false
		w.area.grass_layer.process_mode = Node.PROCESS_MODE_DISABLED
	if what == "walls":
		w.area.walls.process_mode = Node.PROCESS_MODE_DISABLED
	if what == "fog":
		for f in w._fog:
			f.visible = false
		w.motes.emitting = false
	if what == "worldoff":
		w.process_mode = Node.PROCESS_MODE_DISABLED
	if what == "removed":
		w.get_parent().remove_child(w)
	if what == "allvis":
		w.area.visible = false
	if what == "clouds":
		for c in w._clouds:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	if what == "hero":
		w.hero.process_mode = Node.PROCESS_MODE_DISABLED
		w.blik.process_mode = Node.PROCESS_MODE_DISABLED
	if what == "ui":
		w.hud.process_mode = Node.PROCESS_MODE_DISABLED
		w.touch.process_mode = Node.PROCESS_MODE_DISABLED


func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
