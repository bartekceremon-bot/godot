extends "res://scripts/puzzles/puzzle_engine.gd"
## Zaznaczanie elementów spełniających warunek. Tryby:
##  verify  — zaznacz błędy w wyniku automatu,
##  toggles — włącz tylko potrzebne uprawnienia,
##  redact  — zakryj dane prywatne w wiadomości,
##  inspect — wskaż podejrzane elementy i wybierz bezpieczną reakcję.

var marked: Dictionary = {}
var choice := -1
var _buttons: Array = []
var _choice_group: ButtonGroup


func build(d: Dictionary) -> void:
	data = d
	marked.clear()
	_buttons.clear()
	choice = -1
	var mode: String = d.get("mode", "verify")
	if d.has("context"):
		var c := card("Soft")
		c.add_child(UITheme.rich(d["context"]))
	header(d.get("instruction", "Zaznacz elementy:"))
	var items: Array = d.get("items", [])
	var container: Container
	if mode == "redact":
		container = flow()
		container.add_theme_constant_override("h_separation", 6)
	else:
		container = VBoxContainer.new()
	add_child(container)
	for i in items.size():
		var it: Dictionary = items[i]
		var b: Button
		if mode == "toggles":
			var cb := CheckButton.new()
			cb.text = it["text"]
			cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cb.custom_minimum_size = Vector2(0, 52)
			cb.add_theme_font_size_override("font_size", UITheme.fs(19))
			b = cb
		else:
			b = chip(it["text"])
			if mode != "redact":
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.toggled.connect(func(on: bool) -> void:
			if on:
				marked[idx] = true
			else:
				marked.erase(idx)
			_style(idx)
			changed.emit())
		container.add_child(b)
		_buttons.append(b)
	if d.has("choices"):
		header(d.get("choice_label", "Co robisz?"))
		_choice_group = ButtonGroup.new()
		var opts: Array = shuffled(range(d["choices"].size()), 9)
		for oi in opts:
			var b := chip(d["choices"][oi]["text"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.button_group = _choice_group
			var o: int = oi
			b.toggled.connect(func(on: bool) -> void:
				if on:
					choice = o
					changed.emit())
			add_child(b)


func _style(i: int) -> void:
	if data.get("mode", "") != "redact":
		return
	var b: Button = _buttons[i]
	var it: Dictionary = data["items"][i]
	b.text = "█ ukryte █" if marked.has(i) else it["text"]


func _target(it: Dictionary) -> bool:
	return bool(it.get("target", false))


func check() -> Dictionary:
	var items: Array = data.get("items", [])
	var missed: Array = []
	var extra: Array = []
	for i in items.size():
		var want := _target(items[i])
		if want and not marked.has(i):
			missed.append(items[i])
		elif not want and marked.has(i):
			extra.append(items[i])
	var msgs: Array = []
	var mode: String = data.get("mode", "verify")
	if not missed.is_empty():
		var lead: String = data.get("missed_text", {
			"verify": "Nie wszystkie błędy zostały wychwycone.",
			"toggles": "Brakuje uprawnienia, bez którego aplikacja nie zadziała.",
			"redact": "W wiadomości zostały jeszcze dane prywatne.",
			"inspect": "Nie wszystkie podejrzane elementy zostały wskazane.",
		}.get(mode, "Czegoś brakuje."))
		msgs.append(lead + " Podpowiedź: " + str(missed[0].get("why", "")))
	if not extra.is_empty():
		msgs.append("„%s” — %s" % [extra[0]["text"], extra[0].get("why", "to akurat jest w porządku.")])
	if data.has("choices"):
		if choice == -1:
			msgs.append("Wybierz jeszcze, co robisz z tą sytuacją.")
		elif not data["choices"][choice].get("ok", false):
			msgs.append(str(data["choices"][choice].get("why", "To nie jest bezpieczna reakcja.")))
	if msgs.is_empty():
		return {"ok": true, "msg": ""}
	return {"ok": false, "msg": "\n".join(msgs)}


func reset() -> void:
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(false)
		marked.erase(i)
		_style(i)
	if _choice_group and _choice_group.get_pressed_button():
		_choice_group.get_pressed_button().set_pressed_no_signal(false)
	choice = -1


func solve() -> void:
	var items: Array = data.get("items", [])
	for i in items.size():
		if _target(items[i]):
			marked[i] = true
		_buttons[i].set_pressed_no_signal(marked.has(i))
		_style(i)
	if data.has("choices"):
		for oi in data["choices"].size():
			if data["choices"][oi].get("ok", false):
				choice = oi
