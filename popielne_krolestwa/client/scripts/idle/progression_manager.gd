class_name ProgressionManager
extends RefCounted
## Etapy, regiony, bossowie, doświadczenie i poziomy. Wszystkie krzywe balansu w jednym miejscu.
##
## Etap = 10 wrogów. Co 5. etap – elita (boss mini), co 10. – boss regionu (z czasem 30 s).
## Region = 10 etapów; po 8 regionach świat zapętla się w kolejnych Kręgach Popiołu.

var gm: IdleGame
## Po porażce z bossem: automatyczna ponowna próba po tym czasie farmienia (auto-postęp).
const RETRY_AFTER := 45.0
var _farm_t := 0.0


func _init(g: IdleGame) -> void:
	gm = g


# --- Krzywe -------------------------------------------------------------------------

## Zdrowie zwykłego wroga na etapie.
static func enemy_hp(stage: int) -> float:
	return 10.0 * pow(1.6, stage - 1) + 10.0 * (stage - 1)


## Złoto za zwykłego wroga (przed mnożnikami).
static func gold_for(stage: int) -> float:
	return ceilf(enemy_hp(stage) / 15.0 + 1.0)


static func xp_for(stage: int) -> float:
	return ceilf(3.0 * pow(1.18, stage - 1))


## Doświadczenie potrzebne na kolejny poziom.
static func xp_next(level: int) -> float:
	return ceilf(20.0 * pow(1.2, level - 1))


## Rodzaj etapu: 0 – zwykły, 1 – elita, 2 – boss regionu.
func boss_kind(stage: int) -> int:
	var per := gm.db.stages_per_region
	var i := (stage - 1) % per + 1
	if i == per:
		return 2
	if i == per / 2:
		return 1
	return 0


static func boss_hp_mult(kind: int) -> float:
	return [1.0, 6.0, 12.0][kind]


## Obrażenia ciosu bossa (co 2 s) przed obroną.
static func boss_hit(stage: int, kind: int) -> float:
	return 10.0 * pow(1.07, stage - 1) * (1.0 if kind == 1 else 1.4)


# --- Regiony ------------------------------------------------------------------------

func region_index(stage: int) -> int:
	return ((stage - 1) / gm.db.stages_per_region) % gm.db.regions.size()


## Krąg Popiołu (0 = pierwsze przejście świata).
func circle(stage: int) -> int:
	return (stage - 1) / (gm.db.stages_per_region * gm.db.regions.size())


func region(stage: int) -> Dictionary:
	return gm.db.regions[region_index(stage)]


## Tier łupu (T1–T8) dla etapu.
func loot_tier(stage: int) -> int:
	return clampi(int(region(stage).tier) + circle(stage) * 8, 1, 8)


## Premia do poziomu ulepszenia łupu w wyższych kręgach.
func loot_bonus_level(stage: int) -> int:
	return circle(stage) * 5


## Pierwszy etap regionu o danym tierze (ceny, wartości przedmiotów).
func tier_stage(tier: int) -> int:
	return (clampi(tier, 1, 8) - 1) * gm.db.stages_per_region + 5


func region_title(stage: int) -> String:
	var c := circle(stage)
	var name := str(region(stage).name)
	return name if c == 0 else "%s – Krąg %d" % [name, c + 1]


## Najwyższy odblokowany indeks regionu (0..7, liczony w pierwszym kręgu).
func max_region_index() -> int:
	return mini(gm.db.regions.size() - 1, (int(gm.s.max_stage) - 1) / gm.db.stages_per_region)


# --- Poziomy ------------------------------------------------------------------------

func add_xp(amount: float) -> void:
	var s := gm.s
	s.xp = float(s.xp) + amount
	var up := false
	while float(s.xp) >= xp_next(int(s.level)):
		s.xp = float(s.xp) - xp_next(int(s.level))
		s.level = int(s.level) + 1
		up = true
		gm.level_up.emit(int(s.level))
	if up:
		gm.stats.recalc()
		gm.combat.heal_full()
		gm.changed.emit("level")
	gm.changed.emit("xp")


# --- Etapy --------------------------------------------------------------------------

## Po zabiciu zwykłego wroga: licznik etapu i przejście dalej.
func on_normal_kill() -> void:
	var s := gm.s
	s.kills_in_stage = int(s.kills_in_stage) + 1
	if int(s.kills_in_stage) >= gm.db.kills_per_stage:
		if bool(s.farm_mode):
			s.kills_in_stage = gm.db.kills_per_stage
		else:
			advance()
	gm.changed.emit("stage")


func advance() -> void:
	var s := gm.s
	s.stage = int(s.stage) + 1
	s.kills_in_stage = 0
	if int(s.stage) > int(s.max_stage):
		s.max_stage = int(s.stage)
		_on_new_max_stage()
	gm.changed.emit("stage")


func _on_new_max_stage() -> void:
	var s := gm.s
	var per := gm.db.stages_per_region
	if (int(s.max_stage) - 1) % per == 0 and int(s.max_stage) > 1:
		gm.notify("Nowy region: %s!" % region_title(int(s.max_stage)), Color(1.0, 0.85, 0.4))
		gm.audio.play("levelup")
	gm.crafting.check_unlocks()
	gm.story.on_new_stage(int(s.max_stage))
	gm.quests.on_event("stage", 1)
	gm.quests.refresh()


func on_boss_kill(kind: int) -> void:
	var s := gm.s
	s.farm_mode = false
	s.stats.bosses = int(s.stats.bosses) + 1
	if kind == 2:
		gm.story.on_region_boss(int(s.stage))
	gm.quests.on_event("bosses", 1)
	advance()


func on_boss_fail(reason: String) -> void:
	var s := gm.s
	s.farm_mode = true
	s.stage = maxi(1, int(s.stage) - 1)
	s.kills_in_stage = gm.db.kills_per_stage
	_farm_t = 0.0
	gm.boss_failed.emit(reason)
	gm.changed.emit("stage")


## Ręczne wyzwanie bossa z trybu farmienia.
func challenge_boss() -> void:
	if gm.tower.active or gm.raid.active:
		return
	var s := gm.s
	if not bool(s.farm_mode):
		return
	s.farm_mode = false
	advance()
	gm.enemy.spawn()


func toggle_auto(on: bool) -> void:
	gm.s.auto_progress = on
	gm.changed.emit("stage")


## Podróż na wybrany (odblokowany) etap – mapa.
func travel(stage: int) -> void:
	if gm.tower.active or gm.raid.active:
		return
	var s := gm.s
	stage = clampi(stage, 1, int(s.max_stage))
	s.stage = stage
	s.kills_in_stage = 0
	# Etap bossa wybrany z mapy – walka od razu; inny etap poniżej maksimum – farmienie.
	s.farm_mode = stage < int(s.max_stage) and boss_kind(stage) == 0
	gm.enemy.spawn()
	gm.changed.emit("stage")


func tick(dt: float) -> void:
	var s := gm.s
	if gm.tower.active or gm.raid.active:
		return
	if bool(s.farm_mode) and bool(s.auto_progress) and int(s.stage) + 1 == int(s.max_stage) and boss_kind(int(s.stage) + 1) > 0:
		_farm_t += dt
		if _farm_t >= RETRY_AFTER:
			_farm_t = 0.0
			challenge_boss()
