class_name GardenManager
extends RefCounted
## Ogród Alchemika (od etapu 20): grządki z ziołami rosnącymi w czasie rzeczywistym (także
## przy zamkniętej grze). Zebrane zioła warzy się w kotle na eliksiry dające czasowe premie
## (wzmocnienia jak z rzemiosła). Poziom zielarstwa skraca wzrost i zwiększa plony.
## Raz dziennie „Nawóz Żaru” za reklamę – wszystkie rosnące zioła od razu gotowe.
## Stan: s.garden = {plots: [{herb, ready, watered}], herbs: {}, elixirs: {}, xp, lvl, harvests, brews}.

const UNLOCK_STAGE := 20
## Etap odblokowania kolejnych grządek.
const PLOT_STAGES := [20, 20, 20, 35, 50, 70]
const MAX_LVL := 20
const WATER_CUT := 0.3
## [nazwa, czas wzrostu (s), etap odblokowania, koszt (× złoto za wroga), kolor]
const HERBS := {
	"ember_root": ["Korzeń Żaru", 600, 20, 20.0, Color(1.0, 0.5, 0.25)],
	"moon_sage": ["Księżycowa Szałwia", 1800, 25, 50.0, Color(0.6, 0.7, 1.0)],
	"goldbloom": ["Złotokwiat", 3600, 30, 100.0, Color(1.0, 0.85, 0.3)],
	"frost_lily": ["Lilia Mrozu", 7200, 40, 180.0, Color(0.6, 0.95, 1.0)],
	"dragon_pepper": ["Smocza Papryczka", 14400, 55, 300.0, Color(0.95, 0.25, 0.2)],
}
const HERB_ORDER := ["ember_root", "moon_sage", "goldbloom", "frost_lily", "dragon_pepper"]
## [nazwa, składniki, efekty [[premia, siła]], czas (s), opis]
const RECIPES := {
	"might": ["Napar Siły", {"ember_root": 3}, [["damage", 0.5]], 900, "+50% obrażeń na 15 min"],
	"wisdom": ["Eliksir Mądrości", {"ember_root": 2, "moon_sage": 2}, [["xp", 0.5]], 900, "+50% doświadczenia na 15 min"],
	"wealth": ["Napar Złota", {"ember_root": 2, "goldbloom": 2}, [["gold", 0.5]], 900, "+50% złota na 15 min"],
	"strike": ["Mikstura Ciosu", {"moon_sage": 2, "frost_lily": 2}, [["click", 1.0]], 900, "+100% obrażeń kliknięcia na 15 min"],
	"dragon": ["Smoczy Eliksir", {"dragon_pepper": 2, "goldbloom": 1, "frost_lily": 1}, [["damage", 1.0], ["gold", 1.0]], 1800, "+100% obrażeń i złota na 30 min"],
}
const RECIPE_ORDER := ["might", "wisdom", "wealth", "strike", "dragon"]

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("garden"):
		gm.s["garden"] = {"plots": [], "herbs": {}, "elixirs": {}, "xp": 0, "lvl": 1, "harvests": 0, "brews": 0}
	var g: Dictionary = gm.s.garden
	while (g.plots as Array).size() < PLOT_STAGES.size():
		g.plots.append({"herb": "", "ready": 0.0, "watered": false})
	return g


static func now() -> float:
	return Time.get_unix_time_from_system()


func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= UNLOCK_STAGE


func best_stage() -> int:
	return int(gm.achievements.value("best_stage"))


func plot_unlocked(i: int) -> bool:
	return i >= 0 and i < PLOT_STAGES.size() and best_stage() >= int(PLOT_STAGES[i])


func plot_count() -> int:
	var n := 0
	for i in PLOT_STAGES.size():
		if plot_unlocked(i):
			n += 1
	return n


func herb_unlocked(h: String) -> bool:
	return HERBS.has(h) and best_stage() >= int(HERBS[h][2])


static func herb_name(h: String) -> String:
	return str(HERBS[h][0]) if HERBS.has(h) else h


func level() -> int:
	return int(_st().lvl)


func xp() -> int:
	return int(_st().xp)


func xp_need() -> int:
	return 10 * level()


func herbs(h: String) -> int:
	return int(_st().herbs.get(h, 0))


func elixirs(e: String) -> int:
	return int(_st().elixirs.get(e, 0))


func harvests() -> int:
	return int(_st().harvests)


## Czas wzrostu z premią zielarstwa (−2% za poziom).
func grow_time(h: String) -> float:
	return float(HERBS[h][1]) * (1.0 - 0.02 * (level() - 1))


func herb_cost(h: String) -> float:
	return ProgressionManager.gold_for(maxi(1, int(gm.s.max_stage))) * float(HERBS[h][3])


## Plon: 3 + 1 za każde 5 poziomów zielarstwa.
func base_yield() -> int:
	return 3 + int(level() / 5)


func plot(i: int) -> Dictionary:
	return _st().plots[i]


## "locked", "empty", "growing" albo "ready".
func state(i: int) -> String:
	if not plot_unlocked(i):
		return "locked"
	var p := plot(i)
	if str(p.herb) == "":
		return "empty"
	return "ready" if now() >= float(p.ready) else "growing"


func time_left(i: int) -> float:
	return maxf(0.0, float(plot(i).ready) - now())


func progress(i: int) -> float:
	var p := plot(i)
	if str(p.herb) == "":
		return 0.0
	return clampf(1.0 - time_left(i) / maxf(1.0, grow_time(str(p.herb))), 0.0, 1.0)


func ready_count() -> int:
	if not unlocked():
		return 0
	var n := 0
	for i in PLOT_STAGES.size():
		if state(i) == "ready":
			n += 1
	return n


func empty_count() -> int:
	var n := 0
	for i in PLOT_STAGES.size():
		if state(i) == "empty":
			n += 1
	return n


func can_plant(i: int, h: String) -> bool:
	return unlocked() and state(i) == "empty" and herb_unlocked(h) and float(gm.s.gold) >= herb_cost(h)


func plant(i: int, h: String) -> bool:
	if not can_plant(i, h):
		return false
	gm.spend_gold(herb_cost(h))
	var p := plot(i)
	p.herb = h
	p.ready = now() + grow_time(h)
	p.watered = false
	gm.changed.emit("garden")
	return true


## Sadzi to samo zioło na wszystkich pustych grządkach (na ile starczy złota). Zwraca liczbę.
func plant_all(h: String) -> int:
	var n := 0
	for i in PLOT_STAGES.size():
		if plant(i, h):
			n += 1
	return n


func can_water(i: int) -> bool:
	return state(i) == "growing" and not bool(plot(i).watered)


## Podlewanie: −30% pozostałego czasu (raz na zasiew).
func water(i: int) -> bool:
	if not can_water(i):
		return false
	var p := plot(i)
	p.watered = true
	p.ready = float(p.ready) - time_left(i) * WATER_CUT
	gm.changed.emit("garden")
	return true


func water_all() -> int:
	var n := 0
	for i in PLOT_STAGES.size():
		if water(i):
			n += 1
	return n


## Zbiór: [zioło, ilość, obfity?] albo [].
func harvest(i: int) -> Array:
	if state(i) != "ready":
		return []
	var st := _st()
	var p := plot(i)
	var h := str(p.herb)
	var n := base_yield()
	var rich := _rng.randf() < 0.15
	if rich:
		n *= 2
	st.herbs[h] = herbs(h) + n
	st.harvests = harvests() + 1
	p.herb = ""
	p.ready = 0.0
	p.watered = false
	_add_xp(maxi(1, int(float(HERBS[h][1]) / 600.0)))
	gm.quests.on_event("harvest", 1)
	gm.season.add_xp(2)
	gm.changed.emit("garden")
	return [h, n, rich]


## Zbiera wszystkie gotowe grządki. Zwraca {zioło: ilość}.
func harvest_all() -> Dictionary:
	var got := {}
	for i in PLOT_STAGES.size():
		var r := harvest(i)
		if not r.is_empty():
			got[r[0]] = int(got.get(r[0], 0)) + int(r[1])
	if not got.is_empty():
		gm.audio.play("coin")
	return got


func _add_xp(n: int) -> void:
	var st := _st()
	st.xp = xp() + n
	while level() < MAX_LVL and xp() >= xp_need():
		st.xp = xp() - xp_need()
		st.lvl = level() + 1
		gm.toast.emit("Zielarstwo: poziom %d!" % level(), Color(0.55, 0.95, 0.45))
	if level() >= MAX_LVL:
		st.xp = 0


## Nawóz Żaru (reklama, raz dziennie): wszystkie rosnące zioła od razu gotowe.
func grow_all() -> int:
	var n := 0
	for i in PLOT_STAGES.size():
		if state(i) == "growing":
			plot(i).ready = now()
			n += 1
	gm.changed.emit("garden")
	return n


func growing_count() -> int:
	var n := 0
	for i in PLOT_STAGES.size():
		if state(i) == "growing":
			n += 1
	return n


func can_brew(r: String) -> bool:
	if not RECIPES.has(r) or not unlocked():
		return false
	var need: Dictionary = RECIPES[r][1]
	for h in need:
		if herbs(h) < int(need[h]):
			return false
	return true


func brew(r: String) -> bool:
	if not can_brew(r):
		return false
	var st := _st()
	var need: Dictionary = RECIPES[r][1]
	for h in need:
		st.herbs[h] = herbs(h) - int(need[h])
	st.elixirs[r] = elixirs(r) + 1
	st.brews = int(st.brews) + 1
	gm.quests.on_event("brew", 1)
	gm.audio.play("levelup")
	gm.changed.emit("garden")
	return true


## Wypicie eliksiru: wzmocnienia z RECIPES (sumują się czasem jak mikstury z rzemiosła).
func drink(r: String) -> bool:
	if elixirs(r) <= 0:
		return false
	var st := _st()
	st.elixirs[r] = elixirs(r) - 1
	for ef in RECIPES[r][2]:
		gm.crafting.add_boost(str(ef[0]), float(ef[1]), float(RECIPES[r][3]))
	gm.audio.play("rare")
	gm.changed.emit("garden")
	return true


func total_elixirs() -> int:
	var n := 0
	for r in RECIPE_ORDER:
		n += elixirs(r)
	return n
