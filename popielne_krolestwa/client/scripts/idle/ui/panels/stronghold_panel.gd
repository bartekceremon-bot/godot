class_name StrongholdPanel
extends IdlePanel
## Twierdza Popielników: kolejka budowy z licznikami, przyspieszanie, lista budynków.

const DIR := "res://assets/ui/modes/"

var _box: VBoxContainer
## [etykieta, pasek, indeks w kolejce]
var _timers: Array = []
var _qsize := -1


func build() -> void:
	add_child(IdleUI.title("Twierdza Popielników", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	_timers.clear()
	var sh := gm.stronghold
	if not sh.unlocked():
		_box.add_child(IdleUI.label("Twierdza otwiera się po dotarciu do etapu %d." % StrongholdManager.UNLOCK_STAGE, 20, IdleUI.BAD, true))
		return
	sh.check_done()
	_qsize = sh.queue().size()
	_box.add_child(IdleUI.label("Rozbudowuj budynki za złoto – budowa trwa także przy zamkniętej grze. Premie są stałe i zostają po odrodzeniu.", 17, UiTheme.TEXT, true))
	# Kolejka
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	v.add_child(IdleUI.label("Budowniczowie: %d / %d wolnych" % [sh.free_builders(), sh.builders()], 20, UiTheme.ACCENT, true))
	for i in sh.queue().size():
		var q: Dictionary = sh.queue()[i]
		var b := str(q.b)
		var row := IdleUI.hbox(10)
		v.add_child(row)
		row.add_child(IdleUI.icon_rect(load(DIR + "sh_%s.png" % b), 48))
		var col := IdleUI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(IdleUI.label(tr("%s → poziom %d") % [tr(str(StrongholdManager.BUILDINGS[b][0])), sh.level(b) + 1], 18, Color(0.95, 0.92, 0.85), true))
		var pb := IdleUI.bar(Color(0.85, 0.65, 0.3), 20)
		var pl := IdleUI.bar_label(pb, 14)
		col.add_child(pb)
		var rb := IdleUI.button("", Vector2(150, 58), 16)
		var idx := i
		rb.pressed.connect(func():
			if not gm.stronghold.rush(idx):
				ui.toast_msg("Za mało żarokryształów.", IdleUI.BAD)
			request_refresh())
		row.add_child(rb)
		_timers.append([pl, pb, i, rb, sh.build_time(b)])
	if sh.queue().is_empty():
		v.add_child(IdleUI.label("Nic się nie buduje – wybierz budynek poniżej.", 16, IdleUI.DIM, true))
	else:
		var ad := IdleUI.button("▶ Pomocnicy: −30 min dla wszystkich budów", Vector2(0, 62), 18)
		ad.disabled = not gm.premium.ad_available("build_speed")
		ad.pressed.connect(func(): ui.ad_reward("build_speed", func(): request_refresh()))
		v.add_child(ad)
	if sh.builders() < 2:
		var bb := IdleUI.button("Drugi budowniczy (na stałe) – %d żarokr." % StrongholdManager.BUILDER_COST, Vector2(0, 62), 18)
		IdleUI.set_affordable(bb, int(gm.s.gems) >= StrongholdManager.BUILDER_COST)
		bb.pressed.connect(func():
			if gm.stronghold.buy_builder():
				ui.toast_msg("Nowy budowniczy dołączył do Twierdzy!", IdleUI.GOLD_COL)
			request_refresh())
		v.add_child(bb)
	_box.add_child(c)
	_tick_timers()
	# Budynki
	_box.add_child(IdleUI.label("Budynki (suma poziomów: %d)" % sh.total_levels(), 21, UiTheme.ACCENT))
	for b in StrongholdManager.ORDER:
		var d: Array = StrongholdManager.BUILDINGS[b]
		var lvl := sh.level(b)
		var desc := tr(str(d[1])) + "\n" + tr("Teraz: +%d%%") % int(round(sh.bonus(b) * 100.0))
		if lvl < StrongholdManager.MAX_LVL:
			desc += "  •  " + tr("koszt %s zł  •  %s") % [IdleDB.fmt(sh.cost(b)), tr(IdleDB.fmt_time(sh.build_time(b)))]
		var rc := row_card(load(DIR + "sh_%s.png" % b), tr("%s – poziom %d") % [tr(str(d[0])), lvl], desc, UiTheme.ACCENT, 64)
		var btn := IdleUI.button("MAX" if lvl >= StrongholdManager.MAX_LVL else ("W budowie" if sh.in_queue(b) else "Rozbuduj"), Vector2(150, 64), 18)
		IdleUI.set_affordable(btn, sh.can_build(b))
		btn.pressed.connect(func():
			if gm.stronghold.build(b):
				gm.audio.play("click")
			elif gm.stronghold.free_builders() <= 0:
				ui.toast_msg("Wszyscy budowniczowie są zajęci.", IdleUI.BAD)
			else:
				ui.toast_msg("Za mało złota.", IdleUI.BAD)
			request_refresh())
		rc[1].add_child(btn)
		_box.add_child(rc[0])


func _tick_timers() -> void:
	for t in _timers:
		var i := int(t[2])
		if i >= gm.stronghold.queue().size():
			continue
		var left := gm.stronghold.time_left(i)
		(t[0] as Label).text = IdleDB.fmt_time(left)
		(t[1] as ProgressBar).value = 1.0 - left / maxf(1.0, float(t[4]))
		var rb: Button = t[3]
		rb.text = tr("Ukończ\n%d żarokr.") % gm.stronghold.rush_cost(i)
		IdleUI.set_affordable(rb, int(gm.s.gems) >= gm.stronghold.rush_cost(i))


func tick_ui() -> void:
	if not is_visible_in_tree() or not gm.stronghold.unlocked():
		return
	if gm.stronghold.queue().size() != _qsize:
		request_refresh()
		return
	_tick_timers()


func on_changed(what: String) -> void:
	if what in ["stronghold", "all", "premium"]:
		request_refresh()
