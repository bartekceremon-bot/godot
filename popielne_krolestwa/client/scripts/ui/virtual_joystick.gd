extends Control
## Wirtualny joystick dotykowy (lewy dolny róg). Obsługuje multi-touch –
## można jednocześnie chodzić i naciskać przyciski akcji.

const RADIUS := 110.0
const KNOB := 46.0
const DEADZONE := 0.25

var _touch_index := -1
var _vector := Vector2.ZERO
var _knob_offset := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2, RADIUS * 2)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Kierunek ruchu (długość 0..1), Vector2.ZERO gdy puszczony.
func get_vector() -> Vector2:
	return _vector if _vector.length() > DEADZONE else Vector2.ZERO


func _center() -> Vector2:
	return global_position + size / 2.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and event.position.distance_to(_center()) <= RADIUS * 1.3:
			_touch_index = event.index
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_vector = Vector2.ZERO
			_knob_offset = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)
		get_viewport().set_input_as_handled()


func _update(pos: Vector2) -> void:
	_knob_offset = (pos - _center()).limit_length(RADIUS)
	_vector = _knob_offset / RADIUS
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, RADIUS, Color(0, 0, 0, 0.28))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(0.9, 0.6, 0.3, 0.5), 3.0)
	draw_circle(c + _knob_offset, KNOB, Color(0.9, 0.6, 0.3, 0.55 if _touch_index >= 0 else 0.35))
