extends Control
## Sterowanie dotykowe: pływający joystick (lewa strona) + przyciski akcji (prawa).
## Każdy palec jest śledzony osobno, więc można jednocześnie iść i atakować.

const SLOT := preload("res://scripts/ui/skill_slot.gd")
const JOY_R := 72.0

var buttons: Array = []
var interact_btn: Control
var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_home := Vector2.ZERO
var _narrow := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Settings.changed.connect(_update_visibility)
	_update_visibility()


func _build() -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	var cid := GameState.class_id()
	var specs := [["attack", cid + "_basic", 60.0], ["skill1", cid + "_skill1", 42.0], ["skill2", cid + "_skill2", 42.0], ["dodge", "dodge", 40.0]]
	for s in specs:
		var b: Control = SLOT.new()
		b.setup(s[0], s[1], "", s[2], true)
		add_child(b)
		buttons.append(b)
	interact_btn = SLOT.new()
	interact_btn.setup("interact", "interact", "", 44.0, true)
	interact_btn.label_text = "Użyj"
	add_child(interact_btn)
	buttons.append(interact_btn)


func apply_layout(narrow: bool) -> void:
	_narrow = narrow
	if buttons.is_empty():
		return
	if buttons[0].icon != GameState.class_id() + "_basic":
		_build()
	var vs := get_viewport_rect().size
	var m := Router.safe_margins()
	var R: float = vs.x - m["right"] - 24.0
	var B: float = vs.y - m["bottom"] - 24.0
	var k := 1.0
	var portrait := vs.y > vs.x
	if portrait:
		k = 1.05
	# Pozycje środków przycisków (od prawego dolnego rogu).
	var offs := [Vector2(-70, -76), Vector2(-196, -54), Vector2(-178, -170), Vector2(-66, -200), Vector2(-300, -150)]
	if portrait:
		offs = [Vector2(-76, -90), Vector2(-206, -66), Vector2(-188, -190), Vector2(-70, -224), Vector2(-320, -170)]
	for i in buttons.size():
		var b: Control = buttons[i]
		var c = Vector2(R, B) + offs[i] * k
		b.position = c - b.size * 0.5
	_joy_home = Vector2(m["left"] + 140.0, B - (130.0 if portrait else 100.0))
	if _joy_index == -1:
		_joy_center = _joy_home
		_joy_pos = _joy_home


func _update_visibility() -> void:
	visible = Settings.show_touch()


func reset() -> void:
	for b in buttons:
		b.release()
	_joy_index = -1
	_joy_center = _joy_home
	_joy_pos = _joy_home
	var p := World.player()
	if p:
		p.touch_move = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if Settings.touch_mode == "auto" and not Settings.touch_active:
			Settings.touch_active = true
			Settings.changed.emit()
			_update_visibility()
	elif Settings.touch_mode == "auto" and Settings.touch_active:
		# Prawdziwa mysz lub klawiatura — chowamy przyciski dotykowe.
		var real_mouse: bool = event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and event.relative.length() > 6.0
		if real_mouse or (event is InputEventKey and event.pressed):
			Settings.touch_active = false
			reset()
			Settings.changed.emit()
			_update_visibility()
		return
	if not visible:
		return
	if World.current and (World.current.busy() or get_tree().paused):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for b in buttons:
				if b.visible and b.hit(event.position):
					b.touch_down(event.index)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if event.position.x < get_viewport_rect().size.x * 0.5 and _joy_index == -1 and not _over_hud(event.position):
				_joy_index = event.index
				_joy_center = event.position
				_joy_pos = event.position
				get_viewport().set_input_as_handled()
		else:
			for b in buttons:
				if b.owns(event.index):
					b.touch_up(event.index)
			if event.index == _joy_index:
				_joy_index = -1
				_joy_center = _joy_home
				_joy_pos = _joy_home
				var p := World.player()
				if p:
					p.touch_move = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _joy_index:
		_joy_pos = event.position
		var v: Vector2 = (_joy_pos - _joy_center) / JOY_R
		if v.length() > 1.0:
			# Joystick „podąża” za palcem, gdy ten wyjedzie poza obręcz.
			_joy_center = _joy_pos - v.normalized() * JOY_R
			v = v.normalized()
		var p := World.player()
		if p:
			p.touch_move = v if v.length() > 0.12 else Vector2.ZERO
		get_viewport().set_input_as_handled()
		queue_redraw()


func _over_hud(pos: Vector2) -> bool:
	# Lewy górny róg zajmują paski statystyk — nie łapiemy tam joysticka.
	return pos.y < 150.0


func _process(_delta: float) -> void:
	if not visible:
		return
	var p := World.player()
	interact_btn.visible = p != null and p.nearest_interactable() != null
	if not interact_btn.visible and interact_btn.owns(interact_btn._touch_index):
		interact_btn.release()


func _draw() -> void:
	var active := _joy_index != -1
	var a := 0.75 if active else 0.35
	draw_circle(_joy_center, JOY_R, Color(0.04, 0.12, 0.1, 0.45 * a + 0.1))
	draw_arc(_joy_center, JOY_R, 0, TAU, 48, Color(Art.TEAL, a), 3.0, true)
	var knob := _joy_pos
	if (knob - _joy_center).length() > JOY_R:
		knob = _joy_center + (knob - _joy_center).normalized() * JOY_R
	draw_circle(knob, 30, Color(Art.CREAM, 0.35 + 0.4 * a))
	draw_arc(knob, 30, 0, TAU, 32, Color(Art.GOLD, a), 2.0, true)
