class_name ExpeditionsPanel
extends IdlePanel
## Wyprawy: trwające wyprawy (czas, odbiór, przyspieszenie) i wysyłanie nowych – wybór krainy
## i długości z podglądem nagród.

var _region := 0
var _list: VBoxContainer
var _timers: Array = []


func build() -> void:
	add_child(IdleUI.title("Wyprawy", 28))
	add_child(IdleUI.label("Zwiadowcy wyruszają do odkrytych krain i wracają z łupem – także wtedy, gdy gra jest zamknięta.", 17, IdleUI.DIM, true))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]
	_region = maxi(0, gm.expeditions.regions_open() - 1)


func refresh() -> void:
	IdleUI.clear(_list)
	_timers.clear()
	var ex := gm.expeditions
	_list.add_child(IdleUI.label("W drodze: %d / %d  (sloty: etap 20, etap 50, 10. piętro Wieży)" % [ex.active().size(), ex.slots()], 18, UiTheme.ACCENT, true))
	for i in ex.active().size():
		_list.add_child(_active_card(i))
	_list.add_child(IdleUI.spacer(6))
	_list.add_child(IdleUI.title("Nowa wyprawa", 24))
	var regs := IdleUI.hbox(6)
	var rsc := ScrollContainer.new()
	rsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rsc.custom_minimum_size = Vector2(0, 72)
	rsc.add_child(regs)
	_list.add_child(rsc)
	for r in ex.regions_open():
		var b := IdleUI.button(str(gm.db.regions[r].name), Vector2(0, 62), 18)
		b.toggle_mode = true
		b.set_pressed_no_signal(r == _region)
		var rr: int = r
		b.pressed.connect(func():
			_region = rr
			request_refresh())
		regs.add_child(b)
	var free := ex.active().size() < ex.slots()
	for d in ExpeditionManager.DURATIONS.size():
		var dd: Dictionary = ExpeditionManager.DURATIONS[d]
		var p := ex.preview(_region, d)
		var res := row_card(Sprites.icon("map"), "%s  •  %s" % [dd.name, IdleDB.fmt_time(ex.duration_sec(d))], _reward_text(p))
		var btn := IdleUI.button("Wyślij", Vector2(130, 76), 22)
		IdleUI.set_affordable(btn, free)
		var di: int = d
		btn.pressed.connect(func():
			if gm.expeditions.start(_region, di):
				Sfx.play("click")
			request_refresh())
		res[1].add_child(btn)
		_list.add_child(res[0])


func _reward_text(p: Dictionary) -> String:
	var parts := ["%s zł" % IdleDB.fmt(float(p.gold)), "%d surowców" % int(p.mats)]
	var ch: Array = p.chest
	parts.append(("%d%% szans: " % roundi(float(ch[0]) * 100.0) if float(ch[0]) < 1.0 else "") + LootManager.CHEST_NAMES[int(ch[1])])
	if int(p.gems) > 0:
		parts.append("%d żarokr." % int(p.gems))
	if float(p.frag) > 0.0:
		parts.append("%d%% fragmenty wierzchowców" % roundi(float(p.frag) * 100.0))
	return ", ".join(PackedStringArray(parts))


func _active_card(i: int) -> Control:
	var e: Dictionary = gm.expeditions.active()[i]
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	v.add_child(IdleUI.label("%s – %s" % [ExpeditionManager.DURATIONS[int(e.dur)].name, gm.db.regions[int(e.reg)].name], 21, UiTheme.ACCENT, true))
	var pb := IdleUI.bar(Color(0.85, 0.6, 0.25), 24)
	var pl := IdleUI.bar_label(pb, 15)
	v.add_child(pb)
	var row := IdleUI.hbox(8)
	v.add_child(row)
	var claim := IdleUI.button("Odbierz łup", Vector2(0, 72), 22)
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := i
	claim.pressed.connect(func():
		var got := gm.expeditions.claim(idx)
		if not got.is_empty():
			gm.audio.play("rare")
			ui.toast_msg("Wyprawa wróciła: " + ", ".join(PackedStringArray(got.slice(0, 4).map(func(it): return "%s %s" % [IdleDB.fmt(float(it[1])), IdleUI.item_name(gm.db, str(it[0]))]))), IdleUI.GOLD_COL)
		request_refresh())
	row.add_child(claim)
	var rush := IdleUI.button("", Vector2(200, 72), 18)
	rush.pressed.connect(func():
		if not gm.expeditions.rush(idx):
			ui.toast_msg("Za mało żarokryształów.", IdleUI.BAD)
		request_refresh())
	row.add_child(rush)
	_timers.append([i, pb, pl, claim, rush, float(e.end) - float(e.start)])
	_tick_one(_timers.back())
	return c


func _tick_one(t: Array) -> void:
	if int(t[0]) >= gm.expeditions.active().size():
		return
	var left := gm.expeditions.time_left(int(t[0]))
	(t[1] as ProgressBar).value = 1.0 - left / maxf(1.0, float(t[5]))
	(t[2] as Label).text = "Powrót za %s" % IdleDB.fmt_time(left) if left > 0.0 else "Wróciła!"
	(t[3] as Button).disabled = left > 0.0
	(t[4] as Button).visible = left > 0.0
	(t[4] as Button).text = "Teraz: %d żarokr." % gm.expeditions.rush_cost(int(t[0]))


func tick_ui() -> void:
	for t in _timers:
		_tick_one(t)


func on_changed(what: String) -> void:
	if what in ["exped", "all"]:
		request_refresh()
