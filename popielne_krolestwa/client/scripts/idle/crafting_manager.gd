class_name CraftingManager
extends RefCounted
## Rzemiosło: receptury MMO (Rafineria – surowiec → materiał, Kuźnia i Pracownia – ekwipunek T1–T8)
## oraz alchemia idle (mikstury, tymczasowe wzmocnienia). Receptury odblokowują się z postępem.
## CRAFT → PRODUKT → ULEPSZENIE → WIĘKSZY DPS.

const STATIONS := {"refinery": "Rafineria", "forge": "Kuźnia", "workshop": "Pracownia", "alchemy": "Alchemia"}

var gm: IdleGame
var recipes: Array = []
var _by_id: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _known_unlocked := -1


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()
	for r in gm.db.recipes:
		var t := int(r.tier)
		var out := str(r.output)
		var kind := "refine" if str(r.station) == "refinery" else "gear"
		var inputs: Array = []
		for i in r.inputs:
			inputs.append([str(i.item), int(i.count)])
		_add({"id": str(r.id), "name": gm.db.item_name(out), "station": str(r.station), "output": out, "count": int(r.count),
			"inputs": inputs, "tier": t, "kind": kind, "unlock_stage": (t - 1) * gm.db.stages_per_region + 1})
	for r in gm.db.crafting_idle:
		var d: Dictionary = r.duplicate()
		d["station"] = "alchemy"
		d["kind"] = "boost" if r.has("boost") else "potion"
		d["tier"] = 0
		if not d.has("output"):
			d["output"] = ""
			d["count"] = 1
		_add(d)


func _add(r: Dictionary) -> void:
	recipes.append(r)
	_by_id[str(r.id)] = r


func recipe(id: String) -> Dictionary:
	return _by_id.get(id, {})


func unlocked(r: Dictionary) -> bool:
	return int(gm.s.max_stage) >= int(r.get("unlock_stage", 1))


func list_for(station: String) -> Array:
	return recipes.filter(func(r): return str(r.station) == station and unlocked(r))


## Po nowym maksymalnym etapie: komunikat o nowych recepturach.
func check_unlocks() -> void:
	var n := 0
	for r in recipes:
		if unlocked(r):
			n += 1
	if _known_unlocked >= 0 and n > _known_unlocked:
		gm.notify("Nowe receptury w rzemiośle: %d" % (n - _known_unlocked), Color(0.6, 0.9, 1.0))
	_known_unlocked = n


## Ile razy można wykonać recepturę z posiadanych składników.
func max_times(r: Dictionary) -> int:
	var m := 999999
	for inp in r.inputs:
		m = mini(m, gm.inventory.count(str(inp[0])) / maxi(1, int(inp[1])))
	return m


func craft(id: String, times := 1) -> Array:
	var r := recipe(id)
	if r.is_empty() or not unlocked(r):
		return []
	times = mini(times, max_times(r))
	if times <= 0:
		return []
	gm.inventory.remove_all(r.inputs, times)
	var got: Array = []
	match str(r.kind):
		"refine", "potion":
			gm.inventory.add(str(r.output), int(r.count) * times)
			got.append([str(r.output), int(r.count) * times, 0])
		"gear":
			for i in times:
				var it := gm.inventory.add_gear(str(r.output), roll_quality())
				if not it.is_empty():
					got.append([str(it.id), 1, int(it.q)])
		"boost":
			add_boost(str(r.boost), float(r.power), float(r.minutes) * 60.0 * times)
			got.append(["boost", times, 0])
	var s := gm.s
	s.craft_xp = float(s.craft_xp) + times * maxf(1.0, float(r.tier))
	var lvl := int(floor(sqrt(float(s.craft_xp) / 5.0))) + 1
	if lvl > int(s.craft_lvl):
		s.craft_lvl = lvl
		gm.notify("Poziom rzemiosła: %d – lepsza jakość wyrobów!" % lvl, Color(0.6, 0.9, 1.0))
	gm.quests.on_event("crafts", times)
	gm.audio.play("craft")
	if not got.is_empty():
		gm.loot_gained.emit(got)
	return got


## Jakość wyrobu – rośnie z poziomem rzemiosła.
func roll_quality() -> int:
	var lvl := int(gm.s.craft_lvl)
	var w := [0.0, 55.0, 28.0, 12.0, 4.0, 1.0]
	for i in range(2, 6):
		w[i] *= 1.0 + 0.06 * (lvl - 1) * (i - 1)
	var total := 0.0
	for i in range(1, 6):
		total += w[i]
	var r := _rng.randf() * total
	for i in range(1, 6):
		r -= w[i]
		if r <= 0.0:
			return i
	return 1


# --- Wzmocnienia (czas rzeczywisty) --------------------------------------------------

func add_boost(stat: String, power: float, seconds: float) -> void:
	var now := Time.get_unix_time_from_system()
	var b: Dictionary = gm.s.boosts.get(stat, {})
	var until := maxf(float(b.get("until", now)), now) + seconds
	gm.s.boosts[stat] = {"power": maxf(power, float(b.get("power", 0.0))), "until": until}
	gm.stats.mark_dirty()
	gm.changed.emit("boosts")


func active_boosts() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var out := {}
	var expired: Array = []
	for stat in gm.s.boosts:
		var b: Dictionary = gm.s.boosts[stat]
		if float(b.until) > now:
			out[stat] = float(b.power)
		else:
			expired.append(stat)
	for e in expired:
		gm.s.boosts.erase(e)
		gm.stats.mark_dirty()
	return out


func boost_left(stat: String) -> float:
	if not gm.s.boosts.has(stat):
		return 0.0
	return maxf(0.0, float(gm.s.boosts[stat].until) - Time.get_unix_time_from_system())
