class_name WinterManager
extends RefCounted
## Gwiazdka Mrozu: coroczne wydarzenie zimowe (20 grudnia – 6 stycznia). Wrogowie gubią
## Płatki Szronu (elity i bossowie zawsze), wymieniane w Zimowym Kramie na strój Strażnika
## Zimy, jaja, skrzynie, przysmaki dla smoka i żarokryształy. Raz na wydarzenie – nagroda
## za 300 płatków. Płatki zostają do kolejnej Gwiazdki.
## Stan: s.winter = {flames, total, bought: {id: n}, year, milestone}.

const START := [12, 20]
const END := [1, 6]
const DROP_CHANCE := 0.1
const MILESTONE := 300
## [id, nazwa, koszt, limit na wydarzenie]
const SHOP := [
	["skin_winter", "Strój: Strażnik Zimy", 500, 1],
	["pet_egg", "Jajo chowańca", 120, 3],
	["chest_4", "Epicka skrzynia", 100, 5],
	["dragon_treat", "Mroźny przysmak (+300 PD smoka)", 60, 5],
	["elixir", "Smoczy Eliksir", 70, 3],
	["gems", "50 żarokryształów", 80, 5],
	["seal", "Pieczęć Przebudzenia", 60, 5],
]

var gm: IdleGame
## Wymuszenie stanu (testy, przegląd UI): -1 – według daty, 0 – zamknięte, 1 – trwa.
var force := -1
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


static func _date(t := -1.0) -> Dictionary:
	return Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system() if t < 0.0 else t))


func active(t := -1.0) -> bool:
	if force >= 0:
		return force == 1
	var d := _date(t)
	var m := int(d.month)
	var day := int(d.day)
	return (m == START[0] and day >= START[1]) or (m == END[0] and day <= END[1])


## Rok wydarzenia (styczniowa część liczy się do roku startu w grudniu).
static func event_year(t := -1.0) -> int:
	var d := _date(t)
	return int(d.year) - (1 if int(d.month) == END[0] else 0)


func _st() -> Dictionary:
	if not gm.s.has("winter"):
		gm.s["winter"] = {"flames": 0, "total": 0, "bought": {}, "year": 0, "milestone": false}
	var s: Dictionary = gm.s.winter
	if active() and int(s.year) != event_year():
		s.year = event_year()
		s.bought = {}
		s.milestone = false
	return s


## Dni do końca (gdy trwa) albo do początku następnej Gwiazdki Mrozu.
func days_left() -> int:
	var now := Time.get_unix_time_from_system()
	var d := _date()
	var y := int(d.year)
	if active():
		var end := Time.get_unix_time_from_datetime_dict({"year": y + (1 if int(d.month) == START[0] else 0), "month": END[0], "day": END[1], "hour": 23, "minute": 59, "second": 59})
		return maxi(1, int(ceil((end - now) / 86400.0)))
	var start := Time.get_unix_time_from_datetime_dict({"year": y, "month": START[0], "day": START[1], "hour": 0, "minute": 0, "second": 0})
	if start < now:
		start = Time.get_unix_time_from_datetime_dict({"year": y + 1, "month": START[0], "day": START[1], "hour": 0, "minute": 0, "second": 0})
	return maxi(1, int(ceil((start - now) / 86400.0)))


func flames() -> int:
	return int(_st().flames)


func total() -> int:
	return int(_st().total)


func on_kill(kind: int) -> int:
	if not active():
		return 0
	var n := 0
	if kind > 0:
		n = 2 + kind
	elif _rng.randf() < DROP_CHANCE:
		n = 1
	if n > 0:
		var s := _st()
		s.flames = flames() + n
		s.total = total() + n
		gm.changed.emit("winter")
	return n


func milestone_ready() -> bool:
	return active() and not bool(_st().milestone) and total() >= MILESTONE


## Nagroda za 300 płatków (raz na Gwiazdkę Mrozu): 100 żarokryształów i jajo chowańca.
func claim_milestone() -> bool:
	if not milestone_ready():
		return false
	_st().milestone = true
	gm.add_gems(100)
	gm.inventory.add("pet_egg", 1)
	gm.changed.emit("winter")
	return true


func bought(id: String) -> int:
	return int(_st().bought.get(id, 0))


func can_buy(i: int) -> bool:
	if not active() or i < 0 or i >= SHOP.size():
		return false
	var it: Array = SHOP[i]
	var id := str(it[0])
	if id == "skin_winter" and (gm.s.get("skins_owned", []) as Array).has("winter"):
		return false
	if id == "dragon_treat" and not gm.dragon.alive():
		return false
	return flames() >= int(it[2]) and (int(it[3]) == 0 or bought(id) < int(it[3]))


func buy(i: int) -> bool:
	if not can_buy(i):
		return false
	var it: Array = SHOP[i]
	var s := _st()
	s.flames = flames() - int(it[2])
	s.bought[str(it[0])] = bought(str(it[0])) + 1
	match str(it[0]):
		"skin_winter":
			gm.skins.give("winter")
		"dragon_treat":
			gm.dragon.add_xp(300)
		"elixir":
			gm.garden._st().elixirs["dragon"] = gm.garden.elixirs("dragon") + 1
		"gems":
			gm.add_gems(50)
		"seal":
			gm.mercs.add_seals(1)
		_:
			gm.inventory.add(str(it[0]), 1)
	gm.changed.emit("winter")
	return true
