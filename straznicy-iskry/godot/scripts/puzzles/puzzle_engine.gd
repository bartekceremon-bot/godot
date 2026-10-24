extends VBoxContainer
## Bazowy silnik łamigłówki. Podklasy: build(), check(), reset().

signal changed

var data: Dictionary = {}


func build(d: Dictionary) -> void:
	data = d


func check() -> Dictionary:
	return {"ok": false, "msg": ""}


func reset() -> void:
	for c in get_children():
		c.queue_free()
	build(data)


## Zwraca poprawne rozwiązanie w formacie używanym przez testy automatyczne.
func solve() -> void:
	pass


func chip(text: String, toggle := true) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "Chip"
	b.toggle_mode = toggle
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Audio.play("click", 0.08, -10.0))
	return b


func flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 10)
	return f


func card(variation := "Card") -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	return v


func header(text: String) -> Label:
	var l := UITheme.label(text, "Bold")
	l.add_theme_color_override("font_color", Art.TEAL)
	add_child(l)
	return l


static func shuffled(arr: Array, seed_value: int) -> Array:
	var out := arr.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
