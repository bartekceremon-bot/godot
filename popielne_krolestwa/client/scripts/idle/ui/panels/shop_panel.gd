class_name IdleShopPanel
extends IdlePanel
## Sklep (Kupiec Borys), Skup i Targ (oferty kupców trzech miast, odnawiane co 30 minut).

var _tab := "shop"
var _list: VBoxContainer
var _rows: Array = []


func build() -> void:
	var tabs := sub_tabs([["shop", "Kupiec"], ["sell", "Skup"], ["market", "Targ"]], func(id):
		_tab = id
		request_refresh())
	tabs["shop"].set_pressed_no_signal(true)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	_rows.clear()
	match _tab:
		"shop":
			_build_shop()
		"sell":
			_build_sell()
		"market":
			_build_market()
	tick_ui()


func _build_shop() -> void:
	var trader := str(gm.db.cities.popielgrod.npcNames.trader)
	_list.add_child(IdleUI.label("%s: „Najlepsze towary po tej stronie Popieliska!”" % trader, 18, IdleUI.DIM, true))
	for o in gm.shop.offers():
		var id := str(o.id)
		var name := str(o.get("name", IdleUI.item_name(gm.db, id)))
		var tex: Texture2D = Sprites.icon("book") if str(o.kind) == "boost" else IdleUI.item_tex(gm.db, id)
		var rc := row_card(tex, name + (" ×%d" % int(o.amount) if int(o.amount) > 1 else ""), str(o.text), UiTheme.ACCENT, 60)
		_list.add_child(rc[0])
		var gems := str(o.currency) == "gems"
		var b := IdleUI.button("%s %s" % [IdleDB.fmt(float(o.price)), "żarokr." if gems else "zł"], Vector2(170, 76), 19)
		var offer: Dictionary = o
		b.pressed.connect(func():
			if gm.shop.buy(offer):
				ui.toast_msg("Kupiono: %s" % name, IdleUI.GOOD))
		rc[1].add_child(b)
		_rows.append({"btn": b, "price": float(o.price), "gems": gems})


func _build_sell() -> void:
	_list.add_child(IdleUI.label("Sprzedaj nadmiar surowców, trofea i mikstury. Ekwipunek sprzedasz w zakładce EKWIPUNEK.", 18, IdleUI.DIM, true))
	var ids := gm.inventory.list_counted(func(id): return gm.shop.sell_price(id) > 0.0)
	for id in ids:
		var n := gm.inventory.count(id)
		var p := gm.shop.sell_price(id)
		var rc := row_card(Sprites.item_icon_for(gm.db.item(id)), "%s ×%d" % [gm.db.item_name(id), n], "%s zł za sztukę" % IdleDB.fmt(p), UiTheme.ACCENT, 56)
		_list.add_child(rc[0])
		var iid: String = id
		for k in [1, 0]:
			var cnt: int = k if k > 0 else n
			var b := IdleUI.button("×1" if k > 0 else "Wszystko\n%s zł" % IdleDB.fmt(p * n), Vector2(120 if k > 0 else 170, 72), 18)
			b.pressed.connect(func():
				gm.shop.sell(iid, cnt)
				request_refresh())
			rc[1].add_child(b)
	if ids.is_empty():
		_list.add_child(IdleUI.label("Nie masz nic na sprzedaż.", 20, IdleUI.DIM))


func _build_market() -> void:
	var left := gm.market.time_left()
	_list.add_child(IdleUI.label("Nowe oferty za %s. Kupcy trzech miast skupują i sprzedają surowce." % IdleDB.fmt_time(left), 18, IdleUI.DIM, true))
	var offers: Array = gm.market.offers()
	for i in offers.size():
		var o: Dictionary = offers[i]
		var name := gm.db.item_name(str(o.id))
		var sell := str(o.type) == "sell"
		var title := ("Sprzedaje: %d× %s" if sell else "Skupuje: %d× %s") % [int(o.amount), name]
		var desc := "%s (%s)%s" % [o.trader, o.city, "  •  masz: %d" % gm.inventory.count(str(o.id)) if not sell else ""]
		var rc := row_card(Sprites.item_icon_for(gm.db.item(str(o.id))), title, desc, UiTheme.ACCENT if not bool(o.done) else IdleUI.DIM, 60)
		_list.add_child(rc[0])
		var b := IdleUI.button(("Kup\n%s zł" if sell else "Sprzedaj\n+%s zł") % IdleDB.fmt(float(o.price)), Vector2(170, 76), 18)
		if bool(o.done):
			b.text = "Zrealizowano"
			b.disabled = true
		var idx: int = i
		b.pressed.connect(func():
			if gm.market.accept(idx):
				request_refresh())
		rc[1].add_child(b)
		if not bool(o.done):
			_rows.append({"btn": b, "price": float(o.price) if sell else 0.0, "gems": false, "need": "" if sell else str(o.id), "amount": int(o.amount)})


func tick_ui() -> void:
	for r in _rows:
		var ok := true
		if r.has("need") and str(r.need) != "":
			ok = gm.inventory.count(str(r.need)) >= int(r.amount)
		elif bool(r.gems):
			ok = int(gm.s.gems) >= int(r.price)
		else:
			ok = float(gm.s.gold) >= float(r.price)
		IdleUI.set_affordable(r.btn, ok)


func on_changed(what: String) -> void:
	if what in ["market", "all"] or (_tab == "sell" and what == "inventory"):
		request_refresh()
