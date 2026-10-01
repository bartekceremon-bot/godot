class_name WheelManager
extends RefCounted
## Koło Żaru: jeden darmowy obrót dziennie, drugi za reklamę z nagrodą, do 5 kolejnych
## za żarokryształy. 8 pól z jawnie podanymi szansami (wymóg Google Play dla nagród losowych).
## Stan: s.wheel = {day, free, paid, spins}.

const GEM_COST := 25
const PAID_LIMIT := 5
## [id, nazwa, waga (suma 100), kolor pola]
const SEGMENTS := [
	["gold", "Sakwa złota", 24, Color(0.85, 0.62, 0.18)],
	["gems10", "10 żarokryształów", 20, Color(0.75, 0.25, 0.2)],
	["chest", "Niezwykła skrzynia", 14, Color(0.3, 0.55, 0.3)],
	["gold_big", "Skarbiec złota", 12, Color(0.95, 0.78, 0.25)],
	["rune", "Losowa runa", 10, Color(0.45, 0.35, 0.75)],
	["shards", "3 odłamki relikwii", 10, Color(0.6, 0.35, 0.85)],
	["gems50", "50 żarokryształów", 7, Color(0.9, 0.35, 0.15)],
	["jackpot", "WIELKA WYGRANA: 200 żarokr. + jajo", 3, Color(1.0, 0.85, 0.4)],
]

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("wheel"):
		gm.s["wheel"] = {"day": "", "free": 1, "paid": 0, "spins": 0}
	var w: Dictionary = gm.s.wheel
	if str(w.day) != DailyManager.today():
		w.day = DailyManager.today()
		w.free = 1
		w.paid = 0
	return w


func free_spins() -> int:
	return int(_st().free)


func paid_today() -> int:
	return int(_st().paid)


## Darmowy obrót za reklamę (miejsce „wheel_spin” w PremiumManager).
func add_free_spin() -> void:
	_st().free = free_spins() + 1
	gm.changed.emit("wheel")


func odds() -> Array:
	var out: Array = []
	for s in SEGMENTS:
		out.append([str(s[1]), "%d%%" % int(s[2])])
	return out


func can_spin(use_gems := false) -> bool:
	if free_spins() > 0:
		return true
	return use_gems and paid_today() < PAID_LIMIT and int(gm.s.gems) >= GEM_COST


## Losuje pole i przyznaje nagrodę. Zwraca [indeks pola, opis nagrody] albo [].
func spin(use_gems := false) -> Array:
	if not can_spin(use_gems):
		return []
	var st := _st()
	if free_spins() > 0:
		st.free = free_spins() - 1
	else:
		gm.spend_gems(GEM_COST)
		st.paid = paid_today() + 1
	st.spins = int(st.spins) + 1
	gm.quests.on_event("wheel", 1)
	var roll := _rng.randi_range(1, 100)
	var idx := 0
	var acc := 0
	for i in SEGMENTS.size():
		acc += int(SEGMENTS[i][2])
		if roll <= acc:
			idx = i
			break
	var txt := _grant(str(SEGMENTS[idx][0]))
	gm.season.add_xp(5)
	gm.save.save_game()
	gm.changed.emit("wheel")
	return [idx, txt]


## Złoto z koła: tyle, ile ok. 60 / 300 zwykłych wrogów na najdalszym etapie.
func gold_prize(big: bool) -> float:
	return ProgressionManager.gold_for(int(gm.s.max_stage)) * (300.0 if big else 60.0) * gm.stats.gold_mult


func _grant(id: String) -> String:
	match id:
		"gold", "gold_big":
			var g := gold_prize(id == "gold_big")
			gm.add_gold(g)
			return "+%s złota" % IdleDB.fmt(g)
		"gems10":
			gm.add_gems(10)
			return "+10 żarokryształów"
		"gems50":
			gm.add_gems(50)
			return "+50 żarokryształów"
		"chest":
			gm.inventory.add("chest_2", 1)
			return LootManager.CHEST_NAMES[2]
		"rune":
			var rn := gm.runes.random_rune(0.5)
			gm.inventory.add(rn, 1)
			return RuneManager.rune_name(rn)
		"shards":
			gm.relics.add_shards(3)
			return "+3 odłamki relikwii"
		"jackpot":
			gm.add_gems(200)
			gm.inventory.add("pet_egg", 1)
			return "WIELKA WYGRANA! +200 żarokryształów i jajo chowańca"
	return ""
