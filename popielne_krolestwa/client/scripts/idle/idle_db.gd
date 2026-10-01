class_name IdleDB
extends RefCounted
## Dane gry idle: content MMO (data/content/*.json – eksport z serwera, tools/export_idle_data.js)
## i projekt clickera (data/idle/*.json – regiony, najemnicy, czary, wierzchowce, prestiż, receptury, zlecenia).
## Nic nie jest wpisane „na sztywno” w kodzie – balans zmienia się w plikach JSON.

const SLOTS := ["head", "body", "legs", "feet", "weapon", "shield"]
const SLOT_NAMES := {"head": "Głowa", "body": "Tułów", "legs": "Nogi", "feet": "Stopy", "weapon": "Broń", "shield": "Tarcza"}
## Rzadkość = jakość przedmiotu z MMO (1 Zwykły … 5 Arcydzieło).
const RARITY_NAMES := ["", "Zwykły", "Niezwykły", "Rzadki", "Epicki", "Legendarny"]
const RARITY_COLORS := [Color.WHITE, Color(0.85, 0.85, 0.82), Color(0.45, 0.85, 0.4), Color(0.4, 0.62, 1.0), Color(0.75, 0.42, 1.0), Color(1.0, 0.7, 0.2)]
const QUALITY_MULT := [1.0, 1.0, 1.3, 1.7, 2.3, 3.2]
const MATERIAL_KINDS := ["wood", "stone", "ore", "fiber", "hide"]
const REFINED := {"wood": "planks", "stone": "blocks", "ore": "bars", "fiber": "cloth", "hide": "leather"}

var items: Dictionary = {}
var monsters: Dictionary = {}
var spells: Dictionary = {}
var spell_order: Array = []
var school_names: Dictionary = {}
var undead: Array = []
var recipes: Array = []
var station_names: Dictionary = {}
var quests: Array = []
var npcs: Array = []
var cities: Dictionary = {}

var regions: Array = []
var stages_per_region := 10
var kills_per_stage := 10
var boss_time := 30.0
var mercs: Array = []
var merc_growth := 1.07
var merc_milestones: Array = []
var spells_idle: Dictionary = {}
var mounts: Array = []
var prestige: Dictionary = {}
var crafting_idle: Array = []
var tasks: Array = []
var story: Dictionary = {}
var store: Dictionary = {}


func load_all() -> void:
	for it in _json("content/items.json"):
		items[str(it.id)] = it
	for m in _json("content/monsters.json"):
		monsters[str(m.id)] = m
	var sp: Dictionary = _json("content/spells.json")
	school_names = sp.schools
	undead = sp.undead
	for s in sp.list:
		spells[str(s.id)] = s
		spell_order.append(str(s.id))
	var rc: Dictionary = _json("content/recipes.json")
	station_names = rc.stations
	recipes = rc.list
	quests = _json("content/quests.json")
	npcs = _json("content/npcs.json")
	for c in _json("content/cities.json"):
		cities[str(c.id)] = c

	var rg: Dictionary = _json("idle/regions.json")
	regions = rg.list
	stages_per_region = int(rg.stages_per_region)
	kills_per_stage = int(rg.kills_per_stage)
	boss_time = float(rg.boss_time)
	var mc: Dictionary = _json("idle/mercenaries.json")
	mercs = mc.list
	merc_growth = float(mc.cost_growth)
	merc_milestones = mc.milestones
	spells_idle = _json("idle/spells_idle.json").list
	mounts = _json("idle/mounts.json").list
	prestige = _json("idle/prestige.json")
	crafting_idle = _json("idle/crafting_idle.json").list
	tasks = _json("idle/tasks.json").list
	story = _json("idle/story.json")
	store = _json("idle/store.json")


func _json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string("res://data/" + path)
	var v = JSON.parse_string(text)
	if v == null:
		push_error("IdleDB: nie można wczytać %s" % path)
	return v


func item(id: String) -> Dictionary:
	return items.get(id, {"id": id, "name": id, "icon": "unknown", "category": "misc", "value": 1})


func item_name(id: String) -> String:
	return str(item(id).get("name", id))


func monster(id: String) -> Dictionary:
	return monsters.get(id, monsters.get("rat", {}))


## Rodzina przedmiotu ekwipunku z identyfikatora („plate_body_t3” -> „plate_body”).
static func base_of(id: String) -> String:
	var i := id.rfind("_t")
	return id.substr(0, i) if i > 0 else id


static func tier_of(id: String) -> int:
	var i := id.rfind("_t")
	return int(id.substr(i + 2)) if i > 0 else 0


func mount_def(id: String) -> Dictionary:
	for m in mounts:
		if str(m.id) == id:
			return m
	return {}


func merc_def(id: String) -> Dictionary:
	for m in mercs:
		if str(m.id) == id:
			return m
	return {}


## Sformatowana liczba: 12 345 -> 12,3K; do 1e33, potem notacja wykładnicza.
static func fmt(n: float) -> String:
	if is_nan(n) or is_inf(n):
		return "∞"
	var neg := n < 0.0
	n = absf(n)
	var out := ""
	if n < 1000.0:
		out = str(int(floor(n))) if n >= 10.0 or is_equal_approx(n, floor(n)) else ("%.1f" % n)
	else:
		var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
		var e := int(floor(log(n) / log(1000.0)))
		if e > suffixes.size():
			out = "%.2fe%d" % [n / pow(10.0, floor(log(n) / log(10.0))), int(floor(log(n) / log(10.0)))]
		else:
			var v := n / pow(1000.0, e)
			out = ("%.2f" % v if v < 10.0 else ("%.1f" % v if v < 100.0 else "%d" % int(v))) + suffixes[e - 1]
	return ("-" if neg else "") + out


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%d min %02d s" % [s / 60, s % 60]
	return "%d s" % s
