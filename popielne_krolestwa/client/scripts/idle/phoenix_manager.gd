class_name PhoenixManager
extends RefCounted
## Przebudzenie Feniksa – druga warstwa odrodzenia. Od 300 Popiołu Dusz zebranych od ostatniego
## przebudzenia i etapu 80: reset jak przy odrodzeniu oraz Popiołu Dusz i ulepszeń Ołtarza,
## w zamian Pióra Feniksa na potężne, mnożące się ulepszenia. Talenty, runy, chowańce,
## bestiariusz, wieża, osiągnięcia i czary zostają. Stan: s.phoenix = {feathers, total, count, upg}.

const MIN_ASH := 300
const MIN_STAGE := 80
const UPGRADES := [
	{"id": "flame", "name": "Płomień Feniksa", "per": 0.5, "base": 1, "growth": 1.6, "max": 0, "text": "×%s obrażeń (mnożnik)"},
	{"id": "gold", "name": "Złote Pióra", "per": 0.5, "base": 1, "growth": 1.6, "max": 0, "text": "×%s złota (mnożnik)"},
	{"id": "ash", "name": "Popiół Odrodzeń", "per": 0.25, "base": 2, "growth": 1.7, "max": 0, "text": "+%s Popiołu Dusz z odrodzeń"},
	{"id": "memory", "name": "Pamięć Ognia", "per": 10.0, "base": 3, "growth": 2.0, "max": 5, "text": "start od etapu +%s po odrodzeniu"},
	{"id": "wings", "name": "Skrzydła Snu", "per": 0.2, "base": 2, "growth": 1.8, "max": 5, "text": "+%s postępu offline i +2 h limitu"},
	{"id": "wisdom", "name": "Mądrość Feniksa", "per": 3.0, "base": 2, "growth": 1.8, "max": 10, "text": "+%s punktów talentów"},
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("phoenix"):
		gm.s["phoenix"] = {"feathers": 0, "total": 0, "count": 0, "upg": {}, "ash_base": 0}
	return gm.s.phoenix


## Popiół zebrany od ostatniego przebudzenia.
func ash_since() -> int:
	return int(gm.s.ash_total) - int(_st().get("ash_base", 0))


func feather_gain() -> int:
	var a := ash_since()
	if a < MIN_ASH:
		return 0
	return int(floor(sqrt(a / 25.0)))


func can_awaken() -> bool:
	return feather_gain() > 0 and int(gm.s.max_stage) >= MIN_STAGE


func feathers() -> int:
	return int(_st().feathers)


func count() -> int:
	return int(_st().count)


func level(id: String) -> int:
	return int(_st().upg.get(id, 0))


static func def(id: String) -> Dictionary:
	for u in UPGRADES:
		if str(u.id) == id:
			return u
	return {}


func cost(id: String) -> int:
	var u := def(id)
	return int(ceil(float(u.base) * pow(float(u.growth), level(id))))


func maxed(id: String) -> bool:
	var m := int(def(id).max)
	return m > 0 and level(id) >= m


func buy(id: String) -> bool:
	if maxed(id) or feathers() < cost(id):
		return false
	_st().feathers = feathers() - cost(id)
	_st().upg[id] = level(id) + 1
	gm.talents.mark_dirty()
	gm.stats.recalc()
	gm.audio.play("rare")
	gm.changed.emit("phoenix")
	return true


func value(id: String) -> float:
	return float(def(id).per) * level(id)


func awaken() -> bool:
	if not can_awaken():
		return false
	var gain := feather_gain()
	var st := _st()
	st.feathers = feathers() + gain
	st.total = int(st.total) + gain
	st.count = count() + 1
	# Odrodzenie na siłę (bez warunku etapu) i reset warstwy Popiołu.
	gm.s.max_stage = maxi(int(gm.s.max_stage), gm.prestige.min_stage())
	gm.prestige.rebirth()
	gm.s.ash = 0
	st.ash_base = int(gm.s.ash_total)
	gm.s.prestige = {}
	gm.s.stage = gm.prestige.start_stage()
	gm.s.max_stage = gm.s.stage
	gm.enemy.spawn()
	gm.stats.recalc()
	gm.save.save_game()
	gm.notify("PRZEBUDZENIE FENIKSA! +%d Piór Feniksa" % gain, Color(1.0, 0.6, 0.2))
	gm.changed.emit("all")
	return true
