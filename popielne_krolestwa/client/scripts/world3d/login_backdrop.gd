class_name LoginBackdrop
extends Node3D
## Scenka 3D w tle ekranu logowania: obozowisko na skraju Popieliska o zmierzchu –
## ognisko, rycerz, wilk, drzewa i złoża, powoli krążąca kamera.

const OBJECT_SHADER := preload("res://shaders/lowpoly_object.gdshader")
const GROUND_SHADER := preload("res://shaders/lowpoly_ground.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/lowpoly_foliage.gdshader")

var _camera: Camera3D
var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 0.12
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.14, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.42, 0.55)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.3, 0.2, 0.22)
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 22.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 60, 0)
	sun.light_color = Color(1.0, 0.55, 0.35)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 20.0
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	_camera.h_offset = 2.6
	add_child(_camera)
	_camera.make_current()
	_build_ground()
	_build_props()


func _mat(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


## Wyspa terenu: trawa przy ognisku, dalej popiół z żarzącymi się szczelinami.
func _build_ground() -> void:
	var k := MeshKit.new(3)
	k.jitter = 0.04
	var r := 16
	var pts := {}
	for z in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x, z).length()
			var hgt := _noise.get_noise_2d(x, z) * 0.35 + maxf(0.0, d - 7.0) * 0.18
			pts[Vector2i(x, z)] = Vector3(x + (randf() - 0.5) * 0.4, hgt, z + (randf() - 0.5) * 0.4)
	for z in range(-r, r):
		for x in range(-r, r):
			var a: Vector3 = pts[Vector2i(x, z)]
			var b: Vector3 = pts[Vector2i(x + 1, z)]
			var c: Vector3 = pts[Vector2i(x + 1, z + 1)]
			var d: Vector3 = pts[Vector2i(x, z + 1)]
			var dist := Vector2(x + 0.5, z + 0.5).length()
			var ash := smoothstep(4.0, 7.0, dist + _noise.get_noise_2d(x * 2.0, z * 2.0) * 2.0)
			var col := Color(0.34, 0.46, 0.22).lerp(Color(0.25, 0.22, 0.22), ash)
			k.tri(a, b, c, col, Vector3.UP)
			k.tri(a, c, d, col.darkened(0.04), Vector3.UP)
			if ash > 0.8 and randf() < 0.08:
				k.glow = 1.0
				var p := (a + c) / 2.0 + Vector3(0, 0.02, 0)
				var dir := Vector3(randf() - 0.5, 0, randf() - 0.5).normalized() * 0.35
				var side := Vector3(-dir.z, 0, dir.x) * 0.03
				k.quad(p - side, p + dir - side, p + dir + side, p + side, Color(1, 0.4, 0.1), Vector3.UP)
				k.glow = 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = _mat(GROUND_SHADER)
	add_child(mi)


func _build_props() -> void:
	var obj := _mat(OBJECT_SHADER)
	# Ognisko: kamienie i polana.
	var k := MeshKit.new(5)
	k.jitter = 0.05
	for i in 8:
		var a := TAU * i / 8.0
		k.blob(Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), Vector3(0.13, 0.09, 0.11), Color(0.45, 0.43, 0.42), 2, 5, 0.2)
	for i in 3:
		k.xf = Transform3D(Basis(Vector3.UP, i * 1.1).rotated(Vector3.UP, 0.0) * Basis(Vector3.RIGHT, PI / 2.0 - 0.4), Vector3(0, 0.08, 0))
		k.cyl(Vector3(0, -0.3, 0), 0.05, 0.05, 0.6, 5, Color(0.35, 0.22, 0.12))
	k.reset()
	# Namiot.
	var tent := Color(0.62, 0.52, 0.36)
	var tp := Vector3(-2.2, 0.1, -1.6)
	k.quad(tp + Vector3(-0.9, 0, 0.8), tp + Vector3(0, 1.3, 0.8), tp + Vector3(0, 1.3, -0.8), tp + Vector3(-0.9, 0, -0.8), tent, Vector3(-1, 0.6, 0))
	k.quad(tp + Vector3(0.9, 0, 0.8), tp + Vector3(0.9, 0, -0.8), tp + Vector3(0, 1.3, -0.8), tp + Vector3(0, 1.3, 0.8), tent.darkened(0.12), Vector3(1, 0.6, 0))
	k.tri(tp + Vector3(-0.9, 0, -0.8), tp + Vector3(0, 1.3, -0.8), tp + Vector3(0.9, 0, -0.8), tent.darkened(0.2), Vector3(0, 0, -1))
	k.tri(tp + Vector3(-0.9, 0, 0.8), tp + Vector3(-0.2, 1.0, 0.8), tp + Vector3(-0.2, 0, 0.8), tent.darkened(0.05), Vector3(0, 0, 1))
	k.tri(tp + Vector3(0.9, 0, 0.8), tp + Vector3(0.2, 0, 0.8), tp + Vector3(0.2, 1.0, 0.8), tent.darkened(0.05), Vector3(0, 0, 1))
	# Beczka i skrzynia.
	k.cyl(Vector3(1.8, 0.05, -1.4), 0.25, 0.25, 0.6, 8, Color(0.45, 0.3, 0.18), true, Color(0.35, 0.24, 0.14))
	k.metal = 1.0
	k.cyl(Vector3(1.8, 0.15, -1.4), 0.26, 0.26, 0.05, 8, Color(0.35, 0.35, 0.37), false)
	k.cyl(Vector3(1.8, 0.5, -1.4), 0.26, 0.26, 0.05, 8, Color(0.35, 0.35, 0.37), false)
	k.metal = 0.0
	k.box(Vector3(2.3, 0.05, -0.9), Vector3(0.5, 0.36, 0.36), Color(0.5, 0.34, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = obj
	add_child(mi)
	var fire := Fire3D.new()
	fire.kind = "hearth"
	fire.night = 1.0
	fire.position = Vector3(0, 0.1, 0)
	fire.scale = Vector3.ONE * 1.6
	add_child(fire)
	# Rycerz przy ognisku.
	var knight := CharacterModel.new(obj)
	knight.build_humanoid({"skin": CharacterModel.SKINS[1], "hair": CharacterModel.HAIRS[0], "beard": true,
		"eq": ["plate_head_t3", "plate_body_t3", "plate_legs_t3", "plate_feet_t3", "sword_t3", "shield_t3"]})
	knight.position = Vector3(1.1, 0.05, 0.7)
	knight.rotation.y = -2.2
	knight.scale = Vector3.ONE * 1.1
	add_child(knight)
	# Łuczniczka.
	var archer := CharacterModel.new(obj)
	archer.build_humanoid({"skin": CharacterModel.SKINS[0], "hair": CharacterModel.HAIRS[3], "hair_style": 1,
		"eq": ["leather_head_t2", "leather_body_t2", "leather_legs_t2", "leather_feet_t2", "bow_t2", ""]})
	archer.position = Vector3(-1.1, 0.05, 0.9)
	archer.rotation.y = 2.3
	archer.scale = Vector3.ONE * 1.1
	add_child(archer)
	# Wilk w oddali.
	var wolf := CharacterModel.new(obj)
	wolf.build_beast("hound")
	wolf.position = Vector3(4.2, 0.4, -3.0)
	wolf.rotation.y = -2.4
	add_child(wolf)
	# Drzewa i złoża wokół.
	var spots := [["node_wood_3", Vector3(-4.0, 0.2, -3.5)], ["node_wood_4", Vector3(3.5, 0.3, 3.5)], ["node_wood_1", Vector3(-4.5, 0.3, 2.5)],
		["node_wood_3", Vector3(-6, 0.6, -1)], ["node_ore_4", Vector3(2.8, 0.1, -3.4)], ["node_stone_2", Vector3(-3, 0.1, 4.2)],
		["node_fiber_4", Vector3(5.0, 0.4, 0.5)], ["node_wood_2", Vector3(0.5, 0.4, -5.5)], ["node_wood_3", Vector3(6.5, 0.9, -4.5)]]
	for s in spots:
		var m := CharacterModel.new(_mat(FOLIAGE_SHADER) if str(s[0]).begins_with("node_wood") or str(s[0]).begins_with("node_fiber") else obj)
		m.build_node(s[0])
		m.position = s[1]
		m.rotation.y = randf() * TAU
		m.scale = Vector3.ONE * randf_range(1.0, 1.3)
		add_child(m)


func _process(delta: float) -> void:
	_t += delta * 0.06
	var r := 9.0
	_camera.position = Vector3(sin(_t) * r, 4.2, cos(_t) * r)
	_camera.look_at(Vector3(0, 0.7, 0), Vector3.UP)
