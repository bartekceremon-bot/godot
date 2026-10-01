class_name PathManager
extends RefCounted
## Ścieżka Popielnika: 20 celów prowadzących nowego gracza przez wszystkie systemy gry
## (pierwsze ciosy, najemnicy, czary, rzemiosło, lochy, arena, odrodzenie). Zawsze jeden
## aktywny cel – widoczny na ekranie walki, z nagrodą i wskazówką, gdzie go wykonać.
## Stan: s.path = {i, counters: {upgrades, crafts}, done}.

## [tekst, rodzaj, cel, nagroda {gems|chest|potions|shards|egg}, zakładka, element do wskazania]
const GOALS := [
	["Zadaj 15 ciosów przyciskiem ATAK!", "taps", 15, {"gems": 10}, "fight", "attack"],
	["Wynajmij pierwszego najemnika w Drużynie", "merc_levels", 1, {"gems": 10}, "heroes", "party"],
	["Podnieś trening ciosu do poziomu 3", "train", 3, {"chest": 1}, "heroes", "party"],
	["Dotrzyj do etapu 5", "stage", 5, {"gems": 15}, "fight", "attack"],
	["Pokonaj elitę na etapie 5", "stage", 6, {"potions": 3}, "fight", "attack"],
	["Rzuć czar (przycisk czaru na ekranie walki)", "spells", 1, {"gems": 15}, "fight", "spell"],
	["Ulepsz przedmiot w Inwentarzu", "upgrades", 1, {"chest": 2}, "gear", "gear"],
	["Wynajmij 3 różnych najemników", "merc_count", 3, {"gems": 20}, "heroes", "party"],
	["Pokonaj bossa regionu (etap 10)", "stage", 11, {"chest": 2}, "fight", "attack"],
	["Wytwórz przedmiot w Tworzeniu", "crafts", 1, {"gems": 20}, "craft", "craft"],
	["Odbierz codzienną nagrodę (Menu)", "daily", 1, {"gems": 10}, "daily", "menu"],
	["Ukończ zlecenie (Zadania)", "tasks", 1, {"gems": 20}, "quests", "quests"],
	["Dotrzyj do etapu 15", "stage", 15, {"chest": 2}, "fight", "attack"],
	["Oczyść loch w Lochach Żaru (Menu)", "dungeon", 1, {"shards": 5}, "dungeon", "menu"],
	["Odkryj relikwię w Relikwiarzu (Menu)", "relics", 1, {"gems": 25}, "relics", "menu"],
	["Wyślij wyprawę (Menu → Wyprawy)", "exped", 1, {"gems": 20}, "expeditions", "menu"],
	["Dotrzyj do etapu 25", "stage", 25, {"chest": 3}, "fight", "attack"],
	["Wygraj pojedynek na Arenie (Menu)", "arena", 1, {"gems": 30}, "arena", "menu"],
	["Wejdź na 3. piętro Wieży Popiołu (Menu)", "tower", 3, {"chest": 3}, "tower", "menu"],
	["Odródź się na Ołtarzu Popiołu", "rebirths", 1, {"gems": 100, "egg": 1}, "prestige", "menu"],
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("path"):
		# Starsze zapisy z dużym postępem: ścieżka uznana za przebytą (bez zalewu nagród).
		var veteran := int(gm.s.get("max_stage", 1)) > 30 or int(gm.s.get("rebirths", 0)) > 0
		var ms := int(gm.s.get("max_stage", 1))
		var seen: Array = [15, 20, 25, 30, 40, -1].filter(func(x): return x > 0 and ms >= x) if not veteran else [15, 20, 25, 30, 40, -1]
		gm.s["path"] = {"i": GOALS.size() if veteran else 0, "counters": {}, "done": veteran, "seen": seen}
	return gm.s.path


func index() -> int:
	return int(_st().i)


func finished() -> bool:
	return index() >= GOALS.size()


func current() -> Array:
	return [] if finished() else GOALS[index()]


## Zdarzenia z gry (przez QuestManager.on_event) – liczniki, których nie ma w stanie gry.
func on_event(type: String, amount: float) -> void:
	if type in ["upgrades", "crafts"]:
		var c: Dictionary = _st().counters
		c[type] = float(c.get(type, 0.0)) + amount


func value(type: String) -> float:
	var s := gm.s
	match type:
		"taps":
			return float(s.stats.taps)
		"merc_levels":
			var n := 0
			for id in s.mercs:
				n += int(s.mercs[id])
			return n
		"merc_count":
			var n := 0
			for id in s.mercs:
				if int(s.mercs[id]) > 0:
					n += 1
			return n
		"train":
			return float(s.train_lvl)
		"stage":
			return float(s.max_stage)
		"spells":
			return float(s.stats.spells)
		"upgrades", "crafts":
			return float(_st().counters.get(type, 0.0))
		"daily":
			return float(s.daily.day)
		"tasks":
			return float(s.quests.get("tasks_done", 0))
		"dungeon":
			return float(s.get("dungeon", {}).get("clears", 0))
		"relics":
			return float(gm.relics.owned_count())
		"exped":
			return float(s.exped.done) + gm.expeditions.active().size()
		"arena":
			return float(s.get("arena", {}).get("wins", 0))
		"tower":
			return float(gm.tower.best())
		"rebirths":
			return float(s.rebirths)
	return 0.0


func progress() -> float:
	var g := current()
	return 0.0 if g.is_empty() else minf(value(str(g[1])), float(g[2]))


func ready() -> bool:
	var g := current()
	return not g.is_empty() and value(str(g[1])) >= float(g[2])


## Odbiera nagrodę bieżącego celu i przechodzi do następnego. Zwraca łup [[id, ilość], ...].
func claim() -> Array:
	if not ready():
		return []
	var r: Dictionary = current()[3]
	var got: Array = []
	if r.has("gems"):
		gm.add_gems(int(r.gems))
		got.append(["gems", int(r.gems)])
	if r.has("chest"):
		gm.inventory.add("chest_%d" % int(r.chest), 1)
		got.append(["chest_%d" % int(r.chest), 1])
	if r.has("potions"):
		gm.inventory.add("hp_potion", int(r.potions))
		got.append(["hp_potion", int(r.potions)])
	if r.has("shards"):
		gm.relics.add_shards(int(r.shards))
		got.append(["shards", int(r.shards)])
	if r.has("egg"):
		gm.inventory.add("pet_egg", int(r.egg))
		got.append(["pet_egg", int(r.egg)])
	var st := _st()
	st.i = index() + 1
	if finished():
		st.done = true
	gm.changed.emit("path")
	return got


## Zapowiedzi nowych trybów przy pierwszym dotarciu do etapu: [etap, nazwa, opis].
const UNLOCKS := [
	[15, "Lochy Żaru", "Menu → Lochy Żaru: złoto, żarokryształy i surowce co dzień."],
	[20, "Ogród Alchemika", "Menu → Ogród Alchemika: sadź zioła i warz eliksiry wzmacniające."],
	[25, "Arena Popiołu", "Menu → Arena: pojedynki o ranking i odznaki chwały."],
	[40, "Sen Popielnika", "Menu → Sen Popielnika: piętra snu i błogosławieństwa – tryb roguelike."],
	[30, "Klasa bohatera", "Menu → Klasa bohatera: Wojownik, Łowca albo Mag i umiejętność ostateczna."],
]

func check_unlocks() -> void:
	var st := _st()
	var seen: Array = st.get("seen", [])
	for u in UNLOCKS:
		if int(gm.s.max_stage) >= int(u[0]) and not seen.has(int(u[0])):
			seen.append(int(u[0]))
			gm.unlocked.emit(str(u[1]), str(u[2]))
	if int(gm.s.max_stage) >= gm.prestige.min_stage() and not seen.has(-1):
		seen.append(-1)
		gm.unlocked.emit("Ołtarz Popiołu", "Możesz się odrodzić – Popiół Dusz da stałe premie na zawsze.")
	st.seen = seen


static func reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("gems"):
		parts.append("%d żarokr." % int(r.gems))
	if r.has("chest"):
		parts.append(LootManager.CHEST_NAMES[int(r.chest)])
	if r.has("potions"):
		parts.append("%d× mikstura życia" % int(r.potions))
	if r.has("shards"):
		parts.append("%d odłamków relikwii" % int(r.shards))
	if r.has("egg"):
		parts.append("jajo chowańca")
	return ", ".join(PackedStringArray(parts))
