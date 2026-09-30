class_name MountsPanel
extends IdlePanel
## Stajnia: wierzchowce MMO jako stałe premie – odblokowanie fragmentami lub zakupem, ulepszanie.

var _list: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Stajnia", 28))
	add_child(IdleUI.label("Wierzchowce dają stałe premie – działają wszystkie naraz. Fragmenty zdobywasz z bossów (łoś – Król Szronu, wielbłąd – Pustynny Czerw, drake – Żarogniew) i ze skrzyń.", 17, IdleUI.DIM, true))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	for md in gm.db.mounts:
		var id := str(md.id)
		var lvl := gm.mounts.level(id)
		var c := gm.mounts.next_cost(id)
		var stat: String = {"gold": "złota", "xp": "doświadczenia", "offline": "postępu offline", "damage": "obrażeń"}[str(md.stat)]
		var now := gm.mounts.bonus(id)
		var next := gm.mounts.bonus(id, lvl + 1)
		var desc := "%s\n%s\nFragmenty: %d / %d%s" % [gm.db.item(id).get("description", ""), ("Premia: +%d%% %s → +%d%%" % [roundi(now * 100), stat, roundi(next * 100)]) if lvl > 0 else "Po odblokowaniu: %s" % md.text,
			gm.mounts.frags(id), int(c.frags), ("  •  %s zł" % IdleDB.fmt(float(c.gold))) if float(c.gold) > 0.0 else ""]
		var rc := row_card(Sprites.item_icon_for(gm.db.item(id)), "%s%s" % [gm.db.item_name(id), ("  •  poz. %d" % lvl) if lvl > 0 else ""], desc, UiTheme.ACCENT if lvl > 0 else Color(0.75, 0.72, 0.66), 80)
		_list.add_child(rc[0])
		var v := IdleUI.vbox(6)
		rc[1].add_child(v)
		var b := IdleUI.button("Ulepsz" if lvl > 0 else "Odblokuj", Vector2(160, 72), 20)
		IdleUI.set_affordable(b, gm.mounts.can_upgrade(id))
		b.pressed.connect(func():
			if gm.mounts.upgrade(id):
				request_refresh())
		v.add_child(b)
		if lvl == 0:
			var p := gm.mounts.buy_price(id)
			if not p.is_empty():
				var ok := false
				var txt := ""
				if p.has("gold"):
					txt = "Kup: %s zł" % IdleDB.fmt(float(p.gold)) if int(gm.s.max_stage) >= int(p.stage) else "Etap %d" % int(p.stage)
					ok = int(gm.s.max_stage) >= int(p.stage) and float(gm.s.gold) >= float(p.gold)
				else:
					txt = "Kup: %d żarokr." % int(p.gems)
					ok = int(gm.s.gems) >= int(p.gems)
				var kb := IdleUI.button(txt, Vector2(160, 64), 17)
				IdleUI.set_affordable(kb, ok)
				kb.pressed.connect(func():
					if gm.mounts.buy(id):
						request_refresh())
				v.add_child(kb)


func on_changed(what: String) -> void:
	if what in ["mounts", "all"]:
		request_refresh()
