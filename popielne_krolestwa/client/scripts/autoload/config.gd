extends Node
## Ustawienia klienta zapisywane w user://settings.cfg (adres serwera, nazwa, dźwięk).

const PATH := "user://settings.cfg"
## Musi zgadzać się z config.protocolVersion na serwerze.
const PROTOCOL_VERSION := 1
const DEFAULT_PORT := 7171
## Port UDP do wykrywania serwera w sieci lokalnej (tryb „lokalny serwer”).
const DISCOVERY_PORT := 7172

var server_url := "ws://192.168.1.100:7171"
var account_name := ""
var sound_enabled := true
var show_fps := false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	server_url = cfg.get_value("net", "server_url", server_url)
	account_name = cfg.get_value("account", "name", account_name)
	sound_enabled = cfg.get_value("audio", "enabled", sound_enabled)
	show_fps = cfg.get_value("video", "show_fps", show_fps)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("net", "server_url", server_url)
	cfg.set_value("account", "name", account_name)
	cfg.set_value("audio", "enabled", sound_enabled)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.save(PATH)


## Uzupełnia adres wpisany przez gracza: "192.168.1.5" -> "ws://192.168.1.5:7171".
static func normalize_url(text: String) -> String:
	var u := text.strip_edges()
	if u.is_empty():
		return u
	if not (u.begins_with("ws://") or u.begins_with("wss://")):
		u = "ws://" + u
	var host_part := u.split("://")[1]
	if not host_part.contains(":"):
		u += ":%d" % DEFAULT_PORT
	return u
