extends Node2D
## Pocisk gracza lub przeciwnika. Pozycja = punkt na ziemi; rysowany wyżej (lot).

const LIFT := Vector2(0, -24)

var team := "player"
var dir := Vector2.RIGHT
var speed := 500.0
var damage := 10.0
var radius := 14.0
var travelled := 0.0
var max_range := 500.0
var style := "rune"
var homing := 0.0
var pierce := 1
var effect := ""
var direct := true          # false: pocisk konstrukcji (nie wybiera celu w fazie iluzji)
var t := 0.0
var _hit: Array = []


func init(d: Dictionary) -> void:
	team = d.get("team", "player")
	position = d.get("pos", Vector2.ZERO)
	dir = (d.get("dir", Vector2.RIGHT) as Vector2).normalized()
	speed = d.get("speed", 500.0)
	damage = d.get("damage", 10.0)
	radius = d.get("radius", 14.0)
	max_range = d.get("range", 500.0)
	style = d.get("style", "rune")
	homing = d.get("homing", 0.0)
	pierce = d.get("pierce", 1)
	effect = d.get("effect", "")
	direct = d.get("direct", true)
	z_index = 5


func _physics_process(delta: float) -> void:
	t += delta
	if homing > 0.0:
		var best: Node2D = null
		var bd := 220.0
		for e in World.enemies():
			var dd := global_position.distance_to(e.global_position)
			if dd < bd and (e.global_position - global_position).normalized().dot(dir) > 0.3:
				bd = dd
				best = e
		if best:
			var want := (best.global_position - global_position).normalized()
			dir = dir.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
	var step := speed * delta
	position += dir * step
	travelled += step
	if team == "player":
		for e in World.enemies():
			if e in _hit:
				continue
			if global_position.distance_to(e.global_position) < radius + e.hit_radius:
				var dmg := damage
				if e.mark_t > 0.0:
					dmg *= 1.3
				e.take_damage(dmg, global_position - dir * 20.0, 150.0, direct)
				if effect == "rune_mark":
					e.rune_mark = 4.0
				_hit.append(e)
				pierce -= 1
				World.current.burst(global_position + LIFT, _color(), 6, 40.0)
				if pierce <= 0:
					queue_free()
					return
	else:
		var p := World.player()
		if p and not p.dead:
			if p.dome_t > 0.0 and global_position.distance_to(p.global_position) < 50.0:
				World.current.burst(global_position + LIFT, Color("#9fc7ff"), 8, 40.0)
				queue_free()
				return
			if global_position.distance_to(p.global_position) < radius + 12.0:
				p.take_damage(damage, global_position - dir * 30.0)
				queue_free()
				return
	if travelled > max_range:
		if style == "orb":
			World.current.burst(global_position + LIFT, _color(), 5, 30.0)
		queue_free()
		return
	queue_redraw()


func _color() -> Color:
	match style:
		"rune": return Color("#c89bff")
		"wave": return Color("#5ef2e0")
		"arrow": return Color("#8fe0ff")
		"bolt": return Color("#5ef2e0")
		"orb": return Color("#ff7ad9")
	return Art.CREAM


func _draw() -> void:
	var c := _color()
	var ang := dir.angle()
	Art.shadow(self, Vector2.ZERO, 6, 2.5, 0.18)
	draw_set_transform(LIFT, ang, Vector2.ONE)
	match style:
		"rune":
			Art.glow(self, Vector2.ZERO, 24, Color(c, 0.6))
			draw_line(Vector2(-22, 0), Vector2(0, 0), Color(c, 0.4), 5.0, true)
			Art.rune(self, Vector2.ZERO, 6.0, Art.CREAM, int(t * 8.0), 2.0)
		"wave":
			Art.glow(self, Vector2.ZERO, 30, Color(c, 0.45))
			draw_arc(Vector2(-8, 0), 22, -0.9, 0.9, 14, Color(c, 0.95), 5.0, true)
			draw_arc(Vector2(-16, 0), 18, -0.8, 0.8, 12, Color(c, 0.5), 3.0, true)
		"arrow":
			Art.glow(self, Vector2.ZERO, 18, Color(c, 0.5))
			draw_line(Vector2(-26, 0), Vector2(6, 0), Color(c, 0.35), 4.0, true)
			draw_line(Vector2(-16, 0), Vector2(8, 0), Art.CREAM, 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(4, -5), Vector2(4, 5)]), c)
		"bolt":
			Art.glow(self, Vector2.ZERO, 14, Color(c, 0.6))
			draw_line(Vector2(-12, 0), Vector2(4, 0), Art.CREAM, 3.0, true)
		"orb":
			var pulse := 1.0 + 0.2 * sin(t * 20.0)
			Art.glow(self, Vector2.ZERO, 26 * pulse, Color(c, 0.55))
			Art.circle(self, Vector2.ZERO, 8.0 * pulse, Color("#ffd6f2"), Color("#7a2b6a"), 2.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
