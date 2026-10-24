extends Node
## Przełączanie ekranów z płynnym przejściem, orientacja ekranu, safe areas,
## reakcja na utratę fokusu (pauza + zwolnienie przycisków).

signal layout_changed(narrow: bool)
signal focus_lost
signal focus_gained

const SCENES := {
	"title": "res://scenes/title.tscn",
	"intro": "res://scenes/cutscene.tscn",
	"class_select": "res://scenes/class_select.tscn",
	"world": "res://scenes/world.tscn",
}

var params: Dictionary = {}
var narrow := false
var _fade: ColorRect
var _layer: CanvasLayer
var _busy := false
var _safe := Rect2()
var _last_size := Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.07, 0.06, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()


func _process(_delta: float) -> void:
	# Na Web zdarzenie zmiany rozmiaru bywa spóźnione; sprawdzamy tanio co klatkę.
	var s := get_tree().root.size
	if s != _last_size:
		_on_resize()


func _on_resize() -> void:
	var win := get_tree().root
	_last_size = win.size
	var portrait := win.size.y > win.size.x
	var base := Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	if win.content_scale_size != base:
		win.content_scale_size = base
	_update_safe_area()
	# Interfejs przelicza się przy każdej zmianie rozmiaru, nie tylko orientacji.
	narrow = portrait or win.size.x < 900 * _device_ratio()
	layout_changed.emit(narrow)


func _device_ratio() -> float:
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if typeof(r) in [TYPE_FLOAT, TYPE_INT]:
			return float(r)
	return 1.0


func _update_safe_area() -> void:
	## Marginesy bezpieczne (wycięcia ekranu) w pikselach okna.
	_safe = Rect2()
	if OS.has_feature("web"):
		var js := "(function(){var e=document.getElementById('safe-probe');if(!e)return '0,0,0,0';var s=getComputedStyle(e);return [s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(function(v){return parseFloat(v)||0}).join(',');})()"
		var r: Variant = JavaScriptBridge.eval(js, true)
		if typeof(r) == TYPE_STRING:
			var p: PackedStringArray = str(r).split(",")
			if p.size() == 4:
				var ratio := _device_ratio()
				_safe = Rect2(float(p[3]) * ratio, float(p[0]) * ratio, float(p[1]) * ratio, float(p[2]) * ratio)


func safe_margins() -> Dictionary:
	## Zwraca marginesy w jednostkach interfejsu (po skalowaniu canvas_items).
	var win := get_tree().root
	var scale := float(win.size.x) / float(max(1, win.get_visible_rect().size.x))
	if scale <= 0.0:
		scale = 1.0
	return {
		"left": _safe.position.x / scale, "top": _safe.position.y / scale,
		"right": _safe.size.x / scale, "bottom": _safe.size.y / scale,
	}


func go(scene: String, p: Dictionary = {}, fade_time := 0.45) -> void:
	if _busy:
		return
	_busy = true
	params = p
	if Settings.reduced_motion:
		fade_time *= 0.4
	var t := create_tween()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	t.tween_property(_fade, "color:a", 1.0, fade_time)
	await t.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene])
	await get_tree().process_frame
	await get_tree().process_frame
	fade_in(fade_time)
	_busy = false


func fade_out(time := 0.4) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, time * (0.4 if Settings.reduced_motion else 1.0))
	await t.finished


func fade_in(time := 0.4) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, time * (0.4 if Settings.reduced_motion else 1.0))
	await t.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			Settings.release_all_actions()
			focus_lost.emit()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			focus_gained.emit()
