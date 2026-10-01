class_name TitlesPanel
extends IdlePanel
## Tytuły bohatera: lista z postępem, noszony tytuł i jego premia.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Tytuły", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var tm := gm.titles
	tm.check()
	var cur := tm.active()
	var head := tr("Noszony tytuł: %s") % (tr(TitleManager.title_name(cur)) + "  (" + tm.bonus_text(cur) + ")" if cur != "" else tr("brak"))
	_box.add_child(IdleUI.label(head, 21, IdleUI.GOLD_COL, true))
	_box.add_child(IdleUI.label(tr("Zdobyte: %d / %d  •  tytuły zostają na zawsze, nosić można jeden.") % [tm.owned_count(), TitleManager.TITLES.size()], 17, UiTheme.TEXT, true))
	for t in TitleManager.TITLES:
		var id := str(t[0])
		var own := tm.owned(id)
		var prog := tm.value(str(t[3]))
		var desc := tr(str(t[2])) % int(t[4]) + "\n" + tm.bonus_text(id)
		if not own:
			desc += "  •  " + "%s / %s" % [IdleDB.fmt(minf(prog, float(t[4]))), IdleDB.fmt(float(t[4]))]
		var col: Color = IdleUI.GOLD_COL if id == cur else (UiTheme.ACCENT if own else IdleUI.DIM)
		var rc := row_card(load("res://assets/ui/modes/badge.png"), str(t[1]), desc, col, 52)
		if own:
			var b := IdleUI.button("Noszony" if id == cur else "Noś", Vector2(130, 60), 18)
			b.disabled = id == cur
			b.pressed.connect(func():
				gm.titles.wear(id)
				request_refresh())
			rc[1].add_child(b)
		_box.add_child(rc[0])


func on_changed(what: String) -> void:
	if what in ["titles", "all"] and is_visible_in_tree():
		request_refresh()
