class_name AffixManager
extends RefCounted
## Cechy elit i bossów (od etapu 30): elita/boss w zwykłej walce może dostać 1 cechę
## (od etapu 60 – czasem 2), która zmienia walkę. Każda cecha: +50% złota i +1 żarokryształ.
## Cechy zapisane w przeciwniku: cur.affixes = [id, ...].

const UNLOCK_STAGE := 30
const SECOND_STAGE := 60
## [nazwa, opis, kolor]
const AFFIXES := {
	"armored": ["Opancerzony", "−50% obrażeń od ciosów i najemników", Color(0.75, 0.8, 0.9)],
	"regen": ["Regenerujący", "odnawia 2% zdrowia na sekundę", Color(0.5, 1.0, 0.5)],
	"frenzy": ["W szale", "zadaje podwójne obrażenia", Color(1.0, 0.4, 0.3)],
	"agile": ["Zwinny", "unika 25% ciosów", Color(0.6, 0.95, 1.0)],
	"colossal": ["Kolosalny", "+100% zdrowia", Color(1.0, 0.75, 0.4)],
	"cursed": ["Przeklęty", "czary zadają o 50% mniej", Color(0.8, 0.55, 1.0)],
}
const ORDER := ["armored", "regen", "frenzy", "agile", "colossal", "cursed"]

var gm: IdleGame
var _rng := RandomNumberGenerator.new()
## Wymuszone cechy następnego elity/bossa (testy i przegląd UI).
var force: Array = []


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


static func name_of(id: String) -> String:
	return str(AFFIXES[id][0]) if AFFIXES.has(id) else id


## Losuje cechy dla elity (1) lub bossa (2).
func roll(stage: int, kind: int) -> Array:
	if not force.is_empty():
		var f := force.duplicate()
		force = []
		return f
	if kind <= 0 or stage < UNLOCK_STAGE:
		return []
	if _rng.randf() >= (0.6 if kind == 2 else 0.4):
		return []
	var out: Array = [ORDER[_rng.randi() % ORDER.size()]]
	if stage >= SECOND_STAGE and _rng.randf() < 0.5:
		var second: String = ORDER[_rng.randi() % ORDER.size()]
		if not out.has(second):
			out.append(second)
	return out


## Nakłada cechy na nowego przeciwnika (zdrowie Kolosalnego).
func apply(e: Dictionary) -> void:
	var a := roll(int(e.stage), int(e.kind))
	if a.is_empty():
		return
	e["affixes"] = a
	if a.has("colossal"):
		e.max_hp = float(e.max_hp) * 2.0
		e.hp = float(e.max_hp)


static func has(e: Dictionary, id: String) -> bool:
	return (e.get("affixes", []) as Array).has(id)


## Mnożnik obrażeń zadawanych przeciwnikowi wg źródła; 0 – unik.
func damage_mult(e: Dictionary, source: String) -> float:
	if not e.has("affixes"):
		return 1.0
	var m := 1.0
	if source in ["tap", "auto"]:
		if has(e, "agile") and source == "tap" and _rng.randf() < 0.25:
			return 0.0
		if has(e, "armored"):
			m *= 0.5
	if source in ["spell", "dot"] and has(e, "cursed"):
		m *= 0.5
	return m


func attack_mult(e: Dictionary) -> float:
	return 2.0 if has(e, "frenzy") else 1.0


func regen(e: Dictionary, dt: float) -> void:
	if has(e, "regen"):
		e.hp = minf(float(e.max_hp), float(e.hp) + float(e.max_hp) * 0.02 * dt)


func reward_mult(e: Dictionary) -> float:
	return 1.0 + 0.5 * (e.get("affixes", []) as Array).size()


func bonus_gems(e: Dictionary) -> int:
	return (e.get("affixes", []) as Array).size()


## Tekst do HUD: „◆ Opancerzony  ◆ W szale”.
func hud_text(e: Dictionary) -> String:
	var parts: Array = []
	for a in e.get("affixes", []):
		parts.append("◆ " + SmartTranslation.t(name_of(str(a))))
	return "  ".join(parts)
