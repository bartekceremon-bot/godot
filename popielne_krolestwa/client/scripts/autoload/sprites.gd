extends Node
## Grafiki interfejsu: ikony przedmiotów i HUD z res://assets/ (generowane przez tools/build_assets.sh,
## można je podmienić ręcznie narysowanymi), opisane w res://assets/atlas_index.json.

## Rozmiar komórki atlasu ikon (z atlas_index.json, domyślnie 32 – stary pixel art).
var TS := 32

## Kolory tierów (oznaczenia) i ramek jakości (1 zwykły … 5 arcydzieło).
const TIER_COLORS := [Color.WHITE, Color("8a8a8a"), Color("4f9a3e"), Color("3f6fc0"), Color("9848b8"),
	Color("c8a030"), Color("c05028"), Color("d8d8d8"), Color("202020")]
const QUALITY_COLORS := [Color.TRANSPARENT, Color(0, 0, 0, 0), Color("7ac060"), Color("5a90e0"), Color("b060e0"), Color("f0b030")]

## Ikony HUD dostępne jako pliki ui/icon_*.png.
const UI_ICONS := ["bag", "character", "specs", "people", "menu", "chat", "attack", "heal", "skull_white", "skull_red", "book",
	"spell_fire", "spell_meteor", "spell_ice", "spell_shield", "spell_lightning", "spell_storm", "spell_haste",
	"spell_death", "spell_curse", "spell_holy", "spell_purify"]

var index: Dictionary = {}
var items_tex: Texture2D
var _cache: Dictionary = {}


func _ready() -> void:
	index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas_index.json"))
	items_tex = load("res://assets/items/items.png")
	TS = int(index.get("tile", 32))


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
