class_name AudioManager
extends RefCounted
## Dźwięki clickera (syntezowane w autoloadzie Sfx): ograniczenie częstotliwości tych samych
## dźwięków i lekka zmiana wysokości tonu, żeby szybkie klikanie nie męczyło uszu.

const MIN_GAP := {"hit": 0.05, "crit": 0.08, "coin": 0.06, "death": 0.1, "pickup": 0.08}

var gm: IdleGame
var _last: Dictionary = {}


func _init(g: IdleGame) -> void:
	gm = g


func play(name: String, pitch_var := 0.0) -> void:
	if not bool(gm.s.get("settings", {}).get("sound", true)):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap := float(MIN_GAP.get(name, 0.0))
	if gap > 0.0 and now - float(_last.get(name, -10.0)) < gap:
		return
	_last[name] = now
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var) if pitch_var > 0.0 else 1.0
	Sfx.play_ex(name, pitch)
