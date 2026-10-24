extends "res://scripts/puzzles/puzzle_engine.gd"
## Układanie kroków w kolejności (instrukcja dla golema, programy maszyn).

var program: Array = []          # wybrane identyfikatory
var _blocks: Dictionary = {}
var _program_box: VBoxContainer
var _pool: HFlowContainer


func build(d: Dictionary) -> void:
	data = d
	program.clear()
	for b in d.get("blocks", []):
		_blocks[b["id"]] = b
	header(d.get("program_label", "Program (dotknij kroku, aby go usunąć):"))
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Card"
	add_child(pc)
	_program_box = VBoxContainer.new()
	pc.add_child(_program_box)
	header(d.get("pool_label", "Dostępne klocki (dotknij, aby dodać na koniec):"))
	_pool = flow()
	add_child(_pool)
	_refresh()


func _refresh() -> void:
	for c in _program_box.get_children():
		c.queue_free()
	for c in _pool.get_children():
		c.queue_free()
	if program.is_empty():
		var l := UITheme.label("Program jest pusty.", "Small")
		_program_box.add_child(l)
	for i in program.size():
		var b := chip("%d.  %s" % [i + 1, _blocks[program[i]]["text"]], false)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func() -> void:
			program.remove_at(idx)
			_refresh()
			changed.emit())
		_program_box.add_child(b)
	var order := shuffled(data.get("blocks", []), data.get("blocks", []).size() * 31)
	for b in order:
		if b["id"] in program:
			continue
		var c := chip(b["text"], false)
		var bid: String = b["id"]
		c.pressed.connect(func() -> void:
			program.append(bid)
			_refresh()
			changed.emit())
		_pool.add_child(c)


func check() -> Dictionary:
	var answer: Array = data.get("answer", [])
	for i in program.size():
		var id: String = program[i]
		if not id in answer:
			return {"ok": false, "msg": "Krok %d („%s”): %s" % [i + 1, _blocks[id]["text"], _blocks[id].get("why", "Ten klocek nie pasuje do celu.")]}
		if i >= answer.size() or answer[i] != id:
			var expected: Dictionary = _blocks[answer[i]] if i < answer.size() else {}
			return {"ok": false, "msg": "Krok %d jest nie na swoim miejscu. %s" % [i + 1, expected.get("order_hint", "Pomyśl, co musi wydarzyć się wcześniej.")]}
	if program.size() < answer.size():
		return {"ok": false, "msg": "Program jest niepełny — po kroku %d wykonawca nie wie, co dalej. Brakuje jeszcze %d." % [program.size(), answer.size() - program.size()]}
	return {"ok": true, "msg": ""}


func reset() -> void:
	program.clear()
	_refresh()


func solve() -> void:
	program = data.get("answer", []).duplicate()
	_refresh()
