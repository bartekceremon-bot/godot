extends Node
## Zrzuty samej sceny walki 3D (bez interfejsu) do porównania stylów:
## godot --path . res://tests/style_shots.tscn -- --shots=KATALOG [--style=a|b|c]

var dir := "user://style_shots"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(dir)
	_run.call_deferred()


func _run() -> void:
	var g = Idle
	g.save.path = "user://style_shots.save"
	g.save.delete_save()
	g.start()
	g.running = false
	for d in g.db.mercs.slice(0, 3):
		g.s.mercs[str(d.id)] = 10
	var vp := SubViewport.new()
	vp.size = Vector2i(540, 760)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var view := BattleView.new()
	vp.add_child(view)
	view.set_shadows(true)
	for st in [3, 23, 65]:
		g.s.stage = st
		g.s.max_stage = maxi(int(g.s.max_stage), st)
		seed(st)
		g.enemy.spawn()
		view.set_region(g.progression.region(st))
		view.set_hero(g.skins.model(g.equipment.model_equipment()))
		var hired: Array = g.db.mercs.filter(func(d): return g.mercs.level(str(d.id)) > 0)
		view.set_mercs(hired)
		view.spawn_enemy(g.enemy.cur)
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(dir.path_join("etap_%02d.png" % st))
		print("style-shots: ", st)
	g.save.delete_save()
	get_tree().quit()
