extends CharacterBody2D
## Miraż — twórca przekonujących iluzji. Kopie demaskuje się, sprawdzając
## kilka wskazówek naraz (cień, mruganie, migotanie), a nie ufając wyglądowi.

const PROJ := preload("res://scripts/actors/projectile.gd")
const ENEMY := preload("res://scripts/actors/enemy.gd")
const INTER := preload("res://scripts/world/interactable.gd")

signal defeated

var role := "real"           # "real" | "copy"
var master: Node = null
var props := {"shadow": true, "blinks": true, "shimmer": false}
var hp := 640.0
var max_hp := 640.0
var hit_radius := 34.0
var t := 0.0
var tele := 0.0
var hurt := 0.0
var mark_t := 0.0
var rune_mark := 0.0
var slow_t := 0.0
var alive := true
var is_boss := true
var arena := Vector2.ZERO
var phase := 1
var illusion := false
var revealed := 0.0
var wrong_hits := 0
var state := "float"
var state_t := 0.0
var _attack_cd := 2.0
var _summon_cd := 6.0
var _copies: Array = []
var _clues: Array = []
var _fan_dirs: Array = []
var _dash_to := Vector2.ZERO
var _move_to := Vector2.ZERO


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 if role == "real" else 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 22.0
	cs.shape = c
	add_child(cs)
	if role == "real":
		arena = global_position
		_move_to = global_position


func on_scanned() -> void:
	# Skan Źródła (Tropiciel) od razu pokazuje prawdziwego Miraża.
	var real: Node = self if role == "real" else master
	if is_instance_valid(real) and real.illusion:
		real.revealed = 1.0
		World.current.blik_say("Skan Źródła potwierdził: złota obwódka to prawdziwy Miraż!", "cheer")


func _physics_process(delta: float) -> void:
	t += delta
	hurt = maxf(0.0, hurt - delta * 4.0)
	mark_t = maxf(0.0, mark_t - delta)
	rune_mark = maxf(0.0, rune_mark - delta)
	if not alive:
		state_t += delta
		modulate.a = maxf(0.0, 1.0 - state_t / 1.2)
		if state_t > 1.2:
			queue_free()
		queue_redraw()
		return
	if role == "copy":
		global_position = global_position.lerp(_move_to, clampf(delta * 2.0, 0.0, 1.0))
		queue_redraw()
		return
	state_t += delta
	var p := World.player()
	if illusion:
		global_position = global_position.lerp(_move_to, clampf(delta * 2.0, 0.0, 1.0))
		queue_redraw()
		return
	_attack_cd -= delta
	_summon_cd -= delta
	match state:
		"float":
			if fmod(t, 3.5) < delta:
				_move_to = arena + Vector2(randf_range(-220, 220), randf_range(-120, 120))
			global_position = global_position.lerp(_move_to, clampf(delta * 1.2, 0.0, 1.0))
			if _attack_cd <= 0.0 and p and not p.dead:
				if phase >= 3 and randf() < 0.4:
					state = "dash_windup"
					_dash_to = p.global_position
				else:
					state = "fan_windup"
					var base = (p.global_position - global_position).angle()
					var n := 5 + phase
					_fan_dirs.clear()
					for i in n:
						_fan_dirs.append(Vector2.from_angle(base + (i - (n - 1) / 2.0) * 0.22))
				state_t = 0.0
			if _summon_cd <= 0.0:
				_summon_cd = 11.0 - phase * 1.5
				_summon(2)
		"fan_windup":
			tele = clampf(state_t / 0.9, 0.0, 1.0)
			if state_t > 0.9:
				for d in _fan_dirs:
					var pr: Node2D = PROJ.new()
					pr.init({"team": "enemy", "pos": global_position, "dir": d, "speed": 250.0,
						"damage": 13.0, "radius": 12.0, "range": 640.0, "style": "orb"})
					World.current.add_effect(pr)
				Audio.play("enemy_shot")
				_end_attack()
		"dash_windup":
			tele = clampf(state_t / 0.8, 0.0, 1.0)
			if state_t > 0.8:
				state = "dash"
				state_t = 0.0
				Audio.play("lunge")
		"dash":
			global_position = global_position.move_toward(_dash_to, 900.0 * delta)
			if p and not p.dead and global_position.distance_to(p.global_position) < 40.0:
				p.take_damage(18.0, global_position)
			if global_position.distance_to(_dash_to) < 4.0 or state_t > 0.8:
				_end_attack()
	queue_redraw()


func _end_attack() -> void:
	state = "float"
	state_t = 0.0
	tele = 0.0
	_attack_cd = 2.6 - phase * 0.35


func _summon(n: int) -> void:
	var alive_minions := 0
	for e in World.enemies():
		if not e.is_boss:
			alive_minions += 1
	for i in min(n, 4 - alive_minions):
		var e: Node2D = ENEMY.new()
		e.setup("szumik", global_position + Vector2(randf_range(-80, 80), randf_range(30, 80)), {"tag": "boss_minion"})
		World.current.add_enemy(e)
		e.aggro = true
	if n > 0:
		World.current.burst(global_position, Art.MIST, 18, 90.0)


func take_damage(amount: float, from: Vector2, _knock := 0.0) -> void:
	if not alive:
		return
	if role == "copy":
		if is_instance_valid(master):
			master.copy_hit(self)
		return
	if illusion:
		_real_found()
		return
	hp -= amount
	hurt = 1.0
	World.current.float_text(global_position + Vector2(0, -110), str(int(round(amount))), Art.CREAM)
	Audio.play("hit", 0.1, -4.0)
	World.current.boss_hp(hp / max_hp)
	if phase == 1 and hp < max_hp * 0.66:
		_begin_illusion(2)
	elif phase == 2 and hp < max_hp * 0.33:
		_begin_illusion(3)
	elif hp <= 0.0:
		_die()


func _begin_illusion(next_phase: int) -> void:
	phase = next_phase
	illusion = true
	revealed = 0.0
	wrong_hits = 0
	tele = 0.0
	state = "float"
	Audio.play("illusion")
	World.current.shake(6.0)
	World.current.clear_enemy_shots(global_position, 2000.0)
	var spots := [arena + Vector2(-240, -40), arena + Vector2(0, -150), arena + Vector2(240, -40)]
	spots.shuffle()
	var phase_def: Dictionary = Data.get_enemy("miraz").get("illusions", [])[next_phase - 2]
	var copy_props: Array = phase_def.get("copies", [])
	_move_to = spots[0]
	props = {"shadow": true, "blinks": true, "shimmer": false}
	for i in copy_props.size():
		var c: CharacterBody2D = get_script().new()
		c.role = "copy"
		c.master = self
		c.hp = 1.0
		c.props = {"shadow": copy_props[i].get("shadow", true), "blinks": copy_props[i].get("blinks", true), "shimmer": copy_props[i].get("shimmer", false)}
		c.position = global_position
		c._move_to = spots[i + 1]
		c.t = randf() * 2.0
		World.current.add_enemy(c)
		_copies.append(c)
	# Kamienie Prawdy z wskazówkami.
	var clue_spots := [arena + Vector2(-330, 170), arena + Vector2(330, 170)]
	var texts: Array = phase_def.get("clues", [])
	for i in texts.size():
		var stone: Node2D = INTER.new()
		stone.position = clue_spots[i % clue_spots.size()]
		stone.setup("clue", {"id": "clue_%d_%d" % [next_phase, i], "text": texts[i], "title": "Kamień Prawdy"})
		World.current.add_interactable(stone)
		_clues.append(stone)
	World.current.blik_say(str(phase_def.get("intro", "Trzy Miraże! Tylko jeden jest prawdziwy. Przeczytaj Kamienie Prawdy.")), "surprised")


func copy_hit(copy: Node) -> void:
	if not copy in _copies:
		return
	_copies.erase(copy)
	copy.alive = false
	copy.remove_from_group("enemies")
	World.current.burst(copy.global_position + Vector2(0, -60), Art.MIST, 24, 90.0)
	Audio.play("illusion_pop")
	wrong_hits += 1
	_summon(1)
	if wrong_hits >= 2 or _copies.is_empty():
		revealed = 1.0
		World.current.blik_say("To była iluzja. Złota obwódka pokazuje prawdziwego Miraża — sprawdzaj kilka wskazówek naraz!", "thinking")
	else:
		World.current.blik_say("Iluzja! Porównaj pozostałe postacie ze wskazówkami z Kamieni Prawdy.", "worried")


func _real_found() -> void:
	illusion = false
	revealed = 0.0
	Audio.play("reveal")
	World.current.blik_say("Mamy go! Prawdziwy Miraż spełniał wszystkie wskazówki naraz.", "cheer")
	for c in _copies:
		if is_instance_valid(c):
			c.alive = false
			c.remove_from_group("enemies")
			World.current.burst(c.global_position + Vector2(0, -60), Art.MIST, 16, 70.0)
	_copies.clear()
	for s in _clues:
		if is_instance_valid(s):
			s.queue_free()
	_clues.clear()
	hp -= max_hp * 0.04
	hurt = 1.0
	_move_to = arena
	_attack_cd = 2.5
	World.current.boss_hp(hp / max_hp)


func _die() -> void:
	alive = false
	state_t = 0.0
	remove_from_group("enemies")
	collision_layer = 0
	Audio.play("boss_die")
	World.current.shake(10.0)
	for i in 3:
		World.current.burst(global_position + Vector2(randf_range(-40, 40), -60 + randf_range(-30, 30)), [Art.MIST, Art.GOLD, Art.TEAL][i], 30, 140.0)
	for e in World.enemies():
		e.take_damage(999.0, global_position, 0.0)
	GameState.add_xp(150)
	defeated.emit()


func _draw() -> void:
	if role == "real" and state == "fan_windup":
		for d in _fan_dirs:
			draw_line(Vector2(0, -60), Vector2(0, -60) + d * (120 + 260 * tele), Color(Art.DANGER, 0.15 + tele * 0.4), 2.0 + tele * 2.0, true)
	if role == "real" and state == "dash_windup":
		draw_line(Vector2.ZERO, _dash_to - global_position, Color(Art.DANGER, 0.2 + tele * 0.5), 12.0 * tele + 2.0, true)
	var shim := 0.0
	if props.get("shimmer", false):
		shim = 0.5 + 0.5 * sin(t * 9.0)
	Art.enemy(self, "miraz", {"t": t, "tele": tele, "hurt": hurt, "shadow": props.get("shadow", true),
		"blinks": props.get("blinks", true), "shimmer": shim, "revealed": revealed if role == "real" else 0.0})
	if mark_t > 0.0 and role == "real":
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
		draw_arc(Vector2.ZERO, 44, 0, TAU, 32, Color("#8fe0ff", 0.8), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
