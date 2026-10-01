extends PanelContainer
## Okno plecaka i ekwipunku. Dotknięcie przedmiotu pokazuje jego opis i akcje
## (Użyj / Załóż / Zdejmij / Upuść). Wszystkie akcje wykonuje serwer.

const SLOT_SIZE := Vector2(72, 72)
const EQUIP_ORDER := ["head", "weapon", "body", "shield", "legs", "feet"]

var _bag_grid: GridContainer
var _equip_grid: GridContainer
var _details: Label
var _actions: HBoxContainer
var _gold: Label
var _weight: Label
var _bag: Array = []
var _eq: Dictionary = {}
## Zaznaczony przedmiot: {"src": "bag"/"eq", "key": indeks lub nazwa slotu}
var _selected: Dictionary = {}


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiTheme.label("Plecak i ekwipunek", 26, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_weight = UiTheme.label("", 18, Color(0.8, 0.75, 0.7))
	header.add_child(_weight)
	_gold = UiTheme.label("", 20, Color(1, 0.85, 0.3))
	header.add_child(_gold)
	var close := UiTheme.button("X", "", Vector2(56, 56))
	close.pressed.connect(hide)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	_equip_grid = GridContainer.new()
	_equip_grid.columns = 2
	body.add_child(_equip_grid)
	body.add_child(_build_preview())

	_bag_grid = GridContainer.new()
	_bag_grid.columns = 5
	body.add_child(_bag_grid)

	_details = UiTheme.label("Dotknij przedmiotu, aby zobaczyć szczegóły.", 18)
	_details.custom_minimum_size = Vector2(0, 90)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_details)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	root.add_child(_actions)


# --- Podgląd postaci 3D (obraca się powoli, zbroja i broń jak w grze) ---------------

var _pv_root: Node3D
var _pv_model: CharacterModel
var _pv_key := ""


func _build_preview() -> Control:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.9)
	sb.border_color = Color(0.78, 0.58, 0.28, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", sb)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(200, 300)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	_pv_root = Node3D.new()
	vp.add_child(_pv_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.68)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment.glow_enabled = true
	_pv_root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.2
	_pv_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_color = Color(1.0, 0.8, 0.55)
	rim.light_energy = 0.9
	_pv_root.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 0.75, 3.1)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	_pv_root.add_child(cam)
	# Podest.
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.5
	cyl.height = 0.08
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.15, 0.17)
	m.metallic = 0.4
	m.roughness = 0.5
	mi.material_override = m
	mi.position.y = -0.04
	_pv_root.add_child(mi)
	return frame


## Model postaci do podglądu (przebudowa tylko przy zmianie wyglądu).
func set_preview(app: Dictionary) -> void:
	if _pv_root == null:
		return
	var key := str(app)
	if key == _pv_key:
		return
	_pv_key = key
	if _pv_model:
		_pv_model.queue_free()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/lowpoly_object.gdshader")
	_pv_model = CharacterModel.new(mat)
	_pv_model.build_humanoid(app)
	_pv_root.add_child(_pv_model)


func _process(delta: float) -> void:
	if visible and _pv_model:
		_pv_model.rotation.y += delta * 0.6


func set_data(bag: Array, eq: Dictionary) -> void:
	_bag = bag
	_eq = eq
	var gold := 0
	for s in bag:
		if s is Dictionary and s.item == "gold":
			gold += int(s.count)
	_gold.text = "%d zł  " % gold
	_rebuild()


func _rebuild() -> void:
	for c in _equip_grid.get_children():
		c.queue_free()
	for c in _bag_grid.get_children():
		c.queue_free()
	for slot in EQUIP_ORDER:
		var stack = _eq.get(slot)
		var b := _slot_button(stack, GameData.SLOT_LABELS[slot])
		b.pressed.connect(_select.bind("eq", slot))
		_equip_grid.add_child(b)
	for i in _bag.size():
		var b := _slot_button(_bag[i], "")
		b.pressed.connect(_select.bind("bag", i))
		_bag_grid.add_child(b)
	# Odśwież szczegóły zaznaczenia (albo wyczyść, jeśli przedmiot zniknął).
	if not _selected.is_empty():
		_select(_selected.src, _selected.key)


func _slot_button(stack, placeholder: String) -> Button:
	return UiTheme.item_slot(stack, placeholder, SLOT_SIZE)


## Udźwig z pakietu stats.
func set_weight(weight: float, cap: float) -> void:
	_weight.text = "%.0f/%.0f oz  " % [weight, cap]
	_weight.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if weight > cap * 0.9 else Color(0.8, 0.75, 0.7))


func _select(src: String, key) -> void:
	for c in _actions.get_children():
		c.queue_free()
	var stack = _bag[key] if src == "bag" else _eq.get(key)
	if not (stack is Dictionary):
		_selected = {}
		_details.text = "Pusty slot."
		return
	_selected = {"src": src, "key": key}
	var def := GameData.item_def(str(stack.item))
	_details.text = GameData.item_description(str(stack.item), int(stack.get("q", 1))) + ("  (x%d)" % int(stack.count) if int(stack.count) > 1 else "")
	if src == "eq":
		_action("Zdejmij", {"t": "unequip", "slot": key})
		return
	if def.has("use"):
		_action("Użyj", {"t": "use", "slot": key})
	if def.has("slot"):
		_action("Załóż", {"t": "equip", "slot": key})
	_action("Upuść", {"t": "drop", "slot": key})


func _action(text: String, msg: Dictionary) -> void:
	var b := UiTheme.button(text, "", Vector2(140, 60))
	b.pressed.connect(func(): Net.send(msg))
	_actions.add_child(b)
