class_name Abilities
extends RefCounted
## Ataki podstawowe i umiejętności czterech klas.

const PROJ := preload("res://scripts/actors/projectile.gd")
const ABILITY := preload("res://scripts/actors/ability_node.gd")


static func _origin(p: Node2D) -> Vector2:
	return p.global_position


static func basic(p: Node2D, cid: String, dmg: float) -> void:
	var w := World.current
	match cid:
		"tkacz":
			w.add_effect(_proj({"team": "player", "pos": _origin(p) + p.aim * 18, "dir": p.aim, "speed": 640.0,
				"damage": dmg, "radius": 16.0, "range": 540.0, "style": "rune", "homing": 3.0, "effect": "rune_mark"}))
			Audio.play("rune")
		"mechanik":
			w.add_effect(_proj({"team": "player", "pos": _origin(p) + p.aim * 18, "dir": p.aim, "speed": 470.0,
				"damage": dmg, "radius": 24.0, "range": 330.0, "style": "wave", "pierce": 3}))
			Audio.play("wrench")
		"tropiciel":
			w.add_effect(_proj({"team": "player", "pos": _origin(p) + p.aim * 18, "dir": p.aim, "speed": 920.0,
				"damage": dmg, "radius": 12.0, "range": 720.0, "style": "arrow"}))
			Audio.play("arrow")
		_:
			var center = _origin(p) + p.aim * 34.0
			var hit := false
			for e in World.enemies():
				var to: Vector2 = e.global_position - _origin(p)
				if to.length() < 92.0 and (to.length() < 30.0 or absf(to.angle_to(p.aim)) < 1.25):
					e.take_damage(dmg, _origin(p), 340.0, true)
					hit = true
			w.slash(center, p.aim, Color("#9fc7ff"))
			Audio.play("hammer" if hit else "swing")
			if hit:
				w.shake(3.0)


static func skill(p: Node2D, cid: String, slot: String) -> void:
	var w := World.current
	var lvl := GameState.level()
	var m := GameState.damage_mult()
	Audio.play("skill")
	match cid + ":" + slot:
		"tkacz:skill1":
			# Łańcuch Poleceń — trafia kolejnych przeciwników jak dobrze połączone kroki.
			var hits := 3 if lvl < 4 else 4
			var from := _origin(p) + Vector2(0, -24)
			var done: Array = []
			var cur_pos := _origin(p)
			var max_d := 400.0
			for i in hits:
				var best: Node2D = null
				var best_d := max_d
				for e in World.enemies():
					if e in done:
						continue
					var d := cur_pos.distance_to(e.global_position)
					if i == 0 and (e.global_position - _origin(p)).normalized().dot(p.aim) < 0.2 and d > 120.0:
						continue
					if d < best_d:
						best_d = d
						best = e
				if best == null:
					break
				var bonus := 1.3 if best.rune_mark > 0.0 else 1.0
				best.take_damage(24.0 * m * bonus, cur_pos, 120.0, false)
				best.rune_mark = 4.0
				w.lightning(from, best.global_position + Vector2(0, -20), Color("#c89bff"))
				from = best.global_position + Vector2(0, -20)
				cur_pos = best.global_position
				done.append(best)
				max_d = 230.0
			if done.is_empty():
				w.lightning(from, from + p.aim * 160.0, Color("#c89bff"))
		"tkacz:skill2":
			var pos := _clamp_walk(_origin(p), _origin(p) + p.aim * 170.0)
			var dur := 4.0 * 1.4   # pasywna: dłuższe działanie poprawnie połączonych run
			w.add_effect(_ability("field", pos, {"duration": dur, "radius": 140.0 if lvl >= 5 else 110.0, "damage": 7.0 * m}))
		"mechanik:skill1":
			w.add_effect(_ability("drone", _origin(p), {"duration": 14.0 if lvl >= 4 else 10.0, "damage": 8.0 * m, "owner": p}))
		"mechanik:skill2":
			var pos := _clamp_walk(_origin(p), _origin(p) + p.aim * 60.0)
			w.add_effect(_ability("turret", pos, {"duration": 16.0 if lvl >= 5 else 12.0, "damage": 9.0 * m, "double": lvl >= 5}))
		"tropiciel:skill1":
			var r := 480.0 if lvl >= 4 else 360.0
			w.ring(_origin(p) + Vector2(0, -10), Color("#8fe0ff"), r)
			for e in World.enemies():
				if e.global_position.distance_to(_origin(p)) < r:
					e.mark_t = 9.0 if lvl >= 4 else 6.0
					e.on_scanned()
			w.scan_pulse(_origin(p), r)
		"tropiciel:skill2":
			var dir: Vector2 = p.move_dir.normalized() if p.move_dir.length() > 0.1 else p.aim
			var start := _origin(p)
			_burst_damage(start, 90.0, 20.0 * m)
			var target := _clamp_walk(start, start + dir * 210.0)
			p.global_position = target
			p.invuln = maxf(p.invuln, 0.45)
			w.lightning(start + Vector2(0, -20), target + Vector2(0, -20), Color("#8fe0ff"))
			if lvl >= 5:
				_burst_damage(target, 90.0, 16.0 * m)
		"straznik:skill1":
			p.dome_t = 7.0 if lvl >= 4 else 5.0
			w.ring(_origin(p) + Vector2(0, -26), Color("#9fc7ff"), 60.0)
		"straznik:skill2":
			var r := 220.0 if lvl >= 5 else 170.0
			_burst_damage(_origin(p), r, 26.0 * m, 520.0)
			w.ring(_origin(p), Color("#9fc7ff"), r)
			w.clear_enemy_shots(_origin(p), r)
			GameState.hp = minf(GameState.max_hp(), GameState.hp + GameState.max_hp() * 0.08)
			w.shake(5.0)


static func _burst_damage(pos: Vector2, r: float, dmg: float, knock := 260.0) -> void:
	World.current.burst(pos + Vector2(0, -16), Art.CREAM, 16, r)
	for e in World.enemies():
		if e.global_position.distance_to(pos) < r:
			e.take_damage(dmg, pos, knock, false)


static func _clamp_walk(from: Vector2, to: Vector2) -> Vector2:
	## Skoki i pola nie mogą wylądować poza wyspą.
	for i in 12:
		var p := to.lerp(from, i / 12.0)
		if World.current.is_walkable(p):
			return p
	return from


static func _proj(d: Dictionary) -> Node2D:
	var n: Node2D = PROJ.new()
	n.init(d)
	return n


static func _ability(kind: String, pos: Vector2, d: Dictionary) -> Node2D:
	var n: Node2D = ABILITY.new()
	n.init(kind, pos, d)
	return n
