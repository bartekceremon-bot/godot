class_name MasteryPanel
extends IdlePanel
## Mistrzostwo broni: poziomy pięciu rodzajów broni, paski doświadczenia i premie.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Mistrzostwo broni", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var m := gm.mastery
	_box.add_child(IdleUI.label("Każdy pokonany wróg rozwija mistrzostwo broni, którą trzymasz (elity i bossowie – więcej). Premie ze wszystkich rodzajów działają zawsze i zostają po odrodzeniu – warto czasem zmienić broń w Ekwipunku.", 17, UiTheme.TEXT, true))
	_box.add_child(IdleUI.label("Suma poziomów: %d / %d" % [m.total_levels(), MasteryManager.MAX_LVL * MasteryManager.ORDER.size()], 20, UiTheme.ACCENT))
	var cur := m.current()
	for t in MasteryManager.ORDER:
		var d: Array = MasteryManager.TYPES[t]
		var lvl := m.level(t)
		var title_text := tr("%s – poziom %d") % [tr(str(d[0])), lvl]
		if t == cur:
			title_text += "  " + tr("(w ręku)")
		var desc := tr(str(d[1])) + "\n" + tr("Teraz: +%d%%") % int(round(m.bonus(t) * 100.0))
		var rc := row_card(IdleUI.item_tex(gm.db, str(d[4])), title_text, desc, IdleUI.GOLD_COL if t == cur else UiTheme.ACCENT, 64)
		var v: VBoxContainer = rc[2].get_parent()
		var pb := IdleUI.bar(Color(1.0, 0.7, 0.3) if t == cur else Color(0.6, 0.55, 0.5), 20)
		if lvl >= MasteryManager.MAX_LVL:
			pb.value = 1.0
			IdleUI.bar_label(pb, 14).text = "MAX"
		else:
			pb.value = float(m.xp(t)) / float(MasteryManager.need(lvl))
			IdleUI.bar_label(pb, 14).text = "%d / %d" % [m.xp(t), MasteryManager.need(lvl)]
		v.add_child(pb)
		_box.add_child(rc[0])


func on_changed(what: String) -> void:
	if what in ["mastery", "gear", "all"]:
		request_refresh()
