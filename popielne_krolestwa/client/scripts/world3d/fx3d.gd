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
			elif f.c == "shield":
				col = Color(0.55, 0.85, 1.0)
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
		"sp":
			spell(f)


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


# ============================================================================
# Czary
# ============================================================================

const SCHOOL_COL := {"light": Color(1.0, 0.9, 0.5), "fire": Color(1.0, 0.45, 0.1), "ice": Color(0.55, 0.85, 1.0),
	"lightning": Color(0.75, 0.7, 1.0), "death": Color(0.6, 0.2, 0.75)}


## Efekt czaru z pakietu serwera: {s: id czaru, x,y: rzucający, tx,ty: cel, r: promień, chain: [[x,y]…]}.
func spell(f: Dictionary) -> void:
	var s := str(f.get("s", ""))
	var p := center(f.x, f.y)
	var has_t := f.has("tx")
	var t := center(f.get("tx", f.x), f.get("ty", f.y))
	var r := float(f.get("r", 2))
	match s:
		"heal_area":
			ring(p, Color(1.0, 0.9, 0.5), 0.3, r + 0.5, 0.8, 0.15)
			pillar(p, Color(1.0, 0.92, 0.6), 1.2, 0.6, 2.4)
			flash(p, Color(1.0, 0.9, 0.6), 2.0, r * 2.5, 0.6)
		"purify":
			pillar(p, Color(0.9, 0.95, 1.0), 0.9, 0.4, 2.0)
			burst(p + Vector3(0, 0.6, 0), Color(0.95, 0.95, 1.0), 24, 1.5, 1.5, 0.9)
		"holy":
			bolt(p, t, Color(1.0, 0.92, 0.55))
			_later(0.3, func(): pillar(t, Color(1.0, 0.9, 0.5), 0.7, 0.35, 2.8); flash(t, Color(1, 0.9, 0.6), 2.5, 5.0, 0.4))
		"fireball":
			orb(p, t, Color(1.0, 0.45, 0.1), 0.16, 0.32)
			_later(0.32, func(): explode(t, Color(1.0, 0.45, 0.1), 0.9))
		"firestorm":
			for i in 7:
				var o := Vector3(randf_range(-r, r), 0, randf_range(-r, r))
				_later(i * 0.07, func(): orb(t + o + Vector3(-2.5, 3.5, -2.0), t + o, Color(1.0, 0.5, 0.12), 0.12, 0.35, false))
			_later(0.45, func(): aoe(t, "fire", r); flash(t, Color(1, 0.5, 0.2), 3.0, r * 3.0, 0.6))
		"meteor":
			meteor(t, r)
		"icebolt":
			orb(p, t, Color(0.6, 0.88, 1.0), 0.13, 0.3)
			_later(0.3, func(): shards(t, 8, 0.5))
		"frost_nova":
			ring(p, Color(0.6, 0.9, 1.0), 0.3, r + 0.6, 0.6, 0.3)
			shards(p, 18, r)
			flash(p, Color(0.6, 0.85, 1.0), 2.5, r * 3.0, 0.5)
		"ice_armor":
			shards(p, 10, 0.7)
			ring(p, Color(0.6, 0.9, 1.0), 0.2, 1.0, 0.5)
		"lightning":
			lightning(p + Vector3(0, 1.0, 0), t + Vector3(0, 0.7, 0), Color(0.8, 0.8, 1.0))
			lightning(t + Vector3(randf_range(-0.5, 0.5), 7.0, 0), t + Vector3(0, 0.6, 0), Color(0.85, 0.85, 1.0))
			flash(t, Color(0.7, 0.75, 1.0), 4.0, 7.0, 0.25)
		"chain":
			var pts: Array = f.get("chain", [])
			var prev := p + Vector3(0, 1.0, 0)
			for i in pts.size():
				var c: Array = pts[i]
				var q := center(c[0], c[1]) + Vector3(0, 0.7, 0)
				var a := prev
				_later(i * 0.12, func(): lightning(a, q, Color(0.8, 0.8, 1.0)); flash(q, Color(0.7, 0.75, 1.0), 3.0, 5.0, 0.2))
				prev = q
		"storm":
			ring(t, Color(0.55, 0.55, 0.9, 0.7), r + 0.5, r + 0.3, float(f.get("ms", 4000)) / 1000.0, 0.05)
			cloud(t, Color(0.25, 0.25, 0.35), r, float(f.get("ms", 4000)) / 1000.0, 3.0)
		"storm_hit":
			lightning(p + Vector3(randf_range(-0.4, 0.4), 7.0, randf_range(-0.4, 0.4)), p + Vector3(0, 0.3, 0), Color(0.85, 0.85, 1.0))
			flash(p, Color(0.7, 0.75, 1.0), 4.0, 7.0, 0.25)
			burst(p + Vector3(0, 0.2, 0), Color(0.8, 0.8, 1.0), 12, 2.5, -4.0, 0.3)
		"haste":
			burst(p + Vector3(0, 0.3, 0), Color(1.0, 0.95, 0.5), 20, 2.5, 0.0, 0.5, 0.8, 60.0)
			ring(p, Color(1.0, 0.95, 0.5), 0.2, 1.2, 0.4)
		"drain":
			drain(t, p, Color(0.8, 0.1, 0.2))
		"curse":
			ring(t, Color(0.6, 0.2, 0.75), 1.2, 0.2, 0.8, 0.2)
			burst(t + Vector3(0, 0.9, 0), Color(0.45, 0.1, 0.55), 20, 1.0, -1.0, 1.2, 1.2)
		"poison_cloud":
			cloud(t, Color(0.4, 0.8, 0.2), r, float(f.get("ms", 6000)) / 1000.0, 0.8)
		"impact":
			burst(p + Vector3(0, 0.7, 0), Color(1, 1, 1), 5, 1.5, 0.0, 0.25, 0.6)


func _later(sec: float, fn: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(fn)


## Chwilowe światło (błysk czaru, piorun, wybuch) – oświetla okolicę, najlepiej widoczne nocą.
func flash(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	if not Config.effects:
		return
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos + Vector3(0, 1.2, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


func _glow_mat(col: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


## Świecąca kula z ogonem iskier (kula ognia, lodowy pocisk).
func orb(from: Vector3, to: Vector3, col: Color, size: float, dur: float, lift := true) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _glow_mat(col, 4.0)
	mi.mesh = sm
	add_child(mi)
	if Config.effects:
		var tr := CPUParticles3D.new()
		tr.mesh = _dot_mesh
		tr.amount = 24
		tr.lifetime = 0.35
		tr.local_coords = false
		tr.direction = Vector3.UP
		tr.spread = 180
		tr.initial_velocity_min = 0.2
		tr.initial_velocity_max = 0.6
		tr.gravity = Vector3(0, 0.5, 0)
		tr.scale_amount_min = 1.0
		tr.scale_amount_max = 2.2
		var g := Gradient.new()
		g.colors = PackedColorArray([col.lightened(0.5), col, Color(col, 0.0)])
		tr.color_ramp = g
		mi.add_child(tr)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.5
		l.omni_range = 3.0
		mi.add_child(l)
	var a := from + (Vector3(0, 0.9, 0) if lift else Vector3.ZERO)
	var b := to + Vector3(0, 0.6, 0)
	mi.position = a
	var tw := create_tween()
	tw.tween_method(_bolt_step.bind(mi, a, b), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


## Wybuch: kula światła, iskry, fala.
func explode(pos: Vector3, col: Color, size: float) -> void:
	burst(pos + Vector3(0, 0.6, 0), col, 30, 3.0 * size, -2.0, 0.6, 1.4)
	burst(pos + Vector3(0, 0.6, 0), Color(1, 0.95, 0.7), 10, 1.5, 0.5, 0.3, 1.0)
	ring(pos, col, 0.2, 1.4 * size, 0.4, 0.2)
	flash(pos, col, 3.0, 6.0 * size, 0.5)


## Lodowe kolce wyrastające z ziemi i znikające.
func shards(pos: Vector3, count: int, r: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.4, 0.7, 1.0)
	m.emission_energy_multiplier = 0.8
	m.metallic = 0.3
	m.roughness = 0.1
	for i in count:
		var k := MeshKit.new(i)
		k.cone(Vector3.ZERO, 0.08 + randf() * 0.05, 0.4 + randf() * 0.4, 4, Color.WHITE, randf())
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		mi.material_override = m
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		mi.position = pos + Vector3(cos(a) * d, 0, sin(a) * d)
		mi.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		mi.scale = Vector3(1, 0.01, 1)
		add_child(mi)
		var tw := create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.6 + randf() * 0.3)
		tw.tween_property(mi, "scale", Vector3(0.6, 0.01, 0.6), 0.3)
		tw.tween_callback(mi.queue_free)


## Piorun: łamana linia między punktami (dwie skrzyżowane wstęgi), szybko gaśnie.
func lightning(a: Vector3, b: Vector3, col: Color) -> void:
	var k := MeshKit.new(randi())
	var segs := 9
	var pts: Array[Vector3] = []
	var d := b - a
	var side := d.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := d.cross(side).normalized()
	for i in segs + 1:
		var t := float(i) / segs
		var off := Vector3.ZERO if i == 0 or i == segs else (side * randf_range(-0.35, 0.35) + up * randf_range(-0.35, 0.35)) * d.length() * 0.08
		pts.append(a.lerp(b, t) + off)
	for i in segs:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		for axis in [side, up]:
			var w: Vector3 = axis * 0.045
			k.quad(p0 - w, p1 - w, p1 + w, p0 + w, Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


## Meteor: rozżarzona skała spada z nieba, po 1,1 s wybuch w promieniu.
func meteor(t: Vector3, r: float) -> void:
	ring(t, Color(1.0, 0.4, 0.1, 0.9), r + 0.3, r, 1.1, 0.06)
	var mi := MeshInstance3D.new()
	var k := MeshKit.new(7)
	k.blob(Vector3.ZERO, Vector3(0.45, 0.4, 0.45), Color(0.35, 0.12, 0.05), 3, 7, 0.25)
	mi.mesh = k.commit()
	mi.material_override = _glow_mat(Color(1.0, 0.4, 0.1), 2.0)
	add_child(mi)
	var start := t + Vector3(-6.0, 14.0, -4.0)
	mi.position = start
	orb(start, t, Color(1.0, 0.5, 0.15), 0.35, 1.1, false)
	var tw := create_tween()
	tw.tween_property(mi, "position", t + Vector3(0, 0.3, 0), 1.1).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "rotation", Vector3(4, 2, 3), 1.1)
	tw.tween_callback(func():
		mi.queue_free()
		explode(t, Color(1.0, 0.45, 0.1), r * 0.8)
		aoe(t, "fire", r)
		burst(t + Vector3(0, 0.3, 0), Color(0.3, 0.25, 0.22), 30, 2.0, -3.0, 1.2, 2.0))


## Obłok (trucizna, chmura burzowa) nad obszarem przez `dur` sekund.
func cloud(t: Vector3, col: Color, r: float, dur: float, hgt: float) -> void:
	if not Config.effects:
		ring(t, col, r, r, dur, 0.05)
		return
	var pp := CPUParticles3D.new()
	pp.position = t + Vector3(0, hgt, 0)
	pp.mesh = _dot_mesh
	pp.amount = 60
	pp.lifetime = 1.6
	pp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(r, 0.3, r)
	pp.direction = Vector3.UP
	pp.spread = 180
	pp.initial_velocity_min = 0.1
	pp.initial_velocity_max = 0.4
	pp.gravity = Vector3.ZERO
	pp.scale_amount_min = 3.0
	pp.scale_amount_max = 6.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(col, 0.0), Color(col, 0.55), Color(col, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	pp.color_ramp = g
	add_child(pp)
	pp.emitting = true
	_later(dur, func(): pp.emitting = false)
	_later(dur + 1.8, pp.queue_free)


## Wysysanie życia: czerwone iskry płyną od celu do rzucającego.
func drain(from: Vector3, to: Vector3, col: Color) -> void:
	for i in 10:
		var mi := MeshInstance3D.new()
		mi.mesh = _dot_mesh
		mi.material_override = _glow_mat(col, 3.0)
		mi.scale = Vector3.ONE * 2.0
		add_child(mi)
		var a := from + Vector3(randf_range(-0.2, 0.2), 0.7 + randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		var b := to + Vector3(0, 0.9, 0)
		mi.position = a
		var tw := create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_method(_bolt_step.bind(mi, a, b), 0.0, 1.0, 0.45)
		tw.tween_callback(mi.queue_free)
	ring(from, col, 0.8, 0.2, 0.5, 0.2)
