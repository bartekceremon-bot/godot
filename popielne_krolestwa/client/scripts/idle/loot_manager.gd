class_name LootManager
extends RefCounted
## Łup: surowce regionu, łup potworów z bestiariusza MMO (mięso, kości, mikstury, surowce),
## ekwipunek o rzadkości Zwykły…Legendarny, skrzynie, żarokryształy i fragmenty wierzchowców.

const CHEST_NAMES := ["", "Zwykła skrzynia", "Niezwykła skrzynia", "Rzadka skrzynia", "Epicka skrzynia", "Legendarna skrzynia"]
## Wagi rzadkości (1..5) dla zwykłych wrogów, elit i bossów.
const RARITY_WEIGHTS := [[0, 62, 25, 9, 3.5, 0.5], [0, 30, 38, 20, 10, 2], [0, 10, 30, 32, 21, 7]]
## Bazy przedmiotów, które mogą wypaść (bez narzędzi – te są w skrzyniach i rzemiośle).
const GEAR_BASES := ["sword", "axe", "mace", "bow", "staff", "shield", "plate_head", "plate_body", "plate_legs", "plate_feet",
	"leather_head", "leather_body", "leather_legs", "leather_feet", "cloth_head", "cloth_body", "cloth_legs", "cloth_feet"]

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func roll_gems(kind: int) -> int:
	var c := gm.progression.circle(int(gm.s.stage))
	match kind:
		2:
			return _rng.randi_range(3, 6) + c * 2
		1:
			return _rng.randi_range(1, 2) + c
	return 1 if _rng.randf() < 0.006 * gm.stats.loot_mult else 0


func roll_rarity(kind: int) -> int:
	var w: Array = RARITY_WEIGHTS[clampi(kind, 0, 2)].duplicate()
	# Premia do łupu przesuwa szanse w stronę rzadszych przedmiotów.
	var lb := gm.stats.loot_mult - 1.0
	for i in range(2, 6):
		w[i] = float(w[i]) * (1.0 + lb * 1.5)
	var total := 0.0
	for i in range(1, 6):
		total += float(w[i])
	var r := _rng.randf() * total
	for i in range(1, 6):
		r -= float(w[i])
		if r <= 0.0:
			return i
	return 1


## Losowy przedmiot ekwipunku regionu (tier z etapu).
func random_gear(stage: int, rarity: int, bases: Array = GEAR_BASES) -> Dictionary:
	var t := gm.progression.loot_tier(stage)
	var base := str(bases[_rng.randi() % bases.size()])
	return gm.inventory.add_gear("%s_t%d" % [base, t], rarity, gm.progression.loot_bonus_level(stage))


## Surowiec regionu: rodzaje z listy regionu (80%) albo dowolny (20%).
func random_material(stage: int) -> String:
	var reg := gm.progression.region(stage)
	var kinds: Array = reg.materials
	var kind := str(kinds[_rng.randi() % kinds.size()]) if _rng.randf() < 0.8 else str(IdleDB.MATERIAL_KINDS[_rng.randi() % 5])
	var t := gm.progression.loot_tier(stage)
	# Czasem surowiec tieru niżej (przydatny do ulepszeń starszego ekwipunku).
	if t > 1 and _rng.randf() < 0.25:
		t -= 1
	return "%s_t%d" % [kind, t]


func material_amount(base: int) -> int:
	var m := gm.stats.material_mult
	var n := float(base) * m
	return int(n) + (1 if _rng.randf() < n - floor(n) else 0)


func on_kill(e: Dictionary) -> void:
	var stage := int(e.stage)
	var kind := int(e.kind)
	var got: Array = []
	var lm := gm.stats.loot_mult
	# Surowce: 35% szansy (elity i bossowie – zawsze, więcej).
	if kind > 0 or _rng.randf() < 0.35 * lm:
		var id := random_material(stage)
		var n := material_amount([1, 5, 12][kind] + _rng.randi_range(0, 1 + kind * 3))
		if n > 0:
			gm.inventory.add(id, n)
			got.append([id, n, 0])
	# Łup z bestiariusza MMO (bez złota i ekwipunku).
	var m := gm.db.monster(str(e.monster))
	for entry in m.get("loot", []):
		var item := str(entry.item)
		if item == "gold":
			continue
		var cat := str(gm.db.item(item).get("category", ""))
		var chance := float(entry.chance) * 0.5 * lm * (3.0 if kind > 0 else 1.0)
		if _rng.randf() >= chance:
			continue
		if cat == "mount":
			var fr := _rng.randi_range(1, 3)
			gm.inventory.add("frag_" + item, fr)
			got.append(["frag_" + item, fr, 4])
		elif cat in ["weapon", "armor", "shield", "tool"]:
			var it := random_gear(stage, roll_rarity(kind))
			if not it.is_empty():
				got.append([str(it.id), 1, int(it.q)])
		else:
			var n := _rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
			if cat == "resource":
				# Surowce z tabel MMO w tierze etapu.
				item = "%s_t%d" % [IdleDB.base_of(item), gm.progression.loot_tier(stage)]
				n = material_amount(n)
			if n > 0:
				gm.inventory.add(item, n)
				got.append([item, n, 0])
	# Ekwipunek: 1,5% (elita 25%).
	var gear_chance := float([0.015, 0.25, 0.0][kind]) * lm
	if _rng.randf() < gear_chance:
		var it := random_gear(stage, roll_rarity(kind))
		if not it.is_empty():
			got.append([str(it.id), 1, int(it.q)])
	# Skrzynie: elita 30%, boss – zawsze (rzadsza).
	if kind == 2 or (kind == 1 and _rng.randf() < 0.3):
		var r := roll_rarity(kind)
		gm.inventory.add("chest_%d" % r, 1)
		got.append(["chest_%d" % r, 1, r])
	# Boss świata z MMO: fragmenty jego wierzchowca (łoś – Król Szronu, wielbłąd – Czerw, drake – Żarogniew).
	if kind == 2:
		for md in gm.db.mounts:
			if str(md.get("boss", "")) == str(e.monster):
				var fr := _rng.randi_range(2, 4)
				gm.inventory.add("frag_" + str(md.id), fr)
				got.append(["frag_" + str(md.id), fr, 4])
	if not got.is_empty():
		gm.loot_gained.emit(got)


# --- Skrzynie ---------------------------------------------------------------------

func chest_name(r: int) -> String:
	return CHEST_NAMES[clampi(r, 1, 5)]


## Otwiera skrzynię: złoto, surowce, ekwipunek danej rzadkości, mikstury, żarokryształy, fragmenty.
func open_chest(r: int) -> Array:
	var id := "chest_%d" % r
	if not gm.inventory.remove(id, 1):
		return []
	var stage := int(gm.s.max_stage)
	var got: Array = []
	var gold := ProgressionManager.gold_for(stage) * 20.0 * r * gm.stats.gold_mult
	gm.add_gold(gold)
	got.append(["gold", gold, 0])
	for i in 1 + r / 2:
		var mid := random_material(stage)
		var n := material_amount(4 * r + _rng.randi_range(0, 4))
		gm.inventory.add(mid, n)
		got.append([mid, n, 0])
	var it := random_gear(stage, r)
	if not it.is_empty():
		got.append([str(it.id), 1, r])
	if r >= 2:
		var pot := "great_hp_potion" if stage >= 40 else "hp_potion"
		gm.inventory.add(pot, r)
		got.append([pot, r, 0])
	var gems := r * 2 + _rng.randi_range(0, r)
	gm.add_gems(gems)
	got.append(["gems", gems, 0])
	if r >= 4 or (r == 3 and _rng.randf() < 0.3):
		var md: Dictionary = gm.db.mounts[_rng.randi() % gm.db.mounts.size()]
		var fr := _rng.randi_range(1, r - 1)
		gm.inventory.add("frag_" + str(md.id), fr)
		got.append(["frag_" + str(md.id), fr, 4])
	if _rng.randf() < 0.15 * r:
		var tool := random_gear(stage, maxi(1, r - 1), ["woodaxe", "pickaxe", "sickle"])
		if not tool.is_empty():
			got.append([str(tool.id), 1, int(tool.q)])
	gm.audio.play("rare" if r >= 4 else "coin")
	gm.loot_gained.emit(got)
	return got
