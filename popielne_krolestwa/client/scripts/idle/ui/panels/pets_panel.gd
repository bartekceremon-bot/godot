class_name PetsPanel
extends IdlePanel
## Chowańce: jaja do wyklucia, podgląd 3D, lista gatunków (poziom, gwiazdki, premia), aktywacja.

var _list: VBoxContainer
var _vp: SubViewport
var _stage: Node3D
var _preview: Entity3D
var _preview_look := ""
var _t := 0.0


func build() -> void:
	add_child(IdleUI.title("Chowańce", 28))
	var pv := SubViewportContainer.new()
	pv.custom_minimum_size = Vector2(0, 220)
	pv.stretch = true
	add_child(pv)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	pv.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var cam := Camera3D.new()
	cam.fov = 35
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 3.2)).looking_at(Vector3(0, 0.4, 0), Vector3.UP)
	_stage.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	_stage.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	_stage.add_child(env)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func _show_pet(look: String) -> void:
	if look == _preview_look:
		return
	_preview_look = look
	if _preview:
		_preview.queue_free()
		_preview = null
	if look == "":
		return
	_preview = Entity3D.new()
	_stage.add_child(_preview)
	_preview.apply({"i": 99, "k": "m", "n": "", "l": look, "h": 100, "x": 0, "y": 0, "d": 2, "s": 300}, false)
	_preview._to = Vector3.ZERO
	_preview._from = Vector3.ZERO
	_preview.position = Vector3.ZERO
	if _preview.model:
		var body := maxf(0.3, _preview.label_height - 0.32)
		_preview.model.scale *= clampf(1.0 / body, 0.2, 2.0)


func _process(delta: float) -> void:
	_t += delta
	if _preview:
		_preview._yaw = _t * 0.6
		_preview._target_yaw = _t * 0.6


func refresh() -> void:
	IdleUI.clear(_list)
	var pm := gm.pets
	var first := str(pm.active()[0]) if not pm.active().is_empty() else ""
	_show_pet(str(PetManager.def(first).get("look", "")) if first != "" else "")
	var eggs := gm.inventory.count("pet_egg")
	var top := IdleUI.hbox(10)
	_list.add_child(top)
	top.add_child(IdleUI.icon_rect(IdleUI.item_tex(gm.db, "pet_egg"), 64))
	var tl := IdleUI.label("Jaja: %d  •  aktywne: %d / %d (drugi slot – 25. piętro Wieży)\nJaja: bossowie od etapu 15, co 10 pięter Wieży, długie wyprawy, Boss tygodnia." % [eggs, pm.active().size(), pm.slots()], 17, Color(0.9, 0.86, 0.78), true)
	top.add_child(tl)
	var hb := IdleUI.button("Wykluj jajo", Vector2(0, 84), 26)
	IdleUI.set_affordable(hb, eggs > 0)
	hb.pressed.connect(func():
		var r := gm.pets.hatch()
		if not r.is_empty():
			var d := PetManager.def(str(r.id))
			var txt := ("Nowy chowaniec: %s!" if r.new else ("%s: +1 gwiazdka!" if r.star else "%s (maks. gwiazdki) – +60 żarokryształów")) % d.name
			ui.banner("WYKLUCIE!", txt, IdleDB.RARITY_COLORS[int(d.rarity) + 1])
		request_refresh())
	_list.add_child(hb)
	var ob := IdleUI.button("Szanse wyklucia", Vector2(0, 64), 18)
	ob.pressed.connect(func(): ui.show_odds("Jajo chowańca", gm.pets.egg_odds()))
	_list.add_child(ob)
	for d in PetManager.PETS:
		_list.add_child(_card(d))


func _card(d: Dictionary) -> Control:
	var id := str(d.id)
	var pm := gm.pets
	var own := pm.level(id) > 0
	var col: Color = IdleDB.RARITY_COLORS[int(d.rarity) + 1]
	var c := IdleUI.card(Color(), col if pm.active().has(id) else Color(0, 0, 0, 0))
	if not own:
		c.modulate = Color(0.55, 0.55, 0.55)
	var v := IdleUI.vbox(4)
	c.add_child(v)
	var stars := "★".repeat(pm.stars(id)) + "☆".repeat(PetManager.MAX_STARS - pm.stars(id))
	v.add_child(IdleUI.label("%s  %s" % [d.name if own else "???", stars if own else ""], 21, col, true))
	v.add_child(IdleUI.label("%s  •  poz. %d / %d  •  +%s%% %s" % [PetManager.RARITY_NAMES[int(d.rarity)], pm.level(id), pm.max_level(id), _pct(pm.value(id)), d.text] if own else "%s – wykluj z jaja" % PetManager.RARITY_NAMES[int(d.rarity)], 16, Color(0.85, 0.82, 0.76), true))
	if own:
		var row := IdleUI.hbox(8)
		v.add_child(row)
		var act := IdleUI.button("Odwołaj" if pm.active().has(id) else "Przywołaj", Vector2(0, 70), 19)
		act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act.pressed.connect(func():
			gm.pets.set_active(id)
			request_refresh())
		row.add_child(act)
		var up := IdleUI.button("Poziom +1\n%s zł" % IdleDB.fmt(pm.level_cost(id)) if pm.level(id) < pm.max_level(id) else "Maks. poziom\n(więcej gwiazdek)", Vector2(0, 70), 16)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		IdleUI.set_affordable(up, pm.level(id) < pm.max_level(id) and float(gm.s.gold) >= pm.level_cost(id))
		up.pressed.connect(func():
			gm.pets.level_up(id)
			request_refresh())
		row.add_child(up)
	return c


func _pct(x: float) -> String:
	return ("%.1f" % (x * 100.0)) if x < 0.1 else str(roundi(x * 100.0))


func tick_ui() -> void:
	pass


func on_changed(what: String) -> void:
	if what in ["pets", "all"]:
		request_refresh()
