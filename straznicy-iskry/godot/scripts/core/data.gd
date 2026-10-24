extends Node
## Wczytuje treści gry z plików JSON w res://data/.
## Logika gry nie zawiera tekstów misji ani dialogów — wszystko jest tutaj.

var classes: Dictionary = {}
var missions: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var dialogs: Dictionary = {}
var blik: Dictionary = {}
var story: Dictionary = {}
var areas: Dictionary = {}
var class_order: Array = []
var mission_order: Array = []
var load_errors: Array = []


func _ready() -> void:
	var c: Dictionary = _load("res://data/classes.json")
	class_order = c.get("order", [])
	classes = c.get("classes", {})
	var m: Dictionary = _load("res://data/missions.json")
	for entry in m.get("missions", []):
		missions[entry["id"]] = entry
		mission_order.append(entry["id"])
	items = _load("res://data/items.json").get("items", {})
	enemies = _load("res://data/enemies.json").get("enemies", {})
	var d: Dictionary = _load("res://data/dialogs.json")
	dialogs = d.get("dialogs", {})
	blik = d.get("blik", {})
	story = _load("res://data/story.json")
	for area_id in story.get("area_order", []):
		areas[area_id] = _load("res://data/areas/%s.json" % area_id)
	if not load_errors.is_empty():
		push_error("Błędy danych: %s" % [load_errors])


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("Brak pliku: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("Niepoprawny JSON: " + path)
		return {}
	return parsed


func get_class_def(id: String) -> Dictionary:
	return classes.get(id, classes.get(class_order[0], {}) if not class_order.is_empty() else {})


func get_mission(id: String) -> Dictionary:
	return missions.get(id, {})


func get_area(id: String) -> Dictionary:
	return areas.get(id, {})


func get_item(id: String) -> Dictionary:
	return items.get(id, {"name": id, "desc": ""})


func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func missions_in_area(area_id: String) -> Array:
	var out: Array = []
	for id in mission_order:
		if missions[id].get("area", "") == area_id:
			out.append(id)
	return out


func area_name(id: String) -> String:
	return get_area(id).get("name", id)


static func col(v: Variant, fallback := Color.WHITE) -> Color:
	if typeof(v) == TYPE_STRING:
		return Color.from_string(v, fallback)
	return fallback
