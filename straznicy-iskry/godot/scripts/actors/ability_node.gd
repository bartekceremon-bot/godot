extends Node2D
## Trwałe efekty umiejętności: Pole Doprecyzowania, Dron Pomocnik, Wieżyczka Iskrowa.

const PROJ := preload("res://scripts/actors/projectile.gd")

var kind := "field"
var duration := 4.0
var life := 0.0
var radius := 110.0
var damage := 7.0
var owner_node: Node2D
var double := false
var t := 0.0
var _tick := 0.0
var _fire := 0.0
var _aim := Vector2.RIGHT


func init(k: String, pos: Vector2, d: Dictionary) -> void:
	kind = k
	position = pos
	duration = d.get("duration", 4.0)
	radius = d.get("radius", 110.0)
	damage = d.get("damage", 7.0)
	owner_node = d.get("owner", null)
	double = d.get("double", false)
	z_index = -1 if kind == "field" else 4


func _physics_process(delta: float) -> void:
	t += delta
	life += delta
	if life >= duration:
		World.current.burst(global_position + Vector2(0, -20), Art.CREAM, 8, 50.0)
		queue_free()
		return
	match kind:
		"field":
			_tick -= delta
			for e in World.enemies():
				if e.global_position.distance_to(global_position) < radius:
					e.slow_t = 0.3
					if _tick <= 0.0:
						e.take_damage(damage, global_position, 0.0)
			if _tick <= 0.0:
				_tick = 0.5
		"drone":
			if is_instance_valid(owner_node):
				var a := t * 2.2
				var target := owner_node.global_position + Vector2(cos(a) * 46, sin(a) * 22)
				global_position = global_position.lerp(target, clampf(delta * 8.0, 0.0, 1.0))
			_shoot(delta, 0.55, 360.0)
		"turret":
			_shoot(delta, 0.45, 420.0)
	queue_redraw()


func _shoot(delta: float, rate: float, rng: float) -> void:
	_fire -= delta
	if _fire > 0.0:
		return
	var best: Node2D = null
	var bd := rng
	for e in World.enemies():
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	_fire = rate
	_aim = (best.global_position - global_position).normalized()
	var shots := [0.0]
	if double:
		shots = [-0.12, 0.12]
	for off in shots:
		var p: Node2D = PROJ.new()
		p.init({"team": "player", "pos": global_position, "dir": _aim.rotated(off), "speed": 700.0,
			"damage": damage, "radius": 10.0, "range": rng + 40.0, "style": "bolt"})
		World.current.add_effect(p)
	Audio.play("bolt", 0.1, -8.0)


func _draw() -> void:
	var fade := clampf(duration - life, 0.0, 1.0)
	match kind:
		"field":
			var a := 0.35 * fade
			draw_colored_polygon(Art.ellipse(Vector2.ZERO, radius, radius * 0.55, 36), Color("#6b3fa0", a))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(Art.GOLD, 0.8 * fade), 2.0, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.55))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(Art.GOLD, 0.8 * fade), 3.0, true)
			for i in 6:
				var ang := t * 0.8 + i * TAU / 6
				Art.rune(self, Vector2(cos(ang), sin(ang)) * radius * 0.75, 7.0, Color("#c89bff", fade), i, 2.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"drone":
			Art.shadow(self, Vector2(0, 0), 8, 3, 0.2)
			var c := Vector2(0, -44 + sin(t * 6.0) * 2)
			Art.glow(self, c, 20, Color("#5ef2e0", 0.4))
			Art.circle(self, c, 8, Color("#d98a2b"))
			draw_circle(c + _aim * 3, 3, Color("#5ef2e0"))
			var spin := t * 30.0
			draw_line(c + Vector2(-14, -8) + Vector2(cos(spin), 0) * 6, c + Vector2(-14, -8) - Vector2(cos(spin), 0) * 6, Art.INK, 2.0)
			draw_line(c + Vector2(14, -8) + Vector2(cos(spin), 0) * 6, c + Vector2(14, -8) - Vector2(cos(spin), 0) * 6, Art.INK, 2.0)
			draw_line(c + Vector2(-8, -4), c + Vector2(-14, -8), Art.INK, 2.0)
			draw_line(c + Vector2(8, -4), c + Vector2(14, -8), Art.INK, 2.0)
		"turret":
			var grow := minf(1.0, life * 4.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2(grow, grow))
			Art.shadow(self, Vector2.ZERO, 20, 7)
			Art.poly(self, PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(10, -20), Vector2(-10, -20)]), Color("#a35f17"))
			Art.circle(self, Vector2(0, -26), 11, Color("#d98a2b"))
			Art.line(self, Vector2(0, -26), Vector2(0, -26) + _aim * 20, Color("#5d6a73"), 5.0)
			Art.glow(self, Vector2(0, -26), 18, Color("#5ef2e0", 0.35 + 0.2 * sin(t * 6.0)))
			draw_circle(Vector2(0, -26), 4, Color("#5ef2e0"))
			# Pasek czasu działania
			draw_arc(Vector2(0, -26), 15, -PI / 2, -PI / 2 + TAU * (1.0 - life / duration), 20, Color(Art.GOLD, 0.8), 2.0, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
