extends Node
## Stan przygody: klasa, poziom, ekwipunek, zadania, flagi świata, zapis.

signal xp_changed
signal leveled_up(level: int)
signal inventory_changed
signal flag_changed(flag: String)
signal mission_completed(mission_id: String)
signal stats_changed
signal notify(text: String, kind: String)

const SAVE_VERSION := 1
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak.json"
const MAX_LEVEL := 5
const XP_FOR_LEVEL := [0, 0, 80, 220, 420, 700]   # indeks = poziom
const EXPORT_PREFIX := "AIBLIZEJ-ISKRA-1:"

var data: Dictionary = {}
var hp := 100.0
var energy := 100.0
## Komunikat dla ekranu tytułowego (np. o uszkodzonym zapisie).
var load_message := ""
var persistent_storage := true
## Zablokowane podczas automatycznych testów, żeby nie nadpisać zapisu gracza.
var saving_enabled := true
## Ścieżki zapisu — testy podmieniają je, żeby nie dotykać prawdziwego zapisu gracza.
var save_path := SAVE_PATH
var backup_path := BACKUP_PATH


func _ready() -> void:
	persistent_storage = OS.is_userfs_persistent()
	data = default_data("tkacz")


func default_data(class_id: String) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"class_id": class_id,
		"level": 1,
		"xp": 0,
		"inventory": {"eliksir": 2},
		"missions_done": [],
		"flags": {},
		"areas_unlocked": ["latarnia"],
		"areas_visited": [],
		"chests": [],
		"secrets": [],
		"defeated_once": [],
		"checkpoint": {"area": "latarnia", "spawn": "start"},
		"area": "latarnia",
		"play_time": 0.0,
		"deaths": 0,
		"game_complete": false,
	}


func new_game(class_id: String) -> void:
	data = default_data(class_id)
	refill()
	save_game()


# --- Statystyki -------------------------------------------------------------

func class_id() -> String:
	return data.get("class_id", "tkacz")


func class_def() -> Dictionary:
	return Data.get_class_def(class_id())


func level() -> int:
	return int(data.get("level", 1))


func max_hp() -> float:
	return 100.0 + 18.0 * (level() - 1)


func max_energy() -> float:
	return 100.0 + 10.0 * (level() - 1)


func damage_mult() -> float:
	return 1.0 + 0.14 * (level() - 1)


func xp_to_next() -> int:
	if level() >= MAX_LEVEL:
		return 0
	return XP_FOR_LEVEL[level() + 1]


func refill() -> void:
	hp = max_hp()
	energy = max_energy()
	stats_changed.emit()


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	data["xp"] = int(data["xp"]) + amount
	while level() < MAX_LEVEL and int(data["xp"]) >= XP_FOR_LEVEL[level() + 1]:
		data["level"] = level() + 1
		hp = max_hp()
		energy = max_energy()
		leveled_up.emit(level())
	xp_changed.emit()
	stats_changed.emit()


func set_class(new_class: String) -> void:
	if Data.classes.has(new_class):
		data["class_id"] = new_class
		refill()
		save_game()


# --- Flagi, zadania, ekwipunek ---------------------------------------------

func has_flag(flag: String) -> bool:
	if flag.is_empty():
		return true
	return bool(data["flags"].get(flag, false))


func set_flag(flag: String, value := true) -> void:
	if flag.is_empty() or has_flag(flag) == value:
		return
	data["flags"][flag] = value
	flag_changed.emit(flag)


func flags_met(req: Variant) -> bool:
	## Akceptuje "flaga", "!flaga" lub tablicę takich wpisów.
	if req == null:
		return true
	if typeof(req) == TYPE_STRING:
		var s: String = req
		if s.is_empty():
			return true
		if s.begins_with("!"):
			return not has_flag(s.substr(1))
		return has_flag(s)
	if typeof(req) == TYPE_ARRAY:
		for r in req:
			if not flags_met(r):
				return false
	return true


func is_mission_done(id: String) -> bool:
	return id in data["missions_done"]


func complete_mission(id: String) -> void:
	if is_mission_done(id):
		return
	var m := Data.get_mission(id)
	data["missions_done"].append(id)
	var reward: Dictionary = m.get("reward", {})
	for item in reward.get("items", {}):
		add_item(item, int(reward["items"][item]))
	set_flag(m.get("world_flag", ""))
	for f in m.get("extra_flags", []):
		set_flag(f)
	add_xp(int(reward.get("xp", 25)))
	mission_completed.emit(id)
	save_game()


func item_count(id: String) -> int:
	return int(data["inventory"].get(id, 0))


func add_item(id: String, count := 1) -> void:
	if count == 0:
		return
	var n := item_count(id) + count
	if n <= 0:
		data["inventory"].erase(id)
	else:
		data["inventory"][id] = n
	if count > 0:
		var item := Data.get_item(id)
		notify.emit("Zdobyto: %s%s" % [item.get("name", id), (" ×%d" % count) if count > 1 else ""],
			"key" if item.get("key", false) else "item")
		if item.get("flag", "") != "":
			set_flag(item["flag"])
	inventory_changed.emit()


func use_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	var item := Data.get_item(id)
	match item.get("use", ""):
		"heal":
			if hp >= max_hp():
				notify.emit("Zdrowie jest pełne.", "info")
				return false
			hp = minf(max_hp(), hp + float(item.get("amount", 50)))
		"energy":
			if energy >= max_energy():
				notify.emit("Energia jest pełna.", "info")
				return false
			energy = minf(max_energy(), energy + float(item.get("amount", 50)))
		_:
			return false
	add_item(id, -1)
	stats_changed.emit()
	Audio.play("heal")
	return true


func unlock_area(id: String) -> void:
	if not id in data["areas_unlocked"]:
		data["areas_unlocked"].append(id)


func visit_area(id: String) -> void:
	data["area"] = id
	unlock_area(id)
	if not id in data["areas_visited"]:
		data["areas_visited"].append(id)
		set_flag("visited_" + id)


func mark_list(key: String, id: String) -> void:
	if not id in data[key]:
		data[key].append(id)


func in_list(key: String, id: String) -> bool:
	return id in data.get(key, [])


func set_checkpoint(area: String, spawn: String) -> void:
	data["checkpoint"] = {"area": area, "spawn": spawn}


func fragments() -> int:
	var n := 0
	for f in ["frag_jasnosc", "frag_logika", "frag_prawda"]:
		if item_count(f) > 0 or has_flag("placed_" + f):
			n += 1
	return n


# --- Zapis -----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(backup_path)


func save_game() -> bool:
	if not saving_enabled:
		return true
	var text := JSON.stringify(data)
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, backup_path)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		notify.emit("Nie udało się zapisać postępu.", "warn")
		return false
	f.store_string(text)
	f.close()
	return true


func load_game() -> bool:
	## Zwraca true, jeśli wczytano poprawny zapis. Uszkodzony zapis nie wywraca gry.
	load_message = ""
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var clean: Variant = validate(JSON.parse_string(FileAccess.get_file_as_string(path)))
		if clean != null:
			data = clean
			if path == backup_path:
				load_message = "Główny zapis był uszkodzony — wczytano kopię zapasową."
			refill()
			return true
		load_message = "Zapis był uszkodzony i nie dał się odczytać. Możesz zacząć nową grę."
	return false


func delete_save() -> void:
	for path in [save_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func validate(raw: Variant) -> Variant:
	## Traktuje dane jako niezaufane: sprawdza typy, zakresy i znane identyfikatory.
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	var version := int(d.get("version", -1)) if typeof(d.get("version")) in [TYPE_INT, TYPE_FLOAT] else -1
	if version < 1 or version > SAVE_VERSION:
		return null
	var cid := str(d.get("class_id", ""))
	if not Data.classes.has(cid):
		return null
	var out := default_data(cid)
	out["level"] = clampi(_num(d.get("level"), 1), 1, MAX_LEVEL)
	out["xp"] = clampi(_num(d.get("xp"), 0), 0, 100000)
	# Poziom wynika z doświadczenia — nie ufamy samemu polu "level".
	var lvl := 1
	while lvl < MAX_LEVEL and out["xp"] >= XP_FOR_LEVEL[lvl + 1]:
		lvl += 1
	out["level"] = lvl
	var inv: Dictionary = {}
	if typeof(d.get("inventory")) == TYPE_DICTIONARY:
		for k in d["inventory"]:
			if Data.items.has(str(k)):
				var n := clampi(_num(d["inventory"][k], 0), 0, 99)
				if n > 0:
					inv[str(k)] = n
	out["inventory"] = inv
	out["missions_done"] = _id_list(d.get("missions_done"), Data.missions.keys())
	out["areas_unlocked"] = _id_list(d.get("areas_unlocked"), Data.areas.keys())
	if not "latarnia" in out["areas_unlocked"]:
		out["areas_unlocked"].append("latarnia")
	out["areas_visited"] = _id_list(d.get("areas_visited"), Data.areas.keys())
	out["chests"] = _id_list(d.get("chests"), null)
	out["secrets"] = _id_list(d.get("secrets"), null)
	out["defeated_once"] = _id_list(d.get("defeated_once"), null)
	var flags: Dictionary = {}
	if typeof(d.get("flags")) == TYPE_DICTIONARY:
		for k in d["flags"]:
			var key := str(k)
			if key.length() <= 64 and typeof(d["flags"][k]) == TYPE_BOOL:
				flags[key] = d["flags"][k]
	out["flags"] = flags
	var cp: Variant = d.get("checkpoint")
	if typeof(cp) == TYPE_DICTIONARY and Data.areas.has(str(cp.get("area", ""))):
		var spawns: Dictionary = Data.get_area(str(cp["area"])).get("spawns", {})
		if spawns.has(str(cp.get("spawn", ""))):
			out["checkpoint"] = {"area": str(cp["area"]), "spawn": str(cp["spawn"])}
	out["area"] = out["checkpoint"]["area"]
	out["play_time"] = clampf(_numf(d.get("play_time"), 0.0), 0.0, 1.0e7)
	out["deaths"] = clampi(_num(d.get("deaths"), 0), 0, 1000000)
	var gc: Variant = d.get("game_complete", false)
	out["game_complete"] = typeof(gc) == TYPE_BOOL and gc
	return out


func _num(v: Variant, fallback: int) -> int:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)):
		return int(v)
	return fallback


func _numf(v: Variant, fallback: float) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)):
		return float(v)
	return fallback


func _id_list(v: Variant, allowed: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for e in v:
		var s := str(e)
		if s.length() > 64 or s in out:
			continue
		if allowed != null and not s in allowed:
			continue
		out.append(s)
		if out.size() > 500:
			break
	return out


func export_string() -> String:
	var payload := {"save": data, "settings": Settings.to_dict()}
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(payload))


func import_string(text: String) -> String:
	## Zwraca pusty napis przy sukcesie albo opis błędu.
	text = text.strip_edges()
	if text.length() > 200000:
		return "Plik jest za duży, to nie wygląda na zapis tej gry."
	if not text.begins_with(EXPORT_PREFIX):
		return "To nie jest kod zapisu „Strażników Iskry”."
	var decoded := Marshalls.base64_to_utf8(text.substr(EXPORT_PREFIX.length()))
	var parsed: Variant = JSON.parse_string(decoded)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Kod zapisu jest uszkodzony."
	var clean: Variant = validate(parsed.get("save"))
	if clean == null:
		return "Zapis ma niepoprawne lub nieznane dane."
	data = clean
	if typeof(parsed.get("settings")) == TYPE_DICTIONARY:
		Settings.from_dict(parsed["settings"])
		Settings.save_settings()
	refill()
	save_game()
	return ""
