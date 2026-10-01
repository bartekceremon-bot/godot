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
	for opt in [["sound", "Dźwięk"], ["music", "Muzyka"], ["story", "Opowieść (dialogi postaci)"], ["effects", "Efekty (liczby, cząsteczki, monety)"], ["auto_potion", "Automatyczne mikstury życia w walce z bossem"]]:
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
	var sv := IdleUI.button("Zapisz grę teraz", Vector2(0, 80), 22)
	sv.pressed.connect(func():
		gm.save.save_game()
		ui.toast_msg("Zapisano.", IdleUI.GOOD))
	add_child(sv)
	var mmo := IdleUI.button("Klasyczne Popielne Królestwa (MMO online)", Vector2(0, 80), 20)
	mmo.pressed.connect(func(): ui.open_classic())
	add_child(mmo)
	var wipe := IdleUI.button("Zacznij od nowa", Vector2(0, 80), 22)
	wipe.pressed.connect(func():
		ui.confirm("Nowa gra", "Usunąć zapis i zacząć od zera? Tego nie da się cofnąć.", func():
			gm.wipe()
			ui.toast_msg("Nowa gra rozpoczęta.")))
	add_child(wipe)
	add_child(IdleUI.label("Gra zapisuje się sama co 15 s i przy wyjściu. Nie wymaga logowania ani internetu.", 17, IdleUI.DIM, true))
