extends SceneTree
## Testy zapisu: zapis/odczyt, kopia zapasowa, uszkodzone dane, walidacja,
## eksport/import. Uruchom: godot --headless -s res://tests/save_test.gd

var fails := 0
var passes := 0


func ok(c: bool, what: String) -> void:
	if c:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)


func write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	# Osobne pliki — test nie może naruszyć prawdziwego zapisu gracza.
	gs.save_path = "user://test_save.json"
	gs.backup_path = "user://test_save.bak.json"
	gs.delete_save()
	ok(not gs.has_save(), "brak zapisu na starcie")
	# 1. Zapis i odczyt
	gs.new_game("tropiciel")
	gs.add_item("krysztal", 3)
	gs.set_flag("lamp_lit")
	gs.complete_mission("m_lampa")
	gs.save_game()
	gs.data = gs.default_data("tkacz")
	ok(gs.load_game(), "wczytanie poprawnego zapisu")
	ok(gs.class_id() == "tropiciel" and gs.item_count("krysztal") == 3 and gs.has_flag("lamp_lit") and gs.is_mission_done("m_lampa"), "dane po wczytaniu się zgadzają")
	# 2. Uszkodzony główny zapis, poprawna kopia
	gs.save_game()      # kopiuje poprzedni zapis do kopii zapasowej
	write(gs.save_path, "{to nie jest json")
	ok(gs.load_game(), "uszkodzony zapis → wczytano kopię zapasową")
	ok(gs.load_message.contains("kopię"), "komunikat o kopii zapasowej")
	# 3. Oba uszkodzone
	write(gs.save_path, "xxx")
	write(gs.backup_path, "")
	ok(not gs.load_game(), "oba pliki uszkodzone → brak wczytania, bez awarii")
	ok(gs.load_message.contains("uszkodzony"), "komunikat o uszkodzonym zapisie")
	# 4. Walidacja niezaufanych danych
	ok(gs.validate({"version": 99, "class_id": "tkacz"}) == null, "odrzuca nieznaną wersję")
	ok(gs.validate({"version": 1, "class_id": "haker"}) == null, "odrzuca nieznaną klasę")
	ok(gs.validate("tekst") == null, "odrzuca nie-słownik")
	var bad := {"version": 1, "class_id": "tkacz", "level": 99, "xp": -50,
		"inventory": {"eliksir": 500, "miecz_zaglady": 1, "krysztal": "dużo"},
		"missions_done": ["m_lampa", "m_nieistnieje", 5], "flags": {"lamp_lit": true, "x": "tak"},
		"checkpoint": {"area": "mars", "spawn": "baza"}, "play_time": "NaN"}
	var clean: Dictionary = gs.validate(bad)
	ok(clean != null, "naprawia częściowo błędne dane")
	ok(clean["level"] == 1 and clean["xp"] == 0, "poziom wyliczany z PD, ujemne PD obcięte")
	ok(clean["inventory"].get("eliksir", 0) == 99 and not clean["inventory"].has("miecz_zaglady") and not clean["inventory"].has("krysztal"), "ekwipunek: limit, nieznane i błędne pozycje usunięte")
	ok(clean["missions_done"] == ["m_lampa"], "tylko znane zadania")
	ok(clean["flags"].has("lamp_lit") and not clean["flags"].has("x"), "flagi tylko typu bool")
	ok(clean["checkpoint"]["area"] == "latarnia", "nieznany punkt kontrolny → Latarnia")
	ok(clean["play_time"] == 0.0, "czas gry: zła wartość → 0")
	# 5. Eksport i import
	gs.new_game("straznik")
	gs.add_xp(250)
	var code: String = gs.export_string()
	ok(code.begins_with(gs.EXPORT_PREFIX), "eksport ma prefiks")
	gs.new_game("tkacz")
	ok(gs.import_string(code) == "", "import poprawnego kodu")
	ok(gs.class_id() == "straznik" and gs.level() == 3, "import przywraca klasę i poziom")
	ok(gs.import_string("hello") != "", "import śmieci → błąd")
	ok(gs.import_string(gs.EXPORT_PREFIX + "!!!") != "", "import uszkodzonego base64 → błąd")
	ok(gs.import_string(gs.EXPORT_PREFIX + Marshalls.utf8_to_base64("{\"save\": {\"version\": 1, \"class_id\": \"zly\"}}")) != "", "import złych danych → błąd")
	ok(gs.import_string("x".repeat(300000)) != "", "import zbyt dużego tekstu → błąd")
	gs.delete_save()
	print("SAVE_TEST passes=%d fails=%d" % [passes, fails])
	quit(0 if fails == 0 else 1)
