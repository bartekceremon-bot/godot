class_name FestivalPanel
extends IdlePanel
## Festyn Żaru: stan wydarzenia, lampiony i kram z nagrodami (strój Mistrz Festynu).

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Festyn Żaru", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var f := gm.festival
	var c := IdleUI.card()
	var h := IdleUI.hbox(12)
	c.add_child(h)
	h.add_child(IdleUI.icon_rect(load("res://assets/ui/modes/relic_lantern.png"), 80))
	var v := IdleUI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	if f.active():
		v.add_child(IdleUI.label("Festyn trwa! Do końca: %d dni" % f.days_left(), 22, Color(1.0, 0.7, 0.3)))
	else:
		v.add_child(IdleUI.label("Następny festyn za %d dni" % f.days_left(), 22, IdleUI.DIM))
	v.add_child(IdleUI.label("Żarne Lampiony: %d" % f.lanterns(), 24, IdleUI.GOLD_COL))
	_box.add_child(c)
	_box.add_child(IdleUI.label("Festyn odbywa się w dniach %d–%d każdego miesiąca. Wrogowie gubią lampiony (elity i bossowie zawsze), a w kramie wymienisz je na nagrody. Lampiony zostają na kolejny festyn." % [FestivalManager.FIRST_DAY, FestivalManager.LAST_DAY], 17, UiTheme.TEXT, true))
	var icons := {"skin_festival": IdleUI.ash_tex("portrait"), "pet_egg": load("res://assets/ui/runes/egg.png"), "chest_4": Sprites.icon("chest"), "chest_5": Sprites.icon("chest"),
		"shards": load("res://assets/ui/modes/shard.png"), "gems": IdleUI.ash_tex("nav_gem")}
	for i in FestivalManager.SHOP.size():
		var it: Array = FestivalManager.SHOP[i]
		var lim := int(it[3])
		var owned_skin: bool = str(it[0]) == "skin_festival" and (gm.s.get("skins_owned", []) as Array).has("festival")
		var desc := "%d lampionów" % int(it[2]) + ("  •  %d / %d" % [f.bought(str(it[0])), lim] if lim > 0 else "")
		if owned_skin:
			desc = "Posiadasz – załóż w Garderobie"
		var res := row_card(icons.get(str(it[0])), str(it[1]), desc, Color(1.0, 0.72, 0.35), 56)
		var b := IdleUI.button("Kup", Vector2(120, 72), 21)
		IdleUI.set_affordable(b, f.can_buy(i))
		var idx := i
		b.pressed.connect(func():
			if gm.festival.buy(idx):
				ui.toast_msg("Kupiono: %s" % FestivalManager.SHOP[idx][1], IdleUI.GOLD_COL)
				if str(FestivalManager.SHOP[idx][0]) == "skin_festival":
					ui.banner("NOWY STRÓJ", "Mistrz Festynu – załóż go w Garderobie", Color(1.0, 0.7, 0.3))
			request_refresh())
		res[1].add_child(b)
		_box.add_child(res[0])


func on_changed(what: String) -> void:
	if what in ["festival", "all"] and is_visible_in_tree():
		request_refresh()
