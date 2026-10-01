class_name SoulNightPanel
extends IdlePanel
## Noc Dusz: stan wydarzenia, Płomyki Dusz, nagroda za 300 płomyków i Upiorny Kram.

const DIR := "res://assets/ui/modes/"

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Noc Dusz", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var sn := gm.soul_night
	var c := IdleUI.card(Color(0.07, 0.05, 0.1, 0.9), Color(0.6, 0.4, 1.0, 0.35))
	var v := IdleUI.vbox(6)
	c.add_child(v)
	var h := IdleUI.hbox(12)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(load(DIR + "soul_flame.png"), 84))
	var t := IdleUI.vbox(4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if sn.active():
		t.add_child(IdleUI.label("Noc Dusz trwa! Do końca: %d dni" % sn.days_left(), 22, Color(0.75, 0.6, 1.0), true))
	else:
		t.add_child(IdleUI.label("Następna Noc Dusz za %d dni" % sn.days_left(), 22, IdleUI.DIM, true))
	t.add_child(IdleUI.label("Płomyki Dusz: %d" % sn.flames(), 24, Color(0.6, 0.95, 1.0)))
	if sn.active():
		var pb := IdleUI.bar(Color(0.55, 0.4, 1.0), 22)
		pb.value = minf(1.0, float(sn.total()) / float(SoulNightManager.MILESTONE))
		IdleUI.bar_label(pb, 15).text = "%d / %d" % [mini(sn.total(), SoulNightManager.MILESTONE), SoulNightManager.MILESTONE]
		v.add_child(pb)
		var mb := IdleUI.button("Nagroda za %d płomyków: 100 żarokr. + jajo" % SoulNightManager.MILESTONE, Vector2(0, 62), 18)
		IdleUI.set_affordable(mb, sn.milestone_ready())
		if bool(sn._st().milestone):
			mb.text = tr("Nagroda odebrana")
			mb.disabled = true
		mb.pressed.connect(func():
			if gm.soul_night.claim_milestone():
				ui.banner("NOC DUSZ", "+100 żarokryształów i jajo chowańca", Color(0.7, 0.55, 1.0))
			request_refresh())
		v.add_child(mb)
	_box.add_child(c)
	_box.add_child(IdleUI.label("Od 25 października do 3 listopada wrogowie gubią Płomyki Dusz (elity i bossowie zawsze). Wymień je w Upiornym Kramie – płomyki zostają do następnej Nocy Dusz.", 17, UiTheme.TEXT, true))
	var icons := {"skin_reaper": IdleUI.ash_tex("portrait"), "pet_egg": load("res://assets/ui/runes/egg.png"), "chest_4": Sprites.icon("chest"),
		"dragon_treat": load(DIR + "dragon.png"), "elixir": load(DIR + "elixir_dragon.png"), "gems": IdleUI.ash_tex("nav_gem"), "seal": load(DIR + "badge.png")}
	for i in SoulNightManager.SHOP.size():
		var it: Array = SoulNightManager.SHOP[i]
		var id := str(it[0])
		var lim := int(it[3])
		var desc := tr("%d płomyków") % int(it[2]) + ("  •  %d / %d" % [sn.bought(id), lim] if lim > 0 else "")
		if id == "skin_reaper" and (gm.s.get("skins_owned", []) as Array).has("reaper"):
			desc = tr("Posiadasz – załóż w Garderobie")
		elif id == "dragon_treat" and not gm.dragon.alive():
			desc += "  •  " + tr("wymaga smoka")
		var rc := row_card(icons.get(id), str(it[1]), desc, Color(0.75, 0.6, 1.0), 56)
		var b := IdleUI.button("Kup", Vector2(120, 72), 21)
		IdleUI.set_affordable(b, sn.can_buy(i))
		var idx := i
		b.pressed.connect(func():
			if gm.soul_night.buy(idx):
				ui.toast_msg(tr("Kupiono: %s") % tr(str(SoulNightManager.SHOP[idx][1])), Color(0.75, 0.6, 1.0))
				if str(SoulNightManager.SHOP[idx][0]) == "skin_reaper":
					ui.banner("NOWY STRÓJ", "Żniwiarz Dusz – załóż go w Garderobie", Color(0.7, 0.55, 1.0))
			request_refresh())
		rc[1].add_child(b)
		_box.add_child(rc[0])


func on_changed(what: String) -> void:
	if what in ["soul_night", "all", "dragon"] and is_visible_in_tree():
		request_refresh()
