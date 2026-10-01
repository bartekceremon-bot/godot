class_name FestivalManager
extends RefCounted
## Festyn Żaru: wydarzenie w dniach 1–10 każdego miesiąca. Wrogowie gubią Żarne Lampiony
## (zwykli – szansa, elity i bossowie – zawsze), które wymienia się w kramie festynu na
## ekskluzywny strój, jaja, skrzynie, odłamki i żarokryształy. Lampiony nie przepadają –
## zostają do kolejnego festynu (kram otwarty tylko w czasie festynu).
## Stan: s.festival = {lanterns, total, bought: {id: n}, month}.

const FIRST_DAY := 1
const LAST_DAY := 10
const DROP_CHANCE := 0.08
## Kram: [id, nazwa, koszt, limit na festyn (0 – bez)]
const SHOP := [
	["skin_festival", "Strój: Mistrz Festynu", 600, 1],
	["pet_egg", "Jajo chowańca", 150, 3],
	["chest_4", "Epicka skrzynia", 120, 5],
	["shards", "5 odłamków relikwii", 80, 5],
	["gems", "50 żarokryształów", 100, 5],
	["chest_5", "Legendarna skrzynia", 400, 1],
	["seal", "Pieczęć Przebudzenia", 60, 5],
]

var gm: IdleGame
## Wymuszenie stanu (testy, przegląd UI): -1 – według daty, 0 – zamknięty, 1 – otwarty.
var force := -1
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


static func month_id(t := -1.0) -> int:
	var d := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system() if t < 0.0 else t))
	return int(d.year) * 12 + int(d.month)


func _st() -> Dictionary:
	if not gm.s.has("festival"):
		gm.s["festival"] = {"lanterns": 0, "total": 0, "bought": {}, "month": 0}
	var f: Dictionary = gm.s.festival
	if active() and int(f.month) != month_id():
		f.month = month_id()
		f.bought = {}
	return f


func active(t := -1.0) -> bool:
	if force >= 0:
		return force == 1
	var d := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system() if t < 0.0 else t))
	return int(d.day) >= FIRST_DAY and int(d.day) <= LAST_DAY


## Dni do końca festynu (gdy trwa) albo do następnego (gdy nie trwa).
func days_left() -> int:
	var d := Time.get_date_dict_from_system()
	if active():
		return LAST_DAY - int(d.day) + 1
	var dim: int = [31, 29 if int(d.year) % 4 == 0 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][int(d.month) - 1]
	return dim - int(d.day) + FIRST_DAY


func lanterns() -> int:
	return int(_st().lanterns)


func on_kill(kind: int) -> int:
	if not active():
		return 0
	var n := 0
	if kind > 0:
		n = 2 + kind
	elif _rng.randf() < DROP_CHANCE:
		n = 1
	if n > 0:
		var f := _st()
		f.lanterns = lanterns() + n
		f.total = int(f.total) + n
		gm.changed.emit("festival")
	return n


func bought(id: String) -> int:
	return int(_st().bought.get(id, 0))


func can_buy(i: int) -> bool:
	if not active() or i < 0 or i >= SHOP.size():
		return false
	var it: Array = SHOP[i]
	if str(it[0]) == "skin_festival" and (gm.s.get("skins_owned", []) as Array).has("festival"):
		return false
	return lanterns() >= int(it[2]) and (int(it[3]) == 0 or bought(str(it[0])) < int(it[3]))


func buy(i: int) -> bool:
	if not can_buy(i):
		return false
	var it: Array = SHOP[i]
	var f := _st()
	f.lanterns = lanterns() - int(it[2])
	f.bought[str(it[0])] = bought(str(it[0])) + 1
	match str(it[0]):
		"skin_festival":
			gm.skins.give("festival")
		"shards":
			gm.relics.add_shards(5)
		"gems":
			gm.add_gems(50)
		"seal":
			gm.mercs.add_seals(1)
		_:
			gm.inventory.add(str(it[0]), 1)
	gm.changed.emit("festival")
	return true
