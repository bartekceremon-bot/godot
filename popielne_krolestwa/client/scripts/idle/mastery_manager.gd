class_name MasteryManager
extends RefCounted
## Mistrzostwo broni: każdy pokonany wróg daje doświadczenie rodzajowi broni, którą bohater
## trzyma (bossowie i elity więcej). Poziomy mistrzostwa dają stałe premie – wszystkie naraz,
## niezależnie od aktualnej broni – i przetrwają odrodzenie oraz przebudzenie Feniksa.
## Stan: s.mastery = {rodzaj: {lvl, xp}}.

const MAX_LVL := 50
## [nazwa, opis premii, klucz premii (jak talenty), wartość na poziom, ikona przedmiotu]
const TYPES := {
	"sword": ["Miecze", "+2% obrażeń kliknięcia na poziom", "click", 0.02, "sword_t3"],
	"axe": ["Topory", "+3% obrażeń krytycznych na poziom", "critdmg", 0.03, "axe_t3"],
	"mace": ["Buławy", "+3% obrażeń zadawanych bossom na poziom", "boss", 0.03, "mace_t3"],
	"bow": ["Łuki", "+2% DPS najemników na poziom", "merc", 0.02, "bow_t3"],
	"staff": ["Kostury", "+2% mocy czarów na poziom", "spell", 0.02, "staff_t3"],
}
const ORDER := ["sword", "axe", "mace", "bow", "staff"]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("mastery"):
		gm.s["mastery"] = {}
	return gm.s.mastery


func _entry(t: String) -> Dictionary:
	var st := _st()
	if not st.has(t):
		st[t] = {"lvl": 0, "xp": 0}
	return st[t]


func level(t: String) -> int:
	return int(_entry(t).lvl)


func xp(t: String) -> int:
	return int(_entry(t).xp)


## Doświadczenie potrzebne do kolejnego poziomu (rośnie szybciej niż liniowo).
static func need(lvl: int) -> int:
	return int(round(40.0 * pow(lvl + 1, 1.6)))


## Rodzaj trzymanej broni ("" – brak).
func current() -> String:
	var it: Dictionary = gm.equipment.equipped("weapon")
	if it.is_empty():
		return ""
	var t := str(it.get("id", "")).get_slice("_", 0)
	return t if TYPES.has(t) else ""


func add_xp(t: String, n: int) -> void:
	if not TYPES.has(t) or level(t) >= MAX_LVL:
		return
	var e := _entry(t)
	e.xp = xp(t) + n
	var up := false
	while level(t) < MAX_LVL and xp(t) >= need(level(t)):
		e.xp = xp(t) - need(level(t))
		e.lvl = level(t) + 1
		up = true
	if level(t) >= MAX_LVL:
		e.xp = 0
	if up:
		gm.stats.mark_dirty()
		gm.toast.emit("Mistrzostwo – %s: poziom %d!" % [SmartTranslation.t(str(TYPES[t][0])), level(t)], Color(1.0, 0.8, 0.45))
		gm.changed.emit("mastery")


## Wywoływane po każdym zwycięstwie w zwykłej walce (rodzaj wroga 0/1/2).
func on_kill(kind: int) -> void:
	var t := current()
	if t != "":
		add_xp(t, [1, 5, 12][clampi(kind, 0, 2)])


func bonus(t: String) -> float:
	return float(TYPES[t][3]) * level(t)


## Premie do PlayerStats (klucze jak w talentach).
func totals() -> Dictionary:
	var out := {}
	for t in ORDER:
		if level(t) > 0:
			var k := str(TYPES[t][2])
			out[k] = float(out.get(k, 0.0)) + bonus(t)
	return out


func total_levels() -> int:
	var n := 0
	for t in ORDER:
		n += level(t)
	return n
