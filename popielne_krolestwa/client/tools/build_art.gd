extends SceneTree
## Generator grafik gry (pixel art) -> PNG w res://assets/ + indeks res://assets/atlas_index.json.
## Uruchomienie: tools/build_assets.sh (albo: godot --headless --path client --script res://tools/build_art.gd)
##
## Wszystkie grafiki są tworzone przez ten kod (licencja CC0). Każdy PNG można podmienić
## ręcznie narysowaną wersją – gra czyta tylko pliki i indeks.

const OUT := "res://assets/"
var index := {}


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	for d in ["world", "world/terrain", "characters", "items", "ui", "fx"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + d))
	_terrain()
	_objects()
	_nodes()
	_characters()
	_items()
	_ui()
	var f := FileAccess.open(OUT + "atlas_index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t"))
	f.close()
	print("Grafiki wygenerowane w %d ms." % (Time.get_ticks_msec() - t0))
	quit()


## Powiększenie pikseli (nearest) – interfejs w 2x wygląda wyraźnie na telefonie.
func _x2(img: Image, f: int = 2) -> Image:
	img.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	return img


func _save(img: Image, path: String) -> void:
	var err := img.save_png(OUT + path)
	if err != OK:
		push_error("Zapis %s: %s" % [path, error_string(err)])


# ---------------------------------------------------------------------------

func _terrain() -> void:
	_save(ArtTerrain.grass(), "world/terrain/grass.png")
	_save(ArtTerrain.dirt(), "world/terrain/dirt.png")
	_save(ArtTerrain.sand(), "world/terrain/sand.png")
	_save(ArtTerrain.ash(), "world/terrain/ash.png")
	_save(ArtTerrain.floor_stone(), "world/terrain/floor.png")
	_save(ArtTerrain.marble(), "world/terrain/marble.png")
	# Woda: 4 klatki obok siebie (512x128).
	var strip := Image.create(512, 128, false, Image.FORMAT_RGBA8)
	for f in 4:
		strip.blit_rect(ArtTerrain.water(f), Rect2i(0, 0, 128, 128), Vector2i(f * 128, 0))
	_save(strip, "world/terrain/water.png")
	_save(ArtTerrain.noise_tex(), "world/terrain/noise.png")


## Atlas obiektów dla TileSetu (komórka 32 px). Zapisujemy [kolumna, wiersz, szer., wys.] w komórkach.
func _objects() -> void:
	var atlas := Image.create(512, 128, false, Image.FORMAT_RGBA8)
	var objs := {}
	var put := func(name: String, img: Image, cx: int, cy: int) -> void:
		atlas.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(cx * 32, cy * 32))
		objs[name] = [cx, cy, img.get_width() / 32, img.get_height() / 32]
	var styles := ["oak", "dark", "pine", "chestnut"]
	for i in styles.size():
		put.call("tree_%d" % i, ArtWorld.tree(styles[i], i + 1), i * 2, 0)
	for v in 3:
		put.call("wall_front_%d" % v, ArtWorld.wall(true, v), 8 + v, 0)
		put.call("wall_inner_%d" % v, ArtWorld.wall(false, v), 11 + v, 0)
	put.call("stall", ArtWorld.market_stall(), 14, 0)
	put.call("furnace", ArtWorld.furnace(), 15, 0)
	put.call("rock_0", ArtWorld.rock(0, false), 0, 2)
	put.call("rock_1", ArtWorld.rock(1, false), 1, 2)
	put.call("rock_ash_0", ArtWorld.rock(0, true), 2, 2)
	put.call("rock_ash_1", ArtWorld.rock(2, true), 3, 2)
	put.call("chest", ArtWorld.depot_chest(), 4, 2)
	put.call("anvil", ArtWorld.anvil(), 5, 2)
	put.call("workbench", ArtWorld.workbench(), 6, 2)
	put.call("torch", ArtWorld.torch(), 7, 2)
	_save(atlas, "world/objects.png")
	index["objects"] = objs


func _nodes() -> void:
	var atlas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var nodes := {}
	var kinds := ["wood", "stone", "ore", "fiber"]
	for k in kinds.size():
		for t in range(1, 5):
			atlas.blit_rect(ArtWorld.node(kinds[k], t), Rect2i(0, 0, 64, 64), Vector2i((t - 1) * 64, k * 64))
			nodes["node_%s_%d" % [kinds[k], t]] = [(t - 1) * 64, k * 64, 64, 64]
	_save(atlas, "world/nodes.png")
	index["nodes"] = nodes


## Warstwy postaci (arkusze 128x128) w siatce 10 kolumn.
func _characters() -> void:
	var sheets := {}
	var hairs := [Color("4a2e1a"), Color("2a1c14"), Color("8a5a2a"), Color("c8a060"), Color("6a2a1a"), Color("1a1a1e"), Color("8a8a8a"), Color("5a3a1a")]
	for i in 8:
		sheets["body_%d" % i] = ArtCharacters.body({"tunic": ArtLib.OUTFITS[i], "hair": hairs[i]})
	sheets["body_skeleton"] = ArtCharacters.body({"bones": true})
	var npcs := {
		"npc_banker": {"tunic": Color("283a6a"), "pants": Color("1a1a2a"), "hair": Color("b0b0b0")},
		"npc_market": {"tunic": Color("3a7a3a"), "pants": Color("5a3a2a"), "hair": Color("8a4a1a")},
		"npc_trader": {"tunic": Color("8a6a3a"), "pants": Color("3a2a1a"), "hair": Color("2a1a10")},
		"npc_smith": {"tunic": Color("4a4a4a"), "pants": Color("2a2a2a"), "hair": Color("1a1a1a"), "bald": true},
		"npc_crafter": {"tunic": Color("9a2a3a"), "pants": Color("3a2a3a"), "hair": Color("d0a040")},
		"npc_refiner": {"tunic": Color("b0602a"), "pants": Color("3a2a1a"), "hair": Color("5a5a5a")},
		"npc_priest": {"tunic": Color("d8d0c0"), "pants": Color("8a7a50"), "hair": Color("e8d8a0")},
	}
	for n in npcs:
		sheets[n] = ArtCharacters.body(npcs[n])
	for type in ["plate", "leather", "cloth"]:
		for t in range(1, 5):
			sheets["%s_body_t%d" % [type, t]] = ArtCharacters.armor_body(type, t)
			sheets["%s_legs_t%d" % [type, t]] = ArtCharacters.armor_legs(type, t)
			sheets["%s_feet_t%d" % [type, t]] = ArtCharacters.armor_feet(type, t)
			sheets["%s_head_t%d" % [type, t]] = ArtCharacters.armor_head(type, t)
	for kind in ["sword", "axe", "mace", "bow"]:
		for t in range(1, 5):
			sheets["%s_t%d" % [kind, t]] = ArtCharacters.weapon(kind, t)
	for t in range(1, 5):
		sheets["shield_t%d" % t] = ArtCharacters.shield(t)
	sheets["sword_skeleton"] = ArtCharacters.weapon("sword", 0)

	var cols := 10
	var names := sheets.keys()
	var rows := int(ceil(names.size() / float(cols)))
	var atlas := Image.create(cols * 128, rows * 128, false, Image.FORMAT_RGBA8)
	var layers := {}
	for i in names.size():
		var x := (i % cols) * 128
		var y := (i / cols) * 128
		atlas.blit_rect(sheets[names[i]], Rect2i(0, 0, 128, 128), Vector2i(x, y))
		layers[names[i]] = [x, y]
	_save(atlas, "characters/layers.png")
	index["layers"] = layers

	# Zwierzęta: arkusze 128x64 (wiersz 0 = w prawo, wiersz 1 = w lewo).
	var beasts := {"rat": ArtCharacters.rat(), "boar": ArtCharacters.boar(), "wolf": ArtCharacters.wolf(false), "hound": ArtCharacters.wolf(true)}
	var batlas := Image.create(128, 64 * beasts.size(), false, Image.FORMAT_RGBA8)
	var bidx := {}
	var k := 0
	for b in beasts:
		batlas.blit_rect(beasts[b], Rect2i(0, 0, 128, 64), Vector2i(0, k * 64))
		bidx[b] = [0, k * 64]
		k += 1
	_save(batlas, "characters/beasts.png")
	index["beasts"] = bidx


func _items() -> void:
	var names: Array = ArtItems.ICONS
	var atlas := Image.create(5 * 32, names.size() * 32, false, Image.FORMAT_RGBA8)
	var items := {}
	for i in names.size():
		for t in 5:
			atlas.blit_rect(ArtItems.icon(names[i], t), Rect2i(0, 0, 32, 32), Vector2i(t * 32, i * 32))
			items["%s_%d" % [names[i], t]] = [t * 32, i * 32]
	_save(atlas, "items/items.png")
	index["items"] = items


func _ui() -> void:
	_save(_x2(ArtUI.panel()), "ui/panel.png")
	for s in ["normal", "hover", "pressed", "disabled"]:
		_save(_x2(ArtUI.button(s)), "ui/button_%s.png" % s)
	_save(_x2(ArtUI.slot()), "ui/slot.png")
	for b in ["hp", "mp", "exp", "bg"]:
		_save(_x2(ArtUI.bar(b)), "ui/bar_%s.png" % b)
	# Ikona aplikacji, ikona adaptacyjna Androida i ekran startowy.
	_save(_x2(ArtUI.logo(48, true), 4), "../icon.png")
	_save(_x2(ArtUI.logo(108, false), 4), "icon_foreground.png")
	_save(_x2(ArtUI.icon_background(108), 4), "icon_background.png")
	_save(_x2(ArtUI.logo(96, false), 4), "splash.png")
	_save(ArtUI.joystick_base(), "ui/joystick_base.png")
	_save(ArtUI.joystick_knob(), "ui/joystick_knob.png")
	for n in ["bag", "character", "specs", "people", "menu", "chat", "attack", "heal", "skull_white", "skull_red"]:
		_save(ArtUI.icon(n), "ui/icon_%s.png" % n)
	_save(ArtUI.soft_dot(16), "fx/soft_dot.png")
	_save(ArtUI.soft_dot(64), "fx/soft_light.png")
