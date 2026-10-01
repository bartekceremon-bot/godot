class_name ClassManager
extends RefCounted
## Klasy bohatera (od etapu 30): Wojownik, Łowca, Mag. Każda daje stałą premię i umiejętność
## ostateczną ładowaną w walce (ciosy i zabójstwa napełniają Żar; pełny Żar = użycie).
## Zmiana klasy: pierwsza darmowa, kolejne za żarokryształy.
## Stan: s.hero_class = {id, changes, charge, ult_until}.

const UNLOCK_STAGE := 30
const CHANGE_COST := 200
const CHARGE_MAX := 100.0
const CLASSES := {
	"warrior": {"name": "Wojownik", "text": "Mistrz ciosu. +30% obrażeń kliknięcia i +10% szansy krytyka.",
		"bonus": {"click": 0.3, "crit": 0.1}, "ult": "Furia Żaru", "ult_text": "Przez 10 s ciosy zadają ×4 obrażenia i każdy jest krytyczny.", "ult_sec": 10.0,
		"color": Color(1.0, 0.45, 0.25), "weapon": "axe_t4"},
	"hunter": {"name": "Łowca", "text": "Dowódca drużyny. +40% DPS najemników i +15% złota.",
		"bonus": {"merc": 0.4, "gold": 0.15}, "ult": "Deszcz Strzał", "ult_text": "Przez 15 s najemnicy zadają ×5 obrażenia.", "ult_sec": 15.0,
		"color": Color(0.5, 0.95, 0.45), "weapon": "bow_t4"},
	"mage": {"name": "Mag", "text": "Władca żywiołów. +40% siły czarów i +25% many.",
		"bonus": {"spell": 0.4, "mp": 0.25}, "ult": "Kataklizm", "ult_text": "Natychmiast zadaje obrażenia równe 30 s DPS i 30 ciosom oraz odnawia wszystkie czary.", "ult_sec": 0.0,
		"color": Color(0.55, 0.65, 1.0), "weapon": "staff_t4"},
}
const ORDER := ["warrior", "hunter", "mage"]

var gm: IdleGame
var _was_active := false


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("hero_class"):
		gm.s["hero_class"] = {"id": "", "changes": 0, "charge": 0.0, "ult_until": 0.0}
	return gm.s.hero_class


func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= UNLOCK_STAGE


func current() -> String:
	return str(_st().id)


func def() -> Dictionary:
	return CLASSES.get(current(), {})


func change_cost() -> int:
	return 0 if int(_st().changes) == 0 else CHANGE_COST


func choose(id: String) -> bool:
	if not unlocked() or not CLASSES.has(id) or id == current():
		return false
	var cost := change_cost()
	if cost > 0 and not gm.spend_gems(cost):
		return false
	var st := _st()
	st.id = id
	st.changes = int(st.changes) + 1
	st.charge = 0.0
	st.ult_until = 0.0
	gm.stats.mark_dirty()
	gm.changed.emit("class")
	gm.changed.emit("gear")
	return true


## Stałe premie klasy (do PlayerStats – klucze jak runy; „click” i „mp” osobno).
func totals() -> Dictionary:
	return def().get("bonus", {})


# --- Umiejętność ostateczna --------------------------------------------------------

func charge() -> float:
	return float(_st().charge)


func ready() -> bool:
	return current() != "" and charge() >= CHARGE_MAX and not ult_active()


func add_charge(n: float) -> void:
	if current() == "" or ult_active():
		return
	var st := _st()
	var before := float(st.charge)
	st.charge = minf(CHARGE_MAX, before + n)
	if before < CHARGE_MAX and float(st.charge) >= CHARGE_MAX:
		gm.changed.emit("class")


func ult_active() -> bool:
	return Time.get_unix_time_from_system() < float(_st().ult_until)


func ult_left() -> float:
	return maxf(0.0, float(_st().ult_until) - Time.get_unix_time_from_system())


func activate() -> bool:
	if not ready():
		return false
	var st := _st()
	st.charge = 0.0
	var d := def()
	if current() == "mage":
		var s := gm.stats
		gm.combat.damage((s.dps + s.click) * 30.0 * s.spell_power, true, "spell", true)
		gm.spells.reset_cooldowns()
	else:
		st.ult_until = Time.get_unix_time_from_system() + float(d.ult_sec)
		gm.stats.mark_dirty()
	gm.audio.play("rare")
	gm.changed.emit("class")
	return true


## Mnożniki w czasie umiejętności: {click, merc, crit}.
func ult_mults() -> Dictionary:
	if not ult_active():
		return {}
	match current():
		"warrior":
			return {"click": 4.0, "crit": 1.0}
		"hunter":
			return {"merc": 5.0}
	return {}


func tick(_dt: float) -> void:
	var a := ult_active()
	if a != _was_active:
		_was_active = a
		gm.stats.mark_dirty()
		gm.changed.emit("class")
