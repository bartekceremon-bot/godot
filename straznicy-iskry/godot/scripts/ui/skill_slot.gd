extends Control
## Okrągły przycisk akcji: ikona, czas odnowienia, koszt energii, blokada.
## W trybie dotykowym obsługuje własny palec (multitouch: ruch + atak naraz).

var action := "attack"
var icon := "interact"
var key_text := ""
var radius := 34.0
var touch_mode := false
var label_text := ""
var _touch_index := -1
var _pressed := false
var _flash := 0.0


func setup(a: String, ic: String, key: String, r: float, touch: bool) -> void:
	action = a
	icon = ic
	key_text = key
	radius = r
	touch_mode = touch
	custom_minimum_size = Vector2(r * 2, r * 2)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var _last_sig := ""


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	if not is_visible_in_tree():
		return
	# Przerysowanie tylko, gdy coś się zmieniło (odnowienie, energia, wciśnięcie).
	var p := World.player()
	var sig := "%d|%s|%s|%d" % [int(_ratio() * 40.0), _pressed, _flash > 0.0, int(GameState.energy) if action in ["skill1", "skill2"] else 0]
	if p and action in ["skill1", "skill2"]:
		sig += "|%s" % p.skill_unlocked(action)
	if sig != _last_sig or _flash > 0.0:
		_last_sig = sig
		queue_redraw()


func center() -> Vector2:
	return size * 0.5


func hit(global_pos: Vector2) -> bool:
	# Strefa dotyku nieco większa niż rysunek — łatwiej trafić kciukiem.
	return (global_pos - (global_position + center())).length() <= radius * 1.25


func touch_down(index: int) -> void:
	_touch_index = index
	_pressed = true
	_flash = 1.0
	if action == "interact":
		var p := World.player()
		if p:
			p.try_interact()
	else:
		Input.action_press(action)


func touch_up(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	_pressed = false
	if action != "interact":
		Input.action_release(action)


func owns(index: int) -> bool:
	return _touch_index == index


func release() -> void:
	if _touch_index != -1 and action != "interact":
		Input.action_release(action)
	_touch_index = -1
	_pressed = false


func _ratio() -> float:
	var p := World.player()
	if p == null or not p.cooldowns.has(action):
		if action == "dodge" and p:
			return p.dodge_cd / p.DODGE_CD
		return 0.0
	var m: float = p.cd_max[action]
	return p.cooldowns[action] / m if m > 0.0 else 0.0


func _draw() -> void:
	var c := center()
	var p := World.player()
	var locked := false
	var no_energy := false
	if p and action in ["skill1", "skill2"]:
		locked = not p.skill_unlocked(action)
		no_energy = GameState.energy < p.skill_cost(action)
	var bg := Color(0.04, 0.12, 0.1, 0.72 if touch_mode else 0.85)
	draw_circle(c, radius, bg)
	var ring_col := Color(Art.GOLD, 0.9) if action == "attack" else Color(Art.TEAL, 0.8)
	if _pressed:
		ring_col = Color.WHITE
		draw_circle(c, radius, Color(1, 1, 1, 0.12))
	draw_arc(c, radius - 1.5, 0, TAU, 40, ring_col, 3.0, true)
	var ic := Art.CREAM
	if locked:
		ic = Color(Art.CREAM, 0.25)
	elif no_energy:
		ic = Color("#8a9a94")
	Icons.draw(self, icon, c, radius * 1.15, ic)
	var r := _ratio()
	if r > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 24
		for i in steps + 1:
			var a := -PI / 2 + TAU * r * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (radius - 3))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	if _flash > 0.0:
		draw_arc(c, radius + 4 + (1.0 - _flash) * 10, 0, TAU, 40, Color(Art.GOLD, _flash), 3.0, true)
	var font := get_theme_default_font()
	if locked:
		var s := "Poz. 2"
		draw_string_outline(font, c + Vector2(-radius, radius * 0.15), s, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 14, 4, Art.INK)
		draw_string(font, c + Vector2(-radius, radius * 0.15), s, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 14, Art.CREAM)
	if key_text != "" and not touch_mode:
		var tw := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var badge := Rect2(c.x - tw * 0.5 - 6, c.y + radius - 8, tw + 12, 18)
		draw_colored_polygon(Art.rrect(badge, 7), Art.INK)
		draw_string(font, Vector2(badge.position.x + 6, badge.position.y + 14), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.GOLD)
	if label_text != "":
		draw_string_outline(font, Vector2(c.x - 90, c.y + radius + 18), label_text, HORIZONTAL_ALIGNMENT_CENTER, 180, 15, 4, Art.INK)
		draw_string(font, Vector2(c.x - 90, c.y + radius + 18), label_text, HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Art.CREAM)
