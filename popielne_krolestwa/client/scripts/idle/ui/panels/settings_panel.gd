class_name SettingsPanel
extends IdlePanel
## Ustawienia: dźwięk, efekty, automatyczne mikstury, zapis, klasyczne MMO, nowa gra.


func build() -> void:
	pass


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	add_child(IdleUI.title("Ustawienia", 28))
	var set: Dictionary = gm.s.settings
	for opt in [["sound", "Dźwięk"], ["music", "Muzyka"], ["vibration", "Wibracje (krytyki, bossowie)"], ["story", "Opowieść (dialogi postaci)"], ["effects", "Efekty (liczby, cząsteczki, monety)"], ["auto_potion", "Automatyczne mikstury życia w walce z bossem"]]:
		var key := str(opt[0])
		var b := CheckButton.new()
		b.text = str(opt[1])
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(0, 72)
		b.button_pressed = bool(set.get(key, true))
		b.toggled.connect(func(on):
			set[key] = on
			if key == "sound":
				Config.sound_enabled = on
			if key == "music":
				ui.music.set_enabled(on)
			gm.save.save_game())
		add_child(b)
	# Jakość grafiki – słabsze telefony: niższa rozdzielczość sceny 3D, bez cieni i wygładzania.
	var qrow := IdleUI.hbox(8)
	add_child(qrow)
	qrow.add_child(IdleUI.label("Grafika:", 22))
	var q := int(set.get("quality", 1))
	for i in 3:
		var qb := IdleUI.button(["Oszczędna", "Zwykła", "Wysoka"][i], Vector2(0, 68), 19)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.toggle_mode = true
		qb.set_pressed_no_signal(i == q)
		var qi := i
		qb.pressed.connect(func():
			set["quality"] = qi
			if ui.combat:
				ui.combat.apply_quality()
			gm.save.save_game()
			request_refresh())
		qrow.add_child(qb)
	# Język: automatycznie wg telefonu, polski albo angielski.
	var lrow := IdleUI.hbox(8)
	add_child(lrow)
	lrow.add_child(IdleUI.label("Język:", 22))
	var lang := str(set.get("lang", "auto"))
	for l in [["auto", "Automatycznie"], ["pl", "Polski"], ["en", "English"]]:
		var lb := IdleUI.button(str(l[1]), Vector2(0, 68), 19)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.toggle_mode = true
		lb.set_pressed_no_signal(lang == l[0])
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED if l[0] != "auto" else Node.AUTO_TRANSLATE_MODE_INHERIT
		var code: String = l[0]
		lb.pressed.connect(func():
			set["lang"] = code
			SmartTranslation.apply_language(code)
			gm.save.save_game()
			request_refresh())
		lrow.add_child(lb)
	var store: Dictionary = gm.db.store
	var en := not TranslationServer.get_locale().begins_with("pl")
	var links := IdleUI.hbox(8)
	add_child(links)
	for l in [["Polityka prywatności", str(store.get("privacy_url", ""))], ["Regulamin", str(store.get("terms_url", ""))]]:
		var lb := IdleUI.button(str(l[0]), Vector2(0, 72), 19)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var url: String = l[1]
		if en:
			url = url.replace(".html", "_en.html")
		lb.pressed.connect(func(): OS.shell_open(url))
		links.add_child(lb)
	var row2 := IdleUI.hbox(8)
	add_child(row2)
	var consent := IdleUI.button("Zgoda na reklamy", Vector2(0, 72), 19)
	consent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consent.pressed.connect(func(): gm.ads.show_privacy_options())
	consent.disabled = gm.ads.backend != "admob"
	row2.add_child(consent)
	var rest := IdleUI.button("Przywróć zakupy", Vector2(0, 72), 19)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.pressed.connect(func():
		gm.billing.restore()
		ui.toast_msg("Sprawdzanie zakupów w Google Play…"))
	row2.add_child(rest)
	var mail := IdleUI.button("Kontakt i pomoc: %s" % store.get("support_email", ""), Vector2(0, 72), 18)
	mail.pressed.connect(func(): OS.shell_open("mailto:%s?subject=Popielne%%20Kr%%C3%%B3lestwa" % store.get("support_email", "")))
	add_child(mail)
	var sv := IdleUI.button("Zapisz grę teraz", Vector2(0, 80), 22)
	sv.pressed.connect(func():
		gm.save.save_game()
		ui.toast_msg("Zapisano.", IdleUI.GOOD))
	add_child(sv)
	# Kopia zapasowa: kod zapisu do przeniesienia gry na inny telefon (bez konta i serwera).
	var brow := IdleUI.hbox(8)
	add_child(brow)
	var ex := IdleUI.button("Kopiuj kod zapisu", Vector2(0, 76), 19)
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ex.pressed.connect(func():
		gm.save.save_game()
		DisplayServer.clipboard_set(gm.save.export_code())
		ui.toast_msg("Kod zapisu skopiowany – wklej go na nowym telefonie (Ustawienia → Wczytaj z kodu).", IdleUI.GOOD))
	brow.add_child(ex)
	var im := IdleUI.button("Wczytaj z kodu", Vector2(0, 76), 19)
	im.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	im.pressed.connect(_import_dialog)
	brow.add_child(im)
	var mmo := IdleUI.button("Klasyczne Popielne Królestwa (MMO online)", Vector2(0, 80), 20)
	mmo.pressed.connect(func(): ui.open_classic())
	add_child(mmo)
	var wipe := IdleUI.button("Zacznij od nowa", Vector2(0, 80), 22)
	wipe.pressed.connect(func():
		ui.confirm("Nowa gra", "Usunąć zapis i zacząć od zera? Tego nie da się cofnąć.", func():
			gm.wipe()
			ui.toast_msg("Nowa gra rozpoczęta.")))
	add_child(wipe)
	add_child(IdleUI.label("Gra zapisuje się sama co 15 s i przy wyjściu. Nie wymaga logowania ani internetu. Zmieniasz telefon? Skopiuj kod zapisu i wczytaj go na nowym urządzeniu.", 17, IdleUI.DIM, true))


func _import_dialog() -> void:
	var v := IdleUI.vbox(10)
	v.add_child(IdleUI.label("Wklej kod zapisu (zaczyna się od „PK1-”). Obecna gra na tym urządzeniu zostanie zastąpiona.", 18, UiTheme.TEXT, true))
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 220)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_font_size_override("font_size", 16)
	te.placeholder_text = "PK1-…"
	v.add_child(te)
	var paste := IdleUI.button("Wklej ze schowka", Vector2(0, 68), 19)
	paste.pressed.connect(func(): te.text = DisplayServer.clipboard_get())
	v.add_child(paste)
	var go := IdleUI.button("Wczytaj grę", Vector2(0, 80), 22)
	var m: Control
	go.pressed.connect(func():
		var d := SaveManager.parse_code(te.text)
		if d.is_empty():
			ui.toast_msg("Nieprawidłowy kod zapisu.", IdleUI.BAD)
			return
		ui.confirm("Wczytać grę z kodu?", "Etap %d, poziom %d. Obecny postęp na tym urządzeniu zostanie zastąpiony." % [int(d.get("max_stage", 1)), int(d.get("level", 1))], func():
			if gm.import_state(d):
				ui.close_modal(m)
				ui.toast_msg("Gra wczytana!", IdleUI.GOOD)
				request_refresh()))
	v.add_child(go)
	m = ui.modal("Wczytaj z kodu", v)
