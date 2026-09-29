class_name Fire3D
extends Node3D
## Ogień: pochodnia na wieży, kosz ogniowy na słupku albo palenisko pieca.
## Migoczące światło (mocniejsze nocą), płomień i iskry.

const OBJECT_SHADER := preload("res://shaders/lowpoly_object.gdshader")

var kind := "brazier"
## 0 = dzień, 1 = noc.
var night := 0.0:
	set(v):
		night = v
		_update_light()
var effects := true:
	set(v):
		effects = v
		if _sparks:
			_sparks.emitting = v
			_sparks.visible = v

var _light: OmniLight3D
var _flame: MeshInstance3D
var _sparks: CPUParticles3D
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 10.0
	var mat := ShaderMaterial.new()
	mat.shader = OBJECT_SHADER
	var k := MeshKit.new(7)
	var flame_y := 0.0
	match kind:
		"brazier":
			k.cyl(Vector3.ZERO, 0.09, 0.07, 0.8, 6, Color(0.3, 0.2, 0.12))
			k.metal = 0.8
			k.cyl(Vector3(0, 0.8, 0), 0.1, 0.22, 0.16, 7, Color(0.3, 0.28, 0.28))
			flame_y = 0.95
		"wall":
			k.metal = 0.8
			k.box(Vector3(0, -0.15, 0), Vector3(0.06, 0.2, 0.06), Color(0.25, 0.24, 0.24))
			k.metal = 0.0
			k.cyl(Vector3(0, 0.02, 0), 0.05, 0.07, 0.16, 5, Color(0.35, 0.22, 0.12))
			flame_y = 0.2
		_:
			flame_y = 0.0
	if not k.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		mi.material_override = mat
		add_child(mi)
	# Płomień: dwa świecące stożki.
	var fk := MeshKit.new(3)
	fk.glow = 1.0
	fk.cone(Vector3.ZERO, 0.11, 0.34, 5, Color(1.0, 0.45, 0.1))
	fk.cone(Vector3(0, 0.02, 0), 0.06, 0.24, 5, Color(1.0, 0.85, 0.35), 0.6)
	_flame = MeshInstance3D.new()
	_flame.mesh = fk.commit()
	var fm := ShaderMaterial.new()
	fm.shader = OBJECT_SHADER
	_flame.material_override = fm
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position.y = flame_y
	if kind == "hearth":
		_flame.scale = Vector3(1.4, 0.8, 0.6)
	add_child(_flame)
	_sparks = CPUParticles3D.new()
	_sparks.amount = 10
	_sparks.lifetime = 1.1
	_sparks.position.y = flame_y + 0.2
	_sparks.direction = Vector3.UP
	_sparks.spread = 25.0
	_sparks.initial_velocity_min = 0.4
	_sparks.initial_velocity_max = 0.9
	_sparks.gravity = Vector3(0, 0.3, 0)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.06
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.018
	sm.height = 0.036
	sm.radial_segments = 4
	sm.rings = 2
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.6, 0.2)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.5, 0.1)
	spark_mat.emission_energy_multiplier = 3.0
	sm.material = spark_mat
	_sparks.mesh = sm
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.9, 0.5), Color(1, 0.4, 0.1, 0.0)])
	_sparks.color_ramp = g
	add_child(_sparks)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 6.5 if kind != "hearth" else 4.0
	_light.omni_attenuation = 1.3
	_light.position.y = flame_y + 0.3
	_light.shadow_enabled = false
	add_child(_light)
	_update_light()


func _update_light() -> void:
	if _light == null:
		return
	_light.visible = night > 0.05 or kind == "hearth"
	_light.light_energy = (0.5 + 1.8 * night) * (0.8 if kind == "hearth" else 1.0)


func _process(delta: float) -> void:
	_t += delta
	var f := 0.85 + 0.1 * sin(_t * 11.0 + _seed) + 0.07 * sin(_t * 23.0 + _seed * 2.0)
	_flame.scale.y = f * (0.8 if kind == "hearth" else 1.0)
	_flame.rotation.y = _t * 2.0
	if _light and _light.visible:
		_light.light_energy = (0.5 + 1.8 * night) * f * (0.8 if kind == "hearth" else 1.0)
