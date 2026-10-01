class_name GardenPanel
extends IdlePanel
## Ogród Alchemika: grządki (sadzenie wybranego ziela, podlewanie, zbiór), nasiona,
## kocioł z przepisami i zapas eliksirów.

const DIR := "res://assets/ui/modes/"

var _box: VBoxContainer
var _seed := "ember_root"
## [pasek, etykieta, indeks grządki] – odświeżane w tick_ui.
var _bars: Array = []
var _states: Array = []


func build() -> void:
	add_child(IdleUI.title("Ogród Alchemika", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


static func herb_tex(h: String) -> Texture2D:
	return load(DIR + "herb_%s.png" % h)


static func elixir_tex(r: String) -> Texture2D:
	return load(DIR + "elixir_%s.png" % r)


func refresh() -> void:
	IdleUI.clear(_box)
	_bars.clear()
	var g := gm.garden
	if not g.unlocked():
		_box.add_child(IdleUI.label("Ogród otwiera się po dotarciu do etapu %d." % GardenManager.UNLOCK_STAGE, 20, IdleUI.BAD, true))
		return
	if not g.herb_unlocked(_seed):
		_seed = "ember_root"
	_states = []
	for i in GardenManager.PLOT_STAGES.size():
		_states.append(g.state(i))
	_box.add_child(IdleUI.label("Zioła rosną także przy zamkniętej grze. Zebrane warzysz w kotle na eliksiry, które wzmacniają bohatera na czas. Podlanie skraca pozostały czas wzrostu o 30%.", 17, UiTheme.TEXT, true))
	_build_header()
	_build_plots()
	_build_seeds()
	_build_cauldron()


func _build_header() -> void:
	var g := gm.garden
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	var h := IdleUI.hbox(12)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(load(DIR + "garden.png"), 72))
	var t := IdleUI.vbox(4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(IdleUI.label("Zielarstwo – poziom %d" % g.level(), 22, Color(0.55, 0.95, 0.45), true))
	t.add_child(IdleUI.label("Plon: %d ziół z grządki  •  wzrost −%d%%" % [g.base_yield(), 2 * (g.level() - 1)], 17, Color(0.82, 0.8, 0.74), true))
	if g.level() < GardenManager.MAX_LVL:
		var pb := IdleUI.bar(Color(0.35, 0.8, 0.3), 22)
		pb.value = float(g.xp()) / float(g.xp_need())
		IdleUI.bar_label(pb, 16).text = "%d / %d" % [g.xp(), g.xp_need()]
		t.add_child(pb)
	var row := IdleUI.hbox(8)
	v.add_child(row)
	var hb := IdleUI.button("Zbierz wszystko (%d)" % g.ready_count(), Vector2(0, 70), 20)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	IdleUI.set_affordable(hb, g.ready_count() > 0)
	hb.pressed.connect(_harvest_all)
	row.add_child(hb)
	var wb := IdleUI.button("Podlej wszystko", Vector2(0, 70), 20)
	wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var can_w := false
	for i in GardenManager.PLOT_STAGES.size():
		can_w = can_w or g.can_water(i)
	IdleUI.set_affordable(wb, can_w)
	wb.pressed.connect(func():
		if gm.garden.water_all() > 0:
			gm.audio.play("click")
		request_refresh())
	row.add_child(wb)
	var ad := IdleUI.button("▶ Nawóz Żaru: wszystko od razu gotowe", Vector2(0, 66), 19)
	ad.disabled = not gm.premium.ad_available("garden_grow")
	ad.pressed.connect(func(): ui.ad_reward("garden_grow", func(): request_refresh()))
	v.add_child(ad)
	_box.add_child(c)


func _build_plots() -> void:
	var g := gm.garden
	_box.add_child(IdleUI.label("Grządki (%d / %d)" % [g.plot_count(), GardenManager.PLOT_STAGES.size()], 21, UiTheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	for i in GardenManager.PLOT_STAGES.size():
		var st := g.state(i)
		var c := IdleUI.card(Color(0.09, 0.07, 0.05, 0.9) if st != "locked" else Color(0.05, 0.05, 0.06, 0.8))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := IdleUI.vbox(4)
		c.add_child(v)
		var h := str(g.plot(i).herb)
		var tex: Texture2D = herb_tex(h) if h != "" else null
		var ic := IdleUI.icon_rect(tex if tex else load(DIR + "garden.png"), 64)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if st == "locked" or st == "empty":
			ic.modulate = Color(0.35, 0.3, 0.28, 0.8)
		v.add_child(ic)
		var name_text := ""
		match st:
			"locked":
				name_text = "🔒 etap %d" % int(GardenManager.PLOT_STAGES[i])
			"empty":
				name_text = "Pusta grządka"
			_:
				name_text = GardenManager.herb_name(h)
		var nl := IdleUI.label(name_text, 16, Color(0.95, 0.92, 0.85), true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		if st == "growing" or st == "ready":
			var pb := IdleUI.bar(Color(0.4, 0.85, 0.3) if st == "ready" else Color(0.85, 0.65, 0.25), 20)
			pb.value = g.progress(i)
			var pl := IdleUI.bar_label(pb, 14)
			v.add_child(pb)
			_bars.append([pb, pl, i])
		var b: Button = null
		match st:
			"empty":
				b = IdleUI.button("Posadź", Vector2(0, 56), 18)
				IdleUI.set_affordable(b, g.can_plant(i, _seed))
				b.pressed.connect(func():
					if gm.garden.plant(i, _seed):
						gm.audio.play("click")
					else:
						ui.toast_msg("Za mało złota.", IdleUI.BAD)
					request_refresh())
			"growing":
				b = IdleUI.button("Podlej" if g.can_water(i) else "Podlane", Vector2(0, 56), 18)
				IdleUI.set_affordable(b, g.can_water(i))
				b.pressed.connect(func():
					gm.garden.water(i)
					request_refresh())
			"ready":
				b = IdleUI.button("Zbierz", Vector2(0, 56), 18)
				b.pressed.connect(func():
					var r := gm.garden.harvest(i)
					if not r.is_empty():
						gm.audio.play("coin")
						ui.toast_msg(tr("Obfity zbiór! +%d× %s" if bool(r[2]) else "+%d× %s") % [int(r[1]), tr(GardenManager.herb_name(str(r[0])))], Color(0.55, 0.95, 0.45))
					request_refresh())
		if b:
			v.add_child(b)
		grid.add_child(c)
	_update_bars()


func _build_seeds() -> void:
	var g := gm.garden
	_box.add_child(IdleUI.label("Nasiona – wybierz, co sadzić", 21, UiTheme.ACCENT))
	for h in GardenManager.HERB_ORDER:
		var ok := g.herb_unlocked(h)
		var desc := "Wzrost %s  •  koszt %s zł  •  masz: %d" % [IdleDB.fmt_time(g.grow_time(h)), IdleDB.fmt(g.herb_cost(h)), g.herbs(h)] if ok else "🔒 etap %d" % int(GardenManager.HERBS[h][2])
		var hcol: Color = GardenManager.HERBS[h][4] if ok else IdleUI.DIM
		var rc := row_card(herb_tex(h), GardenManager.herb_name(h), desc, hcol, 56)
		if ok:
			var sel: bool = h == _seed
			var b := IdleUI.button("Wybrane" if sel else "Wybierz", Vector2(150, 60), 18)
			b.disabled = sel
			b.pressed.connect(func():
				_seed = h
				request_refresh())
			rc[1].add_child(b)
			if sel and g.empty_count() > 0:
				var all := IdleUI.button("Posadź\nwszędzie", Vector2(130, 60), 16)
				IdleUI.set_affordable(all, g.can_plant(_first_empty(), h))
				all.pressed.connect(func():
					var n := gm.garden.plant_all(h)
					if n == 0:
						ui.toast_msg("Za mało złota.", IdleUI.BAD)
					request_refresh())
				rc[1].add_child(all)
		_box.add_child(rc[0])


func _first_empty() -> int:
	for i in GardenManager.PLOT_STAGES.size():
		if gm.garden.state(i) == "empty":
			return i
	return 0


func _build_cauldron() -> void:
	var g := gm.garden
	var hh := IdleUI.hbox(10)
	hh.add_child(IdleUI.icon_rect(load(DIR + "cauldron.png"), 48))
	hh.add_child(IdleUI.label("Kocioł – przepisy", 21, UiTheme.ACCENT))
	_box.add_child(hh)
	for r in GardenManager.RECIPE_ORDER:
		var rec: Array = GardenManager.RECIPES[r]
		var parts: Array = []
		var need: Dictionary = rec[1]
		for h in need:
			parts.append(tr("%d× %s (%d)") % [int(need[h]), tr(GardenManager.herb_name(h)), g.herbs(h)])
		var desc := tr(str(rec[4])) + "\n" + ", ".join(parts)
		var rc := row_card(elixir_tex(r), str(rec[0]), desc, UiTheme.ACCENT, 56)
		var bv := IdleUI.vbox(6)
		rc[1].add_child(bv)
		var bb := IdleUI.button("Uwarz", Vector2(140, 56), 18)
		IdleUI.set_affordable(bb, g.can_brew(r))
		bb.pressed.connect(func():
			if gm.garden.brew(r):
				ui.toast_msg("Uwarzono: %s" % str(GardenManager.RECIPES[r][0]), Color(0.55, 0.95, 0.45))
			request_refresh())
		bv.add_child(bb)
		var db := IdleUI.button("Wypij (%d)" % g.elixirs(r), Vector2(140, 56), 18)
		IdleUI.set_affordable(db, g.elixirs(r) > 0)
		db.pressed.connect(func():
			if gm.garden.drink(r):
				ui.toast_msg("%s: %s" % [tr(str(GardenManager.RECIPES[r][0])), tr(str(GardenManager.RECIPES[r][4]))], IdleUI.GOLD_COL)
			request_refresh())
		bv.add_child(db)
		var st := str(rec[2][0][0])
		var left := gm.crafting.boost_left(st)
		if left > 0.0:
			rc[2].text += "\n" + tr("Aktywne: %s") % tr(IdleDB.fmt_time(left))
		_box.add_child(rc[0])


func _update_bars() -> void:
	for e in _bars:
		var i := int(e[2])
		var pb: ProgressBar = e[0]
		var l: Label = e[1]
		pb.value = gm.garden.progress(i)
		l.text = "Gotowe!" if gm.garden.state(i) == "ready" else IdleDB.fmt_time(gm.garden.time_left(i))


func tick_ui() -> void:
	if not is_visible_in_tree() or not gm.garden.unlocked():
		return
	_update_bars()
	for i in mini(_states.size(), GardenManager.PLOT_STAGES.size()):
		if gm.garden.state(i) != str(_states[i]):
			request_refresh()
			return


func _harvest_all() -> void:
	var got := gm.garden.harvest_all()
	if got.is_empty():
		return
	var parts: Array = []
	for h in got:
		parts.append(tr("+%d× %s") % [int(got[h]), tr(GardenManager.herb_name(str(h)))])
	ui.toast_msg(", ".join(parts), Color(0.55, 0.95, 0.45))
	request_refresh()


func on_changed(what: String) -> void:
	if what in ["garden", "all", "premium", "boosts"]:
		request_refresh()
