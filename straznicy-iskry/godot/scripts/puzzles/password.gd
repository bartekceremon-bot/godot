extends "res://scripts/puzzles/puzzle_engine.gd"
## Budowanie silnego hasła-frazy z niepowiązanych słów. Miernik siły na żywo.

var parts: Array = []
var _phrase: Label
var _meter: ProgressBar
var _verdict: Label
var _pool: HFlowContainer
var _extras: HFlowContainer


func build(d: Dictionary) -> void:
	data = d
	parts.clear()
	var pv := card("Soft")
	var t := UITheme.label("Twoje hasło:", "Bold")
	t.add_theme_color_override("font_color", Art.GOLD)
	pv.add_child(t)
	_phrase = UITheme.label("")
	_phrase.add_theme_font_size_override("font_size", UITheme.fs(24))
	pv.add_child(_phrase)
	_meter = ProgressBar.new()
	_meter.custom_minimum_size = Vector2(0, 18)
	_meter.show_percentage = false
	_meter.max_value = 100
	pv.add_child(_meter)
	_verdict = UITheme.label("", "Small")
	pv.add_child(_verdict)
	var row := HBoxContainer.new()
	pv.add_child(row)
	var undo := chip("Cofnij ostatni element", false)
	undo.pressed.connect(func() -> void:
		if not parts.is_empty():
			parts.pop_back()
			_refresh())
	row.add_child(undo)
	header(d.get("instruction", "Dotykaj słów, aby zbudować hasło:"))
	_pool = flow()
	add_child(_pool)
	header("Dodatki:")
	_extras = flow()
	add_child(_extras)
	for w in shuffled(d.get("words", []), 3):
		var b := chip(w["w"], false)
		var word: Dictionary = w
		b.pressed.connect(func() -> void:
			if parts.size() < 8:
				parts.append(word)
				_refresh())
		_pool.add_child(b)
	for e in d.get("extras", ["7", "!", "#", "42"]):
		var b := chip(e, false)
		var ex: String = e
		b.pressed.connect(func() -> void:
			if parts.size() < 8:
				parts.append({"w": ex, "extra": true})
				_refresh())
		_extras.add_child(b)
	_refresh()


func phrase() -> String:
	var out := ""
	for p in parts:
		if p.get("extra", false):
			out += p["w"]
		else:
			out += ("-" if out != "" else "") + p["w"]
	return out


func evaluate() -> Dictionary:
	var words := 0
	var personal: Array = []
	var common: Array = []
	for p in parts:
		if p.get("extra", false):
			continue
		words += 1
		if p.get("personal", false):
			personal.append(p["w"])
		if p.get("common", false):
			common.append(p["w"])
	var s := phrase()
	var score := mini(60, s.length() * 3) + mini(30, words * 8)
	for p in parts:
		if p.get("extra", false):
			score += 5
			break
	if not personal.is_empty():
		score = mini(score, 25)
	if not common.is_empty():
		score = mini(score, 20)
	return {"score": clampi(score, 0, 100), "words": words, "len": s.length(), "personal": personal, "common": common}


func _refresh() -> void:
	_phrase.text = phrase() if not parts.is_empty() else "(puste)"
	var e := evaluate()
	_meter.value = e["score"]
	var col := Color("#e0566b")
	var txt := "Słabe"
	if e["score"] >= 75:
		col = Color("#7dffb0")
		txt = "Mocne"
	elif e["score"] >= 45:
		col = Art.GOLD
		txt = "Średnie"
	_meter.add_theme_stylebox_override("fill", UITheme.box(col, Color(0, 0, 0, 0), 8, 0, 0))
	_verdict.text = "%s  •  %d znaków, %d słowa" % [txt, e["len"], e["words"]]
	changed.emit()


func check() -> Dictionary:
	var e := evaluate()
	var min_words := int(data.get("min_words", 3))
	var min_len := int(data.get("min_len", 16))
	if not e["personal"].is_empty():
		return {"ok": false, "msg": "„%s” to informacja o Tobie. Takie hasła łatwo zgadnąć, przeglądając Twoje profile. Usuń ten element." % e["personal"][0]}
	if not e["common"].is_empty():
		return {"ok": false, "msg": "„%s” jest na listach najpopularniejszych haseł — atakujący sprawdzają je w pierwszej kolejności." % e["common"][0]}
	if e["words"] < min_words:
		return {"ok": false, "msg": "Użyj co najmniej %d niepowiązanych słów. Każde kolejne słowo bardzo utrudnia zgadywanie." % min_words}
	if e["len"] < min_len:
		return {"ok": false, "msg": "Hasło ma %d znaków. Celuj w co najmniej %d — długość to najważniejsza cecha." % [e["len"], min_len]}
	return {"ok": true, "msg": ""}


func reset() -> void:
	parts.clear()
	_refresh()


func solve() -> void:
	parts.clear()
	for w in data.get("words", []):
		if not w.get("personal", false) and not w.get("common", false) and parts.size() < 4:
			parts.append(w)
	parts.append({"w": "7", "extra": true})
	_refresh()
