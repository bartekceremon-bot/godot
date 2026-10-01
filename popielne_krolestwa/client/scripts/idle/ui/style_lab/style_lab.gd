class_name StyleLab
extends Node
## Próbki kierunków graficznych (uruchamiane: -- --style=a|b|c). Nie zmienia gry bez tej opcji.
## a – „malowana baśń”: cieniowanie komiksowe, kontury, nasycone kolory
## b – „mroczne dark fantasy”: mgła, popiół, przygaszone barwy, winieta
## c – „ilustrowane 2.5D”: malowane tło krainy + miękkie kontury i ciepła paleta

const POST := preload("res://shaders/style_post.gdshader")
const BACKDROP := preload("res://shaders/style_backdrop.gdshader")

var style := ""
var view: BattleView
var _post: MeshInstance3D
var _post_mat: ShaderMaterial
var _backdrop: MeshInstance3D
var _bd_mat: ShaderMaterial
var _bd_region := ""
var _toon_cache := {}
var _done := {}
var _scan_t := 0.0


static func requested() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--style="):
			return a.substr(8)
	return ""


func _ready() -> void:
	view = get_parent()
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = POST
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_post = MeshInstance3D.new()
	_post.mesh = q
	_post.material_override = _post_mat
	_post.extra_cull_margin = 16384.0
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.camera.add_child(_post)
	if style == "c":
		view.no_ruins = true
		_bd_mat = ShaderMaterial.new()
		_bd_mat.shader = BACKDROP
		var bq := QuadMesh.new()
		bq.size = Vector2(46, 23)
		_backdrop = MeshInstance3D.new()
		_backdrop.mesh = bq
		_backdrop.material_override = _bd_mat
		_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.add_child(_backdrop)
	_apply_post()


func _apply_post() -> void:
	var p := {}
	match style:
		"a":
			p = {"outline": 1.0, "outline_px": 2.0, "saturation": 1.18, "contrast": 1.12, "brightness": 0.95, "vignette": 0.22, "posterize": 0.0}
		"b":
			p = {"outline": 0.0, "saturation": 0.6, "contrast": 1.28, "brightness": 1.12, "tint": Color(1.02, 0.98, 0.98), "vignette": 0.78, "vignette_color": Color(0.02, 0.015, 0.02)}
		"c":
			p = {"outline": 0.75, "outline_px": 1.4, "outline_color": Color(0.16, 0.09, 0.06), "saturation": 1.15, "contrast": 1.04, "brightness": 1.04, "tint": Color(1.05, 1.0, 0.93), "vignette": 0.3, "vignette_color": Color(0.18, 0.1, 0.05)}
	for k in p:
		_post_mat.set_shader_parameter(k, p[k])


func _process(delta: float) -> void:
	var env := view._env.environment
	match style:
		"a":
			env.fog_density = 0.008
			env.adjustment_saturation = 1.0
			env.tonemap_exposure = 0.92
			env.ambient_light_energy = 0.7
			view._sun.light_energy = 1.15
			view._sun.light_color = Color(1.0, 0.95, 0.85)
		"b":
			env.fog_density = 0.07
			env.fog_light_color = Color(0.2, 0.18, 0.18)
			env.tonemap_exposure = 0.9
			env.ambient_light_energy = 0.45
			view._sun.light_energy = 0.75
			view._sun.light_color = Color(0.8, 0.82, 0.95)
			view._rim.light_energy = 4.5 + sin(Time.get_ticks_msec() * 0.004) * 0.6
			view._embers.amount = 260
			view._embers.scale_amount_min = 1.6
			view._embers.scale_amount_max = 2.6
		"c":
			env.fog_density = 0.006
			env.adjustment_saturation = 1.0
			env.tonemap_exposure = 0.92
			env.ambient_light_energy = 0.75
			view._sun.light_energy = 1.1
			view._sun.light_color = Color(1.0, 0.88, 0.7)
			_place_backdrop()
	_scan_t -= delta
	if _scan_t <= 0.0 and style in ["a", "c"]:
		_scan_t = 0.4
		_scan(view)


func _place_backdrop() -> void:
	var cam := view.camera
	var fwd := (view._cam_target - view._cam_base)
	fwd.y = 0.0
	fwd = fwd.normalized()
	_backdrop.global_position = Vector3(view._cam_target.x, 0, view._cam_target.z) + fwd * 13.0 + Vector3(0, 3.3, 0)
	_backdrop.look_at(cam.global_position * Vector3(1, 0, 1) + Vector3(0, _backdrop.global_position.y, 0), Vector3.UP)
	_backdrop.rotate_object_local(Vector3.UP, PI)
	var rid := view._region_id
	if rid != _bd_region:
		_bd_region = rid
		var path := "res://assets/style_lab/backdrop_%s.png" % rid
		_hide_far_props()
		if not ResourceLoader.exists(path):
			path = "res://assets/style_lab/backdrop_meadow.png"
		_bd_mat.set_shader_parameter("tex", load(path))


## Malowane tło zastępuje dalekie ruiny i drzewa za przeciwnikiem.
func _hide_far_props() -> void:
	var cam := view._cam_base
	var fwd := (view._cam_target - cam)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var lim := (view._cam_target - cam).dot(fwd) + 2.0
	for n in view._diorama.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var c := g.global_transform * g.get_aabb().get_center()
		var big := g.get_aabb().size.length() > 40.0
		if not big and (c - cam).dot(fwd) > lim:
			g.visible = false
	view._env.environment.fog_light_color = {"swamp": Color(0.6, 0.64, 0.56), "ash": Color(0.5, 0.22, 0.12)}.get(view._region_id, Color(0.85, 0.76, 0.6))


## Cieniowanie komiksowe: te same shadery z diffuse_toon / specular_toon.
func _scan(n: Node) -> void:
	if n is GeometryInstance3D and n != _post and n != _backdrop:
		var g := n as GeometryInstance3D
		_toonify(g.material_override)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			for i in mi.get_surface_override_material_count():
				_toonify(mi.get_surface_override_material(i))
			if mi.mesh:
				for i in mi.mesh.get_surface_count():
					_toonify(mi.mesh.surface_get_material(i))
	for c in n.get_children():
		_scan(c)


func _toonify(m: Material) -> void:
	if m == null or _done.has(m.get_instance_id()):
		return
	_done[m.get_instance_id()] = true
	if m is ShaderMaterial and m.shader:
		var s: Shader = m.shader
		if s == POST or s == BACKDROP:
			return
		if not _toon_cache.has(s):
			var t := Shader.new()
			t.code = s.code.replace("diffuse_burley", "diffuse_toon").replace("specular_schlick_ggx", "specular_toon").replace("diffuse_lambert", "diffuse_toon")
			_toon_cache[s] = t
		m.shader = _toon_cache[s]
	elif m is StandardMaterial3D:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
