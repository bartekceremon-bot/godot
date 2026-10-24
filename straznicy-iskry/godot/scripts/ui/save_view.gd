extends VBoxContainer
## Zapis ręczny, eksport (plik lub kod) i import (plik lub kod).
## Importowany tekst przechodzi pełną walidację w GameState.import_string().

var status: Label
var _import_poll := false
var _code_box: TextEdit


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var info := "Gra zapisuje się automatycznie przy Kamieniach Iskry, po zadaniach i przy podróżach. Zapis jest przechowywany tylko w tej przeglądarce — wyczyszczenie danych przeglądarki usunie postęp."
	if not GameState.persistent_storage:
		info = "UWAGA: ta przeglądarka nie zapewnia trwałego zapisu (np. tryb prywatny). Grać można dalej, ale postęp zniknie po zamknięciu karty. Użyj eksportu poniżej."
	add_child(UITheme.label(info, "Small"))
	add_child(UITheme.button("Zapisz teraz", func() -> void:
		_set_status("Zapisano." if GameState.save_game() else "Nie udało się zapisać.")))
	add_child(UITheme.label("Eksport zapisu", "Header"))
	var ex := HFlowContainer.new()
	ex.add_theme_constant_override("h_separation", 10)
	ex.add_theme_constant_override("v_separation", 10)
	add_child(ex)
	ex.add_child(UITheme.button("Pobierz plik zapisu", _export_file))
	ex.add_child(UITheme.button("Pokaż kod do skopiowania", _show_code))
	add_child(UITheme.label("Import zapisu", "Header"))
	add_child(UITheme.label("Import zastąpi bieżący postęp. Dane są sprawdzane przed wczytaniem.", "Small"))
	var im := HFlowContainer.new()
	im.add_theme_constant_override("h_separation", 10)
	im.add_theme_constant_override("v_separation", 10)
	add_child(im)
	im.add_child(UITheme.button("Wklej kod zapisu", _paste_code))
	if OS.has_feature("web"):
		im.add_child(UITheme.button("Wczytaj plik", _import_file))
	_code_box = TextEdit.new()
	_code_box.custom_minimum_size = Vector2(0, 120)
	_code_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code_box.visible = false
	add_child(_code_box)
	status = UITheme.label("", "Bold")
	add_child(status)


func _set_status(t: String) -> void:
	status.text = t


func _export_file() -> void:
	var code := GameState.export_string()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "straznicy-iskry-zapis.txt", "text/plain")
		_set_status("Plik zapisu został pobrany.")
	else:
		var path := OS.get_user_data_dir().path_join("straznicy-iskry-zapis.txt")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(code)
			f.close()
		_set_status("Zapisano plik: " + path)


func _show_code() -> void:
	var code := GameState.export_string()
	if OS.has_feature("web"):
		# Okno prompt przeglądarki pozwala zaznaczyć i skopiować tekst na każdym urządzeniu.
		JavaScriptBridge.eval("window.prompt('Skopiuj ten kod i zachowaj go w bezpiecznym miejscu:', %s)" % JSON.stringify(code), true)
		_set_status("Kod został wyświetlony.")
	else:
		_code_box.visible = true
		_code_box.text = code
		DisplayServer.clipboard_set(code)
		_set_status("Kod skopiowano do schowka.")


func _paste_code() -> void:
	var text := ""
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("window.prompt('Wklej kod zapisu:', '') || ''", true)
		text = str(r) if r != null else ""
	else:
		if _code_box.visible and _code_box.text.strip_edges() != "":
			text = _code_box.text
		else:
			_code_box.visible = true
			_code_box.text = ""
			_set_status("Wklej kod w pole powyżej i naciśnij ponownie „Wklej kod zapisu”.")
			return
	_apply_import(text)


func _import_file() -> void:
	var js := """
	(function(){window.__iskraImport=null;var i=document.createElement('input');i.type='file';i.accept='.txt,text/plain';
	i.onchange=function(){var f=i.files&&i.files[0];if(!f){window.__iskraImport='';return;}
	if(f.size>300000){window.__iskraImport='ERR_SIZE';return;}
	var r=new FileReader();r.onload=function(){window.__iskraImport=String(r.result);};
	r.onerror=function(){window.__iskraImport='ERR_READ';};r.readAsText(f);};i.click();})();
	"""
	JavaScriptBridge.eval(js, true)
	_import_poll = true
	_set_status("Wybierz plik zapisu…")


func _process(_delta: float) -> void:
	if not _import_poll:
		return
	var r: Variant = JavaScriptBridge.eval("window.__iskraImport", true)
	if r == null:
		return
	_import_poll = false
	JavaScriptBridge.eval("window.__iskraImport=null", true)
	var s := str(r)
	if s == "ERR_SIZE":
		_set_status("Plik jest za duży, to nie jest zapis tej gry.")
	elif s == "ERR_READ":
		_set_status("Nie udało się odczytać pliku.")
	elif s != "":
		_apply_import(s)


func _apply_import(text: String) -> void:
	if text.strip_edges().is_empty():
		_set_status("Nie wklejono żadnego kodu.")
		return
	var err := GameState.import_string(text)
	if err.is_empty():
		_set_status("Zapis wczytany! Przenoszę do punktu kontrolnego…")
		Router.go("world")
	else:
		_set_status(err)
