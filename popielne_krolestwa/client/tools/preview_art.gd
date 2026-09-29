extends SceneTree
## Podgląd wygenerowanych grafik (dla twórców): składa arkusz porównawczy do PNG.
## godot --headless --path client --script res://tools/preview_art.gd -- /sciezka/podglad.png

func _load(p: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://assets/" + p))


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas_index.json"))
	var img := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color("20242a"))
	# Teren: każdy 128x128.
	var ter := ["grass", "dirt", "sand", "ash", "floor", "marble"]
	for i in ter.size():
		img.blit_rect(_load("world/terrain/%s.png" % ter[i]), Rect2i(0, 0, 128, 128), Vector2i(i * 130, 0))
	img.blit_rect(_load("world/terrain/water.png"), Rect2i(0, 0, 256, 128), Vector2i(780, 0))
	# Obiekty na trawie.
	var grass := _load("world/terrain/grass.png")
	for x in 4:
		img.blit_rect(grass, Rect2i(0, 0, 128, 128), Vector2i(x * 128, 132))
	img.blend_rect(_load("world/objects.png"), Rect2i(0, 0, 512, 128), Vector2i(0, 132))
	img.blend_rect(_load("world/nodes.png"), Rect2i(0, 0, 256, 256), Vector2i(520, 132))
	# Postacie: złożenie warstw.
	var layers := _load("characters/layers.png")
	var combos := [
		["body_0", "plate_legs_t3", "plate_feet_t3", "plate_body_t3", "plate_head_t3", "sword_t3", "shield_t3"],
		["body_1", "leather_legs_t2", "leather_feet_t2", "leather_body_t2", "leather_head_t2", "bow_t2"],
		["body_4", "cloth_legs_t4", "cloth_feet_t4", "cloth_body_t4", "cloth_head_t4", "mace_t4"],
		["body_2"], ["body_skeleton", "sword_skeleton"], ["npc_smith"], ["npc_banker", "axe_t1"],
	]
	for ci in combos.size():
		var sheet := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for l in combos[ci]:
			var pos: Array = idx.layers[l]
			sheet.blend_rect(layers, Rect2i(pos[0], pos[1], 128, 128), Vector2i.ZERO)
		sheet.resize(256, 256, Image.INTERPOLATE_NEAREST)
		var bg := grass.duplicate()
		bg.resize(256, 256, Image.INTERPOLATE_NEAREST)
		var x := (ci % 4) * 258
		var y := 392 + (ci / 4) * 0
		if ci >= 4:
			x = 780
			y = 392
		img.blit_rect(bg, Rect2i(0, 0, 256, 256), Vector2i(x, y)) if ci < 4 else null
		img.blend_rect(sheet, Rect2i(0, 0, 256, 256), Vector2i(x, y)) if ci < 4 else null
	var beasts := _load("characters/beasts.png")
	img.blend_rect(beasts, Rect2i(0, 0, 128, 256), Vector2i(0, 650 - 256)) if false else null
	var small := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	small.blend_rect(beasts, Rect2i(0, 0, 128, 256), Vector2i.ZERO)
	img.blend_rect(small, Rect2i(0, 0, 128, 118), Vector2i(780, 650))
	var items := _load("items/items.png")
	img.blend_rect(items, Rect2i(0, 0, 160, 118), Vector2i(910, 650))
	img.save_png(out)
	print("ok ", out)
	quit()
