class_name DreamPanel
extends IdlePanel
## Sen Popielnika: wejście do snu, wynik ostatniego snu, Drzewo Snu, spis błogosławieństw.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Sen Popielnika", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var d := gm.dream
	if not d.unlocked():
		_box.add_child(IdleUI.label("Sen otwiera się po dotarciu do etapu %d." % DreamManager.UNLOCK_STAGE, 20, IdleUI.BAD, true))
		return
	_box.add_child(IdleUI.label("Zejdź jak najgłębiej w sen: każde piętro to silniejsza zjawa i %d s walki. Po zwycięstwie wybierasz 1 z 3 błogosławieństw – kumulują się do końca snu. Za wynik dostajesz Okruchy Snu na stałe ulepszenia." % int(DreamManager.TIME), 18, UiTheme.TEXT, true))
	var c := IdleUI.card()
	var h := IdleUI.hbox(12)
	c.add_child(h)
	h.add_child(IdleUI.icon_rect(load("res://assets/ui/runes/mind.png"), 80))
	var v := IdleUI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(IdleUI.label("Rekord: piętro %d  •  Okruchy Snu: %d" % [d.best(), d.shards()], 22, Color(0.75, 0.65, 1.0), true))
	if d.free_runs() > 0:
		var b := IdleUI.button("Zaśnij (darmowy sen: %d)" % d.free_runs(), Vector2(0, 84), 24)
		IdleUI.set_affordable(b, d.can_enter())
		b.pressed.connect(func():
			if gm.dream.enter():
				ui.show_tab("fight"))
		v.add_child(b)
	else:
		var gb := IdleUI.button("Zaśnij za %d żarokr. (%d / %d dziś)" % [DreamManager.PAID_COST, d.paid_today(), DreamManager.PAID_LIMIT], Vector2(0, 80), 21)
		IdleUI.set_affordable(gb, d.can_enter(true))
		gb.pressed.connect(func():
			if gm.dream.enter(true):
				ui.show_tab("fight"))
		v.add_child(gb)
	_box.add_child(c)
	if not d.last_run.is_empty():
		var lr: Dictionary = d.last_run
		var names: Array = []
		for id in lr.blessings:
			names.append(str(DreamManager.BLESSINGS[id][0]))
		_box.add_child(IdleUI.label("Ostatni sen: %d pięter, +%d Okruchów Snu. Błogosławieństwa: %s" % [int(lr.floors), int(lr.shards), ", ".join(PackedStringArray(names)) if not names.is_empty() else "brak"], 17, IdleUI.GOLD_COL, true))
	_box.add_child(IdleUI.title("Drzewo Snu", 24))
	for id in DreamManager.TREE:
		var t: Array = DreamManager.TREE[id]
		var lv := d.tree_level(id)
		var res := row_card(null, "%s  •  %d / %d" % [t[0], lv, int(t[2])], str(t[1]), Color(0.75, 0.65, 1.0))
		if lv < int(t[2]):
			var ub := IdleUI.button("%d okruchów" % d.tree_cost(id), Vector2(150, 72), 19)
			IdleUI.set_affordable(ub, d.can_upgrade(id))
			var tid: String = id
			ub.pressed.connect(func():
				if gm.dream.upgrade(tid):
					request_refresh())
			res[1].add_child(ub)
		_box.add_child(res[0])
	_box.add_child(IdleUI.title("Błogosławieństwa", 24))
	for id in DreamManager.BLESSINGS:
		var bl: Array = DreamManager.BLESSINGS[id]
		_box.add_child(IdleUI.label("✦ %s – %s" % [bl[0], bl[1]], 17, Color(0.85, 0.8, 0.95), true))


func on_changed(what: String) -> void:
	if what in ["dream", "all"] and is_visible_in_tree():
		request_refresh()
