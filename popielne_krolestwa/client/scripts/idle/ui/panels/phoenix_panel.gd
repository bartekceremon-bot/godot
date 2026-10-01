class_name PhoenixPanel
extends IdlePanel
## Przebudzenie Feniksa: warunki, Pióra Feniksa, ulepszenia i przycisk przebudzenia.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Przebudzenie Feniksa", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var ph := gm.phoenix
	_box.add_child(IdleUI.label("Druga warstwa odrodzenia. Przebudzenie zeruje to co odrodzenie oraz Popiół Dusz i ulepszenia Ołtarza – w zamian daje Pióra Feniksa na potężne mnożniki. Talenty, runy, chowańce, bestiariusz, wieża, osiągnięcia i czary zostają.", 17, UiTheme.TEXT, true))
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	_box.add_child(c)
	v.add_child(IdleUI.label("Pióra Feniksa: %d  •  przebudzenia: %d" % [ph.feathers(), ph.count()], 24, Color(1.0, 0.6, 0.25)))
	v.add_child(IdleUI.label("Popiół Dusz od ostatniego przebudzenia: %d / %d  •  najdalszy etap: %d / %d" % [ph.ash_since(), PhoenixManager.MIN_ASH, int(gm.s.max_stage), PhoenixManager.MIN_STAGE], 17, Color(0.88, 0.84, 0.76), true))
	var b := IdleUI.button("Przebudź się (+%d piór)" % ph.feather_gain() if ph.can_awaken() else "Jeszcze nie czas", Vector2(0, 88), 26)
	IdleUI.set_affordable(b, ph.can_awaken())
	b.pressed.connect(func():
		ui.confirm("Przebudzenie Feniksa", "Zresetować Popiół Dusz, Ołtarz i postęp etapów w zamian za %d Piór Feniksa?" % gm.phoenix.feather_gain(), func():
			if gm.phoenix.awaken():
				ui.banner("PRZEBUDZENIE!", "Powstajesz z ognia silniejszy", Color(1.0, 0.55, 0.2))
			request_refresh()))
	v.add_child(b)
	for u in PhoenixManager.UPGRADES:
		var id := str(u.id)
		var lv := ph.level(id)
		var per := float(u.per)
		var fmt := func(x: float) -> String:
			if id in ["flame", "gold"]:
				return "%.1f" % (1.0 + x)
			if id in ["memory", "wisdom"]:
				return str(int(x))
			return "%d%%" % roundi(x * 100.0)
		var desc := "Teraz: %s  •  dalej: %s" % [str(u.text) % fmt.call(per * lv), str(u.text) % fmt.call(per * (lv + 1))]
		var res := row_card(Sprites.icon("prestige"), "%s  poz. %d%s" % [u.name, lv, "" if int(u.max) == 0 else " / %d" % int(u.max)], desc, Color(1.0, 0.6, 0.25), 56)
		var bb := IdleUI.button("MAKS" if ph.maxed(id) else "%d piór" % ph.cost(id), Vector2(130, 76), 20)
		IdleUI.set_affordable(bb, not ph.maxed(id) and ph.feathers() >= ph.cost(id))
		bb.pressed.connect(func():
			gm.phoenix.buy(id)
			request_refresh())
		res[1].add_child(bb)
		_box.add_child(res[0])


func on_changed(what: String) -> void:
	if what in ["phoenix", "prestige", "all"]:
		request_refresh()
