extends SceneTree
## Buduje TileSet obiektów świata (res://assets/world/objects_tileset.tres) z atlasu
## objects.png i indeksu atlas_index.json. Uruchamiane po build_art.gd i imporcie PNG.
## Drzewa i obiekty wyższe niż kafelek mają przesunięty punkt zaczepienia (stoją na kafelku)
## i sortowanie Y – postać może schować się „za” drzewem lub murem.

func _init() -> void:
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas_index.json"))
	var tex: Texture2D = load("res://assets/world/objects.png")
	var sway := ShaderMaterial.new()
	sway.shader = load("res://shaders/tree_sway.gdshader")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(32, 32)
	ts.add_source(src, 0)
	for name in idx.objects:
		var o: Array = idx.objects[name]
		var at := Vector2i(int(o[0]), int(o[1]))
		var size := Vector2i(int(o[2]), int(o[3]))
		src.create_tile(at, size)
		var td := src.get_tile_data(at, 0)
		# Obraz stoi dolną krawędzią na dolnej krawędzi kafelka.
		td.texture_origin = Vector2i(0, (size.y * 32) / 2 - 16)
		# Sortowanie: obiekt z tego samego rzędu co postać rysowany jest za nią.
		td.y_sort_origin = -17
		if str(name).begins_with("tree"):
			td.material = sway
	var err := ResourceSaver.save(ts, "res://assets/world/objects_tileset.tres")
	print("TileSet zapisany: ", error_string(err))
	quit()
