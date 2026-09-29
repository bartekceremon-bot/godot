extends Node2D
## Widok jednej istoty (gracz lub potwór): sprite, imię, pasek życia, płynny ruch między kafelkami.

const TS := 32

var id := 0
var kind := "m"
var look = "rat"
var display_name := ""
var hp_pct := 100
var dir := 2
var tile := Vector2i.ZERO
var is_me := false
var targeted := false
## Złoża: etykieta widoczna tylko w pobliżu gracza (żeby nie zaśmiecać ekranu).
var show_label := true
## Własna postać zbiera surowiec – animowany pasek nad głową.
var gathering := false

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _move_t := 1.0
var _move_dur := 0.3
var _anim := 0.0
var _frame := 0
var _sprite: Sprite2D


func _init() -> void:
	# Tekst i paski rysujemy z filtrowaniem liniowym, sprite – pikselowo.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


## Aktualizacja z pakietu "snap" serwera.
func apply(e: Dictionary, me: bool) -> void:
	is_me = me
	kind = str(e.k)
	look = e.l
	display_name = str(e.n)
	hp_pct = int(e.h)
	if not me:
		var t := Vector2i(int(e.x), int(e.y))
		if t != tile:
			var d := t - tile
			# Duży skok (teleport / pierwsze pojawienie się) – bez animacji.
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
		if _anim > 0.15:
			_anim = 0.0
			_frame = 1 - _frame
			_refresh()
	elif _frame != 0:
		_frame = 0
		_refresh()
	if gathering:
		queue_redraw()


func _refresh() -> void:
	_sprite.texture = Sprites.creature(look, dir, _frame)
	_sprite.position = Vector2(0, 0) if kind == "r" else Vector2(0, -4)
	# Złoża pod istotami, NPC i gracze normalnie (sortowanie po Y).
	z_index = -1 if kind == "r" else 0
	queue_redraw()


func _draw() -> void:
	if targeted:
		draw_rect(Rect2(1, 1, TS - 2, TS - 2), Color(1, 0.15, 0.1), false, 1.5)
	var font := ThemeDB.fallback_font
	if kind == "r":
		if show_label:
			draw_string_outline(font, Vector2(-44, -2), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 7, 2, Color.BLACK)
			draw_string(font, Vector2(-44, -2), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 7, Color(0.85, 0.95, 0.8))
		return
	if kind == "n":
		draw_string_outline(font, Vector2(-44, -8), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, 2, Color.BLACK)
		draw_string(font, Vector2(-44, -8), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(1, 0.9, 0.4))
		return
	if gathering:
		var t := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		draw_rect(Rect2(4, -22, 24, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(4, -22, 24.0 * t, 4), Color(0.5, 0.9, 0.4))
	var col := Color(0.4, 1, 0.4) if kind == "p" else Color(1, 0.85, 0.5)
	if is_me:
		col = Color(0.6, 0.85, 1)
	draw_string_outline(font, Vector2(-44, -13), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, 2, Color.BLACK)
	draw_string(font, Vector2(-44, -13), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, col)
	var bar_col := Color(0.2, 0.8, 0.2)
	if hp_pct < 60:
		bar_col = Color(0.9, 0.8, 0.1)
	if hp_pct < 30:
		bar_col = Color(0.9, 0.2, 0.1)
	draw_rect(Rect2(4, -10, 24, 3), Color.BLACK)
	draw_rect(Rect2(4, -10, 24.0 * hp_pct / 100.0, 3), bar_col)
