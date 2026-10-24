extends CharacterBody2D
## Strażnik Iskry sterowany przez gracza.

signal died

const SPEED := 230.0
const ACCEL := 1800.0
const DODGE_SPEED := 560.0
const DODGE_TIME := 0.22
const DODGE_CD := 0.8
const INVULN_HIT := 0.7

var class_id := "tkacz"
var t := 0.0
var walk := 0.0
var aim := Vector2.RIGHT
var move_dir := Vector2.ZERO
var facing := Vector2.RIGHT
var attack_anim := 0.0
var hurt_anim := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector2.RIGHT
var invuln := 0.0
var cooldowns := {"attack": 0.0, "skill1": 0.0, "skill2": 0.0}
var cd_max := {"attack": 0.4, "skill1": 4.0, "skill2": 6.0}
var since_hit := 99.0
var shield_ready := true      # pasywna Strażnika
var dome_t := 0.0
var knock := Vector2.ZERO
var controls_locked := false
var dead := false
var touch_move := Vector2.ZERO
var _use_mouse_aim := false
var _last_mouse := Vector2.ZERO
var _nearest: Node = null
var _regen_t := 0.0
var _mouse_attack := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0
	cs.shape = c
	add_child(cs)
	set_class(GameState.class_id())


func set_class(cid: String) -> void:
	class_id = cid
	var d := Data.get_class_def(cid)
	cd_max["attack"] = float(d.get("basic", {}).get("cooldown", 0.4))
	cd_max["skill1"] = float(d.get("skill1", {}).get("cooldown", 5.0))
	cd_max["skill2"] = float(d.get("skill2", {}).get("cooldown", 7.0))
	if cid == "mechanik":
		# Pasywna: szybsza regeneracja konstrukcji (krótsze odnowienie).
		cd_max["skill1"] *= 0.75
		cd_max["skill2"] *= 0.75
	queue_redraw()


func skill_cost(slot: String) -> float:
	return float(Data.get_class_def(class_id).get(slot, {}).get("cost", 25))


func skill_unlocked(slot: String) -> bool:
	if slot == "skill2":
		return GameState.level() >= 2
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and not Settings.touch_active:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_attack = event.pressed
			_use_mouse_aim = true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not controls_locked:
			try_skill("skill1")
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.relative.length() > 2.0:
			_use_mouse_aim = true
	elif event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventJoypadMotion:
		_use_mouse_aim = false


func _physics_process(delta: float) -> void:
	t += delta
	for k in cooldowns:
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	attack_anim = maxf(0.0, attack_anim - delta * 3.5)
	hurt_anim = maxf(0.0, hurt_anim - delta * 3.0)
	invuln = maxf(0.0, invuln - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	dome_t = maxf(0.0, dome_t - delta)
	since_hit += delta
	if since_hit > 6.0:
		shield_ready = true
	_regen(delta)
	if dead:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var input := Vector2.ZERO
	if not controls_locked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if touch_move.length() > 0.1:
			input = touch_move
	move_dir = input
	if input.length() > 0.1:
		facing = input.normalized()
	_update_aim()
	if dodge_t > 0.0:
		dodge_t -= delta
		velocity = dodge_dir * DODGE_SPEED
	else:
		var target := input.limit_length(1.0) * SPEED
		velocity = velocity.move_toward(target, ACCEL * delta)
	velocity += knock
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	if velocity.length() > 20.0:
		walk += delta * velocity.length() / 38.0
	if not controls_locked:
		_handle_actions()
	_find_interactable()
	queue_redraw()


func _regen(delta: float) -> void:
	var regen := 9.0
	GameState.energy = minf(GameState.max_energy(), GameState.energy + regen * delta)
	# Poza walką zdrowie powoli wraca.
	if since_hit > 5.0 and GameState.hp < GameState.max_hp():
		GameState.hp = minf(GameState.max_hp(), GameState.hp + 3.0 * delta)
	_regen_t += delta
	if _regen_t > 0.2:
		_regen_t = 0.0
		GameState.stats_changed.emit()


func _update_aim() -> void:
	if _use_mouse_aim and not Settings.touch_active:
		var m := get_global_mouse_position()
		if m.distance_to(global_position + Vector2(0, -24)) > 6.0:
			aim = (m - (global_position + Vector2(0, -24))).normalized()
		return
	# Wspomagane celowanie (dotyk, klawiatura, pad): najbliższy przeciwnik w zasięgu.
	var best: Node2D = null
	var best_score := INF
	for e in World.enemies():
		var d := global_position.distance_to(e.global_position)
		if d > 430.0:
			continue
		var dir = (e.global_position - global_position).normalized()
		var score = d - dir.dot(facing) * 120.0
		if score < best_score:
			best_score = score
			best = e
	if best:
		aim = ((best.global_position + Vector2(0, -20)) - (global_position + Vector2(0, -24))).normalized()
	else:
		aim = facing


func _handle_actions() -> void:
	if Input.is_action_pressed("attack") or (_mouse_attack and not Settings.touch_active):
		try_attack()
	if Input.is_action_just_pressed("skill1"):
		try_skill("skill1")
	if Input.is_action_just_pressed("skill2"):
		try_skill("skill2")
	if Input.is_action_just_pressed("dodge"):
		try_dodge()
	if Input.is_action_just_pressed("interact"):
		try_interact()
	if Input.is_action_just_pressed("potion"):
		GameState.use_item("eliksir")


func try_interact() -> void:
	if _nearest and is_instance_valid(_nearest) and not World.current.busy():
		_nearest.interact(self)


func nearest_interactable() -> Node:
	return _nearest if is_instance_valid(_nearest) else null


func _find_interactable() -> void:
	var best: Node = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.is_active():
			continue
		var d := global_position.distance_to(n.global_position)
		if d < n.radius and d < best_d:
			best_d = d
			best = n
	_nearest = best


func try_dodge() -> void:
	if dodge_cd > 0.0 or dead:
		return
	dodge_dir = move_dir.normalized() if move_dir.length() > 0.1 else facing
	dodge_t = DODGE_TIME
	dodge_cd = DODGE_CD
	invuln = maxf(invuln, DODGE_TIME + 0.12)
	Audio.play("dodge")
	World.current.burst(global_position + Vector2(0, -6), Color(Art.CREAM, 0.7), 8, 60.0)


func try_attack() -> void:
	if cooldowns["attack"] > 0.0 or dead:
		return
	cooldowns["attack"] = cd_max["attack"]
	attack_anim = 1.0
	var d = Data.get_class_def(class_id).get("basic", {})
	var dmg := float(d.get("damage", 14)) * GameState.damage_mult()
	if GameState.level() >= 3:
		dmg *= 1.25
	Abilities.basic(self, class_id, dmg)


func try_skill(slot: String) -> void:
	if dead or cooldowns[slot] > 0.0:
		return
	if not skill_unlocked(slot):
		World.current.toast("Ta umiejętność odblokuje się na poziomie 2.", "info")
		return
	var cost := skill_cost(slot)
	if GameState.energy < cost:
		World.current.toast("Za mało energii.", "info")
		Audio.play("error", 0.0, -6.0)
		return
	GameState.energy -= cost
	cooldowns[slot] = cd_max[slot]
	attack_anim = 1.0
	Abilities.skill(self, class_id, slot)
	GameState.stats_changed.emit()


func take_damage(amount: float, from: Vector2) -> void:
	if invuln > 0.0 or dead:
		return
	if dome_t > 0.0:
		amount *= 0.3
	if class_id == "straznik" and shield_ready:
		# Pasywna „Pierwsza Pieczęć”: pierwsze trafienie po odpoczynku słabnie.
		amount *= 0.4 if GameState.level() < 5 else 0.25
		shield_ready = false
		World.current.ring(global_position + Vector2(0, -24), Color("#9fc7ff"), 40.0)
	since_hit = 0.0
	GameState.hp -= amount
	hurt_anim = 1.0
	invuln = INVULN_HIT
	knock = (global_position - from).normalized() * 320.0
	Audio.play("hurt")
	World.current.shake(6.0)
	World.current.float_text(global_position + Vector2(0, -60), str(int(round(amount))), Art.DANGER)
	GameState.stats_changed.emit()
	if GameState.hp <= 0.0:
		GameState.hp = 0.0
		dead = true
		died.emit()


func release_inputs() -> void:
	_mouse_attack = false
	touch_move = Vector2.ZERO


func revive() -> void:
	dead = false
	invuln = 2.0
	hurt_anim = 0.0
	knock = Vector2.ZERO
	velocity = Vector2.ZERO
	for k in cooldowns:
		cooldowns[k] = 0.0


func _draw() -> void:
	if dead:
		Art.shadow(self, Vector2.ZERO, 14, 5)
		draw_circle(Vector2(0, -12), 12, Color(Art.TEAL, 0.4))
		return
	if invuln > 0.0 and hurt_anim <= 0.0 and dodge_t <= 0.0 and fmod(t, 0.2) < 0.1:
		modulate.a = 0.6
	else:
		modulate.a = 1.0
	Art.with_parent(Transform2D.IDENTITY)
	Art.hero(self, class_id, {
		"t": t, "walk": walk, "moving": velocity.length() > 30.0, "aim": aim,
		"attack": attack_anim, "hurt": hurt_anim,
		"dodge": clampf(dodge_t / DODGE_TIME, 0.0, 1.0) if dodge_t > 0.0 else 0.0,
		"reduced": Settings.reduced_motion,
	})
	if dome_t > 0.0:
		var a := minf(1.0, dome_t) * (0.55 + 0.1 * sin(t * 6.0))
		draw_arc(Vector2(0, -26), 46, 0, TAU, 40, Color("#9fc7ff", a), 3.0, true)
		draw_circle(Vector2(0, -26), 46, Color("#9fc7ff", a * 0.18))
	if class_id == "straznik" and shield_ready and not Settings.reduced_motion:
		draw_arc(Vector2(0, -26), 30, -PI * 0.8, -PI * 0.2, 12, Color("#9fc7ff", 0.35), 2.0, true)
