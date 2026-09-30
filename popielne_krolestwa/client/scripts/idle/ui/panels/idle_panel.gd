class_name IdlePanel
extends VBoxContainer
## Bazowa zakładka interfejsu idle: build() raz, refresh() przy otwarciu i zmianach,
## tick_ui() co 0,25 s (dostępność przycisków), on_changed() – zdarzenia GameManagera.

var ui: IdleMain
var gm: IdleGame
var _pending := false


func setup(main: IdleMain) -> void:
	ui = main
	gm = main.gm
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	build()


func build() -> void:
	pass


func refresh() -> void:
	pass


## Odświeżenie odroczone (bezpieczne z obsługi przycisku, który zostanie przebudowany).
func request_refresh() -> void:
	if _pending:
		return
	_pending = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_pending = false
	if is_inside_tree():
		refresh()


func tick_ui() -> void:
	pass


func on_changed(_what: String) -> void:
	pass


## Pasek zakładek wewnętrznych: [[id, tekst], ...]; zwraca słownik przycisków.
func sub_tabs(tabs: Array, on_select: Callable) -> Dictionary:
	var row := IdleUI.hbox(6)
	add_child(row)
	var btns := {}
	for t in tabs:
		var b := IdleUI.button(str(t[1]), Vector2(0, 64), 20)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := str(t[0])
		b.pressed.connect(func():
			for k in btns:
				btns[k].set_pressed_no_signal(k == id)
			on_select.call(id))
		row.add_child(b)
		btns[id] = b
	return btns


## Karta wiersza: ikona, teksty (tytuł + opis), przyciski po prawej. Zwraca [karta, hbox przycisków, etykieta opisu].
func row_card(tex: Texture2D, title_text: String, desc: String, title_col := UiTheme.ACCENT, icon_size := 64) -> Array:
	var c := IdleUI.card()
	var h := IdleUI.hbox(12)
	c.add_child(h)
	if tex:
		h.add_child(IdleUI.icon_rect(tex, icon_size))
	var v := IdleUI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := IdleUI.label(title_text, 22, title_col, true)
	v.add_child(t)
	var d := IdleUI.label(desc, 17, Color(0.82, 0.8, 0.74), true)
	v.add_child(d)
	var btns := IdleUI.hbox(8)
	h.add_child(btns)
	return [c, btns, d, t]
