class_name DragonManager
extends RefCounted
## Smoczy towarzysz (od etapu 45): jajo Żarogniewa wykluwa się w 2 h (albo od razu za
## żarokryształy). Smoka karmi się złotem (limit dzienny) i ziołami z Ogrodu Alchemika.
## W walce co kilka sekund zieje ogniem (obrażenia rosną z poziomem), a każdy poziom daje
## stałe +1% złota. Stadia: Pisklę, Młody, Dorosły, Pradawny smok.
## Stan: s.dragon = {state: "none"/"egg"/"alive", hatch_at, lvl, xp, day, gold_feeds, breaths}.

const UNLOCK_STAGE := 45
const HATCH_SEC := 7200.0
const HATCH_GEMS := 50
const MAX_LVL := 60
const GOLD_FEEDS := 20
const BREATH_CD := 8.0
## Doświadczenie za jedno zioło.
const HERB_XP := {"ember_root": 4, "moon_sage": 8, "goldbloom": 12, "frost_lily": 20, "dragon_pepper": 50}
## [od poziomu, nazwa stadium, skala modelu]
const STAGES := [[1, "Pisklę", 0.45], [10, "Młody smok", 0.6], [25, "Dorosły smok", 0.78], [45, "Pradawny smok", 0.95]]

var gm: IdleGame
var _breath_t := BREATH_CD


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("dragon"):
		gm.s["dragon"] = {"state": "none", "hatch_at": 0.0, "lvl": 0, "xp": 0, "day": "", "gold_feeds": 0, "breaths": 0}
	var d: Dictionary = gm.s.dragon
	if str(d.day) != DailyManager.today():
		d.day = DailyManager.today()
		d.gold_feeds = 0
	return d


static func now() -> float:
	return Time.get_unix_time_from_system()


func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= UNLOCK_STAGE


func state() -> String:
	var d := _st()
	if str(d.state) == "egg" and now() >= float(d.hatch_at):
		return "ready"
	return str(d.state)


func alive() -> bool:
	return str(_st().state) == "alive"


func level() -> int:
	return int(_st().lvl)


func xp() -> int:
	return int(_st().xp)


static func need(lvl: int) -> int:
	return int(round(20.0 + 12.0 * pow(lvl, 1.3)))


func hatch_left() -> float:
	return maxf(0.0, float(_st().hatch_at) - now())


func gold_feeds_left() -> int:
	return maxi(0, GOLD_FEEDS - int(_st().gold_feeds))


func stage_index() -> int:
	var idx := 0
	for i in STAGES.size():
		if level() >= int(STAGES[i][0]):
			idx = i
	return idx


func stage_name() -> String:
	return str(STAGES[stage_index()][1])


func model_scale() -> float:
	return float(STAGES[stage_index()][2])


## Odbiór jaja (raz, po odblokowaniu).
func take_egg() -> bool:
	if not unlocked() or state() != "none":
		return false
	var d := _st()
	d.state = "egg"
	d.hatch_at = now() + HATCH_SEC
	gm.changed.emit("dragon")
	return true


func can_hatch(use_gems := false) -> bool:
	var st := state()
	return st == "ready" or (st == "egg" and use_gems and int(gm.s.gems) >= HATCH_GEMS)


func hatch(use_gems := false) -> bool:
	if not can_hatch(use_gems):
		return false
	if state() == "egg" and not gm.spend_gems(HATCH_GEMS):
		return false
	var d := _st()
	d.state = "alive"
	d.lvl = 1
	d.xp = 0
	_breath_t = BREATH_CD
	gm.stats.mark_dirty()
	gm.audio.play("rare")
	gm.changed.emit("dragon")
	return true


func gold_cost() -> float:
	return ProgressionManager.gold_for(maxi(1, int(gm.s.max_stage))) * 40.0 * (1.0 + 0.1 * level())


func can_feed_gold() -> bool:
	return alive() and level() < MAX_LVL and gold_feeds_left() > 0 and float(gm.s.gold) >= gold_cost()


func feed_gold() -> bool:
	if not can_feed_gold():
		return false
	gm.spend_gold(gold_cost())
	_st().gold_feeds = int(_st().gold_feeds) + 1
	add_xp(10)
	gm.changed.emit("dragon")
	return true


func can_feed_herb(h: String) -> bool:
	return alive() and level() < MAX_LVL and HERB_XP.has(h) and gm.garden.herbs(h) > 0


## Karmi `n` ziołami danego rodzaju (albo wszystkimi, gdy n < 0). Zwraca liczbę zjedzonych.
func feed_herb(h: String, n := 1) -> int:
	if not can_feed_herb(h):
		return 0
	var have := gm.garden.herbs(h)
	var eat := have if n < 0 else mini(n, have)
	gm.s.garden.herbs[h] = have - eat
	add_xp(int(HERB_XP[h]) * eat)
	gm.changed.emit("dragon")
	gm.changed.emit("garden")
	return eat


func add_xp(n: int) -> void:
	if not alive() or level() >= MAX_LVL:
		return
	var d := _st()
	var before := stage_index()
	d.xp = xp() + n
	var up := false
	while level() < MAX_LVL and xp() >= need(level()):
		d.xp = xp() - need(level())
		d.lvl = level() + 1
		up = true
	if level() >= MAX_LVL:
		d.xp = 0
	if up:
		gm.stats.mark_dirty()
		if stage_index() > before:
			gm.toast.emit("Twój smok dorósł: %s!" % SmartTranslation.t(stage_name()), Color(1.0, 0.55, 0.25))
		else:
			gm.toast.emit("Smok: poziom %d!" % level(), Color(1.0, 0.6, 0.3))
		gm.changed.emit("dragon")


## Mnożnik obrażeń zionięcia (× (DPS + cios)).
func breath_mult() -> float:
	return 1.5 + 0.2 * level()


func breath_damage() -> float:
	return (gm.stats.dps + gm.stats.click) * breath_mult()


## Stała premia: +1% złota za poziom.
func totals() -> Dictionary:
	return {"gold": 0.01 * level()} if alive() else {}


func breath_left() -> float:
	return _breath_t


func tick(dt: float) -> void:
	if not alive() or not gm.enemy.alive() or gm.enemy.cur.has("hold"):
		return
	_breath_t -= dt
	if _breath_t <= 0.0:
		_breath_t = BREATH_CD
		_st().breaths = int(_st().breaths) + 1
		gm.combat.damage(breath_damage(), false, "dragon")
