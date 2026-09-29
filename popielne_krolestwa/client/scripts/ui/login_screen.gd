extends Control
## Ekran logowania / rejestracji + ustawienie adresu serwera.
## Przycisk „Szukaj w sieci lokalnej” wykrywa serwer w tej samej sieci Wi-Fi (broadcast UDP).

var _server: LineEdit
var _name: LineEdit
var _pass: LineEdit
var _status: Label
var _login_btn: Button
var _register_btn: Button
var _pending_action := ""
var _discovery: PacketPeerUDP = null
var _discovery_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_build_background()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/splash.png")
	logo.custom_minimum_size = Vector2(0, 96)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(logo)
	var title := UiTheme.label("POPIELNE KRÓLESTWA", 44, UiTheme.ACCENT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("2a0e06"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("Świat spłonął. Odbuduj go.", 20, Color(0.75, 0.7, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(UiTheme.label("Adres serwera", 18))
	var srv_row := HBoxContainer.new()
	box.add_child(srv_row)
	_server = _line_edit(Config.server_url, "ws://192.168.1.10:7171")
	_server.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srv_row.add_child(_server)
	var lan := UiTheme.button("Szukaj w LAN")
	lan.pressed.connect(_start_discovery)
	srv_row.add_child(lan)

	box.add_child(UiTheme.label("Nazwa postaci", 18))
	_name = _line_edit(Config.account_name, "np. Popielnik")
	_name.max_length = 16
	box.add_child(_name)
	box.add_child(UiTheme.label("Hasło", 18))
	_pass = _line_edit("", "min. 4 znaki")
	_pass.secret = true
	_pass.text_submitted.connect(func(_t): _submit("login"))
	box.add_child(_pass)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_login_btn = UiTheme.button("Zaloguj")
	_login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_login_btn.pressed.connect(_submit.bind("login"))
	row.add_child(_login_btn)
	_register_btn = UiTheme.button("Nowa postać")
	_register_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_btn.pressed.connect(_submit.bind("register"))
	row.add_child(_register_btn)

	_status = UiTheme.label("", 18, Color(1, 0.8, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	var ver := UiTheme.label("v%s  •  ETAP 2+" % ProjectSettings.get_setting("application/config/version"), 14, Color(0.5, 0.45, 0.4))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-180, -30)
	add_child(ver)

	Net.connected.connect(_on_connected)
	Net.message.connect(_on_message)


func _build_background() -> void:
	# Tło: spalona ziemia (tekstura terenu), unoszący się popiół i żar, winieta.
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_TILE
	var img: Image = load("res://assets/world/terrain/ash.png").get_image()
	img.resize(256, 256, Image.INTERPOLATE_NEAREST)
	bg.texture = ImageTexture.create_from_image(img)
	bg.modulate = Color(0.75, 0.68, 0.66)
	add_child(bg)
	var dot: Texture2D = load("res://assets/fx/soft_dot.png")
	for kind in ["ash", "ember"]:
		var p := CPUParticles2D.new()
		p.texture = dot
		p.amount = 60 if kind == "ash" else 25
		p.lifetime = 10.0
		p.preprocess = 10.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(900, 10)
		p.position = Vector2(640, -20 if kind == "ash" else 740)
		p.direction = Vector2(0.3, 1) if kind == "ash" else Vector2(0.2, -1)
		p.spread = 25.0
		p.gravity = Vector2(8, 10) if kind == "ash" else Vector2(5, -12)
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 50.0
		p.scale_amount_min = 0.3 if kind == "ash" else 0.2
		p.scale_amount_max = 0.7 if kind == "ash" else 0.45
		var g := Gradient.new()
		if kind == "ash":
			g.colors = PackedColorArray([Color(0.8, 0.78, 0.75, 0), Color(0.8, 0.78, 0.75, 0.6), Color(0.6, 0.58, 0.56, 0)])
		else:
			g.colors = PackedColorArray([Color(1, 0.85, 0.4, 0), Color(1, 0.55, 0.15, 1), Color(0.8, 0.2, 0.05, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		p.color_ramp = g
		add_child(p)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	mat.set_shader_parameter("strength", 0.8)
	vig.material = mat
	add_child(vig)


func _line_edit(text: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 56)
	return e


func set_status(text: String) -> void:
	if _status:
		_status.text = text
	else:
		# Wywołane przed _ready – ustawimy po zbudowaniu UI.
		ready.connect(func(): _status.text = text, CONNECT_ONE_SHOT)


func _submit(action: String) -> void:
	var url := Config.normalize_url(_server.text)
	if url.is_empty():
		set_status("Podaj adres serwera.")
		return
	if _name.text.strip_edges().length() < 3 or _pass.text.length() < 4:
		set_status("Podaj nazwę (min. 3 znaki) i hasło (min. 4 znaki).")
		return
	_server.text = url
	Config.server_url = url
	Config.account_name = _name.text.strip_edges()
	Config.save_settings()
	_pending_action = action
	_set_busy(true)
	set_status("Łączenie z %s..." % url)
	if Net.connect_to(url) != OK:
		_set_busy(false)
		set_status("Nieprawidłowy adres serwera.")


func _on_connected() -> void:
	if _pending_action.is_empty():
		return
	Net.send({
		"t": _pending_action,
		"v": Config.PROTOCOL_VERSION,
		"name": Config.account_name,
		"pass": _pass.text,
	})
	set_status("Logowanie...")


func _on_message(msg: Dictionary) -> void:
	if msg.t == "auth_error":
		set_status(str(msg.text))
		_set_busy(false)
		_pending_action = ""
		Net.close()


func _set_busy(busy: bool) -> void:
	_login_btn.disabled = busy
	_register_btn.disabled = busy
	if not busy:
		return
	# Odblokowanie po czasie, gdyby serwer nie odpowiedział.
	get_tree().create_timer(8.0).timeout.connect(func():
		if is_instance_valid(self) and _login_btn.disabled:
			_login_btn.disabled = false
			_register_btn.disabled = false
			set_status("Serwer nie odpowiada. Sprawdź adres i sieć Wi-Fi.")
			Net.close())


# --- Wykrywanie serwera w sieci lokalnej -------------------------------------

func _start_discovery() -> void:
	_discovery = PacketPeerUDP.new()
	_discovery.set_broadcast_enabled(true)
	_discovery.bind(0)
	_discovery.set_dest_address("255.255.255.255", Config.DISCOVERY_PORT)
	_discovery.put_packet("PK_DISCOVER".to_utf8_buffer())
	_discovery_time = 2.0
	set_status("Szukam serwera w sieci lokalnej...")


func _process(delta: float) -> void:
	if _discovery == null:
		return
	while _discovery.get_available_packet_count() > 0:
		var text := _discovery.get_packet().get_string_from_utf8()
		var ip := _discovery.get_packet_ip()
		if text.begins_with("PK_SERVER"):
			var port := text.get_slice(" ", 1)
			_server.text = "ws://%s:%s" % [ip, port]
			set_status("Znaleziono serwer: %s" % _server.text)
			_discovery.close()
			_discovery = null
			return
	_discovery_time -= delta
	if _discovery_time <= 0:
		_discovery.close()
		_discovery = null
		set_status("Nie znaleziono serwera w sieci lokalnej. Wpisz adres IP komputera ręcznie.")
