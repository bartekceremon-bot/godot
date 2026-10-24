extends Control
## Okno zadania edukacyjnego. Błąd nigdy nie odbiera zdrowia: dostajesz
## wyjaśnienie, podpowiedź i kolejną próbę.

signal finished(mission_id: String, success: bool)

const ENGINES := {
	"sequence": preload("res://scripts/puzzles/sequence.gd"),
	"slots": preload("res://scripts/puzzles/slots.gd"),
	"marks": preload("res://scripts/puzzles/marks.gd"),
	"sort": preload("res://scripts/puzzles/sort.gd"),
	"compare": preload("res://scripts/puzzles/compare.gd"),
	"password": preload("res://scripts/puzzles/password.gd"),
}

var mission: Dictionary = {}
var engine: Control
var panel: PanelContainer
var title: Label
var tag: Label
var goal: Label
var intro: RichTextLabel
var scroll: ScrollContainer
var body: VBoxContainer
var feedback: RichTextLabel
var feedback_box: PanelContainer
var buttons: HBoxContainer
var check_btn: Button
var hint_btn: Button
var _hint_i := 0
var _attempts := 0
var _solved := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	tag = UITheme.label("", "Small", false)
	tv.add_child(tag)
	title = UITheme.label("", "Header")
	tv.add_child(title)
	var close := UITheme.button("Zamknij", _close)
	close.theme_type_variation = "Chip"
	head.add_child(close)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	feedback_box = PanelContainer.new()
	feedback_box.theme_type_variation = "CardBad"
	feedback_box.visible = false
	v.add_child(feedback_box)
	feedback = UITheme.rich("")
	feedback_box.add_child(feedback)
	buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(buttons)
	hint_btn = UITheme.button("Podpowiedź", _hint)
	hint_btn.theme_type_variation = "Chip"
	buttons.add_child(hint_btn)
	var again := UITheme.button("Od nowa", _reset)
	again.theme_type_variation = "Chip"
	buttons.add_child(again)
	check_btn = UITheme.button("Sprawdź", _check, "Primary")
	check_btn.custom_minimum_size.x = 170
	buttons.add_child(check_btn)


func apply_layout(narrow: bool) -> void:
	var vs := get_viewport_rect().size
	var m := Router.safe_margins()
	var pad := 10.0 if narrow else 30.0
	var w := minf(vs.x - pad * 2 - m["left"] - m["right"], 1040.0)
	var h := minf(vs.y - pad * 2 - m["top"] - m["bottom"], 900.0)
	panel.position = Vector2((vs.x - w) * 0.5, (vs.y - h) * 0.5 + (m["top"] - m["bottom"]) * 0.5)
	panel.size = Vector2(w, h)
	panel.custom_minimum_size = panel.size


func open(m: Dictionary) -> void:
	mission = m
	_hint_i = 0
	_attempts = 0
	_solved = false
	visible = true
	apply_layout(Router.narrow)
	Audio.play("open")
	_build_task()


func _clear_body() -> void:
	for c in body.get_children():
		c.queue_free()
	engine = null


func _build_task() -> void:
	_clear_body()
	feedback_box.visible = false
	buttons.visible = true
	title.text = mission.get("title", "")
	var area_name := Data.area_name(mission.get("area", ""))
	tag.text = "%s  •  %s" % [area_name, mission.get("topic", "")]
	if GameState.is_mission_done(mission.get("id", "")):
		tag.text += "  •  powtórka"
	var gp := PanelContainer.new()
	gp.theme_type_variation = "Soft"
	body.add_child(gp)
	var gv := VBoxContainer.new()
	gp.add_child(gv)
	var gl := UITheme.label("Cel", "Bold")
	gl.add_theme_color_override("font_color", Art.GOLD)
	gv.add_child(gl)
	goal = UITheme.label(mission.get("goal", ""))
	gv.add_child(goal)
	if mission.has("intro"):
		intro = UITheme.rich(mission["intro"])
		body.add_child(intro)
	var script: Script = ENGINES.get(mission.get("type", "sequence"))
	engine = script.new()
	engine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	engine.add_theme_constant_override("separation", 10)
	body.add_child(engine)
	engine.build(mission.get("data", {}))
	engine.changed.connect(func() -> void: feedback_box.visible = false)
	check_btn.grab_focus.call_deferred()
	scroll.scroll_vertical = 0


func _check() -> void:
	if engine == null:
		return
	var r: Dictionary = engine.check()
	_attempts += 1
	if r.get("ok", false):
		_success()
		return
	Audio.play("error", 0.0, -4.0)
	feedback_box.theme_type_variation = "CardBad"
	var extra := ""
	if _attempts >= 2 and _hint_i < mission.get("hints", []).size():
		extra = "\n[color=#e8b84a]Możesz też użyć przycisku „Podpowiedź”.[/color]"
	feedback.text = "[b]Jeszcze nie.[/b] " + str(r.get("msg", "")) + extra
	feedback_box.visible = true
	_shake_panel()


func _shake_panel() -> void:
	if Settings.reduced_motion:
		return
	var x := panel.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(panel, "position:x", x + (8 if i % 2 == 0 else -8), 0.04)
	tw.tween_property(panel, "position:x", x, 0.04)


func _hint() -> void:
	var hints: Array = mission.get("hints", [])
	if hints.is_empty():
		return
	var h: String = hints[min(_hint_i, hints.size() - 1)]
	_hint_i += 1
	feedback_box.theme_type_variation = "Card"
	feedback.text = "[color=#3fd1c1][b]BLIK podpowiada:[/b][/color] " + h
	feedback_box.visible = true
	Audio.play("blik", 0.1, -6.0)


func _reset() -> void:
	if engine:
		engine.reset()
	feedback_box.visible = false


func _success() -> void:
	_solved = true
	Audio.play("success")
	_clear_body()
	feedback_box.visible = false
	var ok := PanelContainer.new()
	ok.theme_type_variation = "CardOk"
	body.add_child(ok)
	var v := VBoxContainer.new()
	ok.add_child(v)
	var head := UITheme.label("Udało się!", "Header")
	head.add_theme_color_override("font_color", Color("#7dffb0"))
	v.add_child(head)
	v.add_child(UITheme.rich(mission.get("success", "")))
	if mission.has("real_life"):
		var rl := PanelContainer.new()
		rl.theme_type_variation = "Card"
		body.add_child(rl)
		var rv := VBoxContainer.new()
		rl.add_child(rv)
		var rh := UITheme.label("W prawdziwym życiu", "Bold")
		rh.add_theme_color_override("font_color", Art.GOLD)
		rv.add_child(rh)
		rv.add_child(UITheme.rich(mission["real_life"]))
	if mission.has("ai_note"):
		var an := PanelContainer.new()
		an.theme_type_variation = "Soft"
		body.add_child(an)
		var av := VBoxContainer.new()
		an.add_child(av)
		var ah := UITheme.label("Gra a prawdziwe AI", "Bold")
		ah.add_theme_color_override("font_color", Art.TEAL)
		av.add_child(ah)
		av.add_child(UITheme.rich(mission["ai_note"]))
	var done := GameState.is_mission_done(mission.get("id", ""))
	var reward: Dictionary = mission.get("reward", {})
	var rtxt := "Powtórka zaliczona — nagroda była już odebrana." if done else "Nagroda: +%d PD" % int(reward.get("xp", 25))
	if not done:
		for item in reward.get("items", {}):
			rtxt += ", " + str(Data.get_item(item).get("name", item))
	body.add_child(UITheme.label(rtxt, "Bold"))
	buttons.visible = false
	var cont := UITheme.button("Dalej", _finish_success, "Primary")
	body.add_child(cont)
	cont.grab_focus.call_deferred()
	scroll.scroll_vertical = 0


func _finish_success() -> void:
	visible = false
	finished.emit(mission.get("id", ""), true)


func _close() -> void:
	visible = false
	finished.emit(mission.get("id", ""), _solved)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


## Używane przez testy automatyczne: rozwiązuje bieżące zadanie poprawnie.
func autosolve() -> bool:
	if engine == null:
		return false
	engine.solve()
	var r: Dictionary = engine.check()
	if r.get("ok", false):
		_success()
		return true
	push_error("Autosolve nie powiódł się dla %s: %s" % [mission.get("id", ""), r.get("msg", "")])
	return false
