extends Node2D
## BLIK — świetlisty robot-towarzysz. Podąża za graczem i reaguje emocjami.
## Mówi wyłącznie przygotowanymi kwestiami (nie jest modelem AI).

var target: Node2D
var mood := "idle"
var mood_t := 0.0
var talk := 0.0
var t := 0.0
var _vel := Vector2.ZERO


func set_mood(m: String, dur := 3.0) -> void:
	mood = m
	mood_t = dur
	talk = minf(2.5, dur)


func _process(delta: float) -> void:
	t += delta
	mood_t -= delta
	talk = maxf(0.0, talk - delta)
	if mood_t <= 0.0:
		mood = "idle"
	if target and is_instance_valid(target):
		var side := -1.0 if target.aim.x > 0 else 1.0
		var want := target.global_position + Vector2(side * 38, -6)
		var d := want - global_position
		if d.length() > 600.0:
			global_position = want
		_vel = _vel.lerp(d * 4.0, clampf(delta * 5.0, 0.0, 1.0))
		global_position += _vel * delta
	# Ruch daje pozycja węzła; mimikę wystarczy odświeżać co drugą klatkę.
	if Engine.get_process_frames() % 2 == 0:
		queue_redraw()


func _draw() -> void:
	var spin := 0.0
	if mood == "cheer" and not Settings.reduced_motion:
		spin = sin(t * 8.0) * 0.25
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	Art.blik(self, t, mood, talk, Settings.reduced_motion)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
