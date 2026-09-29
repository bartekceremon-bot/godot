extends Node
## Główny węzeł: przełącza ekran logowania i grę.

const LoginScreen := preload("res://scripts/ui/login_screen.gd")
const Game := preload("res://scripts/game/game.gd")

var _current: Node = null


func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	Net.disconnected.connect(_on_disconnected)
	Net.message.connect(_on_message)
	show_login("")
	_maybe_start_autotest()


## Tryb testu automatycznego: argumenty po "--" w linii poleceń (patrz scripts/debug/autotest.gd).
func _maybe_start_autotest() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			opts[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)
	if not opts.has("autotest"):
		return
	var parts: PackedStringArray = str(opts.autotest).split(",")
	var t = load("res://scripts/debug/autotest.gd").new()
	t.url = parts[0]
	t.account = parts[1]
	t.password = parts[2]
	t.shots_dir = opts.get("shots", "")
	t.scenario = opts.get("scenario", "etap2")
	add_child(t)


func show_login(status: String) -> void:
	_swap(LoginScreen.new())
	_current.set_status(status)


func _on_message(msg: Dictionary) -> void:
	if msg.t == "welcome":
		GameData.load_welcome(msg)
		var game := Game.new()
		_swap(game)


func _on_disconnected(reason: String) -> void:
	show_login(reason)


func _swap(node: Node) -> void:
	if _current:
		_current.queue_free()
	_current = node
	add_child(node)
