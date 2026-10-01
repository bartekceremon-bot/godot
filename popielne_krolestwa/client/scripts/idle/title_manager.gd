class_name TitleManager
extends RefCounted
## Tytuły bohatera: zdobywane za wyczyny w różnych trybach (na stałe, także po odrodzeniu).
## Jeden tytuł jest noszony – daje swoją premię i widać go w Rekordach i przy portrecie.
## Stan: s.titles = {owned: [id], active: id}.

## [id, nazwa, opis warunku, rodzaj licznika, próg, klucz premii, premia]
const TITLES := [
	["boss_slayer", "Łowca Bossów", "Pokonaj %d bossów i elit", "bosses", 500, "boss", 0.10],
	["goblin_hunter", "Pogromca Goblinów", "Pokonaj %d Złotych Goblinów", "goblins", 10, "gold", 0.05],
	["combo_master", "Burza Ciosów", "Osiągnij combo %d", "combo", 100, "click", 0.10],
	["gardener", "Zielarz z Popielgrodu", "Zbierz plony %d razy", "harvests", 100, "xp", 0.05],
	["architect", "Architekt Twierdzy", "Suma poziomów budynków Twierdzy: %d", "stronghold", 60, "gold", 0.05],
	["weapon_master", "Mistrz Oręża", "Suma poziomów mistrzostwa broni: %d", "mastery", 100, "critdmg", 0.10],
	["dragon_rider", "Smoczy Jeździec", "Wychowaj smoka do poziomu %d", "dragon", 25, "damage", 0.05],
	["dreamer", "Śniący", "Dotrzyj do %d. piętra Snu", "dream", 20, "spell", 0.10],
	["tower_keeper", "Strażnik Wieży", "Dotrzyj do %d. piętra Wieży Popiołu", "tower", 50, "damage", 0.05],
	["reborn", "Wiecznie Odradzający się", "Odródź się %d razy", "rebirths", 10, "xp", 0.10],
	["collector", "Kolekcjoner Relikwii", "Zdobądź %d relikwii", "relics", 12, "gold", 0.10],
	["legend", "Legenda Popiołu", "Dotrzyj do etapu %d", "stage", 120, "damage", 0.10],
]
## Nazwy premii do opisu.
const BONUS_NAMES := {"boss": "obrażeń bossom", "gold": "złota", "click": "obrażeń kliknięcia", "xp": "doświadczenia",
	"critdmg": "obrażeń krytycznych", "damage": "wszystkich obrażeń", "spell": "mocy czarów"}

var gm: IdleGame
var _t := 0.0


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("titles"):
		gm.s["titles"] = {"owned": [], "active": ""}
	return gm.s.titles


static func def(id: String) -> Array:
	for t in TITLES:
		if str(t[0]) == id:
			return t
	return []


static func title_name(id: String) -> String:
	var d := def(id)
	return str(d[1]) if not d.is_empty() else ""


func value(kind: String) -> float:
	var st: Dictionary = gm.s.stats
	match kind:
		"bosses":
			return float(st.get("bosses", 0))
		"goblins":
			return float(gm.goblin.kills())
		"combo":
			return float(st.get("best_combo", 0))
		"harvests":
			return float(gm.garden.harvests()) if gm.s.has("garden") else 0.0
		"stronghold":
			return float(gm.stronghold.total_levels())
		"mastery":
			return float(gm.mastery.total_levels())
		"dragon":
			return float(gm.dragon.level()) if gm.dragon.alive() else 0.0
		"dream":
			return float(gm.dream.best())
		"tower":
			return float(gm.tower.best())
		"rebirths":
			return float(gm.s.rebirths)
		"relics":
			return float(gm.relics.owned_count())
		"stage":
			return gm.achievements.value("best_stage")
	return 0.0


func owned(id: String) -> bool:
	return (_st().owned as Array).has(id)


func active() -> String:
	return str(_st().active)


## Sprawdza warunki i przyznaje nowe tytuły. Zwraca listę nowych id.
func check() -> Array:
	var got: Array = []
	for t in TITLES:
		var id := str(t[0])
		if not owned(id) and value(str(t[3])) >= float(t[4]):
			_st().owned.append(id)
			got.append(id)
			gm.toast.emit("Nowy tytuł: %s!" % SmartTranslation.t(str(t[1])), Color(1.0, 0.85, 0.45))
	if not got.is_empty():
		if active() == "":
			wear(str(got[0]))
		gm.changed.emit("titles")
	return got


func wear(id: String) -> bool:
	if id != "" and not owned(id):
		return false
	_st().active = id
	gm.stats.mark_dirty()
	gm.changed.emit("titles")
	return true


func totals() -> Dictionary:
	var d := def(active())
	if d.is_empty():
		return {}
	return {str(d[5]): float(d[6])}


func owned_count() -> int:
	return (_st().owned as Array).size()


func bonus_text(id: String) -> String:
	var d := def(id)
	return "+%d%% %s" % [int(round(float(d[6]) * 100.0)), SmartTranslation.t(str(BONUS_NAMES.get(str(d[5]), "")))]


func tick(dt: float) -> void:
	_t += dt
	if _t >= 5.0:
		_t = 0.0
		check()
