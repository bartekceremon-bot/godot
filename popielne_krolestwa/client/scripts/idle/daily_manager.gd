class_name DailyManager
extends RefCounted
## Codzienna nagroda: seria 7 dni (dzień 7 – epicka skrzynia i żarokryształy), potem od nowa.
## Opuszczony dzień zeruje serię. Stan w s.daily = {day: odebrane w serii, last: "RRRR-MM-DD"}.

const REWARDS := [
	{"gold_kills": 40},
	{"items": [["hp_potion", 5], ["mp_potion", 3]]},
	{"gems": 20},
	{"items": [["chest_2", 1]]},
	{"gems": 40, "gold_kills": 80},
	{"items": [["chest_3", 1]]},
	{"items": [["chest_4", 1]], "gems": 100},
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("daily"):
		gm.s["daily"] = {"day": 0, "last": ""}
	return gm.s.daily


static func today() -> String:
	return Time.get_date_string_from_system()


static func _days(a: String, b: String) -> int:
	var ta := Time.get_unix_time_from_datetime_string(a + "T12:00:00")
	var tb := Time.get_unix_time_from_datetime_string(b + "T12:00:00")
	return roundi((tb - ta) / 86400.0)


func available(date := "") -> bool:
	return str(_st().last) != (date if date != "" else today())


## Który dzień serii (0–6) zostanie odebrany dziś.
func current_day(date := "") -> int:
	var st := _st()
	if str(st.last) == "":
		return 0
	var d := date if date != "" else today()
	if str(st.last) == d:
		return (int(st.day) - 1) % 7
	return 0 if _days(str(st.last), d) > 1 else int(st.day) % 7


## Złoto nagrody: równowartość N zwykłych wrogów na najdalszym etapie.
func gold_of(r: Dictionary) -> float:
	return ProgressionManager.gold_for(int(gm.s.max_stage)) * float(r.get("gold_kills", 0)) * gm.stats.gold_mult


## Odbiera nagrodę dnia; zwraca łup [[id, ilość, rzadkość], ...] (pusty – już odebrano).
func claim(date := "") -> Array:
	if not available(date):
		return []
	var d := date if date != "" else today()
	var day := current_day(d)
	var r: Dictionary = REWARDS[day]
	var got: Array = []
	var gold := gold_of(r)
	if gold > 0.0:
		gm.add_gold(gold)
		got.append(["gold", gold, 0])
	if r.has("gems"):
		gm.add_gems(int(r.gems))
		got.append(["gems", int(r.gems), 0])
	for it in r.get("items", []):
		gm.inventory.add(str(it[0]), int(it[1]))
		got.append([str(it[0]), int(it[1]), int(str(it[0]).substr(6)) if str(it[0]).begins_with("chest_") else 0])
	var st := _st()
	st.day = day + 1
	st.last = d
	gm.save.save_game()
	gm.changed.emit("inventory")
	return got
