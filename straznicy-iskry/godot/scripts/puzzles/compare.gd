extends "res://scripts/puzzles/puzzle_engine.gd"
## Porównanie komunikatów i ich źródeł — wybór najbardziej wiarygodnego.

var choice := -1
var _group: ButtonGroup


func build(d: Dictionary) -> void:
	data = d
	choice = -1
	if d.has("question"):
		var q := card("Soft")
		var l := UITheme.label(d["question"], "Bold")
		l.add_theme_color_override("font_color", Art.GOLD)
		q.add_child(l)
	header(d.get("instruction", "Które źródło jest najbardziej wiarygodne?"))
	_group = ButtonGroup.new()
	var srcs: Array = d.get("sources", [])
	for i in srcs.size():
		var s: Dictionary = srcs[i]
		var v := card()
		var name_l := UITheme.label(s.get("name", ""), "Bold")
		name_l.add_theme_color_override("font_color", Art.TEAL)
		v.add_child(name_l)
		v.add_child(UITheme.label("„%s”" % s.get("text", "")))
		for meta in s.get("meta", []):
			v.add_child(UITheme.label("•  " + str(meta), "Small"))
		var b := chip("Wybieram to źródło")
		b.button_group = _group
		var idx := i
		b.toggled.connect(func(on: bool) -> void:
			if on:
				choice = idx
				changed.emit())
		v.add_child(b)


func check() -> Dictionary:
	if choice == -1:
		return {"ok": false, "msg": "Wybierz jedno ze źródeł."}
	var s: Dictionary = data["sources"][choice]
	if s.get("ok", false):
		return {"ok": true, "msg": ""}
	return {"ok": false, "msg": str(s.get("why", "To źródło nie daje wystarczających dowodów."))}


func reset() -> void:
	if _group.get_pressed_button():
		_group.get_pressed_button().set_pressed_no_signal(false)
	choice = -1


func solve() -> void:
	for i in data["sources"].size():
		if data["sources"][i].get("ok", false):
			choice = i
