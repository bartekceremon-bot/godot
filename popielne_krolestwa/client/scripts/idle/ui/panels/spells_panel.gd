class_name SpellsPanel
extends IdlePanel
## Zakładka CZARY: pasek 4 czarów (dotknij miejsca, potem czaru), księga pięciu szkół magii MMO –
## nauka u kapłanów (złoto + wymagany poziom), ulepszanie (złoto + żarokryształy), rzucanie automatyczne.

const SCHOOLS := ["light", "fire", "ice", "lightning", "death"]
const SCHOOL_COL := {"light": Color(1.0, 0.88, 0.5), "fire": Color(1.0, 0.55, 0.25), "ice": Color(0.6, 0.85, 1.0),
	"lightning": Color(0.78, 0.74, 1.0), "death": Color(0.78, 0.45, 0.9)}

var _slots_box: HBoxContainer
var _pick := -1
var _hint: Label
var _list: VBoxContainer
var _rows: Array = []


func build() -> void:
	add_child(IdleUI.title("Pasek czarów", 26))
	_slots_box = IdleUI.hbox(10)
	add_child(_slots_box)
	_hint = IdleUI.label("", 17, IdleUI.DIM, true)
	add_child(_hint)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_slots_box)
	for i in 4:
		var id := str(gm.s.spell_slots[i])
		var b := IdleUI.item_button(Sprites.icon(str(gm.spells.def(id).icon)) if id != "" else null, 4 if i == _pick else 0, "", 100)
		if id == "":
			b.text = "+"
			b.add_theme_font_size_override("font_size", 36)
		var idx: int = i
		b.pressed.connect(func():
			_pick = -1 if _pick == idx else idx
			request_refresh())
		_slots_box.add_child(b)
	var auto := gm.spells.auto_enabled()
	_hint.text = ("Wybierz czar dla miejsca %d (przycisk „Na pasek”)." % (_pick + 1)) if _pick >= 0 else \
		("Czary rzucasz przyciskami na ekranie walki. " + ("AUTO – czar rzuca się sam, gdy jest gotowy." if auto else "Automatyczne rzucanie odblokujesz na etapie %d." % SpellManager.AUTO_CAST_STAGE))
	IdleUI.clear(_list)
	_rows.clear()
	for school in SCHOOLS:
		var head := IdleUI.title("— %s —" % gm.db.school_names[school], 24)
		head.add_theme_color_override("font_color", SCHOOL_COL[school])
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(head)
		for id in gm.db.spell_order:
			var d := gm.spells.def(str(id))
			if str(d.school) != school:
				continue
			_add_row(str(id))
	tick_ui()


func _add_row(id: String) -> void:
	var d := gm.spells.def(id)
	var idle := gm.spells.idle_def(id)
	var known := gm.spells.is_known(id)
	var rc := row_card(Sprites.icon(str(d.icon)), "%s  „%s”" % [d.name, d.words], str(idle.get("text", "")), UiTheme.ACCENT if known else Color(0.7, 0.68, 0.62), 72)
	_list.add_child(rc[0])
	var btns: HBoxContainer = rc[1]
	var v := IdleUI.vbox(6)
	btns.add_child(v)
	var main_b := IdleUI.button("", Vector2(170, 70), 17)
	v.add_child(main_b)
	var second: Button = null
	if known:
		main_b.pressed.connect(func():
			if gm.spells.upgrade(id):
				ui.toast_msg("%s – poziom %d" % [d.name, gm.spells.level(id)], IdleUI.GOOD)
				request_refresh())
		var h := IdleUI.hbox(6)
		v.add_child(h)
		second = IdleUI.button("Na pasek", Vector2(0, 58), 16)
		second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		second.pressed.connect(func():
			var slot := _pick if _pick >= 0 else maxi(0, gm.s.spell_slots.find(""))
			gm.spells.set_slot(slot, id)
			_pick = -1
			request_refresh())
		h.add_child(second)
		if gm.spells.auto_enabled():
			var ab := IdleUI.button("AUTO", Vector2(80, 58), 15)
			ab.toggle_mode = true
			ab.set_pressed_no_signal(bool(gm.s.auto_spells.get(id, false)))
			ab.toggled.connect(func(_on): gm.spells.toggle_auto(id))
			h.add_child(ab)
	else:
		main_b.pressed.connect(func():
			if gm.spells.learn(id):
				request_refresh())
	_rows.append({"id": id, "btn": main_b, "desc": rc[2], "idle": idle})


func tick_ui() -> void:
	for r in _rows:
		var id := str(r.id)
		var d := gm.spells.def(id)
		var b: Button = r.btn
		var info := "Odnowienie %d s  •  mana %d" % [roundi(gm.spells.cooldown_of(id)), int(gm.spells.mana_of(id))]
		if gm.spells.is_known(id):
			var lvl := gm.spells.level(id)
			r.desc.text = "%s\n%s  •  poziom %d" % [r.idle.get("text", ""), info, lvl]
			if lvl >= SpellManager.MAX_LEVEL:
				b.text = "Maks. poziom"
				IdleUI.set_affordable(b, false)
			else:
				var c := gm.spells.upgrade_cost(id)
				b.text = "Ulepsz: %s zł\n+ %d żarokr." % [IdleDB.fmt(float(c.gold)), int(c.gems)]
				IdleUI.set_affordable(b, float(gm.s.gold) >= float(c.gold) and int(gm.s.gems) >= int(c.gems))
		else:
			var need := int(d.get("minLevel", 1))
			r.desc.text = "%s\n%s  •  wymaga poziomu %d" % [r.idle.get("text", ""), info, need]
			b.text = "Naucz: %s zł" % IdleDB.fmt(gm.spells.learn_cost(id)) if int(gm.s.level) >= need else "Poziom %d" % need
			IdleUI.set_affordable(b, gm.spells.can_learn(id))


func on_changed(what: String) -> void:
	if what in ["spells", "all"]:
		request_refresh()
