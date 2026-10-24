extends "res://scripts/puzzles/puzzle_engine.gd"
## Składanie polecenia lub reguły z części (Cel/Kontekst/Ograniczenia/Format,
## albo KIEDY/JEŚLI/TO). Na dole widać złożony wynik.

var picks: Dictionary = {}      # indeks slotu → indeks opcji
var _preview: RichTextLabel
var _groups: Array = []


func build(d: Dictionary) -> void:
	data = d
	picks.clear()
	_groups.clear()
	var slots: Array = d.get("slots", [])
	for si in slots.size():
		var s: Dictionary = slots[si]
		header(s.get("label", "Część %d" % (si + 1)))
		if s.has("help"):
			add_child(UITheme.label(s["help"], "Small"))
		var f := VBoxContainer.new()
		add_child(f)
		var group := ButtonGroup.new()
		group.allow_unpress = false
		var opts: Array = shuffled(range(s["options"].size()), si * 17 + 5)
		for oi in opts:
			var b := chip(s["options"][oi]["text"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.button_group = group
			var slot_i := si
			var opt_i: int = oi
			b.toggled.connect(func(on: bool) -> void:
				if on:
					picks[slot_i] = opt_i
					_update_preview()
					changed.emit())
			f.add_child(b)
		_groups.append(group)
	var pv := card("Soft")
	var lab := UITheme.label(d.get("preview_label", "Twoje polecenie:"), "Bold")
	lab.add_theme_color_override("font_color", Art.GOLD)
	pv.add_child(lab)
	_preview = UITheme.rich("")
	pv.add_child(_preview)
	_update_preview()


func _update_preview() -> void:
	var parts: Array = []
	var slots: Array = data.get("slots", [])
	for si in slots.size():
		if picks.has(si):
			parts.append(slots[si]["options"][picks[si]]["text"])
		else:
			parts.append("[color=#8a9a94]…%s…[/color]" % slots[si].get("label", "").to_lower())
	_preview.text = data.get("joiner", " ").join(parts)


func check() -> Dictionary:
	var slots: Array = data.get("slots", [])
	var msgs: Array = []
	for si in slots.size():
		if not picks.has(si):
			msgs.append("[b]%s[/b]: wybierz jedną z opcji." % slots[si].get("label", ""))
			continue
		var o: Dictionary = slots[si]["options"][picks[si]]
		if not o.get("ok", false):
			msgs.append("[b]%s[/b]: %s" % [slots[si].get("label", ""), o.get("why", "To nie pasuje.")])
	if msgs.is_empty():
		return {"ok": true, "msg": ""}
	return {"ok": false, "msg": "\n".join(msgs)}


func reset() -> void:
	for g in _groups:
		var p: BaseButton = g.get_pressed_button()
		if p:
			p.set_pressed_no_signal(false)
	picks.clear()
	_update_preview()


func solve() -> void:
	var slots: Array = data.get("slots", [])
	for si in slots.size():
		for oi in slots[si]["options"].size():
			if slots[si]["options"][oi].get("ok", false):
				picks[si] = oi
	_update_preview()
