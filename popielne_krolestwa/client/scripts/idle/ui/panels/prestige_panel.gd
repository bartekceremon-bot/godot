class_name PrestigePanel
extends IdlePanel
## Ołtarz Popiołu: Odrodzenie z Popiołu (prestiż) i stałe ulepszenia kupowane za Popiół Dusz.

var _list: VBoxContainer


func build() -> void:
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	var s := gm.s
	_list.add_child(IdleUI.title("Ołtarz Popiołu", 28))
	_list.add_child(IdleUI.label("Odrodzenie resetuje etapy, złoto, poziom, najemników, ekwipunek i surowce. Zostają czary, wierzchowce, żarokryształy, Kronika i ulepszenia Ołtarza. W zamian dostajesz Popiół Dusz.", 18, Color(0.85, 0.82, 0.76), true))
	var c := IdleUI.card(Color(0.08, 0.05, 0.05, 0.94), Color(1.0, 0.55, 0.3))
	_list.add_child(c)
	var v := IdleUI.vbox(8)
	c.add_child(v)
	var gain := gm.prestige.ash_gain()
	v.add_child(IdleUI.label("Popiół Dusz: %d  (zdobyty łącznie: %d, odrodzenia: %d)" % [int(s.ash), int(s.ash_total), int(s.rebirths)], 21, IdleUI.ASH_COL, true))
	if gm.prestige.can_rebirth():
		v.add_child(IdleUI.label("Najdalszy etap %d – odrodzenie da %d Popiołu Dusz (więcej, im dalej dojdziesz). Start od etapu %d." % [int(s.max_stage), gain, gm.prestige.start_stage()], 19, UiTheme.TEXT, true))
		var b := IdleUI.button("Odródź się z Popiołu (+%d)" % gain, Vector2(0, 90), 26)
		b.pressed.connect(func():
			ui.confirm("Odrodzenie z Popiołu", "Na pewno? Stracisz etapy, złoto, poziom, najemników, ekwipunek i surowce. Zyskasz %d Popiołu Dusz." % gain, func():
				gm.prestige.rebirth()
				ui.banner("ODRODZENIE!", "+%d Popiołu Dusz" % gain, Color(1.0, 0.55, 0.3))
				request_refresh()))
		v.add_child(b)
	else:
		v.add_child(IdleUI.label("Odrodzenie odblokujesz na etapie %d (teraz: %d)." % [gm.prestige.min_stage(), int(s.max_stage)], 19, IdleUI.DIM, true))
	_list.add_child(IdleUI.title("Ulepszenia Ołtarza", 24))
	for u in gm.db.prestige.upgrades:
		var id := str(u.id)
		var lvl := gm.prestige.level(id)
		var mx := int(u.get("max", 0))
		var rc := row_card(Sprites.icon("ash"), "%s  •  poz. %d%s" % [u.name, lvl, ("/%d" % mx) if mx > 0 else ""], str(u.text), UiTheme.ACCENT, 56)
		_list.add_child(rc[0])
		var b := IdleUI.button("Maks." if gm.prestige.maxed(id) else "%d popiołu" % gm.prestige.cost(id), Vector2(150, 72), 19)
		IdleUI.set_affordable(b, not gm.prestige.maxed(id) and int(s.ash) >= gm.prestige.cost(id))
		b.pressed.connect(func():
			if gm.prestige.buy(id):
				request_refresh())
		rc[1].add_child(b)


func on_changed(what: String) -> void:
	if what in ["prestige", "all"]:
		request_refresh()
