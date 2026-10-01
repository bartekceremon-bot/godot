class_name TowerPanel
extends IdlePanel
## Wieża Popiołu: rekord, próby, następne piętro, nagrody i wejście.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Wieża Popiołu", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var t := gm.tower
	_box.add_child(IdleUI.label("Bossowie wszystkich krain na kolejnych piętrach. 30 sekund na każde piętro – zwycięstwo prowadzi od razu wyżej, porażka kończy wspinaczkę. Rekord daje stałe nagrody.", 18, UiTheme.TEXT, true))
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	_box.add_child(c)
	v.add_child(IdleUI.label("Rekord: piętro %d" % t.best(), 26, UiTheme.ACCENT))
	var nf := t.best() + 1
	var m := t.floor_monster(nf)
	v.add_child(IdleUI.label("Następne: piętro %d – %s (zdrowie %s)" % [nf, m[1], IdleDB.fmt(t.boss_hp(nf))], 19, Color(0.92, 0.88, 0.8), true))
	v.add_child(IdleUI.label("Twój DPS: %s  •  cios: %s  •  potrzeba ok. %s obrażeń na sekundę" % [IdleDB.fmt(gm.stats.dps), IdleDB.fmt(gm.stats.click), IdleDB.fmt(t.boss_hp(nf) / TowerManager.TIME)], 17, IdleUI.DIM, true))
	v.add_child(IdleUI.label("Nagrody: żarokryształy za każde piętro, skrzynia co 5 pięter, punkt talentu za każde 5 pięter rekordu, dodatkowy slot wyprawy za 10. piętro.", 17, IdleUI.GOLD_COL, true))
	v.add_child(IdleUI.label("Próby na dziś: %d / %d" % [t.attempts(), TowerManager.DAILY_ATTEMPTS], 20, IdleUI.GOOD if t.attempts() > 0 else IdleUI.BAD))
	var b := IdleUI.button("Wejdź do Wieży" if t.attempts() > 0 else "Wejdź za %d żarokryształów" % TowerManager.EXTRA_COST, Vector2(0, 92), 28)
	b.pressed.connect(func():
		if gm.tower.enter(true):
			ui.show_tab("fight")
			ui.banner("WIEŻA POPIOŁU", "Piętro %d" % gm.tower.floor_n, Color(1.0, 0.6, 0.3))
		else:
			ui.toast_msg("Za mało żarokryształów.", IdleUI.BAD))
	v.add_child(b)
	if not t.last_run.is_empty():
		var lr: Dictionary = t.last_run
		_box.add_child(IdleUI.label("Ostatnia wspinaczka: piętra %d → %d, +%d żarokryształów, skrzynie: %d (%s)." % [int(lr.from) + 1, int(lr.reached), int(lr.gems), lr.chests.size(), lr.reason], 17, Color(0.85, 0.82, 0.76), true))


func on_changed(what: String) -> void:
	if what in ["tower", "all"]:
		request_refresh()
