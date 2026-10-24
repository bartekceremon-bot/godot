extends Node
## Ustawienia gracza (dźwięk, grafika, animacje, sterowanie) i mapa wejścia.

signal changed

const PATH := "user://settings.json"

var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.8
var quality := "high"            # "high" | "low"
var reduced_motion := false
var screen_shake := true
var text_scale := 1.0            # 1.0 | 1.15 | 1.3
var touch_mode := "auto"         # "auto" | "on" | "off"
var show_hints := true

## Ustawiane w trakcie gry: czy ostatnio używany był dotyk.
var touch_active := false


func _ready() -> void:
	_setup_input()
	load_settings()
	if touch_mode == "on":
		touch_active = true


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_J],
		"skill1": [KEY_Q, KEY_1],
		"skill2": [KEY_R, KEY_2],
		"dodge": [KEY_SPACE, KEY_SHIFT],
		"interact": [KEY_E, KEY_ENTER, KEY_F],
		"pause": [KEY_ESCAPE, KEY_TAB],
		"map": [KEY_M],
		"journal": [KEY_L],
		"potion": [KEY_H],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Przyciski myszy obsługuje gracz w _unhandled_input (z pominięciem
	# zdarzeń emulowanych z dotyku i kliknięć w interfejs).
	# Pad (bonus, nieobowiązkowy).
	var pad := {
		"attack": JOY_BUTTON_X, "skill1": JOY_BUTTON_Y, "skill2": JOY_BUTTON_B,
		"dodge": JOY_BUTTON_RIGHT_SHOULDER, "interact": JOY_BUTTON_A, "pause": JOY_BUTTON_START,
	}
	for action in pad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


func release_all_actions() -> void:
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			Input.action_release(action)


func to_dict() -> Dictionary:
	return {
		"master_volume": master_volume, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"quality": quality, "reduced_motion": reduced_motion, "screen_shake": screen_shake,
		"text_scale": text_scale, "touch_mode": touch_mode, "show_hints": show_hints,
	}


func from_dict(d: Dictionary) -> void:
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	var q := str(d.get("quality", quality))
	quality = q if q in ["high", "low"] else "high"
	reduced_motion = bool(d.get("reduced_motion", reduced_motion))
	screen_shake = bool(d.get("screen_shake", screen_shake))
	var ts := float(d.get("text_scale", text_scale))
	text_scale = ts if ts in [1.0, 1.15, 1.3] else 1.0
	var tm := str(d.get("touch_mode", touch_mode))
	touch_mode = tm if tm in ["auto", "on", "off"] else "auto"
	show_hints = bool(d.get("show_hints", show_hints))


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		from_dict(parsed)


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))
		f.close()
	changed.emit()


func set_value(key: String, value: Variant) -> void:
	var d := to_dict()
	d[key] = value
	from_dict(d)
	if key == "touch_mode":
		touch_active = touch_mode == "on" or (touch_mode == "auto" and touch_active)
		if touch_mode == "off":
			touch_active = false
	save_settings()


func low_quality() -> bool:
	return quality == "low"


func show_touch() -> bool:
	if touch_mode == "on":
		return true
	if touch_mode == "off":
		return false
	return touch_active
