extends Node2D
## Widok istoty (scena scenes/entity.tscn): gracz, potwór, NPC albo złoże surowca.
## Gracze składani są z warstw (ciało + założony ekwipunek), więc widać, co kto nosi.
## Płynny ruch między kafelkami, animacja chodu (4 klatki), błysk przy trafieniu,
## pierścień celu, imię i pasek życia.

const TS := 32

var id := 0
var kind := "m"
var look = "rat"
var display_name := ""
var hp_pct := 100
var dir := 2
var tile := Vector2i.ZERO
var is_me := false
var targeted := false:
	set(v):
		targeted = v
		_redraw()
var show_label := true:
	set(v):
		show_label = v
		_redraw()
var gathering := false:
	set(v):
		gathering = v
		_redraw()
## Czaszka gracza: "", "white", "red".
var skull := ""
## Wygląd ekwipunku: [głowa, tułów, nogi, stopy, broń, tarcza] (id przedmiotów).
var equipment: Array = []

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _move_t := 1.0
var _move_dur := 0.3
var _anim := 0.0
var _frame := 0
var _facing_right := true
var _flash_tween: Tween

@onready var shadow: Sprite2D = $Shadow
@onready var layers: Node2D = $Layers
@onready var body: Sprite2D = $Layers/Body
@onready var overlay: Node2D = $Overlay
@onready var light: PointLight2D = $Light
@onready var _slots := {
	"head": $Layers/Head, "body": $Layers/Armor, "legs": $Layers/Legs, "feet": $Layers/Feet,
	"weapon": $Layers/Weapon, "shield": $Layers/Shield,
}


func _redraw() -> void:
	if is_node_ready():
		overlay.queue_redraw()


func _ready() -> void:
	overlay.draw.connect(_draw_overlay)
	# Pojawienie się: krótkie rozjaśnienie.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


## Aktualizacja z pakietu "snap" serwera.
func apply(e: Dictionary, me: bool) -> void:
	is_me = me
	kind = str(e.k)
	look = e.l
	display_name = str(e.n)
	hp_pct = int(e.h)
	equipment = e.get("eq", [])
	skull = str(e.get("sk", ""))
	if not me:
		var t := Vector2i(int(e.x), int(e.y))
		if t != tile:
			var d := t - tile
			if absi(d.x) > 1 or absi(d.y) > 1 or position == Vector2.ZERO:
				snap_to(t)
			else:
				move_to(t, maxf(0.1, float(e.s) / 1000.0))
		dir = int(e.d)
	_refresh()


func snap_to(t: Vector2i) -> void:
	tile = t
	_to = Vector2(t) * TS
	_from = _to
	_move_t = 1.0
	position = _to


func move_to(t: Vector2i, duration: float, new_dir: int = -1) -> void:
	var dx := t.x - tile.x
	if dx != 0:
		_facing_right = dx > 0
	_from = position
	tile = t
	_to = Vector2(t) * TS
	_move_t = 0.0
	_move_dur = duration
	if new_dir >= 0:
		dir = new_dir
	_refresh()


func is_moving() -> bool:
	return _move_t < 1.0


func _process(delta: float) -> void:
	if _move_t < 1.0:
		_move_t = minf(1.0, _move_t + delta / _move_dur)
		position = _from.lerp(_to, _move_t)
		_anim += delta
		if _anim > 0.11:
			_anim = 0.0
			_frame = (_frame + 1) % 4
			_update_frames()
	elif _frame != 0:
		_frame = 0
		_update_frames()
	if targeted or gathering:
		overlay.queue_redraw()


## Biały błysk po trafieniu.
func flash() -> void:
	var mat := layers.material as ShaderMaterial
	if mat == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	mat.set_shader_parameter("flash", 0.85)
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v): mat.set_shader_parameter("flash", v), 0.85, 0.0, 0.22)


## Znikanie (śmierć / wyjście z pola widzenia).
func vanish() -> void:
	set_process(false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func _refresh() -> void:
	var s := str(look)
	if kind == "r":
		# Złoże: sprite 64x64 stojący na kafelku, bez cienia (jest w grafice).
		shadow.visible = false
		body.texture = Sprites.nodes_tex
		body.region_rect = Sprites.node_region(s)
		body.position = Vector2(-16, -32)
		for k in _slots:
			_slots[k].visible = false
	elif Sprites.is_beast(s):
		shadow.visible = false
		body.texture = Sprites.beasts_tex
		body.position = Vector2(0, -2)
		for k in _slots:
			_slots[k].visible = false
	else:
		shadow.visible = true
		body.texture = Sprites.layers_tex
		body.position = Vector2(0, -2)
		_setup_equipment(s)
	_update_frames()
	overlay.queue_redraw()


## Warstwy ekwipunku z id przedmiotów (np. "plate_body_t2" -> warstwa o tej samej nazwie).
func _setup_equipment(s: String) -> void:
	var names := {}
	if kind == "p" and equipment.size() == 6:
		var slots := ["head", "body", "legs", "feet", "weapon", "shield"]
		for i in 6:
			var item := str(equipment[i])
			if item != "" and Sprites.has_layer(item):
				names[slots[i]] = item
	elif s == "skeleton":
		names["weapon"] = "sword_skeleton"
	for k in _slots:
		var spr: Sprite2D = _slots[k]
		spr.visible = names.has(k)
		if spr.visible:
			spr.texture = Sprites.layers_tex
			spr.set_meta("layer", names[k])


func _body_layer() -> String:
	var s := str(look)
	if kind == "p":
		return "body_%d" % (int(look) % 8)
	if s == "skeleton":
		return "body_skeleton"
	return s


func _update_frames() -> void:
	if kind == "r":
		return
	var s := str(look)
	if Sprites.is_beast(s):
		if dir == 1:
			_facing_right = true
		elif dir == 3:
			_facing_right = false
		body.region_rect = Sprites.beast_region(s, _facing_right, _frame)
		return
	body.region_rect = Sprites.layer_region(_body_layer(), dir, _frame)
	for k in _slots:
		var spr: Sprite2D = _slots[k]
		if spr.visible:
			spr.region_rect = Sprites.layer_region(str(spr.get_meta("layer")), dir, _frame)
	# Tarcza za plecami (widok z tyłu i z boku), broń za plecami od tyłu.
	var shield: Sprite2D = _slots["shield"]
	layers.move_child(shield, 0 if dir != 2 else layers.get_child_count() - 1)


func _draw_overlay() -> void:
	var o := overlay
	var font := ThemeDB.fallback_font
	if targeted:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		o.draw_arc(Vector2(16, 28), 13.0, 0, TAU, 32, Color(1, 0.2, 0.1, pulse), 1.5)
	if kind == "r":
		if show_label:
			o.draw_string_outline(font, Vector2(-44, -34), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 7, 2, Color.BLACK)
			o.draw_string(font, Vector2(-44, -34), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 7, Color(0.85, 0.95, 0.8))
		return
	var col := Color(0.45, 1, 0.45) if kind == "p" else Color(1, 0.85, 0.5)
	if kind == "n":
		col = Color(1, 0.9, 0.4)
	if is_me:
		col = Color(0.6, 0.85, 1)
	var name_y := -12 if kind != "n" else -6
	o.draw_string_outline(font, Vector2(-44, name_y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, 3, Color(0, 0, 0, 0.9))
	o.draw_string(font, Vector2(-44, name_y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, col)
	if skull != "":
		var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		o.draw_texture_rect(Sprites.icon("skull_" + skull), Rect2(16 - w / 2.0 - 12, name_y - 9, 10, 10), false)
	if kind == "n":
		return
	if gathering:
		var t := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		o.draw_rect(Rect2(4, -22, 24, 4), Color(0, 0, 0, 0.7))
		o.draw_rect(Rect2(4, -22, 24.0 * t, 4), Color(0.5, 0.9, 0.4))
	var bar_col := Color(0.25, 0.85, 0.25)
	if hp_pct < 60:
		bar_col = Color(0.95, 0.8, 0.15)
	if hp_pct < 30:
		bar_col = Color(0.95, 0.2, 0.1)
	o.draw_rect(Rect2(3, -9, 26, 4), Color(0, 0, 0, 0.8))
	o.draw_rect(Rect2(4, -8, 24.0 * hp_pct / 100.0, 2), bar_col)
