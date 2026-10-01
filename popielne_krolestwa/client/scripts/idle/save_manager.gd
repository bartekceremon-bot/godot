class_name SaveManager
extends RefCounted
## Lokalny zapis gry (bez logowania i sieci): JSON w user://, zapis atomowy (plik tymczasowy
## + podmiana), suma kontrolna i kopia zapasowa poprzedniego zapisu (.bak) na wypadek uszkodzenia.

const PATH := "user://popielne_idle.save"
const BAK := "user://popielne_idle.bak"
const TMP := "user://popielne_idle.tmp"

var gm: IdleGame
## Inna ścieżka (testy).
var path := PATH


func _init(g: IdleGame) -> void:
	gm = g


func save_game() -> bool:
	if gm.s.is_empty():
		return false
	gm.s.last_time = Time.get_unix_time_from_system()
	var data := JSON.stringify(gm.s)
	var wrapped := JSON.stringify({"sum": data.sha256_text(), "data": data})
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Zapis: nie można otworzyć %s" % tmp)
		return false
	f.store_string(wrapped)
	f.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(path):
		dir.copy(path, path + ".bak")
	dir.rename(tmp, path)
	return true


## Wczytuje zapis (a gdy jest uszkodzony – kopię zapasową). Pusty słownik = nowa gra.
func load_game() -> Dictionary:
	for p in [path, path + ".bak"]:
		var d := _read(p)
		if not d.is_empty():
			return d
	return {}


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var text := FileAccess.get_file_as_string(p)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Zapis %s nieczytelny – próba kopii zapasowej" % p)
		return {}
	var w = json.data
	if not (w is Dictionary) or not w.has("data"):
		return {}
	var data := str(w.data)
	if str(w.get("sum", "")) != data.sha256_text():
		push_warning("Zapis %s uszkodzony – próba kopii zapasowej" % p)
		return {}
	var d = JSON.parse_string(data)
	return d if d is Dictionary else {}


## Kod zapisu do przeniesienia gry na inny telefon (bez serwera): PK1-<base64(gzip(JSON))>-<suma>.
func export_code() -> String:
	if gm.s.is_empty():
		return ""
	var raw := JSON.stringify(gm.s).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	var b64 := Marshalls.raw_to_base64(packed)
	return "PK1-%s-%s" % [b64, b64.sha256_text().left(8)]


## Odczyt kodu zapisu; pusty słownik przy błędnym kodzie.
static func parse_code(code: String) -> Dictionary:
	var c := code.strip_edges().replace("\n", "").replace(" ", "")
	if not c.begins_with("PK1-"):
		return {}
	var parts := c.substr(4).rsplit("-", true, 1)
	if parts.size() != 2 or parts[0].sha256_text().left(8) != parts[1]:
		return {}
	var packed := Marshalls.base64_to_raw(parts[0])
	if packed.is_empty():
		return {}
	var raw := packed.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var d = JSON.parse_string(raw.get_string_from_utf8())
	if not (d is Dictionary) or not d.has("stage") or not d.has("gold") or not d.has("gear"):
		return {}
	return d


func has_save() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			dir.remove(p.get_file())
