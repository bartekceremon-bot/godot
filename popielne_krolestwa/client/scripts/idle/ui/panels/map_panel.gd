class_name MapPanel
extends IdlePanel
## Zakładka MAPA: krainy Popielnych Królestw jako regiony po 10 etapów (elita na 5., boss na 10.),
## wybór etapu do farmienia, podróż do odblokowanych regionów.

var _list: VBoxContainer
var _stage_l: Label


func build() -> void:
	var c := IdleUI.card()
	add_child(c)
	var v := IdleUI.vbox(6)
	c.add_child(v)
	_stage_l = IdleUI.label("", 20, UiTheme.ACCENT, true)
	v.add_child(_stage_l)
	var h := IdleUI.hbox(8)
	v.add_child(h)
	for d in [-10, -1, 1, 10]:
		var b := IdleUI.button(("%+d" % d), Vector2(0, 70), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dd: int = d
		b.pressed.connect(func():
			gm.progression.travel(int(gm.s.stage) + dd)
			request_refresh())
		h.add_child(b)
	var mx := IdleUI.button("Najdalej", Vector2(0, 70), 20)
	mx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mx.pressed.connect(func():
		gm.progression.travel(int(gm.s.max_stage))
		request_refresh())
	h.add_child(mx)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	var s := gm.s
	_stage_l.text = "Etap %d (najdalej: %d)  •  %s" % [int(s.stage), int(s.max_stage), gm.progression.region_title(int(s.stage))]
	IdleUI.clear(_list)
	var per := gm.db.stages_per_region
	var circle := gm.progression.circle(int(s.max_stage))
	for i in gm.db.regions.size():
		var reg: Dictionary = gm.db.regions[i]
		var first := i * per + 1 + circle * per * gm.db.regions.size()
		var unlocked := int(s.max_stage) >= first or i <= gm.progression.max_region_index()
		if circle > 0:
			unlocked = true
		var here := gm.progression.region_index(int(s.stage)) == i
		var names: Array = []
		for m in reg.monsters:
			names.append(str(gm.db.monster(str(m)).name))
		var mats: Array = []
		for k in reg.materials:
			mats.append(gm.db.item_name("%s_t%d" % [k, int(reg.tier)]).get_slice(" (", 0))
		var city: Dictionary = gm.db.cities.get(str(reg.city), {})
		var desc := "%s\nEtapy %d–%d  •  T%d  •  miasto: %s\nPotwory: %s\nElita: %s  •  Boss: %s\nSurowce: %s" % [reg.text, first, first + per - 1, int(reg.tier),
			city.get("name", ""), ", ".join(PackedStringArray(names)), reg.elite.name, reg.boss.name, ", ".join(PackedStringArray(mats))]
		var col := UiTheme.ACCENT if unlocked else Color(0.55, 0.52, 0.48)
		var rc := row_card(Sprites.icon("map"), ("▶ " if here else "") + str(reg.name), desc if unlocked else "Zablokowane – dotrzyj do etapu %d." % first, col, 64)
		_list.add_child(rc[0])
		if unlocked:
			var b := IdleUI.button("Idź", Vector2(110, 80), 22)
			var target := mini(int(s.max_stage), first + per - 1)
			b.pressed.connect(func():
				gm.progression.travel(target)
				request_refresh())
			rc[1].add_child(b)


func on_changed(what: String) -> void:
	if what in ["stage", "all"]:
		request_refresh()
