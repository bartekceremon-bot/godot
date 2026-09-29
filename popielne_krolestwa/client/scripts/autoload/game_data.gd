extends Node
## Dane gry otrzymane od serwera przy logowaniu (definicje przedmiotów, czarów, mapa).
## Klient nie ma nic „na sztywno” – balans zmienia się tylko na serwerze.

var items: Dictionary = {}
var spells: Dictionary = {}
var my_id := 0
var my_name := ""
var map_w := 0
var map_h := 0
var map_rows: PackedStringArray = []

## Kafelki, po których można chodzić (musi zgadzać się z map.ts na serwerze).
const WALKABLE := ".,safx"
## Kafelki strefy ochronnej.
const PROTECTION := "fxD"

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
	map_w = int(msg.map.w)
	map_h = int(msg.map.h)
	map_rows = PackedStringArray(msg.map.rows)


func tile_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= map_w or y >= map_h:
		return "#"
	return map_rows[y][x]


func is_walkable(x: int, y: int) -> bool:
	return WALKABLE.contains(tile_at(x, y))


func is_protection_zone(x: int, y: int) -> bool:
	return PROTECTION.contains(tile_at(x, y))


func item_def(id: String) -> Dictionary:
	return items.get(id, {"id": id, "name": id, "icon": "unknown"})


## Opis przedmiotu do okienka szczegółów.
func item_description(id: String) -> String:
	var d := item_def(id)
	var lines: PackedStringArray = [str(d.name)]
	if d.has("tier"):
		lines.append("Tier T%d" % int(d.tier))
	if d.has("attack"):
		lines.append("Atak: %d" % int(d.attack))
	if d.has("defense"):
		lines.append("Obrona: %d" % int(d.defense))
	if d.has("armor"):
		lines.append("Pancerz: %d" % int(d.armor))
	if d.has("range") and int(d.range) > 1:
		lines.append("Zasięg: %d%s" % [int(d.range), " (dwuręczna)" if d.get("twoHanded", false) else ""])
	if d.has("use"):
		if d.use.has("heal"):
			lines.append("Leczy: %d HP" % int(d.use.heal))
		if d.use.has("mana"):
			lines.append("Przywraca: %d many" % int(d.use.mana))
	lines.append("Waga: %.1f oz" % float(d.weight))
	if d.has("description"):
		lines.append(str(d.description))
	return "\n".join(lines)
