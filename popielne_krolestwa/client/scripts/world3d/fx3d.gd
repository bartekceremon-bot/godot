class_name Fx3D
extends Node3D
## Efekty w świecie 3D: iskry i krew przy trafieniu, strzały, leczenie, awans, umiejętności,
## znacznik dotknięcia. Liczby i teksty trafiają do nakładki 2D (overlay).

var overlay: Overlay2D
var _dot_mesh: SphereMesh
var _dot_mat: StandardMaterial3D
var _arrow_mesh: ArrayMesh
var _arrow_mat: ShaderMaterial


func _ready() -> void:
	_dot_mesh = SphereMesh.new()
	_dot_mesh.radius = 0.035
	_dot_mesh.height = 0.07
	_dot_mesh.radial_segments = 5
	_dot_mesh.rings = 2
	_dot_mat = StandardMaterial3D.new()
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_mat.vertex_color_use_as_albedo = true
	_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_mesh.material = _dot_mat
	var k := MeshKit.new(5)
	# Strzała budowana wzdłuż osi Y i obracana tak, by grot celował w +Z.
	k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	k.box(Vector3(0, -0.5, 0), Vector3(0.02, 0.5, 0.02), Color(0.55, 0.38, 0.2))
	k.metal = 1.0
	k.cone(Vector3(0, 0, 0), 0.035, 0.1, 4, Color(0.7, 0.7, 0.72))
	k.metal = 0.0
	k.blade(Vector3(0, -0.46, 0), Vector3(0.06, -0.52, 0), Vector3(0, -0.36, 0), Color(0.9, 0.9, 0.9))
	k.blade(Vector3(0, -0.46, 0), Vector3(0, -0.52, 0.06), Vector3(0, -0.36, 0), Color(0.9, 0.9, 0.9))
	_arrow_mesh = k.commit()
	_arrow_mat = ShaderMaterial.new()
	_arrow_mat.shader = preload("res://shaders/lowpoly_object.gdshader")


static func center(x, y) -> Vector3:
	return Vector3(float(x) + 0.5, 0.0, float(y) + 0.5)


## Jednorazowy wybuch cząsteczek.
func burst(pos: Vector3, color: Color, amount: int, speed: float, gravity := -4.0, life := 0.5, size := 1.0, spread := 180.0) -> void:
	if not Config.effects:
		return
	var p := CPUParticles3D.new()
	p.position = pos
	p.mesh = _dot_mesh
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.3 * size
	var g := Gradient.new()
	g.colors = PackedColorArray([color.lightened(0.4), color, Color(color, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## Płaski krąg na ziemi (znacznik, fala) – rośnie i znika.
func ring(pos: Vector3, color: Color, r0: float, r1: float, dur: float, width := 0.08, glow := true) -> void:
	var k := MeshKit.new(1)
	for i in 28:
		var a0 := TAU * i / 28.0
		var a1 := TAU * (i + 1) / 28.0
		k.quad(Vector3(cos(a0), 0, sin(a0)) * (1.0 - width), Vector3(cos(a1), 0, sin(a1)) * (1.0 - width), Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a0), 0, sin(a0)), Color.WHITE, Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.06, 0)
	mi.scale = Vector3(r0, 1, r0)
	add_child(mi)
	var t := create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3(r1, 1, r1), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(mi.queue_free)


## Pionowy słup światła (awans, leczenie).
func pillar(pos: Vector3, color: Color, dur: float, radius := 0.45, hgt := 2.6) -> void:
	var k := MeshKit.new(2)
	k.cyl(Vector3.ZERO, radius, radius * 0.6, hgt, 10, Color.WHITE, false)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	var t := create_tween()
	t.tween_property(m, "albedo_color:a", 0.45, dur * 0.2)
	t.parallel().tween_property(mi, "rotation:y", 2.0, dur)
	t.tween_property(m, "albedo_color:a", 0.0, dur * 0.8)
	t.tween_callback(mi.queue_free)


## Strzała lecąca łukiem z punktu do punktu.
func arrow(from: Vector3, to: Vector3, dur := 0.22) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _arrow_mesh
	mi.material_override = _arrow_mat
	add_child(mi)
	var a := from + Vector3(0, 0.75, 0)
	var b := to + Vector3(0, 0.6, 0)
	mi.position = a
	var arc := 0.35 * a.distance_to(b) / 4.0
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var p := a.lerp(b, k) + Vector3(0, sin(k * PI) * arc, 0)
		var p2 := a.lerp(b, minf(1.0, k + 0.05)) + Vector3(0, sin(minf(1.0, k + 0.05) * PI) * arc, 0)
		mi.position = p
		if p2.distance_to(p) > 0.001:
			mi.look_at(p2, Vector3.UP)
			mi.rotate_object_local(Vector3.UP, PI)
		, 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


## Plama krwi na ziemi.
func splat(pos: Vector3) -> void:
	var k := MeshKit.new(randi())
	for i in 7:
		var a0 := TAU * i / 7.0
		var a1 := TAU * (i + 1) / 7.0
		k.tri(Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * randf_range(0.12, 0.2), Vector3(cos(a1), 0, sin(a1)) * randf_range(0.12, 0.2), Color.WHITE, Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.04, 0.03, 0.75)
	m.roughness = 0.3
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(randf_range(-0.15, 0.15), 0.045, randf_range(-0.15, 0.15))
	add_child(mi)
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_property(m, "albedo_color:a", 0.0, 1.5)
	t.tween_callback(mi.queue_free)


## Gwiazdki krążące nad głową (ogłuszenie).
func stars(pos: Vector3, dur: float) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 1.45, 0)
	add_child(holder)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.95, 0.4)
	for i in 3:
		var st := MeshInstance3D.new()
		var k := MeshKit.new(i)
		k.blob(Vector3.ZERO, Vector3(0.06, 0.06, 0.06), Color.WHITE, 2, 4, 0.0)
		st.mesh = k.commit()
		st.material_override = m
		var a := TAU * i / 3.0
		st.position = Vector3(cos(a), 0, sin(a)) * 0.25
		holder.add_child(st)
	var t := create_tween()
	t.tween_property(holder, "rotation:y", TAU * 2.0, dur)
	t.tween_callback(holder.queue_free)


## Dodaje efekt z pakietu „fx” serwera.
func spawn(f: Dictionary) -> void:
	var p := center(f.x, f.y)
	var head := p + Vector3(0, 1.3, 0)
	match str(f.k):
		"num":
			var col := Color(1, 0.3, 0.22)
			if f.c == "heal":
				col = Color(0.35, 1, 0.45)
			elif f.c == "mana":
				col = Color(0.45, 0.65, 1)
			overlay.float_text(head, str(int(f.v)), col, 1.0, 44.0, 22)
			if f.c == "dmg":
				burst(p + Vector3(0, 0.6, 0), Color(0.85, 0.1, 0.08), 14, 2.2, -7.0, 0.5)
				burst(p + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.6), 5, 3.0, -2.0, 0.2, 0.6)
				splat(p)
			elif f.c == "heal":
				burst(p + Vector3(0, 0.3, 0), Color(0.4, 1.0, 0.5), 14, 1.2, 1.5, 0.9)
		"miss":
			burst(p + Vector3(0, 0.6, 0), Color(0.85, 0.85, 0.85), 8, 1.0, 0.0, 0.4)
			overlay.float_text(head, "pudło", Color(0.85, 0.85, 0.85), 0.8, 20.0, 15)
		"block":
			burst(p + Vector3(0, 0.6, 0), Color(0.6, 0.8, 1.0), 10, 2.0, -3.0, 0.3)
			ring(p + Vector3(0, 0.5, 0), Color(0.6, 0.8, 1.0, 0.8), 0.3, 0.7, 0.3)
		"puff":
			burst(p + Vector3(0, 0.3, 0), Color(0.6, 0.6, 0.6), 12, 1.0, 0.5, 0.6, 1.5)
		"shot":
			arrow(p, center(f.tx, f.ty))
		"heal":
			pillar(p, Color(0.4, 1.0, 0.5), 0.9, 0.45, 1.6)
			burst(p + Vector3(0, 0.2, 0), Color(0.5, 1.0, 0.6), 18, 1.4, 1.0, 1.0)
		"death":
			if int(f.get("boss", 0)) == 1:
				pillar(p, Color(1.0, 0.6, 0.2), 2.5, 1.2, 5.0)
				ring(p, Color(1.0, 0.6, 0.2), 0.5, 6.0, 1.5, 0.12)
				burst(p + Vector3(0, 1.0, 0), Color(1, 0.7, 0.3), 60, 5.0, -3.0, 1.6, 1.5)
			burst(p + Vector3(0, 0.4, 0), Color(0.5, 0.05, 0.05), 20, 1.8, -6.0, 0.6)
			burst(p + Vector3(0, 0.3, 0), Color(0.3, 0.3, 0.3), 14, 0.8, 1.0, 1.2, 2.0)
			splat(p)
			splat(p)
		"levelup":
			pillar(p, Color(1.0, 0.85, 0.3), 1.6, 0.55, 3.2)
			ring(p, Color(1, 0.85, 0.3), 0.2, 2.0, 1.0, 0.1)
			burst(p + Vector3(0, 0.5, 0), Color(1, 0.8, 0.3), 40, 3.0, -2.0, 1.2)
			overlay.float_text(head + Vector3(0, 0.3, 0), "AWANS!", Color(1, 0.85, 0.3), 2.0, 50.0, 28)
		"gather":
			burst(p + Vector3(0, 0.5, 0), Color(0.85, 0.75, 0.5), 10, 1.8, -6.0, 0.5)
			var d := GameData.item_def(str(f.get("item", "")))
			overlay.float_text(head, "+%d %s" % [int(f.v), str(d.get("name", "")).get_slice(" (", 0)], Color(0.6, 1, 0.5), 1.4, 36.0, 17)
		"craft":
			burst(p + Vector3(0, 0.6, 0), Color(1, 0.7, 0.3), 20, 1.5, -1.0, 0.8)
			ring(p, Color(1, 0.7, 0.3), 0.2, 1.2, 0.6)
		"stun":
			stars(p, 1.5)
			overlay.float_text(head, "ogłuszony!", Color(1, 0.95, 0.4), 1.2, 18.0, 16)
		"whirl":
			ring(p, Color(0.9, 0.9, 1.0), 0.3, 1.6, 0.4, 0.2)
			burst(p + Vector3(0, 0.5, 0), Color(0.9, 0.9, 1.0), 24, 3.5, 0.0, 0.35, 1.0, 90.0)
		"volley":
			for i in 6:
				var from := p + Vector3(randf_range(-2.5, -1.0), 3.0, randf_range(-2.5, -1.0))
				arrow(from, p + Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9)), 0.3 + i * 0.03)
			burst(p + Vector3(0, 0.2, 0), Color(0.85, 0.7, 0.45), 16, 1.5)
		"frenzy":
			burst(p + Vector3(0, 0.6, 0), Color(1.0, 0.3, 0.15), 24, 1.5, 1.5, 0.9)
			ring(p, Color(1.0, 0.3, 0.15), 0.3, 1.1, 0.5)
		"ironskin":
			pillar(p, Color(0.75, 0.82, 0.95), 1.0, 0.5, 1.5)
			burst(p + Vector3(0, 0.6, 0), Color(0.75, 0.8, 0.9), 16, 1.2, 0.0, 0.8)
		"bolt":
			var col := Color.html(str(f.get("col", ""))) if str(f.get("col", "")) != "" else Color(0.6, 0.8, 1.0)
			bolt(p, center(f.tx, f.ty), col)
		"poison":
			burst(p + Vector3(0, 0.4, 0), Color(0.45, 0.95, 0.25), 10, 0.8, 0.8, 0.8)
		"aoe":
			aoe(p, str(f.get("kind", "fire")), float(f.get("r", 3)))
		"words":
			overlay.float_text(head + Vector3(0, 0.35, 0), str(f.text), Color(1, 0.62, 0.22), 1.6, 12.0, 18)


## Znacznik miejsca dotknięcia.
func tap_marker(tile: Vector2i) -> void:
	ring(center(tile.x, tile.y), Color(1, 1, 1, 0.8), 0.5, 0.2, 0.35, 0.18, false)


## Pocisk magiczny: świecąca kula lecąca łukiem z iskrami.
func bolt(from: Vector3, to: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.5
	sm.material = m
	mi.mesh = sm
	add_child(mi)
	var a := from + Vector3(0, 0.8, 0)
	var b := to + Vector3(0, 0.6, 0)
	mi.position = a
	var tw := create_tween()
	tw.tween_method(_bolt_step.bind(mi, a, b), 0.0, 1.0, 0.3)
	tw.tween_callback(_bolt_hit.bind(mi, b, col))


func _bolt_step(k: float, mi: Node3D, a: Vector3, b: Vector3) -> void:
	mi.position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 0.4, 0)


func _bolt_hit(mi: Node3D, b: Vector3, col: Color) -> void:
	burst(b, col, 12, 2.0, 0.0, 0.4)
	mi.queue_free()


## Atak obszarowy bossa: fala ognia / mrozu / piasku / trucizny o danym promieniu.
func aoe(p: Vector3, kind: String, r: float) -> void:
	var col: Color = {"fire": Color(1.0, 0.45, 0.1), "frost": Color(0.55, 0.85, 1.0), "sand": Color(0.9, 0.75, 0.45), "poison": Color(0.45, 0.95, 0.25)}.get(kind, Color(1, 0.5, 0.2))
	ring(p, col, 0.3, r + 0.5, 0.6, 0.25)
	ring(p, col.lightened(0.3), 0.2, r, 0.9, 0.1)
	if not Config.effects:
		return
	var pp := CPUParticles3D.new()
	pp.position = p + Vector3(0, 0.2, 0)
	pp.mesh = _dot_mesh
	pp.one_shot = true
	pp.explosiveness = 0.9
	pp.amount = 60
	pp.lifetime = 0.9
	pp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pp.emission_sphere_radius = r * 0.7
	pp.direction = Vector3.UP
	pp.spread = 40
	pp.initial_velocity_min = 1.0
	pp.initial_velocity_max = 3.0
	pp.gravity = Vector3(0, -2.0 if kind == "sand" else 1.0, 0)
	pp.scale_amount_min = 1.0
	pp.scale_amount_max = 2.2
	var g := Gradient.new()
	g.colors = PackedColorArray([col.lightened(0.4), col, Color(col, 0.0)])
	pp.color_ramp = g
	add_child(pp)
	pp.emitting = true
	get_tree().create_timer(1.3).timeout.connect(pp.queue_free)
