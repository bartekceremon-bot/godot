class_name EquipmentManager
extends RefCounted
## Ekwipunek MMO (miecze, topory, buławy, łuki, kostury, tarcze, pancerze płytowe/skórzane/
## materiałowe, narzędzia) jako źródło premii clickera. Siła przedmiotu R zależy od tieru,
## rzadkości (jakość 1–5) i poziomu ulepszenia; każda rodzina daje inne, czytelne premie.

## Siła bazowa tieru (T1–T8).
const TIER_R := [0.0, 1.0, 1.5, 2.2, 3.1, 4.3, 5.8, 7.6, 9.8]
## Wzrost siły na poziom ulepszenia.
const UPGRADE_GROWTH := 1.08
## Premie rodzin na 1 punkt siły. click – płaskie obrażenia kliknięcia × R².
const FAMILY := {
	"sword": {"dmg": 0.08, "crit": 0.01, "click": 4.0},
	"axe": {"dmg": 0.09, "critdmg": 0.2, "click": 5.0},
	"mace": {"dmg": 0.07, "merc": 0.08, "click": 4.0},
	"bow": {"dmg": 0.07, "speed": 0.03, "click": 3.0},
	"staff": {"dmg": 0.05, "spell": 0.12, "mp": 20.0, "click": 2.0},
	"shield": {"hp": 100.0, "def": 0.02, "merc": 0.03},
	"plate": {"hp": 80.0, "def": 0.015},
	"leather": {"hp": 50.0, "gold": 0.04, "def": 0.008},
	"cloth": {"mp": 15.0, "xp": 0.04, "spell": 0.03},
}
const SLOT_WEIGHT := {"head": 1.0, "body": 1.5, "legs": 1.2, "feet": 0.8, "weapon": 1.0, "shield": 1.0}
const STAT_NAMES := {"dmg": "obrażeń", "crit": "szansy krytyka", "critdmg": "obrażeń krytycznych", "merc": "DPS najemników",
	"speed": "szybkości ataku", "spell": "siły czarów", "mp": "many", "hp": "zdrowia", "def": "obrony", "gold": "złota",
	"xp": "doświadczenia", "click": "obrażeń kliknięcia", "materials": "surowców"}
## Surowce do ulepszeń (główny, dodatkowy) – „20 rudy, 10 drewna”.
const UPGRADE_MATS := {
	"sword": ["ore", "hide"], "axe": ["ore", "wood"], "mace": ["ore", "stone"], "bow": ["wood", "fiber"], "staff": ["wood", "fiber"],
	"shield": ["wood", "ore"], "plate": ["ore", "stone"], "leather": ["hide", "fiber"], "cloth": ["fiber", "hide"],
	"woodaxe": ["wood", "ore"], "pickaxe": ["ore", "stone"], "sickle": ["fiber", "ore"],
}
## Narzędzia zbierackie: premia do zdobywanych surowców (+10% na tier najlepszego narzędzia).
const TOOLS := {"woodaxe": ["wood"], "pickaxe": ["ore", "stone"], "sickle": ["fiber"]}

var gm: IdleGame
var _totals: Dictionary = {}
var _totals_dirty := true


func _init(g: IdleGame) -> void:
	gm = g
	gm.changed.connect(func(w):
		if w == "gear" or w == "all":
			_totals_dirty = true
			gm.stats.mark_dirty())


func give_starter_gear() -> void:
	var it := gm.inventory.add_gear("sword_t1", 1)
	equip(int(it.uid))
	var sh := gm.inventory.add_gear("leather_body_t1", 1)
	equip(int(sh.uid))


static func family(id: String) -> String:
	var base := IdleDB.base_of(id)
	if base.begins_with("plate_"):
		return "plate"
	if base.begins_with("leather_"):
		return "leather"
	if base.begins_with("cloth_"):
		return "cloth"
	return base


func slot_of(id: String) -> String:
	return str(gm.db.item(id).get("slot", ""))


func is_tool(id: String) -> bool:
	return TOOLS.has(IdleDB.base_of(id))


func power(it: Dictionary) -> float:
	var t := clampi(IdleDB.tier_of(str(it.id)), 1, 8)
	var slot := slot_of(str(it.id))
	return TIER_R[t] * IdleDB.QUALITY_MULT[clampi(int(it.q), 1, 5)] * pow(UPGRADE_GROWTH, int(it.lvl)) * float(SLOT_WEIGHT.get(slot, 1.0))


## Premie jednego przedmiotu: {stat: wartość}.
func item_stats(it: Dictionary) -> Dictionary:
	var id := str(it.id)
	var out := {}
	var r := power(it)
	if is_tool(id):
		out["materials"] = 0.1 * IdleDB.tier_of(id) * (1.0 + 0.05 * int(it.lvl))
		return out
	var fam: Dictionary = FAMILY.get(family(id), {})
	for k in fam:
		if k == "click":
			out[k] = float(fam[k]) * r * r
		else:
			out[k] = float(fam[k]) * r
	if out.has("crit"):
		out["crit"] = minf(0.2, out["crit"])
	return out


## Suma premii założonego ekwipunku i najlepszych narzędzi.
func totals() -> Dictionary:
	if not _totals_dirty:
		return _totals
	_totals_dirty = false
	var t := {}
	for slot in gm.s.equip:
		var it := gm.inventory.gear_by_uid(int(gm.s.equip[slot]))
		if it.is_empty():
			continue
		var st := item_stats(it)
		for k in st:
			t[k] = float(t.get(k, 0.0)) + float(st[k])
	var best_tools := {}
	for it in gm.s.gear:
		var base := IdleDB.base_of(str(it.id))
		if TOOLS.has(base):
			var v: float = item_stats(it).materials
			best_tools[base] = maxf(float(best_tools.get(base, 0.0)), v)
	var mat := 0.0
	for b in best_tools:
		mat += float(best_tools[b]) / 3.0
	if mat > 0.0:
		t["materials"] = mat
	t["crit"] = minf(0.5, float(t.get("crit", 0.0)))
	_totals = t
	return t


## Czytelny opis premii: ["+125 obrażeń kliknięcia", "+8% szansy krytyka"].
func describe(it: Dictionary) -> Array:
	var out: Array = []
	var st := item_stats(it)
	for k in ["click", "dmg", "crit", "critdmg", "merc", "speed", "spell", "hp", "def", "mp", "gold", "xp", "materials"]:
		if not st.has(k):
			continue
		var v := float(st[k])
		if k in ["click", "hp", "mp"]:
			out.append("+%s %s" % [IdleDB.fmt(v), STAT_NAMES[k]])
		else:
			out.append("+%s%% %s" % [_pct(v), STAT_NAMES[k]])
	return out


static func _pct(v: float) -> String:
	var p := v * 100.0
	return ("%.1f" % p) if p < 10.0 else IdleDB.fmt(roundf(p))


func gear_name(it: Dictionary) -> String:
	var name := gm.db.item_name(str(it.id))
	if int(it.lvl) > 0:
		name += " +%d" % int(it.lvl)
	return name


## Porównanie „siły” przedmiotów (sortowanie, podpowiedź „lepszy”).
func score(it: Dictionary) -> float:
	var st := item_stats(it)
	var sc := 0.0
	for k in st:
		sc += float(st[k]) * (0.02 if k in ["hp", "mp"] else (0.0005 if k == "click" else 1.0))
	return sc


func equipped(slot: String) -> Dictionary:
	if not gm.s.equip.has(slot):
		return {}
	return gm.inventory.gear_by_uid(int(gm.s.equip[slot]))


func is_equipped(uid: int) -> bool:
	for slot in gm.s.equip:
		if int(gm.s.equip[slot]) == uid:
			return true
	return false


func equip(uid: int) -> void:
	var it := gm.inventory.gear_by_uid(uid)
	if it.is_empty():
		return
	var slot := slot_of(str(it.id))
	if slot == "":
		return
	gm.s.equip[slot] = uid
	# Broń dwuręczna (łuk, kostur) zdejmuje tarczę.
	if slot == "weapon" and bool(gm.db.item(str(it.id)).get("twoHanded", false)):
		gm.s.equip.erase("shield")
	if slot == "shield":
		var w := equipped("weapon")
		if not w.is_empty() and bool(gm.db.item(str(w.id)).get("twoHanded", false)):
			gm.s.equip.erase("weapon")
	gm.changed.emit("gear")


func unequip(slot: String) -> void:
	gm.s.equip.erase(slot)
	gm.changed.emit("gear")


## Identyfikatory założonych przedmiotów w kolejności slotów modelu 3D (głowa, tułów, nogi, stopy, broń, tarcza).
func model_equipment() -> Array:
	var out: Array = []
	for slot in IdleDB.SLOTS:
		var it := equipped(slot)
		out.append("" if it.is_empty() else str(it.id))
	return out


# --- Ulepszanie ------------------------------------------------------------------

## Koszt ulepszenia: złoto + surowce rodziny (tieru przedmiotu), rosnące wykładniczo.
func upgrade_cost(it: Dictionary) -> Dictionary:
	var id := str(it.id)
	var t := clampi(IdleDB.tier_of(id), 1, 8)
	var lvl := int(it.lvl)
	var fam := family(id)
	var mats: Array = UPGRADE_MATS.get(IdleDB.base_of(id), UPGRADE_MATS.get(fam, ["ore", "wood"]))
	var gold := ProgressionManager.gold_for(gm.progression.tier_stage(t)) * 6.0 * pow(1.45, lvl) * float(IdleDB.QUALITY_MULT[int(it.q)])
	var main := int(ceil(4.0 * pow(1.3, lvl)))
	var extra := int(ceil(2.0 * pow(1.3, lvl)))
	return {"gold": ceilf(gold), "mats": [["%s_t%d" % [mats[0], t], main], ["%s_t%d" % [mats[1], t], extra]]}


func can_upgrade(it: Dictionary) -> bool:
	var c := upgrade_cost(it)
	return float(gm.s.gold) >= float(c.gold) and gm.inventory.has_all(c.mats)


func upgrade(uid: int) -> bool:
	var it := gm.inventory.gear_by_uid(uid)
	if it.is_empty() or not can_upgrade(it):
		return false
	var c := upgrade_cost(it)
	gm.spend_gold(float(c.gold))
	gm.inventory.remove_all(c.mats)
	it.lvl = int(it.lvl) + 1
	gm.quests.on_event("upgrades", 1)
	gm.quests.on_event("upgrade_level", int(it.lvl))
	gm.audio.play("craft")
	gm.changed.emit("gear")
	return true


## Najlepszy przedmiot plecaka dla slotu (auto-zakładanie).
func best_for(slot: String) -> Dictionary:
	var best: Dictionary = {}
	for it in gm.s.gear:
		if slot_of(str(it.id)) == slot and (best.is_empty() or score(it) > score(best)):
			best = it
	return best


func equip_best() -> void:
	for slot in IdleDB.SLOTS:
		var b := best_for(slot)
		var cur := equipped(slot)
		if b.is_empty() or (not cur.is_empty() and score(b) <= score(cur)):
			continue
		if slot == "shield":
			# Tarcza nie zdejmuje lepszej broni dwuręcznej.
			var w := equipped("weapon")
			if not w.is_empty() and bool(gm.db.item(str(w.id)).get("twoHanded", false)):
				continue
		equip(int(b.uid))
