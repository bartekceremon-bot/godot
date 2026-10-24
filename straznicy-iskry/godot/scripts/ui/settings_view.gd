extends VBoxContainer
## Ustawienia dźwięku, grafiki, animacji, tekstu i sterowania (menu i gra).

signal text_scale_changed


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_section("Dźwięk")
	_slider("Głośność ogólna", "master_volume")
	_slider("Muzyka", "music_volume")
	_slider("Efekty", "sfx_volume")
	_section("Grafika i animacje")
	_options("Jakość grafiki", "quality", [["high", "Wysoka"], ["low", "Niska (słabsze urządzenia)"]])
	_toggle("Ograniczone animacje (mniej ruchu i błysków)", "reduced_motion")
	_toggle("Drgania kamery", "screen_shake")
	_section("Czytelność i sterowanie")
	_options("Wielkość tekstu", "text_scale", [[1.0, "Normalna"], [1.15, "Większa"], [1.3, "Duża"]])
	_options("Przyciski dotykowe", "touch_mode", [["auto", "Automatycznie"], ["on", "Zawsze"], ["off", "Nigdy"]])
	_toggle("Podpowiedzi BLIKA", "show_hints")


func _section(t: String) -> void:
	var l := UITheme.label(t, "Header")
	add_child(l)


func _slider(t: String, key: String) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var l := UITheme.label(t, "", false)
	l.custom_minimum_size.x = 220
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.get(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(160, 44)
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		Audio.play("click", 0.0, -8.0))
	row.add_child(s)


func _toggle(t: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = t
	c.button_pressed = Settings.get(key)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(0, 50)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	add_child(c)


func _options(t: String, key: String, opts: Array) -> void:
	add_child(UITheme.label(t, "Bold"))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	add_child(f)
	var g := ButtonGroup.new()
	for o in opts:
		var b := Button.new()
		b.text = o[1]
		b.toggle_mode = true
		b.button_group = g
		b.theme_type_variation = "Chip"
		b.custom_minimum_size = Vector2(0, 50)
		b.button_pressed = Settings.get(key) == o[0]
		var val: Variant = o[0]
		b.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(key, val)
				if key == "text_scale":
					text_scale_changed.emit())
		f.add_child(b)
