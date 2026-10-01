class_name ArenaPanel
extends IdlePanel
## Arena Popiołu: ranking i liga, rywale, nagroda tygodnia, sklep za odznaki chwały.

var _box: VBoxContainer
var _tab := "fight"


func build() -> void:
	add_child(IdleUI.title("Arena Popiołu", 28))
	sub_tabs([["fight", "Pojedynki"], ["shop", "Sklep areny"], ["leagues", "Ligi"]], func(id):
		_tab = id
		request_refresh())
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var a := gm.arena
	if not a.unlocked():
		_box.add_child(IdleUI.label("Arena otwiera się po dotarciu do etapu 25.", 20, IdleUI.BAD, true))
		return
	_box.add_child(_header())
	match _tab:
		"shop":
			_shop()
		"leagues":
			_leagues()
		_:
			_fights()


func _header() -> Control:
	var a := gm.arena
	var c := IdleUI.card()
	var h := IdleUI.hbox(12)
	c.add_child(h)
	h.add_child(IdleUI.icon_rect(load("res://assets/ui/modes/arena.png"), 72))
	var v := IdleUI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var lg := ArenaManager.league(a.rating())
	v.add_child(IdleUI.label("Liga: %s  •  ranking %d" % [ArenaManager.LEAGUES[lg][0], a.rating()], 24, ArenaManager.LEAGUES[lg][2]))
	var st: Dictionary = gm.s.arena
	v.add_child(IdleUI.label("Bilety: %d / %d  •  wygrane %d, porażki %d  •  rekord %d" % [a.tickets(), ArenaManager.DAILY_TICKETS, int(st.wins), int(st.losses), int(st.best)], 17, IdleUI.DIM, true))
	var coin := IdleUI.hbox(6)
	coin.add_child(IdleUI.icon_rect(load("res://assets/ui/modes/badge.png"), 32))
	coin.add_child(IdleUI.label("%d odznak chwały" % a.coins(), 19, IdleUI.GOLD_COL))
	v.add_child(coin)
	return c


func _fights() -> void:
	var a := gm.arena
	if not a.last_fight.is_empty():
		var lf: Dictionary = a.last_fight
		_box.add_child(IdleUI.label("Ostatnia walka z %s: %s  %+d  •  +%d odznak%s" % [lf.rival.name, "zwycięstwo" if bool(lf.win) else "porażka", int(lf.delta), int(lf.coins), "  •  +1 odłamek relikwii" if bool(lf.shard) else ""], 18, IdleUI.GOOD if bool(lf.win) else IdleUI.BAD, true))
	if a.weekly_ready():
		var w: Array = a.weekly_reward()
		var res := row_card(Sprites.icon("chest"), "Nagroda tygodnia – liga %s" % ArenaManager.league_name(int(gm.s.arena.week_best)), "%d żarokr., %s, %d odznak, %d odłamków relikwii" % [int(w[0]), LootManager.CHEST_NAMES[int(w[1])], int(w[2]), int(w[3])], IdleUI.GOLD_COL, 56)
		var cb := IdleUI.button("Odbierz", Vector2(130, 72), 20)
		cb.pressed.connect(func():
			if not gm.arena.claim_weekly().is_empty():
				ui.toast_msg("Nagroda ligowa odebrana!", IdleUI.GOLD_COL)
			request_refresh())
		res[1].add_child(cb)
		_box.add_child(res[0])
	_box.add_child(IdleUI.label("Wybierz rywala. Pokonaj jego championa w 30 s – wygrana podnosi ranking, porażka go obniża. Silniejsi rywale dają więcej punktów.", 17, UiTheme.TEXT, true))
	var rv: Array = a.rivals()
	for i in rv.size():
		var r: Dictionary = rv[i]
		var lg := ArenaManager.league(int(r.rating))
		var ch := ArenaManager.expected(a.rating(), int(r.rating))
		var win := roundi(ArenaManager.K * (1.0 - ch))
		var lose := roundi(ArenaManager.K * ch)
		var res := row_card(Sprites.icon("character"), "%s  •  %d" % [r.name, int(r.rating)], "Liga %s  •  poziom %d  •  zdrowie championa %s\nWygrana +%d, porażka −%d" % [ArenaManager.LEAGUES[lg][0], int(r.level), IdleDB.fmt(a.rival_hp(r)), maxi(win, 6), lose], ArenaManager.LEAGUES[lg][2], 56)
		var fb := IdleUI.button("Walcz" if a.tickets() > 0 else "%d żarokr." % ArenaManager.EXTRA_COST, Vector2(140, 76), 21)
		IdleUI.set_affordable(fb, a.can_fight() and (a.tickets() > 0 or int(gm.s.gems) >= ArenaManager.EXTRA_COST))
		var idx := i
		fb.pressed.connect(func():
			if gm.arena.fight(idx, true):
				ui.show_tab("fight")
			else:
				ui.toast_msg("Nie można teraz walczyć.", IdleUI.BAD))
		res[1].add_child(fb)
		_box.add_child(res[0])
	var rr := IdleUI.button("Nowi rywale (5 żarokr.)", Vector2(0, 68), 19)
	IdleUI.set_affordable(rr, int(gm.s.gems) >= 5 and not a.active)
	rr.pressed.connect(func():
		gm.arena.reroll()
		request_refresh())
	_box.add_child(rr)


func _shop() -> void:
	var a := gm.arena
	var icons := {"chest_3": Sprites.icon("chest"), "chest_4": Sprites.icon("chest"), "rune": load("res://assets/ui/runes/fire.png"), "pet_egg": load("res://assets/ui/runes/egg.png"),
		"shards": load("res://assets/ui/modes/shard.png"), "gems": load("res://assets/ui/ash/nav_gem.png"), "key": load("res://assets/ui/modes/key.png")}
	for i in ArenaManager.SHOP.size():
		var it: Array = ArenaManager.SHOP[i]
		var lim := int(it[3])
		var desc := "%d odznak" % int(it[2]) + ("  •  dziś %d / %d" % [a.bought_today(str(it[0])), lim] if lim > 0 else "")
		var res := row_card(icons.get(str(it[0])), str(it[1]), desc, UiTheme.ACCENT, 56)
		var bb := IdleUI.button("Kup", Vector2(120, 72), 21)
		IdleUI.set_affordable(bb, a.can_buy(i))
		var idx := i
		bb.pressed.connect(func():
			var got := gm.arena.buy(idx)
			if got != "":
				ui.toast_msg("Kupiono: %s" % ArenaManager.SHOP[idx][1], IdleUI.GOLD_COL)
			request_refresh())
		res[1].add_child(bb)
		_box.add_child(res[0])


func _leagues() -> void:
	var a := gm.arena
	_box.add_child(IdleUI.label("Co tydzień (od poniedziałku) ranking zbliża się do 1000. Nagroda tygodnia zależy od najwyższej ligi osiągniętej w tym tygodniu.", 17, UiTheme.TEXT, true))
	var cur := ArenaManager.league(int(gm.s.arena.week_best))
	for i in ArenaManager.LEAGUES.size():
		var l: Array = ArenaManager.LEAGUES[i]
		var w: Array = ArenaManager.WEEKLY[i]
		var res := row_card(load("res://assets/ui/modes/badge.png"), "%s  (od %d)" % [l[0], int(l[1])], "Tydzień: %d żarokr., %s, %d odznak, %d odłamków" % [int(w[0]), LootManager.CHEST_NAMES[int(w[1])], int(w[2]), int(w[3])], l[2], 48)
		if i == cur:
			res[1].add_child(IdleUI.label("◀ Ty", 22, IdleUI.GOOD))
		_box.add_child(res[0])


func on_changed(what: String) -> void:
	if what in ["arena", "all", "relics"]:
		request_refresh()
