class_name AchievementManager
extends RefCounted
## Osiągnięcia: progi statystyk całej gry (nie znikają po odrodzeniu), nagroda w żarokryształach.
## Stan: s.ach = {claimed: {klucz: liczba odebranych progów}, best_stage, best_level}.

const LIST := [
	["kills", "Łowca", "Pokonani przeciwnicy: %s", [100, 1000, 10000, 100000, 1000000]],
	["bosses", "Pogromca bossów", "Pokonani bossowie i elity: %s", [1, 10, 50, 200, 1000]],
	["best_stage", "Wędrowiec", "Dotrzyj do etapu %s", [10, 25, 50, 80, 120]],
	["best_level", "Weteran", "Osiągnij poziom %s", [10, 25, 50, 100, 200]],
	["taps", "Niezmordowana pięść", "Zadane ciosy: %s", [500, 5000, 50000, 500000]],
	["crits", "Ostrze losu", "Trafienia krytyczne: %s", [50, 500, 5000, 50000]],
	["spells", "Adept magii", "Rzucone czary: %s", [10, 100, 1000, 10000]],
	["rebirths", "Feniks", "Odrodzenia z popiołu: %s", [1, 3, 10, 25]],
	["dungeon_clears", "Grotołaz", "Oczyszczone lochy: %s", [1, 10, 50, 200]],
	["arena_wins", "Gladiator", "Wygrane pojedynki na Arenie: %s", [1, 10, 50, 250]],
	["relic_levels", "Kolekcjoner relikwii", "Suma poziomów relikwii: %s", [1, 12, 40, 120]],
	["harvests", "Zielarz", "Zebrane plony: %s", [1, 25, 100, 500]],
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("ach"):
		gm.s["ach"] = {"claimed": {}, "best_stage": 1, "best_level": 1}
	return gm.s.ach


func value(key: String) -> float:
	var st := _st()
	match key:
		"best_stage":
			st.best_stage = maxi(int(st.best_stage), int(gm.s.max_stage))
			return float(st.best_stage)
		"best_level":
			st.best_level = maxi(int(st.best_level), int(gm.s.level))
			return float(st.best_level)
		"rebirths":
			return float(gm.s.rebirths)
		"dungeon_clears":
			return float(gm.s.get("dungeon", {}).get("clears", 0))
		"arena_wins":
			return float(gm.s.get("arena", {}).get("wins", 0))
		"harvests":
			return float(gm.s.get("garden", {}).get("harvests", 0))
		"relic_levels":
			var n := 0
			for id in gm.s.get("relics", {}).get("owned", {}):
				n += int(gm.s.relics.owned[id])
			return float(n)
	return float(gm.s.stats.get(key, 0))


## Zapisuje rekordy etapu i poziomu (przed odrodzeniem, które je zeruje).
func remember() -> void:
	value("best_stage")
	value("best_level")


func claimed(key: String) -> int:
	return int(_st().claimed.get(key, 0))


static func reward(tier: int) -> int:
	return int(round(10.0 * pow(tier + 1, 1.5)))


## Wpis do wyświetlenia: {key, name, text, tier, tiers, need, prog, ready, done, gems}.
func entry(a: Array) -> Dictionary:
	var key := str(a[0])
	var tiers: Array = a[3]
	var t := claimed(key)
	var done := t >= tiers.size()
	var need := float(tiers[mini(t, tiers.size() - 1)])
	var prog := value(key)
	return {"key": key, "name": "%s %s" % [a[1], ["I", "II", "III", "IV", "V"][mini(t, 4)]], "text": str(a[2]) % IdleDB.fmt(need),
		"tier": t, "tiers": tiers.size(), "need": need, "prog": prog, "ready": not done and prog >= need, "done": done, "gems": reward(t)}


func entries() -> Array:
	return LIST.map(func(a): return entry(a))


func ready_count() -> int:
	var n := 0
	for a in LIST:
		if entry(a).ready:
			n += 1
	return n


func claim(key: String) -> bool:
	for a in LIST:
		if str(a[0]) == key:
			var e := entry(a)
			if not e.ready:
				return false
			_st().claimed[key] = int(e.tier) + 1
			gm.add_gems(int(e.gems))
			gm.audio.play("levelup")
			gm.notify("Osiągnięcie: %s  (+%d żarokryształów)" % [e.name, int(e.gems)], Color(1.0, 0.8, 0.4))
			gm.changed.emit("quests")
			return true
	return false
