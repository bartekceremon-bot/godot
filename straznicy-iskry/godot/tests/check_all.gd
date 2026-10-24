extends SceneTree
## Test statyczny: kompilacja wszystkich skryptów i spójność danych.
## Uruchom: godot --headless -s res://tests/check_all.gd

var errors: Array = []


func _init() -> void:
	await process_frame
	_check_scripts("res://scripts")
	_check_data()
	if errors.is_empty():
		print("CHECK_ALL: OK")
		quit(0)
	else:
		for e in errors:
			printerr("CHECK_ALL FAIL: ", e)
		quit(1)


func _check_scripts(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	for f in d.get_files():
		if f.ends_with(".gd"):
			var s: Script = load(dir_path + "/" + f)
			if s == null or not s.can_instantiate():
				errors.append("Skrypt nie kompiluje się: " + dir_path + "/" + f)
	for sub in d.get_directories():
		_check_scripts(dir_path + "/" + sub)


func _data() -> Node:
	return root.get_node("Data")


func _check_data() -> void:
	var data := _data()
	if not data.load_errors.is_empty():
		errors.append_array(data.load_errors)
	var types := ["sequence", "slots", "marks", "sort", "compare", "password"]
	var mission_count := 0
	for id in data.missions:
		var m: Dictionary = data.missions[id]
		mission_count += 1
		for key in ["title", "goal", "type", "data", "hints", "success", "real_life", "lesson", "area"]:
			if not m.has(key):
				errors.append("Zadanie %s nie ma pola %s" % [id, key])
		if not m.get("type", "") in types:
			errors.append("Zadanie %s ma nieznany typ" % id)
		if not data.areas.has(m.get("area", "")):
			errors.append("Zadanie %s ma nieznany obszar" % id)
		for item in m.get("reward", {}).get("items", {}):
			if not data.items.has(item):
				errors.append("Zadanie %s nagradza nieznanym przedmiotem %s" % [id, item])
	if mission_count < 9:
		errors.append("Za mało zadań: %d" % mission_count)
	# Każde zadanie musi mieć stację w swoim obszarze.
	for id in data.missions:
		var found := false
		for s in data.areas[data.missions[id]["area"]].get("stations", []):
			if s["mission"] == id:
				found = true
		if not found:
			errors.append("Zadanie %s nie ma stacji w świecie" % id)
	for area_id in data.areas:
		var a: Dictionary = data.areas[area_id]
		var spawns: Dictionary = a.get("spawns", {})
		for cp in a.get("checkpoints", []):
			if not spawns.has(cp["id"]):
				errors.append("%s: punkt kontrolny %s nie ma punktu odrodzenia" % [area_id, cp["id"]])
		for p in a.get("portals", []):
			var target: Dictionary = data.areas.get(p["target"], {})
			if target.is_empty() or not target.get("spawns", {}).has(p.get("spawn", "start")):
				errors.append("%s: portal %s prowadzi do nieistniejącego miejsca" % [area_id, p["id"]])
		for n in a.get("npcs", []):
			for r in n.get("dialogs", []):
				if not data.dialogs.has(r["id"]):
					errors.append("%s: brak dialogu %s" % [area_id, r["id"]])
		for e in a.get("enemies", []):
			if not data.enemies.has(e["type"]):
				errors.append("%s: nieznany przeciwnik %s" % [area_id, e["type"]])
		for c in a.get("chests", []) + a.get("secrets", []) + a.get("class_spots", []):
			for item in c.get("loot", {}):
				if not data.items.has(item):
					errors.append("%s: nieznany przedmiot %s" % [area_id, item])
	for cid in data.class_order:
		var c: Dictionary = data.classes[cid]
		for key in ["basic", "skill1", "skill2", "passive", "path"]:
			if not c.has(key):
				errors.append("Klasa %s nie ma %s" % [cid, key])
