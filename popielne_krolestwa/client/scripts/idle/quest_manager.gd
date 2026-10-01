class_name QuestManager
extends RefCounted
## Zadania:
##  - Kronika – 22 zadania MMO (mistrzowie gildii, rzemieślnicy, kapłani trzech miast) przerobione na
##    cele clickera: zabij potwory, zbierz surowce, dotrzyj do regionu. Aktywują się same (do 3 naraz),
##    gdy region z celem jest odblokowany i poprzednie zadanie łańcucha ukończone.
##  - Zlecenia – 3 krótkie, odnawiane cele (data/idle/tasks.json).

const MAX_ACTIVE := 3
const MAX_TASKS := 3
## Cele „odwiedź” z MMO -> region idle.
const VISIT_REGION := {"city:szronogrod": 5, "fire_temple": 7, "obelisk:0": 6}

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _q() -> Dictionary:
	return gm.s.quests


func def(id: String) -> Dictionary:
	for q in gm.db.quests:
		if str(q.id) == id:
			return q
	return {}


## Region, w którym cel zadania jest osiągalny.
func region_of(q: Dictionary) -> int:
	var best := 0
	for g in q.goals:
		var r := 0
		match str(g.kind):
			"kill":
				r = _monster_region(str(g.monster))
			"gather":
				r = clampi(IdleDB.tier_of(str(g.item)) - 1, 0, 7)
			"visit":
				r = int(VISIT_REGION.get(str(g.place), 7))
		best = maxi(best, r)
	return best


func _monster_region(mid: String) -> int:
	for i in gm.db.regions.size():
		var reg: Dictionary = gm.db.regions[i]
		if reg.monsters.has(mid) or str(reg.elite.monster) == mid or str(reg.boss.monster) == mid:
			return i
	return 7


func need(g: Dictionary) -> int:
	return 1 if str(g.kind) == "visit" else int(g.count)


func progress(id: String) -> Array:
	var q := def(id)
	var prog: Array = _q().active.get(id, [])
	var out: Array = []
	for i in q.goals.size():
		var g: Dictionary = q.goals[i]
		var v := int(prog[i]) if i < prog.size() else 0
		if str(g.kind) == "visit" and gm.progression.max_region_index() >= int(VISIT_REGION.get(str(g.place), 7)):
			v = 1
		out.append(mini(v, need(g)))
	return out


func is_ready(id: String) -> bool:
	var q := def(id)
	var p := progress(id)
	for i in q.goals.size():
		if int(p[i]) < need(q.goals[i]):
			return false
	return true


## Aktywacja kolejnych zadań Kroniki i uzupełnienie zleceń.
func refresh() -> void:
	var qs := _q()
	var maxr := gm.progression.max_region_index()
	for q in gm.db.quests:
		if qs.active.size() >= MAX_ACTIVE:
			break
		var id := str(q.id)
		if qs.active.has(id) or (qs.done.has(id) and not bool(q.get("repeatable", false))):
			continue
		if q.get("after") != null and not qs.done.has(str(q.after)):
			continue
		if region_of(q) > maxr:
			continue
		qs.active[id] = []
		for g in q.goals:
			qs.active[id].append(0)
	while qs.tasks.size() < MAX_TASKS:
		qs.tasks.append(_new_task())
	gm.changed.emit("quests")


func _new_task() -> Dictionary:
	var used: Array = _q().tasks.map(func(t): return str(t.type))
	var defs: Array = gm.db.tasks.filter(func(t): return _task_allowed(str(t.type)) and not used.has(str(t.type)))
	var t: Dictionary = defs[_rng.randi() % defs.size()]
	var n := int(_q().tasks_done)
	var scale := 1.0 + n * 0.08
	var need_v := float(t.need) * scale
	if str(t.type) == "gold":
		need_v = ProgressionManager.gold_for(int(gm.s.max_stage)) * 60.0 * scale
	var val := IdleDB.fmt(need_v) if str(t.type) == "gold" else str(int(ceil(need_v)))
	var text := str(t.text).replace("%d", val).replace("%s", val)
	return {"type": str(t.type), "text": text, "need": ceilf(need_v), "prog": 0.0, "reward": float(t.reward)}


func _task_allowed(type: String) -> bool:
	var s := gm.s
	match type:
		"spells":
			return gm.spells.known().size() > 1
		"upgrades", "crafts":
			return int(s.max_stage) >= 4
		"bosses":
			return int(s.max_stage) >= 4
	return true


# --- Zdarzenia -------------------------------------------------------------------

func on_kill(monster_id: String) -> void:
	var qs := _q()
	var changed := false
	for id in qs.active:
		var q := def(str(id))
		for i in q.goals.size():
			var g: Dictionary = q.goals[i]
			if str(g.kind) == "kill" and str(g.monster) == monster_id and int(qs.active[id][i]) < int(g.count):
				qs.active[id][i] = int(qs.active[id][i]) + 1
				changed = true
				if int(qs.active[id][i]) == int(g.count):
					gm.notify("„%s”: %s – wykonane!" % [q.name, g.label], Color(0.6, 1.0, 0.6))
	if changed:
		gm.changed.emit("quests")


func on_gather(item_id: String, n: int) -> void:
	var qs := _q()
	for id in qs.active:
		var q := def(str(id))
		for i in q.goals.size():
			var g: Dictionary = q.goals[i]
			if str(g.kind) == "gather" and str(g.item) == item_id:
				qs.active[id][i] = mini(int(g.count), int(qs.active[id][i]) + n)
				gm.changed.emit("quests")


## Postęp zleceń: kills, taps, gold, spells, upgrades, crafts, materials, bosses, crits, mercs.
func on_event(type: String, amount: float) -> void:
	gm.path.on_event(type, amount)
	gm.weekly.on_event(type, amount)
	var qs := _q()
	if qs.is_empty():
		return
	var changed := false
	for t in qs.tasks:
		if str(t.type) == type and float(t.prog) < float(t.need):
			t.prog = minf(float(t.need), float(t.prog) + amount)
			changed = true
	if changed:
		gm.changed.emit("quests")


# --- Nagrody ---------------------------------------------------------------------

func quest_reward(id: String) -> Dictionary:
	var q := def(id)
	var stage := int(gm.s.max_stage)
	var size := 1.0 + float(q.minLevel) / 10.0
	var r := {"gold": ProgressionManager.gold_for(stage) * 25.0 * size, "xp": ProgressionManager.xp_next(int(gm.s.level)) * 0.35,
		"gems": 3 + region_of(q) * 2, "items": [], "chest": 0}
	for it in q.reward.get("items", []):
		r.items.append([str(it[0]), int(it[1])])
	for g in q.goals:
		if str(g.kind) == "kill" and gm.db.monster(str(g.monster)).get("boss", false):
			r.chest = 5
	if r.chest == 0 and q.get("after") != null:
		r.chest = 2 + mini(2, region_of(q) / 3)
	return r


func claim(id: String) -> bool:
	var qs := _q()
	if not qs.active.has(id) or not is_ready(id):
		return false
	var q := def(id)
	var r := quest_reward(id)
	qs.active.erase(id)
	if not qs.done.has(id):
		qs.done.append(id)
	_give(r)
	gm.notify("Zadanie ukończone: „%s”" % q.name, Color(1.0, 0.85, 0.4))
	refresh()
	return true


func task_reward(t: Dictionary) -> Dictionary:
	var stage := int(gm.s.max_stage)
	return {"gold": ProgressionManager.gold_for(stage) * 25.0 * float(t.reward), "xp": ProgressionManager.xp_next(int(gm.s.level)) * 0.1 * float(t.reward),
		"gems": 1 + int(float(t.reward) * 2.0), "items": [], "chest": 2 if float(t.reward) >= 1.5 else (1 if _rng.randf() < 0.3 else 0)}


func claim_task(index: int) -> bool:
	var qs := _q()
	if index < 0 or index >= qs.tasks.size():
		return false
	var t: Dictionary = qs.tasks[index]
	if float(t.prog) < float(t.need):
		return false
	_give(task_reward(t))
	qs.tasks_done = int(qs.tasks_done) + 1
	gm.season.add_xp(15)
	qs.tasks[index] = _new_task()
	gm.notify("Zlecenie wykonane!", Color(1.0, 0.85, 0.4))
	gm.changed.emit("quests")
	return true


func _give(r: Dictionary) -> void:
	gm.add_gold(float(r.gold) * gm.stats.gold_mult)
	gm.progression.add_xp(float(r.xp))
	gm.add_gems(int(r.gems))
	var got: Array = [["gold", float(r.gold) * gm.stats.gold_mult, 0], ["gems", int(r.gems), 0]]
	for it in r.items:
		gm.inventory.add(str(it[0]), int(it[1]))
		got.append([str(it[0]), int(it[1]), 0])
	if int(r.chest) > 0:
		gm.inventory.add("chest_%d" % int(r.chest), 1)
		got.append(["chest_%d" % int(r.chest), 1, int(r.chest)])
	gm.audio.play("levelup")
	gm.loot_gained.emit(got)


## Krótkie cele do HUD: [{text, prog, need, ready, kind ("quest"/"task"), id}] – gotowe najpierw.
func hud_goals(limit := 2) -> Array:
	var out: Array = []
	var qs := _q()
	for id in qs.active:
		var q := def(str(id))
		var p := progress(str(id))
		var done := 0
		var total := 0
		for i in q.goals.size():
			done += int(p[i])
			total += need(q.goals[i])
		var label := str(q.goals[0].label) if q.goals.size() == 1 else str(q.name)
		out.append({"text": label, "prog": float(done), "need": float(total), "ready": is_ready(str(id)), "kind": "quest", "id": str(id)})
	for i in qs.tasks.size():
		var t: Dictionary = qs.tasks[i]
		out.append({"text": str(t.text), "prog": float(t.prog), "need": float(t.need), "ready": float(t.prog) >= float(t.need), "kind": "task", "id": str(i)})
	out.sort_custom(func(a, b):
		if a.ready != b.ready:
			return a.ready
		return a.prog / maxf(1.0, a.need) > b.prog / maxf(1.0, b.need))
	return out.slice(0, limit)


func ready_count() -> int:
	var n := 0
	for g in hud_goals(99):
		if g.ready:
			n += 1
	return n
