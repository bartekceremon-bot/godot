class_name GoblinManager
extends RefCounted
## Złoty Goblin (od etapu 8): rzadki przeciwnik w zwykłej walce zamiast zwykłego potwora.
## Ma dużo zdrowia i ucieka po kilku sekundach – kto zdąży go pokonać, dostaje worek złota,
## żarokryształy i szansę na skrzynię lub runę. Nie pojawia się częściej niż co 2 min.
## Statystyka: s.stats.goblins (pokonane), s.stats.goblins_fled (uciekły).

const UNLOCK_STAGE := 8
const CHANCE := 0.025
const COOLDOWN := 120.0
const TIME := 12.0
const HP_MULT := 8.0
const GOLD_MULT := 150.0

var gm: IdleGame
var _rng := RandomNumberGenerator.new()
var _last := -COOLDOWN
## Wymuszenie następnego goblina (testy i przegląd UI).
var force := false


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func chance() -> float:
	return CHANCE * (1.0 + gm.events.bonus("loot"))


func kills() -> int:
	return int(gm.s.stats.get("goblins", 0))


## Zwraca przeciwnika-goblina albo {} (losowanie przy pojawieniu się zwykłego wroga).
func maybe_spawn(stage: int) -> Dictionary:
	if stage < UNLOCK_STAGE and not force:
		return {}
	var t := float(gm.s.play_time)
	if not force and (t - _last < COOLDOWN or _rng.randf() >= chance()):
		return {}
	force = false
	_last = t
	var hp := ProgressionManager.enemy_hp(stage) * HP_MULT
	gm.audio.play("rare")
	return {"monster": "orc_shaman", "name": "Złoty Goblin", "look": "orc_shaman", "max_hp": hp, "hp": hp, "kind": 0,
		"stage": stage, "time_left": TIME, "time_max": TIME, "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0, "undead": false, "goblin": true}


## Nagroda za pokonanie: {gold, gems, extra}.
func on_kill(e: Dictionary) -> Dictionary:
	var stage := int(e.stage)
	var gold := ProgressionManager.gold_for(stage) * GOLD_MULT * gm.stats.gold_mult
	gm.add_gold(gold)
	var gems := _rng.randi_range(5, 15)
	gm.add_gems(gems)
	var extra := ""
	var r := _rng.randf()
	if r < 0.25:
		var tier := clampi(1 + gm.progression.region_index(stage) / 2, 1, 4)
		gm.inventory.add("chest_%d" % tier, 1)
		extra = LootManager.CHEST_NAMES[tier]
	elif r < 0.37:
		var rn := gm.runes.random_rune(clampf(stage / 150.0, 0.0, 1.0))
		gm.inventory.add(rn, 1)
		extra = RuneManager.rune_name(rn)
	gm.s.stats["goblins"] = kills() + 1
	gm.quests.on_event("goblins", 1)
	gm.season.add_xp(5)
	gm.audio.play("rare")
	return {"gold": gold, "gems": gems, "extra": extra}


func on_escape() -> void:
	gm.s.stats["goblins_fled"] = int(gm.s.stats.get("goblins_fled", 0)) + 1
	gm.toast.emit("Złoty Goblin uciekł z łupem!", Color(1.0, 0.75, 0.3))
