extends Node
## Tryb automatycznego testu (dla deweloperów / CI). Włączany argumentami:
##   godot --path client -- --autotest=ws://127.0.0.1:7171,Nazwa,haslo --shots=/tmp/out
## Loguje się (rejestruje, gdy konto nie istnieje), chodzi, atakuje, leczy się,
## robi zrzuty ekranu i kończy działanie.

var url := ""
var account := ""
var password := ""
var shots_dir := ""
var _t := 0.0
var _step := 0
var _mode := "register"


func _ready() -> void:
	Net.message.connect(_on_message)
	Net.connected.connect(func(): Net.send({"t": _mode, "v": Config.PROTOCOL_VERSION, "name": account, "pass": password}))
	Net.connect_to(url)


func _on_message(msg: Dictionary) -> void:
	if msg.t != "auth_error":
		return
	# Konto już istnieje -> ponowne połączenie i logowanie.
	if _mode == "register":
		_mode = "login"
		Net.connect_to.call_deferred(url)
	else:
		push_error("autotest: " + str(msg.text))
		get_tree().quit(1)


func _game() -> Node:
	for c in get_parent().get_children():
		if c.has_method("attack_nearest"):
			return c
	return null


func _process(delta: float) -> void:
	_t += delta
	var game := _game()
	if game == null:
		if _t > 15.0:
			push_error("autotest: brak logowania")
			get_tree().quit(1)
		return
	# Scenariusz: krok co ~1.5 s.
	if _t < 1.5:
		return
	_t = 0.0
	_step += 1
	match _step:
		1:
			_shot("01_miasto")
			# Wyjście z miasta zachodnią bramą (tap-to-move).
			game._on_tap(game.my_pos + Vector2i(-11, 2))
		4:
			_shot("02_brama")
			game._on_tap(game.my_pos + Vector2i(-8, -1))
		7:
			_shot("03_poza_miastem")
			game.attack_nearest()
		10:
			_shot("04_walka")
			Net.send({"t": "say", "text": "exura"})
			Net.send({"t": "say", "text": "Test czatu z klienta!"})
		11:
			# Zmiana broni na łuk (walka na dystans).
			for i in game.hud._bag.size():
				var st = game.hud._bag[i]
				if st is Dictionary and st.item == "hunting_bow":
					Net.send({"t": "equip", "slot": i})
			game.attack_nearest()
		12:
			game.hud._toggle(game.hud._inventory)
			_shot("05_plecak")
		13:
			game.hud._toggle(game.hud._character)
			_shot("06_postac")
		14:
			game.hud._toggle(game.hud._character)
			await _shot("07_koniec")
			print("autotest: OK, pozycja ", game.my_pos, " cel ", game.target_id)
			get_tree().quit(0)


func _shot(name: String) -> void:
	if shots_dir.is_empty():
		return
	# Czekamy na narysowanie klatki z aktualnym stanem interfejsu.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [shots_dir, name]
	img.save_png(path)
	print("autotest: zrzut ", path)
