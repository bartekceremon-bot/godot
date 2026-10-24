extends Node2D
## Iskierka zdrowia lub energii wypadająca z przeciwników — przyciągana do gracza.

var kind := "heal"
var t := 0.0


func _physics_process(delta: float) -> void:
	t += delta
	var p := World.player()
	if p and not p.dead:
		var d := global_position.distance_to(p.global_position)
		if d < 140.0 or t > 1.0:
			global_position = global_position.move_toward(p.global_position, (260.0 + 300.0 * t) * delta)
		if d < 20.0:
			if kind == "heal":
				GameState.hp = minf(GameState.max_hp(), GameState.hp + 14.0)
			else:
				GameState.energy = minf(GameState.max_energy(), GameState.energy + 22.0)
			GameState.stats_changed.emit()
			Audio.play("pickup", 0.1, -6.0)
			queue_free()
			return
	if t > 12.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var c := Color("#7dffb0") if kind == "heal" else Color("#5ef2e0")
	var y := -16.0 + sin(t * 5.0) * 4.0
	Art.shadow(self, Vector2.ZERO, 6, 2, 0.2)
	Art.glow(self, Vector2(0, y), 18, Color(c, 0.6))
	Art.poly(self, Art.star(Vector2(0, y), 7, 3, 4, t * 2.0), c, Art.INK, 1.2)
