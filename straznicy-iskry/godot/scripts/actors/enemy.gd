extends CharacterBody2D
## Przeciwnicy z Mgły Chaosu. Każdy atak ma wyraźną zapowiedź (telegraf).

const PROJ := preload("res://scripts/actors/projectile.gd")
const PICKUP := preload("res://scripts/actors/pickup.gd")

var kind := "szumik"
var def: Dictionary = {}
var tag := ""
var hp := 30.0
var max_hp := 30.0
var speed := 100.0
var damage := 10.0
var xp := 5
var hit_radius := 16.0
var home := Vector2.ZERO
var state := "idle"
var state_t := 0.0
var t := 0.0
var tele := 0.0
var hurt := 0.0
var mark_t := 0.0
var rune_mark := 0.0
var slow_t := 0.0
var knock := Vector2.ZERO
var alive := true
var target_pos := Vector2.ZERO
var aggro := false
var _hit_done := false
var _wander := Vector2.ZERO
var _cool := 0.0
var is_boss := false


func setup(k: String, pos: Vector2, d: Dictionary = {}) -> void:
	kind = k
	def = Data.get_enemy(k)
	position = pos
	home = pos
	tag = d.get("tag", "")
	max_hp = float(def.get("hp", 30))
	hp = max_hp
	speed = float(def.get("speed", 100))
	damage = float(def.get("damage", 10))
	xp = int(def.get("xp", 5))
	hit_radius = float(def.get("radius", 16))
	_cool = randf_range(0.5, 1.5)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = hit_radius * 0.7
	cs.shape = c
	add_child(cs)


func on_scanned() -> void:
	pass


func _physics_process(delta: float) -> void:
	t += delta
	hurt = maxf(0.0, hurt - delta * 4.0)
	mark_t = maxf(0.0, mark_t - delta)
	rune_mark = maxf(0.0, rune_mark - delta)
	slow_t = maxf(0.0, slow_t - delta)
	_cool = maxf(0.0, _cool - delta)
	if not alive:
		state_t += delta
		modulate.a = 1.0 - state_t / 0.5
		if state_t > 0.5:
			queue_free()
		queue_redraw()
		return
	var p := World.player()
	var sp := speed * (0.45 if slow_t > 0.0 else 1.0)
	var to_p := Vector2.ZERO
	var dist := INF
	if p and not p.dead:
		to_p = p.global_position - global_position
		dist = to_p.length()
	if dist < float(def.get("aggro", 380)):
		aggro = true
	if global_position.distance_to(home) > 700.0 or dist > 900.0 or (p and p.dead):
		aggro = false
	state_t += delta
	var desired := Vector2.ZERO
	match state:
		"idle":
			if aggro:
				_set_state("chase")
			else:
				if fmod(t, 3.0) < delta:
					_wander = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.0, 0.5)
				var back := (home - global_position)
				desired = (_wander + back / 400.0).limit_length(1.0) * sp * 0.4
		"chase":
			if not aggro:
				_set_state("idle")
			else:
				desired = _chase(to_p, dist, sp)
		"windup":
			tele = clampf(state_t / _windup_time(), 0.0, 1.0)
			if kind == "zaklocacz" and p:
				target_pos = p.global_position
			if state_t >= _windup_time():
				_attack(p)
		"attack":
			if kind == "szumik":
				desired = (target_pos - global_position).normalized() * 430.0
				if p and not _hit_done and global_position.distance_to(p.global_position) < 26.0:
					p.take_damage(damage, global_position)
					_hit_done = true
				if state_t > 0.3:
					_set_state("recover")
			else:
				_set_state("recover")
		"recover":
			tele = maxf(0.0, tele - delta * 4.0)
			desired = Vector2.ZERO
			if state_t > float(def.get("recover", 0.8)):
				_set_state("chase" if aggro else "idle")
	velocity = velocity.move_toward(desired, 900.0 * delta) + knock
	knock = knock.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	if World.current == null or World.current.on_screen(global_position, 120.0):
		queue_redraw()


func _windup_time() -> float:
	return float(def.get("windup", 0.6))


func _chase(to_p: Vector2, dist: float, sp: float) -> Vector2:
	match kind:
		"zaklocacz":
			if _cool <= 0.0 and dist < 420.0:
				target_pos = global_position + to_p
				_set_state("windup")
				return Vector2.ZERO
			if dist < 200.0:
				return -to_p.normalized() * sp
			if dist > 300.0:
				return to_p.normalized() * sp
			return to_p.normalized().orthogonal() * sp * 0.5 * sin(t)
		"golem":
			if dist < 95.0 and _cool <= 0.0:
				_set_state("windup")
				return Vector2.ZERO
			return to_p.normalized() * sp
		_:
			if dist < 120.0 and _cool <= 0.0:
				target_pos = global_position + to_p.normalized() * 150.0
				_set_state("windup")
				return Vector2.ZERO
			# Lekki zygzak, żeby szumiki nie szły gęsiego.
			return (to_p.normalized() + to_p.normalized().orthogonal() * sin(t * 3.0 + home.x) * 0.4).normalized() * sp


func _attack(p: Node2D) -> void:
	_hit_done = false
	_cool = float(def.get("cooldown", 1.5))
	match kind:
		"zaklocacz":
			var dir := (target_pos - global_position).normalized()
			var shots := [0.0] if def.get("spread", 1) == 1 else [-0.25, 0.0, 0.25]
			for off in shots:
				var pr: Node2D = PROJ.new()
				pr.init({"team": "enemy", "pos": global_position, "dir": dir.rotated(off), "speed": 270.0,
					"damage": damage, "radius": 12.0, "range": 560.0, "style": "orb"})
				World.current.add_effect(pr)
			Audio.play("enemy_shot", 0.1, -4.0)
		"golem":
			World.current.ring(global_position, Art.DANGER, 110.0)
			World.current.shake(5.0)
			Audio.play("slam")
			if p and not p.dead and global_position.distance_to(p.global_position) < 100.0:
				p.take_damage(damage, global_position)
		_:
			Audio.play("lunge", 0.1, -6.0)
	_set_state("attack")


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if s != "windup" and s != "recover":
		tele = 0.0


func take_damage(amount: float, from: Vector2, knock_force := 150.0, _direct := true) -> void:
	if not alive:
		return
	hp -= amount
	hurt = 1.0
	aggro = true
	var resist := float(def.get("knock_resist", 0.0))
	knock = (global_position - from).normalized() * knock_force * (1.0 - resist)
	World.current.float_text(global_position + Vector2(0, -50), str(int(round(amount))), Art.CREAM if mark_t <= 0.0 else Color("#8fe0ff"))
	Audio.play("hit", 0.15, -4.0)
	if hp <= 0.0:
		die()


func die() -> void:
	alive = false
	state_t = 0.0
	remove_from_group("enemies")
	collision_layer = 0
	Audio.play("enemy_die")
	World.current.burst(global_position + Vector2(0, -20), Art.MIST, 16, 70.0)
	World.current.burst(global_position + Vector2(0, -20), Art.GOLD, 8, 40.0)
	GameState.add_xp(xp)
	World.current.float_text(global_position + Vector2(0, -70), "+%d PD" % xp, Art.GOLD)
	if randf() < float(def.get("drop", 0.3)):
		var pk: Node2D = PICKUP.new()
		pk.position = global_position
		pk.kind = "heal" if randf() < 0.55 else "energy"
		World.current.add_effect(pk)
	World.current.enemy_died(self)


func _draw() -> void:
	# Zapowiedzi ataków rysowane na ziemi — muszą być dobrze widoczne.
	if state == "windup" or (state == "attack" and kind == "szumik"):
		match kind:
			"szumik":
				var to := target_pos - global_position
				draw_line(Vector2.ZERO, to, Color(Art.DANGER, 0.25 + tele * 0.5), 10.0 * tele + 2.0, true)
			"zaklocacz":
				var to := (target_pos - global_position).normalized() * 520.0
				draw_line(Vector2(0, -24), to + Vector2(0, -24), Color(Art.DANGER, 0.15 + tele * 0.55), 2.0 + tele * 3.0, true)
			"golem":
				draw_colored_polygon(Art.ellipse(Vector2.ZERO, 100 * tele, 60 * tele, 30), Color(Art.DANGER, 0.18 + tele * 0.22))
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.6))
				draw_arc(Vector2.ZERO, 100, 0, TAU, 40, Color(Art.DANGER, 0.8), 3.0, true)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if mark_t > 0.0:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
		draw_arc(Vector2.ZERO, hit_radius + 10, 0, TAU, 24, Color("#8fe0ff", 0.8), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if rune_mark > 0.0:
		Art.rune(self, Vector2(0, -hit_radius * 3.2 - 10), 4.0, Color("#c89bff", 0.9), 0, 1.6)
	Art.enemy(self, kind, {"t": t, "tele": tele, "hurt": hurt, "aim": (target_pos - global_position).normalized() if target_pos != Vector2.ZERO else Vector2.RIGHT, "moving": velocity.length() > 20.0})
	# Pasek zdrowia po pierwszym trafieniu.
	if hp < max_hp and alive:
		var w := 36.0
		var y := -hit_radius * 3.0 - 18.0
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 6), Art.INK)
		draw_rect(Rect2(-w / 2, y, w * hp / max_hp, 4), Art.DANGER)
