extends Node
## Dostęp do grafik gry: atlasy PNG z res://assets/ (generowane przez tools/build_assets.sh,
## można je podmienić ręcznie narysowanymi) opisane w res://assets/atlas_index.json.

const TS := 32

## Kolory tierów (oznaczenia) i ramek jakości (1 zwykły … 5 arcydzieło).
const TIER_COLORS := [Color.WHITE, Color("8a8a8a"), Color("4f9a3e"), Color("3f6fc0"), Color("9848b8"),
	Color("c8a030"), Color("c05028"), Color("d8d8d8"), Color("202020")]
const QUALITY_COLORS := [Color.TRANSPARENT, Color(0, 0, 0, 0), Color("7ac060"), Color("5a90e0"), Color("b060e0"), Color("f0b030")]

## Ikony HUD dostępne jako pliki ui/icon_*.png.
const UI_ICONS := ["bag", "character", "specs", "people", "menu", "chat", "attack", "heal", "skull_white", "skull_red"]

var index: Dictionary = {}
var layers_tex: Texture2D
var beasts_tex: Texture2D
var nodes_tex: Texture2D
var items_tex: Texture2D
var objects_tex: Texture2D
var _cache: Dictionary = {}


func _ready() -> void:
	index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas_index.json"))
	layers_tex = load("res://assets/characters/layers.png")
	beasts_tex = load("res://assets/characters/beasts.png")
	nodes_tex = load("res://assets/world/nodes.png")
	items_tex = load("res://assets/items/items.png")
	objects_tex = load("res://assets/world/objects.png")


func tileset() -> TileSet:
	return load("res://assets/world/objects_tileset.tres")


## Współrzędne obiektu w atlasie TileSetu (kolumna, wiersz).
func object_coords(name: String) -> Vector2i:
	var o: Array = index.objects.get(name, [0, 2])
	return Vector2i(int(o[0]), int(o[1]))


## Region klatki warstwy postaci: dir 0=N 1=E 2=S 3=W, frame 0–3.
func layer_region(layer: String, dir: int, frame: int) -> Rect2:
	var p: Array = index.layers.get(layer, index.layers["body_0"])
	return Rect2(float(p[0]) + frame * TS, float(p[1]) + dir * TS, TS, TS)


func has_layer(layer: String) -> bool:
	return index.layers.has(layer)


func is_beast(look: String) -> bool:
	return index.beasts.has(look)


## Zwierzęta mają tylko widok z boku: facing_right wybiera wiersz.
func beast_region(look: String, facing_right: bool, frame: int) -> Rect2:
	var p: Array = index.beasts[look]
	return Rect2(float(p[0]) + frame * TS, float(p[1]) + (0 if facing_right else TS), TS, TS)


func node_region(look: String) -> Rect2:
	var p: Array = index.nodes.get(look, [0, 0, 64, 64])
	return Rect2(p[0], p[1], p[2], p[3])


## Ikona przedmiotu (32x32) dla nazwy ikony i tieru.
func item_icon(icon: String, tier: int = 0) -> Texture2D:
	var key := "%s_%d" % [icon, tier]
	if _cache.has(key):
		return _cache[key]
	var p: Array = index.items.get(key, index.items.get("%s_0" % icon, index.items["unknown_0"]))
	var at := AtlasTexture.new()
	at.atlas = items_tex
	at.region = Rect2(p[0], p[1], TS, TS)
	_cache[key] = at
	return at


## Ikona dla definicji przedmiotu z serwera (ikona + tier).
func item_icon_for(def: Dictionary) -> Texture2D:
	return item_icon(str(def.get("icon", "unknown")), int(def.get("tier", 0)))


## Ikona interfejsu: ikony HUD z ui/, w pozostałych przypadkach ikona przedmiotu.
func icon(name: String) -> Texture2D:
	var map := {"spell_heal": "heal"}
	var n: String = map.get(name, name)
	if n in UI_ICONS:
		return load("res://assets/ui/icon_%s.png" % n)
	return item_icon(name, 0)


## Tekstura obiektu z atlasu (np. pochodnia) jako AtlasTexture.
func object_texture(name: String) -> Texture2D:
	var key := "obj_" + name
	if _cache.has(key):
		return _cache[key]
	var o: Array = index.objects[name]
	var at := AtlasTexture.new()
	at.atlas = objects_tex
	at.region = Rect2(int(o[0]) * TS, int(o[1]) * TS, int(o[2]) * TS, int(o[3]) * TS)
	_cache[key] = at
	return at
