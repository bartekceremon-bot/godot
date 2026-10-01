class_name StrongholdManager
extends RefCounted
## Twierdza Popielników (od etapu 12): budynki rozbudowywane za złoto w czasie rzeczywistym
## (budowa trwa także przy zamkniętej grze). Każdy poziom daje stałą premię; budynki
## zostają po odrodzeniu. Jeden budowniczy (drugi na stałe za żarokryształy), przyspieszanie
## za żarokryształy i raz dziennie za reklamę.
## Stan: s.stronghold = {lv: {budynek: poziom}, queue: [{b, done_at}], builders, built}.

const UNLOCK_STAGE := 12
const MAX_LVL := 30
const MAX_TIME := 8.0 * 3600.0
const BUILDER_COST := 300
const AD_CUT := 1800.0
## [nazwa, opis, klucz premii, premia na poziom, koszt bazowy (× złoto za wroga), czas bazowy (s)]
const BUILDINGS := {
	"treasury": ["Skarbiec", "+4% złota na poziom", "gold", 0.04, 60.0, 120.0],
	"barracks": ["Koszary", "+4% DPS najemników na poziom", "merc", 0.04, 70.0, 150.0],
	"forge": ["Kuźnia Twierdzy", "+3% wszystkich obrażeń na poziom", "damage", 0.03, 90.0, 180.0],
	"library": ["Biblioteka", "+4% doświadczenia na poziom", "xp", 0.04, 50.0, 120.0],
	"mage_tower": ["Wieża Magów", "+4% mocy czarów na poziom", "spell", 0.04, 80.0, 180.0],
	"watchtower": ["Strażnica", "+3% postępu offline na poziom", "offline", 0.03, 100.0, 240.0],
}
const ORDER := ["treasury", "barracks", "forge", "library", "mage_tower", "watchtower"]

var gm: IdleGame
var _check_t := 0.0


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("stronghold"):
		gm.s["stronghold"] = {"lv": {}, "queue": [], "builders": 1, "built": 0}
	return gm.s.stronghold


static func now() -> float:
	return Time.get_unix_time_from_system()


func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= UNLOCK_STAGE


func level(b: String) -> int:
	return int(_st().lv.get(b, 0))


func builders() -> int:
	return int(_st().builders)


func queue() -> Array:
	return _st().queue


func in_queue(b: String) -> bool:
	for q in queue():
		if str(q.b) == b:
			return true
	return false


func free_builders() -> int:
	return builders() - queue().size()


func cost(b: String) -> float:
	return ProgressionManager.gold_for(maxi(1, int(gm.s.max_stage))) * float(BUILDINGS[b][4]) * pow(1.25, level(b))


func build_time(b: String) -> float:
	return minf(MAX_TIME, float(BUILDINGS[b][5]) * pow(1.35, level(b)))


func can_build(b: String) -> bool:
	return unlocked() and BUILDINGS.has(b) and level(b) < MAX_LVL and not in_queue(b) and free_builders() > 0 and float(gm.s.gold) >= cost(b)


func build(b: String) -> bool:
	if not can_build(b):
		return false
	gm.spend_gold(cost(b))
	queue().append({"b": b, "done_at": now() + build_time(b)})
	gm.changed.emit("stronghold")
	return true


func time_left(i: int) -> float:
	return maxf(0.0, float(queue()[i].done_at) - now())


## Koszt natychmiastowego ukończenia: 1 żarokryształ za każde rozpoczęte 3 minuty.
func rush_cost(i: int) -> int:
	return maxi(1, int(ceil(time_left(i) / 180.0)))


func rush(i: int) -> bool:
	if i < 0 or i >= queue().size() or not gm.spend_gems(rush_cost(i)):
		return false
	queue()[i].done_at = now()
	check_done()
	return true


## Reklama (raz dziennie): −30 min dla wszystkich budów w kolejce.
func ad_speedup() -> void:
	for q in queue():
		q.done_at = float(q.done_at) - AD_CUT
	check_done()
	gm.changed.emit("stronghold")


func buy_builder() -> bool:
	if builders() >= 2 or not gm.spend_gems(BUILDER_COST):
		return false
	_st().builders = 2
	gm.changed.emit("stronghold")
	return true


## Kończy gotowe budowy (wywoływane co sekundę i przy otwarciu panelu). Zwraca liczbę.
func check_done() -> int:
	var st := _st()
	var left: Array = []
	var n := 0
	for q in st.queue:
		if now() >= float(q.done_at):
			var b := str(q.b)
			st.lv[b] = level(b) + 1
			st.built = int(st.built) + 1
			n += 1
			gm.toast.emit("Twierdza: %s – poziom %d!" % [SmartTranslation.t(str(BUILDINGS[b][0])), level(b)], Color(0.9, 0.8, 0.55))
		else:
			left.append(q)
	if n > 0:
		st.queue = left
		gm.quests.on_event("build", n)
		gm.stats.mark_dirty()
		gm.audio.play("levelup")
		gm.changed.emit("stronghold")
	return n


func tick(dt: float) -> void:
	_check_t += dt
	if _check_t >= 1.0:
		_check_t = 0.0
		if gm.s.has("stronghold") and not queue().is_empty():
			check_done()


func bonus(b: String) -> float:
	return float(BUILDINGS[b][3]) * level(b)


## Premie do PlayerStats (klucze jak w talentach).
func totals() -> Dictionary:
	var out := {}
	if not gm.s.has("stronghold"):
		return out
	for b in ORDER:
		if level(b) > 0:
			var k := str(BUILDINGS[b][2])
			out[k] = float(out.get(k, 0.0)) + bonus(b)
	return out


func total_levels() -> int:
	var n := 0
	for b in ORDER:
		n += level(b)
	return n


func ready_badge() -> int:
	if not unlocked():
		return 0
	return free_builders()
