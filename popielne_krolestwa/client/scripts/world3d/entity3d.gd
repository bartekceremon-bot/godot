class_name Entity3D
extends Node3D
## Istota w świecie 3D: gracz, potwór, NPC albo złoże surowca.
## Płynny ruch między kafelkami, obrót w kierunku marszu, model z ekwipunkiem, błysk przy trafieniu,
## pierścień celu. Imię i pasek życia rysuje nakładka 2D (overlay_2d.gd).

const OBJECT_SHADER := preload("res://shaders/lowpoly_object.gdshader")

## Wygląd NPC (klucz „look” z serwera).
const NPC_LOOKS := {
	"npc_banker": {"shirt": Color(0.16, 0.2, 0.42), "pants": Color(0.15, 0.15, 0.2), "hair": Color(0.7, 0.7, 0.7), "hat": "top", "beard": true, "robe": true, "robe_trim": Color(0.95, 0.75, 0.3), "skin": 0},
	"npc_market": {"shirt": Color(0.7, 0.18, 0.2), "pants": Color(0.4, 0.2, 0.2), "hair": Color(0.3, 0.18, 0.1), "hair_style": 1, "hat": "scarf", "hat_col": Color(0.95, 0.8, 0.3), "robe": true, "apron": Color(0.95, 0.93, 0.88), "skin": 1},
	"npc_trader": {"shirt": Color(0.3, 0.48, 0.25), "pants": Color(0.4, 0.3, 0.2), "hair": Color(0.45, 0.3, 0.15), "beard": true, "backpack": true, "hat": "cap", "hat_col": Color(0.45, 0.3, 0.15), "skin": 2},
	"npc_smith": {"shirt": Color(0.35, 0.33, 0.33), "pants": Color(0.25, 0.22, 0.2), "hair": Color(0.1, 0.08, 0.08), "hair_style": 2, "beard": true, "apron": Color(0.4, 0.25, 0.14), "held": "hammer_t1", "skin": 2},
	"npc_crafter": {"shirt": Color(0.3, 0.4, 0.7), "pants": Color(0.3, 0.3, 0.45), "hair": Color(0.75, 0.5, 0.2), "hair_style": 4, "robe": true, "apron": Color(0.7, 0.55, 0.35), "skin": 0},
	"npc_refiner": {"shirt": Color(0.72, 0.42, 0.18), "pants": Color(0.3, 0.25, 0.2), "hair": Color(0.2, 0.15, 0.1), "hat": "cap", "hat_col": Color(0.25, 0.2, 0.18), "apron": Color(0.3, 0.22, 0.15), "skin": 3},
	"npc_priest": {"shirt": Color(0.95, 0.93, 0.88), "pants": Color(0.9, 0.88, 0.82), "hair": Color(0.85, 0.8, 0.6), "hat": "hood", "hat_col": Color(0.96, 0.94, 0.88), "robe": true, "robe_trim": Color(0.95, 0.72, 0.25), "skin": 0},
	"npc_stable": {"shirt": Color(0.55, 0.4, 0.25), "pants": Color(0.3, 0.25, 0.2), "hair": Color(0.5, 0.3, 0.15), "hat": "cap", "hat_col": Color(0.35, 0.25, 0.15), "beard": true, "apron": Color(0.4, 0.28, 0.16), "skin": 1},
	"npc_guild": {"shirt": Color(0.3, 0.3, 0.35), "hair": Color(0.25, 0.2, 0.15), "beard": true, "cape": Color(0.6, 0.12, 0.12), "skin": 1,
		"eq": ["", "plate_body_t4", "plate_legs_t3", "plate_feet_t3", "sword_t4", "shield_t4"]},
}

## Potwory humanoidalne: wygląd (skóra, ekwipunek, dodatki).
const MONSTER_LOOKS := {
	"bandit": {"skin": Color(0.85, 0.66, 0.5), "bandana": Color(0.6, 0.12, 0.1), "hair": Color(0.2, 0.15, 0.1), "beard": true,
		"eq": ["", "leather_body_t3", "leather_legs_t2", "leather_feet_t2", "sword_t3", ""]},
	"bandit_archer": {"skin": Color(0.9, 0.72, 0.56), "hair": Color(0.3, 0.2, 0.1), "hair_style": 1,
		"eq": ["leather_head_t3", "leather_body_t2", "leather_legs_t2", "leather_feet_t2", "bow_t3", ""]},
	"orc": {"skin": Color(0.36, 0.52, 0.24), "tusks": true, "hair": Color(0.1, 0.1, 0.08), "hair_style": 4,
		"eq": ["", "leather_body_t5", "plate_legs_t4", "leather_feet_t4", "axe_t5", "shield_t4"]},
	"orc_shaman": {"skin": Color(0.4, 0.56, 0.28), "tusks": true, "hair": Color(0.85, 0.85, 0.8), "hair_style": 1, "beard": true, "robe": true,
		"shirt": Color(0.35, 0.22, 0.12), "robe_trim": Color(0.5, 0.9, 0.3), "held": "staff_t5", "eye_glow": Color(0.5, 1.0, 0.3)},
	"mummy": {"skin": Color(0.84, 0.78, 0.62), "shirt": Color(0.84, 0.78, 0.62), "pants": Color(0.78, 0.72, 0.56), "boots": Color(0.7, 0.64, 0.5),
		"hair_style": 2, "stripes": Color(0.6, 0.54, 0.4), "eye_glow": Color(0.3, 0.9, 1.0)},
	"zombie": {"skin": Color(0.5, 0.58, 0.46), "shirt": Color(0.3, 0.32, 0.26), "pants": Color(0.25, 0.24, 0.2), "hair": Color(0.2, 0.22, 0.18),
		"hair_style": 1, "eye_glow": Color(0.8, 1.0, 0.3)},
	"lizard": {"skin": Color(0.32, 0.5, 0.3), "head_shape": "lizard", "hair_style": 2, "tail": Color(0.3, 0.46, 0.28), "eye_glow": Color(1.0, 0.85, 0.2),
		"eq": ["", "leather_body_t4", "", "", "sword_t4", "shield_t3"]},
	"troll": {"skin": Color(0.46, 0.52, 0.58), "tusks": true, "hair": Color(0.3, 0.3, 0.3), "hair_style": 2, "shirt": Color(0.4, 0.3, 0.2),
		"held": "club_big_t5"},
	"yeti": {"skin": Color(0.92, 0.94, 0.97), "shirt": Color(0.9, 0.92, 0.96), "pants": Color(0.88, 0.9, 0.95), "boots": Color(0.85, 0.88, 0.94),
		"head_shape": "yeti", "hair_style": 2, "eye_glow": Color(0.4, 0.8, 1.0)},
	"frost_king": {"skin": Color(0.86, 0.92, 1.0), "shirt": Color(0.82, 0.9, 1.0), "pants": Color(0.8, 0.88, 0.98), "boots": Color(0.75, 0.85, 0.95),
		"head_shape": "yeti", "hair_style": 2, "eye_glow": Color(0.4, 0.9, 1.0), "crown": Color(0.6, 0.9, 1.0), "cape": Color(0.2, 0.35, 0.7), "held": "club_big_t7"},
	"ash_knight": {"skin": Color(0.2, 0.18, 0.18), "hair_style": 2, "eye_glow": Color(1.0, 0.3, 0.1), "cape": Color(0.35, 0.08, 0.06),
		"eq": ["plate_head_t4", "plate_body_t4", "plate_legs_t4", "plate_feet_t4", "greatsword_t7", ""]},
	"demon": {"skin": Color(0.62, 0.14, 0.1), "shirt": Color(0.5, 0.1, 0.08), "pants": Color(0.2, 0.08, 0.06), "boots": Color(0.12, 0.06, 0.05),
		"hair_style": 2, "horns": Color(0.15, 0.1, 0.08), "wings": Color(0.35, 0.08, 0.06), "tail": Color(0.5, 0.1, 0.08), "eye_glow": Color(1.0, 0.7, 0.1),
		"held": "greatsword_t8"},
	"ice_wraith": {"skin": Color(0.7, 0.85, 0.95), "shirt": Color(0.65, 0.82, 0.95), "float": true, "robe_glow": 0.35, "hat": "hood",
		"hat_col": Color(0.6, 0.78, 0.92), "eye_glow": Color(0.6, 0.95, 1.0), "held": "staff_t7"},
}

## Skala modeli (duże potwory, bossowie).
const LOOK_SCALE := {
	"orc": 1.15, "orc_shaman": 1.05, "troll": 1.55, "yeti": 1.45, "frost_king": 2.4, "demon": 1.55, "ash_knight": 1.2, "treant": 1.5,
	"golem": 1.45, "bear": 1.15, "basilisk": 1.15, "bog_mother": 2.6, "sand_worm": 1.5, "ash_dragon": 2.5, "lizard": 1.08, "spider": 1.2,
	"scorpion": 1.2, "fire_elemental": 1.15, "ice_wraith": 1.1,
}

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
		if _ring:
			_ring.visible = v
var show_label := true
var gathering := false:
	set(v):
		gathering = v
		if model:
			model.gathering = v
			if rider:
				rider.gathering = v
var skull := ""
var equipment: Array = []
## Wierzchowiec (id przedmiotu), skrót gildii, boss, właściciel obelisku.
var mount := ""
var guild_tag := ""
var boss := false
var owner_tag := ""
var capturer_tag := ""
## Jeździec (gdy istota jedzie na wierzchowcu – `model` jest wtedy wierzchowcem).
var rider: CharacterModel

var model: CharacterModel
var light: OmniLight3D
var material := ShaderMaterial.new()
## Pozycja „głowy” do nakładki 2D.
var label_height := 1.4

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _move_t := 1.0
var _move_dur := 0.3
var _yaw := 0.0
var _target_yaw := 0.0
var _model_key := ""
var _flash := 0.0
var _ring: MeshInstance3D
var _shadow: MeshInstance3D
var _vanishing := false
var _fade := 0.0
var _node_scale := 1.0
var _still_t := 1.0


func _ready() -> void:
	material.shader = OBJECT_SHADER
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.5)
	light.omni_range = 6.0
	light.position = Vector3(0, 2.6, 0.4)
	light.visible = false
	add_child(light)
	_shadow = MeshInstance3D.new()
	var disc := MeshKit.new(1)
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 1) / 10.0
		disc.tri(Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * 0.34, Vector3(cos(a1), 0, sin(a1)) * 0.34, Color(0, 0, 0), Vector3.UP)
	_shadow.mesh = disc.commit()
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0, 0, 0, 0.28)
	_shadow.material_override = sm
	_shadow.position.y = 0.03
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_ring = MeshInstance3D.new()
	var rk := MeshKit.new(2)
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		rk.quad(Vector3(cos(a0), 0, sin(a0)) * 0.42, Vector3(cos(a1), 0, sin(a1)) * 0.42, Vector3(cos(a1), 0, sin(a1)) * 0.5, Vector3(cos(a0), 0, sin(a0)) * 0.5, Color(1, 0.2, 0.1), Vector3.UP)
	_ring.mesh = rk.commit()
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.vertex_color_use_as_albedo = true
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.9)
	_ring.material_override = rm
	_ring.position.y = 0.05
	_ring.visible = targeted
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Aktualizacja z pakietu „snap” serwera.
func apply(e: Dictionary, me: bool) -> void:
	is_me = me
	kind = str(e.k)
	look = e.l
	display_name = str(e.n)
	hp_pct = int(e.h)
	equipment = e.get("eq", [])
	skull = str(e.get("sk", ""))
	mount = str(e.get("mt", ""))
	guild_tag = str(e.get("gt", ""))
	boss = int(e.get("b", 0)) == 1
	owner_tag = str(e.get("o", ""))
	capturer_tag = str(e.get("c", ""))
	if not me:
		var t := Vector2i(int(e.x), int(e.y))
		if t != tile or _to == Vector3.ZERO:
			var d := t - tile
			if absi(d.x) > 1 or absi(d.y) > 1 or _to == Vector3.ZERO:
				snap_to(t)
			else:
				move_to(t, maxf(0.1, float(e.s) / 1000.0))
		dir = int(e.d)
		if not is_moving():
			_target_yaw = _dir_yaw(dir)
	_refresh_model()


static func tile_pos(t: Vector2i) -> Vector3:
	return Vector3(t.x + 0.5, 0.0, t.y + 0.5)


static func _dir_yaw(d: int) -> float:
	return [PI, PI / 2.0, 0.0, -PI / 2.0][clampi(d, 0, 3)]


func snap_to(t: Vector2i) -> void:
	tile = t
	_to = tile_pos(t)
	_from = _to
	_move_t = 1.0
	position = _to


func move_to(t: Vector2i, duration: float, new_dir: int = -1) -> void:
	var d := t - tile
	_from = position
	tile = t
	_to = tile_pos(t)
	_move_t = 0.0
	_move_dur = duration
	if d != Vector2i.ZERO:
		_target_yaw = atan2(float(d.x), float(d.y))
	if new_dir >= 0:
		dir = new_dir
	if model:
		model.move_speed = clampf(0.32 / maxf(duration, 0.05), 0.6, 1.8)


## Obrót w stronę kafelka (np. celu ataku).
func face_tile(t: Vector2i) -> void:
	var d := t - tile
	if d != Vector2i.ZERO:
		_target_yaw = atan2(float(d.x), float(d.y))


func is_moving() -> bool:
	return _move_t < 1.0


func _process(delta: float) -> void:
	if _move_t < 1.0:
		_move_t = minf(1.0, _move_t + delta / _move_dur)
		position = _from.lerp(_to, _move_t)
		_still_t = 0.0
	else:
		_still_t += delta
	if model:
		# Krótka tolerancja między krokami – nogi nie „zatrzymują się” na każdym kafelku.
		model.moving = _still_t < 0.12
		if kind != "r":
			_yaw = lerp_angle(_yaw, _target_yaw, minf(1.0, delta * 12.0))
			model.rotation.y = _yaw
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		material.set_shader_parameter("flash", _flash)
	if targeted and _ring:
		_ring.rotation.y += delta * 1.5
		var s := 1.0 + sin(Time.get_ticks_msec() / 150.0) * 0.05
		_ring.scale = Vector3(s, 1, s)


func flash() -> void:
	_flash = 0.85
	material.set_shader_parameter("flash", _flash)


func play_attack(kind_hint := "") -> void:
	if rider:
		rider.play_attack(kind_hint)
	elif model:
		model.play_attack(kind_hint)


## Znikanie: śmierć (przewrócenie) lub wyjście z pola widzenia.
func vanish(dead := false) -> void:
	if _vanishing:
		return
	_vanishing = true
	if model and dead and kind != "r":
		model.die()
	var t := create_tween()
	if dead:
		t.tween_interval(0.6)
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


# ============================================================================
# Model
# ============================================================================

func _refresh_model() -> void:
	var key := "%s|%s|%s|%s|%s" % [kind, str(look), ",".join(PackedStringArray(equipment.map(func(x): return str(x)))), mount, owner_tag]
	if kind == "r":
		# Wyczerpane złoże zmniejsza się.
		_node_scale = 0.35 if hp_pct <= 0 else 0.6 + 0.4 * hp_pct / 100.0
	if key == _model_key:
		if model and kind == "r":
			model.scale = Vector3.ONE * _node_scale
		return
	_model_key = key
	var old := model
	rider = null
	model = CharacterModel.new(material)
	var s := str(look)
	var sc := 1.15
	if kind == "r":
		model.build_node(s)
		_shadow.visible = false
		sc = _node_scale
	elif kind == "t":
		CreatureModels.obelisk(model, owner_tag)
		_shadow.visible = false
		sc = 1.0
	elif CreatureModels.build(model, s):
		pass
	elif s in ["rat", "boar", "wolf", "hound", "snow_fox", "snow_wolf", "bear", "basilisk"]:
		model.build_beast(s)
		_shadow.scale = Vector3.ONE * (0.6 if s in ["rat", "snow_fox"] else 1.2)
	else:
		model.build_humanoid(_appearance(s))
	if kind != "r" and kind != "t":
		sc *= float(LOOK_SCALE.get(s, 1.0))
		if boss and not LOOK_SCALE.has(s):
			sc *= 1.8
	# Wierzchowiec: model = zwierzę, jeździec siedzi na siodle.
	if mount != "" and kind == "p":
		var human := model
		model = CharacterModel.new(material)
		if not CreatureModels.build(model, mount):
			model.build_beast(mount)
		human.riding = true
		# Biodra jeźdźca (0,42 nad stopami) na siodle, nogi zgięte do przodu.
		human.position = Vector3(0, model.riding_height - 0.46, -0.05)
		model.add_child(human)
		rider = human
		label_height = (model.riding_height + 1.0) * sc
		_shadow.scale = Vector3.ONE * 1.4
	else:
		label_height = model.height * sc + 0.32
	if kind == "r":
		label_height = 1.2
	model.scale = Vector3.ONE * sc
	if old:
		model.rotation.y = old.rotation.y
		old.queue_free()
	model.gathering = gathering
	add_child(model)


func _appearance(s: String) -> Dictionary:
	if s == "skeleton":
		return {"skeleton": true, "skin": Color(0.88, 0.85, 0.76), "held": "sword_skeleton_t1"}
	if MONSTER_LOOKS.has(s):
		return MONSTER_LOOKS[s].duplicate()
	if s.begins_with("npc_"):
		# Stroje NPC: w Szronogrodzie futrzane czapy i ciepłe barwy, w Złotopiasku turbany i jasne szaty.
		var base := s.trim_suffix("_snow").trim_suffix("_desert")
		var a: Dictionary = NPC_LOOKS.get(base, NPC_LOOKS["npc_trader"]).duplicate()
		a.skin = CharacterModel.SKINS[int(a.get("skin", 0))]
		if s.ends_with("_snow"):
			a.hat = "scarf"
			a.hat_col = Color(0.92, 0.9, 0.85)
			a.shirt = (a.get("shirt", Color.GRAY) as Color).darkened(0.1).lerp(Color(0.25, 0.3, 0.5), 0.3)
			a.beard = true
		elif s.ends_with("_desert"):
			a.hat = "scarf"
			a.hat_col = Color(0.95, 0.9, 0.78)
			a.skin = CharacterModel.SKINS[2]
			a.shirt = (a.get("shirt", Color.GRAY) as Color).lerp(Color(0.9, 0.82, 0.62), 0.45)
			a.robe = true
		return a
	var n := int(s) if s.is_valid_int() else absi(hash(s))
	var eq := equipment if equipment.size() == 6 else ["", "", "", "", "", ""]
	return {
		"skin": CharacterModel.SKINS[n % 4],
		"hair": CharacterModel.HAIRS[(n / 2 + n) % CharacterModel.HAIRS.size()],
		"hair_style": [0, 1, 3, 0, 4, 1, 2, 3][n % 8],
		"shirt": CharacterModel.SHIRTS[n % CharacterModel.SHIRTS.size()],
		"beard": n % 3 == 1,
		"eq": eq,
	}
