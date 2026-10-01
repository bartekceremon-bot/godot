class_name IdleShopPanel
extends IdlePanel
## Sklep: Skarbiec (zakupy w Google Play, nagrody za reklamy, Przymierze Żaru, Złoty Karnet),
## Kupiec Borys (za złoto i żarokryształy), Skup i Targ (oferty kupców, odnawiane co 30 minut).

var _tab := "vault"
var _fury_l: Label
var _chest_b: Button
var _list: VBoxContainer
var _rows: Array = []


func build() -> void:
	var tabs := sub_tabs([["vault", "Skarbiec"], ["shop", "Kupiec"], ["sell", "Skup"], ["market", "Targ"]], func(id):
		_tab = id
		request_refresh())
	tabs["vault"].set_pressed_no_signal(true)
	gm.billing.prices_updated.connect(func(): if _tab == "vault": request_refresh())
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	_rows.clear()
	match _tab:
		"vault":
			_build_vault()
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
		if id.begins_with("chest_"):
			var r := int(id.substr(6))
			var ob := IdleUI.button("Szanse", Vector2(110, 76), 17)
			ob.pressed.connect(func(): ui.show_odds(LootManager.CHEST_NAMES[r], gm.loot.chest_odds(r)))
			rc[1].add_child(ob)
		b.pressed.connect(func():
			if gm.shop.buy(offer):
				ui.toast_msg("Kupiono: %s" % name, IdleUI.GOOD))
		rc[1].add_child(b)
		_rows.append({"btn": b, "price": float(o.price), "gems": gems})


# --- Skarbiec -------------------------------------------------------------------------

func _build_vault() -> void:
	var b := gm.billing
	if b.is_sandbox():
		_list.add_child(_note("TRYB TESTOWY – zakupy i reklamy bez płatności (wersja poza Google Play).", Color(1.0, 0.75, 0.3)))
	elif not b.available():
		_list.add_child(_note("Zakupy są dostępne w aplikacji pobranej z Google Play. Nagrody za reklamy – gdy reklama jest gotowa.", IdleUI.DIM))
	# Darmowe nagrody (reklamy – zawsze dobrowolne).
	_list.add_child(IdleUI.title("Darmowe nagrody", 24))
	var purse := gm.premium.has_purse()
	_list.add_child(IdleUI.label(("Mieszek Kupca: nagrody bez oglądania reklam." if purse else "Obejrzyj krótką reklamę, by odebrać nagrodę. Pozostało dziś: %d." % gm.premium.ads_left()), 16, IdleUI.DIM, true))
	for place in ["free_chest", "fury", "tower_attempt"]:
		var rc := row_card(Sprites.icon("chest") if place == "free_chest" else (IdleUI.ash_tex("ico_skull") if place == "tower_attempt" else Sprites.icon("attack")), str(PremiumManager.PLACEMENTS[place].name), "", UiTheme.ACCENT, 56)
		var btn := IdleUI.button("Odbierz" if purse else "▶ Reklama", Vector2(170, 72), 19)
		var pl: String = place
		btn.pressed.connect(func(): ui.ad_reward(pl, func(): request_refresh()))
		rc[1].add_child(btn)
		if place == "free_chest":
			_chest_b = btn
		if place == "fury":
			_fury_l = rc[2]
		_list.add_child(rc[0])
		_rows.append({"ad": place, "btn": btn, "desc": rc[2]})
	# Przymierze Żaru.
	if gm.premium.monthly_active():
		var mc := row_card(Sprites.icon("prestige"), "Przymierze Żaru – zostało %d dni" % gm.premium.monthly_days_left(), "100 żarokryształów każdego dnia, +10% złota", Color(1.0, 0.75, 0.3), 56)
		var cb := IdleUI.button("Odbierz 100" if gm.premium.monthly_ready() else "Jutro", Vector2(170, 72), 19)
		IdleUI.set_affordable(cb, gm.premium.monthly_ready())
		cb.pressed.connect(func():
			var g := gm.premium.claim_monthly()
			if g > 0:
				ui.toast_msg("+%d żarokryształów" % g, IdleUI.GEM_COL)
			request_refresh())
		mc[1].add_child(cb)
		_list.add_child(mc[0])
	# Oferty za prawdziwe pieniądze.
	_list.add_child(IdleUI.title("Skarbiec", 24))
	for p in gm.premium.catalog():
		var id := str(p.id)
		if not gm.premium.can_buy(id) and not bool(p.consumable):
			continue
		var title := str(p.name)
		var desc := str(p.get("text", ""))
		if str(p.kind) == "gems":
			var first := gm.premium.is_first(id)
			desc = "%d żarokryształów%s%s" % [int(p.gems) * (2 if first else 1) + int(p.get("bonus", 0)), " (×2 przy pierwszym zakupie!)" if first else "", " + %d bonus" % int(p.bonus) if int(p.get("bonus", 0)) > 0 and not first else ""]
		if p.has("tag"):
			title += "  •  " + str(p.tag)
		var tex: Texture2D = Sprites.icon(str(p.icon)) if str(p.icon) != "gem" else Sprites.icon("gem")
		var rc := row_card(tex, title, desc, Color(1.0, 0.8, 0.4) if p.has("tag") else UiTheme.ACCENT, 60)
		var price := b.price_of(id, str(p.price_pln))
		var bb := IdleUI.button(price, Vector2(170, 80), 21)
		IdleUI.set_affordable(bb, b.available() and gm.premium.can_buy(id))
		var pid := id
		bb.pressed.connect(func(): ui.buy_product(pid))
		rc[1].add_child(bb)
		_list.add_child(rc[0])
	var restore := IdleUI.button("Przywróć zakupy", Vector2(0, 72), 20)
	restore.pressed.connect(func():
		gm.billing.restore()
		ui.toast_msg("Sprawdzanie zakupów w Google Play…"))
	_list.add_child(restore)
	_list.add_child(IdleUI.label("Ceny zawierają podatek VAT. Płatności obsługuje Google Play – gra nie widzi danych karty. Żarokryształy można też zdobywać w grze: bossowie, Wieża, wyprawy, osiągnięcia, codzienne nagrody i Karnet.", 15, IdleUI.DIM, true))


func _note(text: String, col: Color) -> Control:
	var c := IdleUI.card()
	c.add_child(IdleUI.label(text, 17, col, true))
	return c


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
		if r.has("ad"):
			var place := str(r.ad)
			var avail := gm.premium.ad_available(place) and (gm.premium.has_purse() or gm.ads.ready_to_show())
			IdleUI.set_affordable(r.btn, avail)
			var d: Label = r.desc
			if place == "free_chest":
				var w := gm.premium.free_chest_wait()
				d.text = "Gotowa!" if w <= 0.0 else "Następna za %s" % IdleDB.fmt_time(w)
			elif place == "fury":
				d.text = "Aktywny: %s" % IdleDB.fmt_time(gm.premium.fury_left()) if gm.premium.fury_active() else "Idealny na bossa albo Wieżę"
			elif place == "tower_attempt":
				d.text = "Wykorzystano dziś" if not gm.premium.ad_available(place) else "Raz dziennie"
			if not gm.ads.available() and not gm.premium.has_purse():
				d.text = "Reklamy są niedostępne w tej wersji"
			continue
		var ok := true
		if r.has("need") and str(r.need) != "":
			ok = gm.inventory.count(str(r.need)) >= int(r.amount)
		elif bool(r.gems):
			ok = int(gm.s.gems) >= int(r.price)
		else:
			ok = float(gm.s.gold) >= float(r.price)
		IdleUI.set_affordable(r.btn, ok)


func on_changed(what: String) -> void:
	if what in ["market", "all"] or (_tab == "sell" and what == "inventory") or (_tab == "vault" and what == "premium"):
		request_refresh()
