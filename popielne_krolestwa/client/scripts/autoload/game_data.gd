extends Node
## Dane gry otrzymane od serwera przy logowaniu (definicje przedmiotów, czarów, mapa).
## Klient nie ma nic „na sztywno” – balans zmienia się tylko na serwerze.

var items: Dictionary = {}
var spells: Dictionary = {}
## id receptury -> receptura; stacja -> lista receptur
var recipes: Dictionary = {}
var recipes_by_station: Dictionary = {}
var station_names: Dictionary = {}
## Lista definicji specjalizacji [{id, name, group, description}]
var spec_defs: Array = []
var tier_spec_req: Array = []
var quality_names: Array = []
## Umiejętności broni: rodzaj broni -> [def slot 1, 2, 3]
var abilities: Dictionary = {}
## Strefy: wiersze znaków g/y/r
var zones: PackedStringArray = []

const ZONE_NAMES := {"g": "Strefa zielona", "y": "Strefa żółta", "r": "Strefa czerwona"}
const ZONE_HINTS := {"g": "bezpieczna – bez PvP", "y": "PvP – po śmierci tracisz część plecaka", "r": "PEŁNE PvP – full loot!"}
const ZONE_COLORS := {"g": Color(0.55, 0.95, 0.5), "y": Color(1.0, 0.85, 0.3), "r": Color(1.0, 0.35, 0.25)}
var my_id := 0
var my_name := ""
var map_w := 0
var map_h := 0
var map_rows: PackedStringArray = []

## Kafelki, po których można chodzić (musi zgadzać się z map.ts na serwerze).
const WALKABLE := ".,safx"
## Kafelki strefy ochronnej.
const PROTECTION := "fxDMKWP"

const SKILL_LABELS := {
	"sword": "Miecz",
	"axe": "Topór",
	"club": "Maczuga",
	"distance": "Dystans",
	"magic": "Magia",
	"shielding": "Tarcza",
	"fishing": "Wędkarstwo",
}

const SLOT_LABELS := {
	"head": "Głowa",
	"body": "Tułów",
	"legs": "Nogi",
	"feet": "Stopy",
	"weapon": "Broń",
	"shield": "Tarcza",
}


func load_welcome(msg: Dictionary) -> void:
	my_id = int(msg.id)
	my_name = str(msg.name)
	items.clear()
	for it in msg.items:
		items[it.id] = it
	spells.clear()
	for sp in msg.spells:
		spells[sp.id] = sp
	recipes.clear()
	recipes_by_station.clear()
	for r in msg.get("recipes", []):
		recipes[r.id] = r
		if not recipes_by_station.has(r.station):
			recipes_by_station[r.station] = []
		recipes_by_station[r.station].append(r)
	station_names = msg.get("stations", {})
	spec_defs = msg.get("specs", [])
	tier_spec_req = msg.get("tierSpecReq", [])
	quality_names = msg.get("qualities", [])
	abilities.clear()
	for a in msg.get("abilities", []):
		if not abilities.has(a.weapon):
			abilities[a.weapon] = [null, null, null]
		abilities[a.weapon][int(a.slot) - 1] = a
	zones = PackedStringArray(msg.get("zones", []))
	map_w = int(msg.map.w)
	map_h = int(msg.map.h)
	map_rows = PackedStringArray(msg.map.rows)


func tile_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= map_w or y >= map_h:
		return "#"
	return map_rows[y][x]


func is_walkable(x: int, y: int) -> bool:
	return WALKABLE.contains(tile_at(x, y))


## Strefa kafelka: "g", "y" albo "r".
func zone_at(x: int, y: int) -> String:
	if y < 0 or y >= zones.size() or x < 0 or x >= zones[y].length():
		return "r"
	return zones[y][x]


## Rodzaj broni z id przedmiotu ("sword_t2" -> "sword").
static func weapon_kind(item_id: String) -> String:
	var k := item_id.get_slice("_", 0)
	return k if k in ["sword", "axe", "mace", "bow"] else ""


func is_protection_zone(x: int, y: int) -> bool:
	return PROTECTION.contains(tile_at(x, y))


func item_def(id: String) -> Dictionary:
	return items.get(id, {"id": id, "name": id, "icon": "unknown"})


const QUALITY_MULT := [1.0, 1.0, 1.05, 1.1, 1.18, 1.3]
const QUALITY_COLORS := ["#ffffff", "#e0e0e0", "#8ad070", "#6aa0f0", "#c070f0", "#f0c040"]


func quality_name(q: int) -> String:
	return str(quality_names[q]) if q >= 0 and q < quality_names.size() else ""


func spec_name(id: String) -> String:
	for d in spec_defs:
		if d.id == id:
			return str(d.name)
	return id


## Nazwa przedmiotu z jakością (dla ekwipunku), np. "Miecz Nowicjusza (T1) – Doskonały".
func item_label(id: String, q: int = 1) -> String:
	var d := item_def(id)
	if q > 1:
		return "%s – %s" % [d.name, quality_name(q)]
	return str(d.name)


## Opis przedmiotu do okienka szczegółów.
func item_description(id: String, q: int = 1) -> String:
	var d := item_def(id)
	var m: float = QUALITY_MULT[clampi(q, 1, 5)]
	var lines: PackedStringArray = [item_label(id, q)]
	if d.has("minLevel") and int(d.minLevel) > 1:
		lines.append("Wymagany poziom: %d" % int(d.minLevel))
	if d.has("attack"):
		lines.append("Atak: %d" % roundi(float(d.attack) * m))
	if d.has("defense"):
		lines.append("Obrona: %d" % roundi(float(d.defense) * m))
	if d.has("armor") and int(d.armor) > 0:
		lines.append("Pancerz: %d" % roundi(float(d.armor) * m))
	if d.has("hpBonus"):
		lines.append("Zdrowie: +%d" % roundi(float(d.hpBonus) * m))
	if d.has("mpBonus"):
		lines.append("Mana: +%d" % roundi(float(d.mpBonus) * m))
	if d.has("range") and int(d.range) > 1:
		lines.append("Zasięg: %d%s" % [int(d.range), " (dwuręczna)" if d.get("twoHanded", false) else ""])
	if d.has("use"):
		if d.use.has("heal"):
			lines.append("Leczy: %d HP" % int(d.use.heal))
		if d.use.has("mana"):
			lines.append("Przywraca: %d many" % int(d.use.mana))
	lines.append("Waga: %.1f oz  •  wartość ~%d zł" % [float(d.weight), int(d.get("value", 0))])
	if d.has("description"):
		lines.append(str(d.description))
	return "\n".join(lines)
