class_name SeasonPanel
extends IdlePanel
## Karnet Popiołu: poziom sezonu, ścieżka darmowa i złota (Złoty Karnet z Google Play), odbiór.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Karnet Popiołu", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var se := gm.season
	_box.add_child(IdleUI.label("Sezon kończy się za %d dni. Punkty karnetu: pokonani wrogowie, bossowie, piętra Wieży, wyprawy, nagroda dnia, zlecenia i Boss tygodnia." % se.days_left(), 17, IdleUI.DIM, true))
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	_box.add_child(c)
	v.add_child(IdleUI.label("Poziom %d / %d" % [se.level(), SeasonManager.LEVELS], 26, UiTheme.ACCENT))
	var pb := IdleUI.bar(Color(0.95, 0.65, 0.2), 24)
	var into := se.xp() % SeasonManager.XP_PER_LEVEL if se.level() < SeasonManager.LEVELS else SeasonManager.XP_PER_LEVEL
	pb.value = float(into) / SeasonManager.XP_PER_LEVEL
	IdleUI.bar_label(pb, 15).text = "%d / %d" % [into, SeasonManager.XP_PER_LEVEL]
	v.add_child(pb)
	if not se.premium():
		var p := gm.premium.product("pk_season")
		var bb := IdleUI.button("Złoty Karnet – %s" % gm.billing.price_of("pk_season", str(p.get("price_pln", ""))), Vector2(0, 84), 24)
		IdleUI.set_affordable(bb, gm.billing.available())
		bb.pressed.connect(func(): ui.buy_product("pk_season"))
		v.add_child(bb)
		v.add_child(IdleUI.label(str(p.get("text", "")), 15, IdleUI.GOLD_COL, true))
	else:
		v.add_child(IdleUI.label("Złoty Karnet aktywny – +20% punktów karnetu.", 17, IdleUI.GOOD))
	if se.ready_count() > 0:
		var all := IdleUI.button("Odbierz wszystko (%d)" % se.ready_count(), Vector2(0, 76), 22)
		all.pressed.connect(func():
			var got := gm.season.claim_all()
			ui.toast_msg("Odebrano %d nagród karnetu" % got.size(), IdleUI.GOOD)
			request_refresh())
		v.add_child(all)
	for lv in range(1, SeasonManager.LEVELS + 1):
		var row := IdleUI.hbox(8)
		var l := IdleUI.label(str(lv), 22, UiTheme.ACCENT if lv <= se.level() else IdleUI.DIM)
		l.custom_minimum_size = Vector2(44, 0)
		row.add_child(l)
		row.add_child(_cell(lv, false))
		row.add_child(_cell(lv, true))
		_box.add_child(row)


func _cell(lv: int, gold: bool) -> Control:
	var se := gm.season
	var b := IdleUI.button("", Vector2(0, 70), 15)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var txt := SeasonManager.reward_text(SeasonManager.reward(lv, gold))
	if se.claimed(lv, gold):
		b.text = "✔ " + txt
		b.disabled = true
	elif se.claimable(lv, gold):
		b.text = "Odbierz: " + txt
		b.add_theme_color_override("font_color", IdleUI.GOOD)
	else:
		b.text = ("🔒 " if gold and not se.premium() else "") + txt
		b.disabled = true
	if gold:
		b.add_theme_stylebox_override("normal", IdleUI.ash_box("tile_on", 26, 8))
		b.add_theme_stylebox_override("disabled", IdleUI.ash_box("tile_on", 26, 8))
	b.pressed.connect(func():
		var got := gm.season.claim(lv, gold)
		for it in got:
			ui.toast_msg("+%s %s" % [IdleDB.fmt(float(it[1])), IdleUI.item_name(gm.db, str(it[0]))], IdleUI.GOLD_COL)
		request_refresh())
	return b


func on_changed(what: String) -> void:
	if what in ["season", "premium", "all"]:
		request_refresh()
