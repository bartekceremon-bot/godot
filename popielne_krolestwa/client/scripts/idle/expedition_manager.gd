class_name ExpeditionManager
extends RefCounted
## Wyprawy: oddziały zwiadowców ruszają do odkrytej krainy na 15 min – 12 h (czas rzeczywisty,
## także gdy gra jest zamknięta) i wracają ze złotem, surowcami krainy, skrzyniami,
## żarokryształami i fragmentami wierzchowców. Sloty: 1 + etap 20 + etap 50 + 10. piętro Wieży.
## Stan: s.exped = {active: [{reg, dur, start, end}], done}.

const DURATIONS := [
	{"name": "Zwiad", "min": 15, "kills": 50, "mats": 4, "chest": [0.15, 1], "gems": 0, "frag": 0.0},
	{"name": "Patrol", "min": 60, "kills": 220, "mats": 14, "chest": [0.5, 2], "gems": 2, "frag": 0.05},
	{"name": "Wyprawa", "min": 240, "kills": 950, "mats": 50, "chest": [1.0, 3], "gems": 8, "frag": 0.25},
	{"name": "Wielka wyprawa", "min": 720, "kills": 3000, "mats": 140, "chest": [1.0, 4], "gems": 25, "frag": 0.6},
]
const MOUNT_FRAGS := ["frag_mount_horse", "frag_mount_elk", "frag_mount_camel", "frag_mount_warwolf", "frag_mount_drake"]

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("exped"):
		gm.s["exped"] = {"active": [], "done": 0}
	return gm.s.exped


static func now() -> float:
	return Time.get_unix_time_from_system()


func slots() -> int:
	var ms := int(gm.s.max_stage)
	return 1 + (1 if ms >= 20 else 0) + (1 if ms >= 50 else 0) + (1 if gm.tower.best() >= 10 else 0)


func active() -> Array:
	return _st().active


func regions_open() -> int:
	return mini(gm.db.regions.size(), gm.progression.region_index(int(gm.s.max_stage)) + 1)


## Etap, według którego liczone są nagrody z krainy (koniec krainy albo najdalszy etap).
func region_stage(reg: int) -> int:
	return mini(int(gm.s.max_stage), (reg + 1) * gm.db.stages_per_region)


func duration_sec(dur: int) -> float:
	var t: float = gm.talents.totals().get("exped", 0.0)
	return float(DURATIONS[dur].min) * 60.0 * (1.0 - minf(0.3, t / 2.0))


func start(reg: int, dur: int, t := -1.0) -> bool:
	if active().size() >= slots() or reg < 0 or reg >= regions_open():
		return false
	var at := now() if t < 0.0 else t
	active().append({"reg": reg, "dur": dur, "start": at, "end": at + duration_sec(dur)})
	gm.changed.emit("exped")
	return true


func time_left(i: int, t := -1.0) -> float:
	var at := now() if t < 0.0 else t
	return maxf(0.0, float(active()[i].end) - at)


func ready_count(t := -1.0) -> int:
	var n := 0
	for i in active().size():
		if time_left(i, t) <= 0.0:
			n += 1
	return n


## Koszt natychmiastowego powrotu: 1 żarokryształ za każde rozpoczęte 6 minut.
func rush_cost(i: int, t := -1.0) -> int:
	return int(ceil(time_left(i, t) / 360.0))


func rush(i: int) -> bool:
	if not gm.spend_gems(rush_cost(i)):
		return false
	active()[i].end = now() - 1.0
	gm.changed.emit("exped")
	return true


## Przewidywane nagrody (opis w panelu).
func preview(reg: int, dur: int) -> Dictionary:
	var d: Dictionary = DURATIONS[dur]
	var mult := 1.0 + float(gm.talents.totals().get("exped", 0.0))
	var stage := region_stage(reg)
	return {"gold": ProgressionManager.gold_for(stage) * float(d.kills) * mult * gm.stats.gold_mult,
		"mats": int(float(d.mats) * mult), "chest": d.chest, "gems": int(float(d.gems) * mult), "frag": float(d.frag)}


## Odbiera wyprawę i; zwraca łup [[id, ilość, rzadkość], ...].
func claim(i: int, t := -1.0) -> Array:
	if i < 0 or i >= active().size() or time_left(i, t) > 0.0:
		return []
	var e: Dictionary = active()[i]
	var reg := int(e.reg)
	var p := preview(reg, int(e.dur))
	var stage := region_stage(reg)
	var got: Array = []
	gm.add_gold(float(p.gold))
	got.append(["gold", float(p.gold), 0])
	var mats := {}
	for k in int(p.mats):
		var id := gm.loot.random_material(stage)
		mats[id] = int(mats.get(id, 0)) + 1
	for id in mats:
		gm.inventory.add(str(id), int(mats[id]))
		got.append([str(id), int(mats[id]), 0])
	if _rng.randf() < float(p.chest[0]):
		var r := int(p.chest[1])
		if _rng.randf() < 0.15 * (1.0 + float(gm.talents.totals().get("exped", 0.0))):
			r = mini(5, r + 1)
		gm.inventory.add("chest_%d" % r, 1)
		got.append(["chest_%d" % r, 1, r])
	if int(p.gems) > 0:
		gm.add_gems(int(p.gems))
		got.append(["gems", int(p.gems), 0])
	if _rng.randf() < float(p.frag):
		var f: String = MOUNT_FRAGS[_rng.randi() % MOUNT_FRAGS.size()]
		var n := _rng.randi_range(1, 2 + int(e.dur))
		gm.inventory.add(f, n)
		got.append([f, n, 4])
	active().remove_at(i)
	_st().done = int(_st().done) + 1
	gm.quests.on_event("expeditions", 1)
	gm.changed.emit("exped")
	return got
