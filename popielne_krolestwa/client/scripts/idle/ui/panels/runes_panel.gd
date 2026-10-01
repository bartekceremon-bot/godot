class_name RunesPanel
extends IdlePanel
## Runy: gniazda sześciu slotów ekwipunku (dotknij gniazda – włóż / wyjmij runę),
## suma premii, posiadane runy i łączenie 3 → 1 wyższego stopnia.

var _list: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Runy", 28))
	add_child(IdleUI.label("Gniazda należą do slotów ekwipunku – runy zostają przy zmianie przedmiotów i po odrodzeniu.", 17, IdleUI.DIM, true))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	var rm := gm.runes
	var tot := rm.totals()
	var parts: Array = []
	for k in RuneManager.KINDS:
		var stat: String = RuneManager.KINDS[k].stat
		if tot.has(stat):
			parts.append("+%d%% %s" % [roundi(float(tot[stat]) * 100.0), RuneManager.KINDS[k].text])
	_list.add_child(IdleUI.label("Moc run: " + (", ".join(PackedStringArray(parts)) if not parts.is_empty() else "brak – włóż runy w gniazda"), 18, UiTheme.ACCENT, true))
	for slot in IdleDB.SLOTS:
		var c := IdleUI.card()
		var h := IdleUI.hbox(10)
		c.add_child(h)
		var name_l := IdleUI.label(str(IdleDB.SLOT_NAMES.get(slot, slot)), 20, UiTheme.ACCENT)
		name_l.custom_minimum_size = Vector2(130, 0)
		h.add_child(name_l)
		var sk := rm.sockets(slot)
		for i in sk.size():
			h.add_child(_socket_button(slot, i, str(sk[i])))
		if sk.size() <= RuneManager.BASE_SOCKETS:
			var buy := IdleUI.button("+ gniazdo\n%d żarokr." % RuneManager.THIRD_SOCKET_GEMS, Vector2(130, 84), 15)
			var sl: String = slot
			buy.pressed.connect(func():
				if not gm.runes.buy_socket(sl):
					ui.toast_msg("Za mało żarokryształów.", IdleUI.BAD)
				request_refresh())
			h.add_child(buy)
		_list.add_child(c)
	_list.add_child(IdleUI.spacer(6))
	_list.add_child(IdleUI.title("Posiadane runy", 24))
	var own := rm.owned()
	if own.is_empty():
		_list.add_child(IdleUI.label("Runy wypadają z bossów i elit (od etapu 10), z Wieży Popiołu, długich wypraw i skrzyń.", 18, IdleUI.DIM, true))
	for id in own:
		var p := RuneManager.parse(id)
		var n := gm.inventory.count(id)
		var res := row_card(IdleUI.item_tex(gm.db, id), "%s  ×%d" % [RuneManager.rune_name(id), n], RuneManager.describe(id), RuneManager.KINDS[p[0]].color, 60)
		if int(p[1]) < 5:
			var cost := rm.combine_cost(int(p[1]))
			var b := IdleUI.button("Połącz 3 → 1\n%s zł" % IdleDB.fmt(cost), Vector2(170, 80), 16)
			IdleUI.set_affordable(b, n >= 3 and float(gm.s.gold) >= cost)
			var kind: String = p[0]
			var tier: int = int(p[1])
			b.pressed.connect(func():
				if gm.runes.combine(kind, tier):
					ui.toast_msg("Powstała: %s!" % RuneManager.rune_name(RuneManager.rid(kind, tier + 1)), RuneManager.KINDS[kind].color)
				request_refresh())
			res[1].add_child(b)
		_list.add_child(res[0])


func _socket_button(slot: String, i: int, id: String) -> Button:
	var b := IdleUI.ash_button("slot", 18)
	b.custom_minimum_size = Vector2(84, 84)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if id != "":
		b.icon = IdleUI.item_tex(gm.db, id)
		var t := IdleUI.hud_label(["I", "II", "III", "IV", "V"][clampi(int(RuneManager.parse(id)[1]) - 1, 0, 4)], 16, Color(1, 0.9, 0.7), 4)
		t.position = Vector2(6, 2)
		b.add_child(t)
	else:
		b.text = "+"
	b.pressed.connect(func():
		Sfx.play("click")
		if id != "":
			gm.runes.unsocket(slot, i)
			request_refresh()
		else:
			_pick(slot, i))
	return b


## Okno wyboru runy do gniazda (najmocniejsze na górze).
func _pick(slot: String, i: int) -> void:
	var own := gm.runes.owned()
	if own.is_empty():
		ui.toast_msg("Nie masz run – zdobywaj je na bossach, w Wieży i na wyprawach.", IdleUI.BAD)
		return
	own.sort_custom(func(a, b): return int(RuneManager.parse(a)[1]) > int(RuneManager.parse(b)[1]))
	var v := IdleUI.vbox(8)
	var m: Control
	for id in own:
		var b := IdleUI.button("%s  ×%d   (%s)" % [RuneManager.rune_name(id), gm.inventory.count(id), RuneManager.describe(id)], Vector2(0, 76), 19)
		b.icon = IdleUI.item_tex(gm.db, id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rid: String = id
		b.pressed.connect(func():
			ui.close_modal(m)
			gm.runes.socket(slot, i, rid)
			request_refresh())
		v.add_child(b)
	m = ui.modal("Wybierz runę – %s" % IdleDB.SLOT_NAMES.get(slot, slot), v)


func on_changed(what: String) -> void:
	if what in ["runes", "inventory", "all"]:
		request_refresh()
