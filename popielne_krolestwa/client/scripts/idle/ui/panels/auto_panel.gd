class_name AutoPanel
extends IdlePanel
## Kwatermistrz: przełączniki automatyzacji i ich ustawienia.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Kwatermistrz", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var a := gm.auto
	_box.add_child(IdleUI.label("Kwatermistrz Gildii przejmie nudne obowiązki, gdy zdobędziesz jego zaufanie. Działa tylko w zwykłej walce (nie w Wieży, lochach, na Arenie ani we śnie).", 17, UiTheme.TEXT, true))
	_toggle("mercs", "Auto-najemnicy", "Co 3 s kupuje najemnika o najlepszym stosunku DPS do kosztu (oraz trening ciosu).", a.mercs_unlocked(), tr("Odblokowanie: pierwsze odrodzenie"), Sprites.icon("character"))
	if a.mercs_unlocked():
		var rb := IdleUI.button(tr("Rezerwa złota: %d%%") % int(a.reserve() * 100.0), Vector2(0, 58), 18)
		rb.pressed.connect(func():
			gm.auto.cycle("reserve", AutoManager.RESERVES.size())
			request_refresh())
		_box.add_child(rb)
	_toggle("gear", "Auto-ekwipunek", "Co 10 s zakłada najlepsze przedmioty i sprzedaje słabe (Zwykłe i Niezwykłe, bez ulepszeń i zaklęć).", a.gear_unlocked(), tr("Odblokowanie: etap %d") % AutoManager.GEAR_STAGE, IdleUI.item_tex(gm.db, "plate_body_t4"))
	_toggle("rebirth", "Auto-odrodzenie", "Gdy przez 3 min nie dotrzesz dalej, a odrodzenie da co najmniej wybraną ilość Popiołu Dusz – odradza bohatera.", a.rebirth_unlocked(), tr("Odblokowanie: %d odrodzenia") % AutoManager.REBIRTH_REBIRTHS, Sprites.icon("prestige"))
	if a.rebirth_unlocked():
		var mb := IdleUI.button(tr("Minimum Popiołu Dusz: %d") % a.min_ash(), Vector2(0, 58), 18)
		mb.pressed.connect(func():
			gm.auto.cycle("min_ash", AutoManager.MIN_ASH.size())
			request_refresh())
		_box.add_child(mb)
		if gm.prestige.can_rebirth():
			_box.add_child(IdleUI.label(tr("Odrodzenie teraz dałoby: %d Popiołu Dusz") % gm.prestige.ash_gain(), 17, IdleUI.DIM, true))


func _toggle(key: String, title_text: String, desc: String, ok: bool, lock_text: String, tex: Texture2D) -> void:
	var rc := row_card(tex, title_text, desc if ok else tr(desc) + "\n🔒 " + lock_text, UiTheme.ACCENT if ok else IdleUI.DIM, 56)
	var on := gm.auto.enabled(key)
	var b := IdleUI.button("WŁ" if on else "WYŁ", Vector2(110, 64), 22)
	b.disabled = not ok
	b.modulate = Color(0.6, 1.0, 0.55) if on and ok else Color.WHITE
	b.pressed.connect(func():
		gm.auto.set_enabled(key, not gm.auto.enabled(key))
		request_refresh())
	rc[1].add_child(b)
	_box.add_child(rc[0])


func on_changed(what: String) -> void:
	if what in ["auto", "all"] and is_visible_in_tree():
		request_refresh()
