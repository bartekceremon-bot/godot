class_name SkinsPanel
extends IdlePanel
## Garderoba: stroje bohatera z podglądem 3D (wygląd – premie zostają z ekwipunku).

var _list: VBoxContainer
var _stage: Node3D
var _hero: Entity3D
var _key := "?"
var _t := 0.0


func build() -> void:
	add_child(IdleUI.title("Garderoba", 28))
	var pv := SubViewportContainer.new()
	pv.custom_minimum_size = Vector2(0, 260)
	pv.stretch = true
	add_child(pv)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	pv.add_child(vp)
	_stage = Node3D.new()
	vp.add_child(_stage)
	var cam := Camera3D.new()
	cam.fov = 32
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 3.6)).looking_at(Vector3(0, 0.85, 0), Vector3.UP)
	_stage.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	_stage.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 1.6, -1.0)
	rim.light_color = Color(1.0, 0.5, 0.2)
	rim.light_energy = 2.0
	_stage.add_child(rim)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.48)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	_stage.add_child(env)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func _show(eq: Array) -> void:
	var key := ",".join(PackedStringArray(eq))
	if key == _key:
		return
	_key = key
	if _hero:
		_hero.queue_free()
	_hero = Entity3D.new()
	_stage.add_child(_hero)
	_hero.apply({"i": 98, "k": "p", "n": "", "l": "3", "h": 100, "eq": eq, "x": 0, "y": 0, "d": 2, "s": 300}, false)
	_hero._to = Vector3.ZERO
	_hero._from = Vector3.ZERO
	_hero.position = Vector3.ZERO


func _process(delta: float) -> void:
	_t += delta
	if _hero:
		_hero._yaw = sin(_t * 0.5) * 0.8
		_hero._target_yaw = _hero._yaw


func refresh() -> void:
	IdleUI.clear(_list)
	_show(gm.skins.model(gm.equipment.model_equipment()))
	var cur := gm.skins.current()
	for d in SkinManager.SKINS:
		var id := str(d.id)
		var ok := gm.skins.unlocked(id)
		var res := row_card(IdleUI.ash_tex("portrait"), str(d.name), "Odblokowany" if ok and id != "" else str(d.text), IdleUI.GOOD if id == cur else UiTheme.ACCENT, 56)
		if not ok:
			res[0].modulate = Color(0.55, 0.55, 0.55)
		var b := IdleUI.button("Założony" if id == cur else ("Załóż" if ok else "Zablokowany"), Vector2(150, 72), 19)
		IdleUI.set_affordable(b, ok and id != cur)
		b.pressed.connect(func():
			gm.skins.select(id)
			request_refresh())
		res[1].add_child(b)
		_list.add_child(res[0])


func on_changed(what: String) -> void:
	if what in ["gear", "all"]:
		request_refresh()
