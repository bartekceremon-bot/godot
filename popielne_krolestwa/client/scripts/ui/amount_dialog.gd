extends WindowPanel
## Okno wyboru ilości (i opcjonalnie ceny oraz jakości) – używane przez sklep,
## depozyt, rynek i rzemiosło. Wynik: callback(amount, price, quality).

var _amount: SpinBox
var _price: SpinBox
var _price_row: HBoxContainer
var _quality: OptionButton
var _quality_row: HBoxContainer
var _info: Label
var _total: Label
var _ok: Button
var _callback: Callable
var _show_total := false


func _init() -> void:
	super._init("", Vector2(520, 0))
	z_index = 10
	_info = UiTheme.label("", 18)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_info)

	var row := HBoxContainer.new()
	row.add_child(_fixed_label("Ilość"))
	_amount = _spin(1, 1)
	row.add_child(_amount)
	for d in [-10, -1, 1, 10]:
		var b := UiTheme.button(("%+d" % d), "", Vector2(60, 52))
		b.pressed.connect(func(): _amount.value += d)
		row.add_child(b)
	var mx := UiTheme.button("max", "", Vector2(70, 52))
	mx.pressed.connect(func(): _amount.value = _amount.max_value)
	row.add_child(mx)
	content.add_child(row)

	_price_row = HBoxContainer.new()
	_price_row.add_child(_fixed_label("Cena/szt."))
	_price = _spin(1, 10000000)
	_price_row.add_child(_price)
	for f in [0.9, 1.1]:
		var b := UiTheme.button("-10%" if f < 1 else "+10%", "", Vector2(80, 52))
		b.pressed.connect(func(): _price.value = maxf(1, roundf(_price.value * f)))
		_price_row.add_child(b)
	content.add_child(_price_row)

	_quality_row = HBoxContainer.new()
	_quality_row.add_child(_fixed_label("Min. jakość"))
	_quality = OptionButton.new()
	_quality.custom_minimum_size = Vector2(240, 52)
	_quality_row.add_child(_quality)
	content.add_child(_quality_row)

	_total = UiTheme.label("", 20, Color(1, 0.85, 0.3))
	content.add_child(_total)
	_amount.value_changed.connect(func(_v): _update_total())
	_price.value_changed.connect(func(_v): _update_total())

	_ok = UiTheme.button("OK", "", Vector2(0, 60))
	_ok.pressed.connect(_confirm)
	content.add_child(_ok)


func _fixed_label(t: String) -> Label:
	var l := UiTheme.label(t, 18)
	l.custom_minimum_size = Vector2(120, 0)
	return l


func _spin(min_v: int, max_v: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.rounded = true
	s.custom_minimum_size = Vector2(150, 52)
	s.get_line_edit().add_theme_font_size_override("font_size", 22)
	return s


## Otwiera okno. opts: title, info, max, amount, button, price (int lub brak), quality (bool), total (bool).
func open(opts: Dictionary, callback: Callable) -> void:
	set_title(str(opts.get("title", "Ilość")))
	_info.text = str(opts.get("info", ""))
	_amount.max_value = maxi(1, int(opts.get("max", 1)))
	_amount.value = clampi(int(opts.get("amount", 1)), 1, int(_amount.max_value))
	_price_row.visible = opts.has("price")
	if opts.has("price"):
		_price.value = maxi(1, int(opts.price))
	_quality_row.visible = opts.get("quality", false)
	if _quality_row.visible:
		_quality.clear()
		for q in range(1, 6):
			_quality.add_item(GameData.quality_name(q), q)
	_show_total = opts.get("total", false)
	_ok.text = str(opts.get("button", "OK"))
	_callback = callback
	_update_total()
	show()
	move_to_front()


func _update_total() -> void:
	_total.visible = _show_total
	if _show_total:
		var price := int(_price.value) if _price_row.visible else 0
		_total.text = "Razem: %d zł" % (int(_amount.value) * price)


func _confirm() -> void:
	var q := _quality.get_selected_id() if _quality_row.visible else 1
	hide()
	_callback.call(int(_amount.value), int(_price.value), maxi(1, q))
