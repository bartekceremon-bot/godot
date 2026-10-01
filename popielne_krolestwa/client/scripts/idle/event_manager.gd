class_name EventManager
extends RefCounted
## Tygodnie świąteczne: co tydzień (od poniedziałku) inny modyfikator świata dla wszystkich krain.

const EVENTS := [
	{"id": "gold", "name": "Tydzień Złota", "text": "+50% złota z wrogów, skrzyń i wypraw", "gold": 0.5},
	{"id": "hunt", "name": "Tydzień Łowów", "text": "podwójne surowce i +25% szansy na łup", "materials": 1.0, "loot": 0.25},
	{"id": "runes", "name": "Tydzień Run", "text": "podwójna szansa na runy i jaja chowańców", "runes": 1.0},
	{"id": "wisdom", "name": "Tydzień Nauki", "text": "+50% doświadczenia i +25% siły czarów", "xp": 0.5, "spell": 0.25},
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func current() -> Dictionary:
	return EVENTS[(RaidManager.week_id() + 1) % EVENTS.size()]


func bonus(key: String) -> float:
	return float(current().get(key, 0.0))
