extends "res://scripts/puzzles/puzzle_engine.gd"
## Przyporządkowanie zdań do kategorii (np. fakt / opinia).

var picks: Dictionary = {}
var _groups: Array = []


func build(d: Dictionary) -> void:
	data = d
	picks.clear()
	_groups.clear()
	header(d.get("instruction", "Przyporządkuj każde zdanie:"))
	var bins := _bins()
	var items: Array = d.get("items", [])
	for i in items.size():
		var v := card()
		v.add_child(UITheme.label("„%s”" % items[i]["text"]))
		var row := HBoxContainer.new()
		v.add_child(row)
		var g := ButtonGroup.new()
		for bi in bins.size():
			var b := chip(bins[bi], true, false)
			b.button_group = g
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var item_i := i
			var bin_i := bi
			b.toggled.connect(func(on: bool) -> void:
				if on:
					picks[item_i] = bin_i
					changed.emit())
			row.add_child(b)
		_groups.append(g)


func _bins() -> Array:
	return data.get("bins", ["Fakt", "Opinia"])


func check() -> Dictionary:
	var items: Array = data.get("items", [])
	var bins := _bins()
	for i in items.size():
		if not picks.has(i):
			return {"ok": false, "msg": "Przyporządkuj jeszcze: „%s”." % items[i]["text"]}
		if bins[picks[i]] != items[i]["bin"]:
			return {"ok": false, "msg": "„%s” — %s" % [items[i]["text"], items[i].get("why", "")]}
	return {"ok": true, "msg": ""}


func reset() -> void:
	for g in _groups:
		if g.get_pressed_button():
			g.get_pressed_button().set_pressed_no_signal(false)
	picks.clear()


func solve() -> void:
	var items: Array = data.get("items", [])
	var bins := _bins()
	for i in items.size():
		picks[i] = bins.find(items[i]["bin"])
