class_name WeeklyPanel
extends IdlePanel
## Wyzwania tygodnia: 7 celów z nagrodami i nagroda za komplet.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Wyzwania tygodnia", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var w := gm.weekly
	_box.add_child(IdleUI.label("Nowe wyzwania za %d dni. Wykonaj wszystkie 7, by zdobyć wielką nagrodę tygodnia." % WeeklyManager.days_left(), 18, UiTheme.TEXT, true))
	var gs := w.goals()
	for i in gs.size():
		var g: Array = gs[i]
		var done := w.done(i)
		var cl := w.claimed(i)
		var res := row_card(Sprites.icon("quest"), str(g[1]) % int(g[2]), "Nagroda: " + WeeklyManager.reward_text(WeeklyManager.GOAL_REWARDS[i]), IdleUI.GOOD if cl else UiTheme.ACCENT, 52)
		var pb := IdleUI.bar(Color(0.85, 0.6, 0.2), 18)
		pb.value = w.progress(i) / float(g[2])
		res[2].get_parent().add_child(pb)
		res[2].get_parent().add_child(IdleUI.label("%s / %s" % [IdleDB.fmt(w.progress(i)), IdleDB.fmt(float(g[2]))], 15, IdleUI.DIM))
		if cl:
			res[1].add_child(IdleUI.label("✔", 30, IdleUI.GOOD))
		elif done:
			var b := IdleUI.button("Odbierz", Vector2(130, 72), 20)
			var idx := i
			b.pressed.connect(func():
				for it in gm.weekly.claim(idx):
					ui.toast_msg("+%d %s" % [int(it[1]), _name(str(it[0]))], IdleUI.GOLD_COL)
				request_refresh())
			res[1].add_child(b)
		_box.add_child(res[0])
	var fin := row_card(Sprites.icon("chest"), "Komplet tygodnia", "Nagroda: " + WeeklyManager.reward_text(WeeklyManager.FINAL_REWARD), IdleUI.GOLD_COL, 64)
	if bool(gm.s.weekly.final):
		fin[1].add_child(IdleUI.label("✔", 30, IdleUI.GOOD))
	else:
		var fb := IdleUI.button("Odbierz", Vector2(130, 72), 20)
		IdleUI.set_affordable(fb, w.final_ready())
		fb.pressed.connect(func():
			var got := gm.weekly.claim_final()
			if not got.is_empty():
				ui.banner("KOMPLET TYGODNIA!", WeeklyManager.reward_text(WeeklyManager.FINAL_REWARD), IdleUI.GOLD_COL)
			request_refresh())
		fin[1].add_child(fb)
	_box.add_child(fin[0])


func _name(id: String) -> String:
	match id:
		"shards":
			return "odłamków relikwii"
		"seals":
			return "Pieczęć Przebudzenia"
	return IdleUI.item_name(gm.db, id)


func on_changed(what: String) -> void:
	if what in ["weekly", "all"] and is_visible_in_tree():
		request_refresh()
