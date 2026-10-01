class_name HeroesPanel
extends IdlePanel
## Zakładka WALKA: Trening ciosu (obrażenia kliknięcia) i Najemnicy (DPS) – główny wydatek złota.

const MODES := [1, 10, 100, 0]

var _mode := 0
var _mode_btn: Button
var _list: VBoxContainer
var _rows: Array = []
var _sum: Label


func build() -> void:
	var head := IdleUI.hbox(10)
	add_child(head)
	var t := IdleUI.title("Drużyna", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_mode_btn = IdleUI.button("×1", Vector2(130, 64), 22)
	_mode_btn.pressed.connect(func():
		_mode = (_mode + 1) % MODES.size()
		request_refresh())
	head.add_child(_mode_btn)
	_sum = IdleUI.label("", 18, Color(0.9, 0.86, 0.76), true)
	add_child(_sum)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func _count() -> int:
	return MODES[_mode]


func refresh() -> void:
	_mode_btn.text = "×%d" % _count() if _count() > 0 else "MAKS"
	IdleUI.clear(_list)
	_rows.clear()
	var tr := row_card(Sprites.icon("attack"), "", "")
	_list.add_child(tr[0])
	var b := IdleUI.button("", Vector2(190, 84), 19)
	b.pressed.connect(func():
		if gm.mercs.buy_train(_count()):
			request_refresh())
	tr[1].add_child(b)
	_rows.append({"id": "", "btn": b, "title": tr[3], "desc": tr[2]})
	for d in gm.mercs.visible_list():
		var id := str(d.id)
		var r := row_card(Sprites.icon("people"), "", "")
		_list.add_child(r[0])
		var mb := IdleUI.button("", Vector2(190, 84), 19)
		mb.pressed.connect(func():
			if gm.mercs.buy(id, _count()):
				request_refresh())
		r[1].add_child(mb)
		var ab := IdleUI.button("", Vector2(120, 84), 17)
		ab.pressed.connect(func():
			if gm.mercs.awaken(id):
				ui.banner("PRZEBUDZENIE", "%s ★%d – DPS ×%d" % [gm.db.merc_def(id).name, gm.mercs.stars(id), int(MercenaryManager.STAR_MULT)], Color(1.0, 0.85, 0.35))
				request_refresh())
		r[1].add_child(ab)
		r[1].move_child(ab, 0)
		_rows.append({"id": id, "btn": mb, "title": r[3], "desc": r[2], "awaken": ab})
	tick_ui()


func tick_ui() -> void:
	var st := gm.stats
	_sum.text = "Klik: %s   •   DPS drużyny: %s   •   Najemnicy: %s DPS" % [IdleDB.fmt(st.click), IdleDB.fmt(st.dps), IdleDB.fmt(st.merc_dps)]
	if gm.mercs.seals() > 0 or not gm.s.get("merc_stars", {}).is_empty():
		_sum.text += "\nPieczęcie Przebudzenia: %d  (najemnik od poz. 100: gwiazdka = DPS ×3)" % gm.mercs.seals()
	for r in _rows:
		var id := str(r.id)
		var n := _count()
		var b: Button = r.btn
		if id == "":
			var lvl := int(gm.s.train_lvl)
			if n <= 0:
				n = maxi(1, gm.mercs.affordable(MercenaryManager.TRAIN_BASE, lvl))
			var c := gm.mercs.train_cost(n)
			r.title.text = "Trening ciosu  •  poz. %d" % lvl
			r.desc.text = "+%d obrażeń kliknięcia za poziom. Co 10 poziomów klik zadaje +1%% DPS drużyny (teraz %d%%)." % [1, roundi(st.click_dps_share * 100.0)]
			b.text = "+%d\n%s zł" % [n, IdleDB.fmt(c)]
			IdleUI.set_affordable(b, float(gm.s.gold) >= c)
		else:
			var d := gm.db.merc_def(id)
			var lvl := gm.mercs.level(id)
			if n <= 0:
				n = maxi(1, gm.mercs.affordable(float(d.cost), lvl))
			var c := gm.mercs.cost(id, n)
			var gain := gm.mercs.dps(id, lvl + n) - gm.mercs.dps(id)
			var stv := gm.mercs.stars(id)
			r.title.text = "%s  •  poz. %d%s" % [d.name, lvl, ("  " + "★".repeat(stv)) if stv > 0 else ""]
			var ab: Button = r.awaken
			ab.visible = stv < MercenaryManager.MAX_STARS and lvl >= gm.mercs.awaken_level(id)
			if ab.visible:
				ab.text = "Przebudź\n%d pieczęci" % gm.mercs.awaken_cost(id)
				IdleUI.set_affordable(ab, gm.mercs.can_awaken(id))
			var ms := gm.mercs.next_milestone(lvl)
			r.desc.text = "%s\nDPS: %s  (+%s)%s" % [d.text, IdleDB.fmt(gm.mercs.dps(id) * st.dmg_mult * st.atk_speed), IdleDB.fmt(gain * st.dmg_mult * st.atk_speed), ("  •  ×2 na poz. %d" % ms) if ms > 0 else ""]
			b.text = ("Wynajmij\n" if lvl == 0 else "+%d\n" % n) + "%s zł" % IdleDB.fmt(c)
			IdleUI.set_affordable(b, float(gm.s.gold) >= c)


func on_changed(what: String) -> void:
	if what == "mercs" or what == "all":
		request_refresh()
