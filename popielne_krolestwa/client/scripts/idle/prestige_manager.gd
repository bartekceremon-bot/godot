class_name PrestigeManager
extends RefCounted
## Odrodzenie z Popiołu (prestiż): reset etapów, złota, poziomu, najemników, ekwipunku i surowców
## w zamian za Popiół Dusz – walutę stałych ulepszeń Ołtarza Popiołu.
## Zostają: czary i ich poziomy, wierzchowce, żarokryształy, ukończona Kronika, ulepszenia Ołtarza.

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func min_stage() -> int:
	return int(gm.db.prestige.min_stage)


func can_rebirth() -> bool:
	return int(gm.s.max_stage) >= min_stage()


func ash_gain() -> int:
	var ms := int(gm.s.max_stage)
	if ms < min_stage():
		return 0
	return int(floor(3.0 * pow((ms - 30) / 10.0, 2.0)))


func upg_def(id: String) -> Dictionary:
	for u in gm.db.prestige.upgrades:
		if str(u.id) == id:
			return u
	return {}


func level(id: String) -> int:
	return int(gm.s.prestige.get(id, 0))


func cost(id: String) -> int:
	var u := upg_def(id)
	return int(ceil(float(u.base) * pow(float(u.growth), level(id))))


func maxed(id: String) -> bool:
	var m := int(upg_def(id).get("max", 0))
	return m > 0 and level(id) >= m


func buy(id: String) -> bool:
	if maxed(id) or int(gm.s.ash) < cost(id):
		return false
	gm.s.ash = int(gm.s.ash) - cost(id)
	gm.s.prestige[id] = level(id) + 1
	gm.stats.recalc()
	gm.audio.play("rare")
	gm.changed.emit("prestige")
	return true


func totals() -> Dictionary:
	var t := {}
	for u in gm.db.prestige.upgrades:
		var l := level(str(u.id))
		if l <= 0:
			continue
		t[str(u.stat)] = float(u.per) * l
		if str(u.stat) == "offline":
			t["offline_h"] = float(l)
	return t


func start_stage() -> int:
	return 1 + int(totals().get("start", 0.0))


func rebirth() -> bool:
	if not can_rebirth():
		return false
	var s := gm.s
	var gain := ash_gain()
	s.ash = int(s.ash) + gain
	s.ash_total = int(s.ash_total) + gain
	s.rebirths = int(s.rebirths) + 1
	var start := start_stage()
	# Osiągnięcia liczą rekordy całej gry – zapamiętaj je przed wyzerowaniem.
	gm.achievements.remember()
	gm.tower.active = false
	gm.raid.active = false
	s.gold = 0.0
	s.level = 1
	s.xp = 0.0
	s.stage = start
	s.max_stage = start
	s.kills_in_stage = 0
	s.farm_mode = false
	s.train_lvl = 0
	s.mercs = {}
	s.gear = []
	s.equip = {}
	# Surowce, mikstury i skrzynie przepadają; zostają fragmenty wierzchowców i trofea bossów.
	var keep := {}
	for id in s.inv:
		if str(id).begins_with("frag_") or str(id).begins_with("rune_") or str(id) == "pet_egg" or str(gm.db.item(str(id)).get("category", "")) == "misc":
			keep[id] = s.inv[id]
	keep["hp_potion"] = 3
	s.inv = keep
	s.quests.tasks = []
	gm.equipment.give_starter_gear()
	gm.stats.recalc()
	gm.combat.reset_player()
	gm.quests.refresh()
	gm.market.generate()
	gm.enemy.spawn()
	gm.save.save_game()
	gm.notify("Odrodzenie z Popiołu! +%d Popiołu Dusz" % gain, Color(1.0, 0.55, 0.3))
	gm.changed.emit("all")
	return true
