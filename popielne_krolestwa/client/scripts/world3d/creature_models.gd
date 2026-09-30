class_name CreatureModels
extends RefCounted
## Stworzenia o nietypowej budowie: pająk, skorpion, skarabeusz, ropucha (i Matka Moczarów),
## Pustynny Czerw, smok Żarogniew (i drake-wierzchowiec), żywiołak ognia, drzewiec, golem,
## kryształ obelisku. Budują części w CharacterModel i animują je w kodzie.


static func build(m: CharacterModel, look: String) -> bool:
	match look:
		"spider":
			_spider(m)
		"scorpion":
			_scorpion(m)
		"scarab":
			_scarab(m)
		"toad":
			_toad(m, 1.0, Color(0.36, 0.44, 0.22))
		"bog_mother":
			_toad(m, 1.0, Color(0.26, 0.34, 0.16), true)
		"sand_worm":
			_worm(m)
		"ash_dragon":
			_dragon(m, false)
		"mount_drake":
			_dragon(m, true)
		"fire_elemental":
			_elemental(m)
		"treant":
			_treant(m)
		"golem":
			_golem(m)
		_:
			return false
	return true


static func _legs(m: CharacterModel, root: Node3D, count: int, body_y: float, spread: float, length: float, col: Color, prefix := "leg_") -> void:
	for i in count:
		var side := -1 if i % 2 == 0 else 1
		var row := i / 2
		var z := (row - (count / 2 - 1) / 2.0) * spread
		var k := MeshKit.new(200 + i)
		# Odnóże: udo w górę i na zewnątrz, goleń w dół.
		k.xf = Transform3D(Basis(Vector3(0, 0, 1), side * -0.9), Vector3.ZERO)
		k.box(Vector3(0, 0, 0), Vector3(0.04, length * 0.55, 0.04), col)
		k.xf = Transform3D(Basis(Vector3(0, 0, 1), side * 0.35), Vector3(side * length * 0.45, length * 0.3, 0))
		k.box(Vector3(0, -length * 0.62, 0), Vector3(0.035, length * 0.62, 0.035), col.darkened(0.15))
		k.xf = Transform3D.IDENTITY
		m._part(prefix + str(i), root, Vector3(side * 0.12, body_y, z), k)


# --- Pająk -------------------------------------------------------------------------

static func _spider(m: CharacterModel) -> void:
	m.type = "spider"
	var root := m._part("root", m, Vector3.ZERO)
	var col := Color(0.22, 0.18, 0.16)
	var k := MeshKit.new(210)
	k.jitter = 0.03
	k.blob(Vector3(0, 0.28, -0.22), Vector3(0.26, 0.2, 0.3), col, 3, 7, 0.08, col.lightened(0.1))
	k.box(Vector3(0, 0.36, -0.2), Vector3(0.08, 0.02, 0.3), Color(0.7, 0.15, 0.1))
	k.blob(Vector3(0, 0.24, 0.08), Vector3(0.15, 0.12, 0.15), col.lightened(0.05), 2, 6, 0.05)
	k.glow = 1.0
	for i in 4:
		k.box(Vector3((i % 2 - 0.5) * 0.08, 0.28 + (i / 2) * 0.04, 0.22), Vector3(0.03, 0.03, 0.01), Color(1, 0.2, 0.1))
	k.glow = 0.0
	for side in [-1, 1]:
		k.cone(Vector3(side * 0.05, 0.18, 0.2), 0.025, 0.1, 4, Color(0.9, 0.85, 0.7))
	var body := m._part("body", root, Vector3.ZERO, k)
	_legs(m, body, 8, 0.26, 0.11, 0.42, col)
	m.height = 0.55


# --- Skorpion ----------------------------------------------------------------------

static func _scorpion(m: CharacterModel) -> void:
	m.type = "scorpion"
	var root := m._part("root", m, Vector3.ZERO)
	var col := Color(0.62, 0.42, 0.2)
	var k := MeshKit.new(220)
	k.jitter = 0.03
	for i in 3:
		k.box(Vector3(0, 0.12, 0.12 - i * 0.14), Vector3(0.3 - i * 0.03, 0.12, 0.15), col.darkened(i * 0.05), Vector2(0.85, 0.9))
	k.glow = 0.6
	for side in [-1, 1]:
		k.box(Vector3(side * 0.05, 0.2, 0.2), Vector3(0.03, 0.03, 0.01), Color(0.1, 0.05, 0.05))
	k.glow = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	_legs(m, body, 6, 0.12, 0.13, 0.3, col.darkened(0.1))
	for side in [-1, 1]:
		var ck := MeshKit.new(221 + side)
		ck.box(Vector3(0, 0, 0.1), Vector3(0.05, 0.05, 0.2), col)
		ck.box(Vector3(0, 0, 0.26), Vector3(0.12, 0.07, 0.12), col.lightened(0.05))
		ck.cone(Vector3(side * 0.04, 0, 0.32), 0.03, 0.12, 4, col.darkened(0.2))
		var claw := m._part("claw_l" if side < 0 else "claw_r", body, Vector3(side * 0.18, 0.14, 0.16), ck)
		claw.rotation.y = -side * 0.4
	var tk := MeshKit.new(223)
	var p := Vector3.ZERO
	for i in 5:
		var q := p + Vector3(0, 0.1, -0.06 + i * 0.03)
		tk.box(p, Vector3(0.1 - i * 0.012, 0.1, 0.1 - i * 0.01), col.darkened(0.05 * i))
		p = q
	tk.glow = 0.5
	tk.cone(p + Vector3(0, 0.02, 0.04), 0.04, 0.14, 4, Color(0.3, 0.9, 0.3))
	tk.glow = 0.0
	var tail := m._part("tail", body, Vector3(0, 0.16, -0.26), tk)
	tail.rotation.x = -0.3
	m.height = 0.7


# --- Skarabeusz ----------------------------------------------------------------------

static func _scarab(m: CharacterModel) -> void:
	m.type = "spider"
	var root := m._part("root", m, Vector3.ZERO)
	var k := MeshKit.new(230)
	k.metal = 0.8
	k.blob(Vector3(0, 0.14, -0.02), Vector3(0.2, 0.13, 0.24), Color(0.15, 0.35, 0.3), 3, 7, 0.0, Color(0.25, 0.55, 0.45))
	k.box(Vector3(0, 0.12, 0.16), Vector3(0.14, 0.08, 0.08), Color(0.12, 0.2, 0.18))
	k.cone(Vector3(0, 0.16, 0.2), 0.03, 0.12, 4, Color(0.85, 0.7, 0.3))
	k.metal = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	_legs(m, body, 6, 0.1, 0.1, 0.2, Color(0.1, 0.12, 0.1))
	m.height = 0.35


# --- Ropucha / Matka Moczarów -------------------------------------------------------------

static func _toad(m: CharacterModel, s: float, col: Color, boss := false) -> void:
	m.type = "toad"
	var root := m._part("root", m, Vector3.ZERO)
	var k := MeshKit.new(240)
	k.jitter = 0.04
	k.blob(Vector3(0, 0.2, 0), Vector3(0.3, 0.2, 0.32) * s, col, 3, 8, 0.1, col.lightened(0.1))
	k.blob(Vector3(0, 0.14, 0.06), Vector3(0.24, 0.1, 0.26) * s, Color(0.7, 0.68, 0.45), 2, 7, 0.0)
	for i in 6:
		k.blob(Vector3(cos(i * 1.1) * 0.18, 0.34, sin(i * 1.1) * 0.15 - 0.05), Vector3(0.04, 0.03, 0.04), col.darkened(0.2), 2, 5, 0.0)
	if boss:
		# Mech, grzyby i świecące wrzody.
		for i in 8:
			k.blob(Vector3(cos(i * 0.8) * 0.2, 0.36 + (i % 3) * 0.02, sin(i * 0.8) * 0.2), Vector3(0.07, 0.04, 0.07), Color(0.3, 0.45, 0.15), 2, 5, 0.2)
		k.glow = 0.9
		for i in 5:
			k.blob(Vector3(cos(i * 1.3) * 0.26, 0.26, sin(i * 1.3) * 0.22), Vector3(0.03, 0.03, 0.03), Color(0.6, 1.0, 0.3), 2, 4, 0.0)
		k.glow = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	var hk := MeshKit.new(241)
	hk.blob(Vector3(0, 0.0, 0.08), Vector3(0.22, 0.12, 0.16), col, 3, 7, 0.08)
	hk.box(Vector3(0, -0.04, 0.2), Vector3(0.3, 0.02, 0.06), Color(0.3, 0.1, 0.1))
	hk.glow = 0.6 if boss else 0.2
	for side in [-1, 1]:
		hk.blob(Vector3(side * 0.12, 0.1, 0.12), Vector3(0.06, 0.06, 0.06), Color(0.95, 0.8, 0.2), 2, 6, 0.0)
		hk.box(Vector3(side * 0.12, 0.1, 0.175), Vector3(0.02, 0.05, 0.01), Color(0.05, 0.05, 0.05))
	hk.glow = 0.0
	m._part("head", body, Vector3(0, 0.26, 0.18), hk)
	for i in 4:
		var side := -1 if i % 2 == 0 else 1
		var front := i < 2
		var lk := MeshKit.new(242 + i)
		lk.box(Vector3(0, -0.06, 0), Vector3(0.08, 0.12, 0.1), col.darkened(0.1))
		lk.box(Vector3(0, -0.13, 0.05), Vector3(0.12, 0.03, 0.14), col.darkened(0.15))
		m._part(["leg_fl", "leg_fr", "leg_bl", "leg_br"][i], root, Vector3(side * 0.24, 0.14, 0.14 if front else -0.16), lk)
	m.height = 0.55


# --- Pustynny Czerw -------------------------------------------------------------------

static func _worm(m: CharacterModel) -> void:
	m.type = "worm"
	var root := m._part("root", m, Vector3.ZERO)
	var col := Color(0.72, 0.52, 0.36)
	var n := 7
	var parent: Node3D = root
	for i in n:
		var k := MeshKit.new(250 + i)
		var r := 0.36 - i * 0.02
		k.jitter = 0.03
		k.cyl(Vector3(0, 0, 0), r, r * 0.95, 0.3, 9, col.lerp(col.darkened(0.2), float(i % 2)), true, col.darkened(0.1))
		k.cyl(Vector3(0, 0.3, 0), r * 0.95, r * 0.9, 0.05, 9, col.darkened(0.3), false)
		var seg := m._part("seg_%d" % i, parent, Vector3(0, 0.0 if i == 0 else 0.32, 0), k)
		parent = seg
	# Głowa z żuwaczkami i pierścieniem zębów.
	var hk := MeshKit.new(260)
	hk.cyl(Vector3.ZERO, 0.24, 0.3, 0.2, 9, col.darkened(0.15), true, Color(0.3, 0.1, 0.08))
	for i in 9:
		var a := i * TAU / 9.0
		hk.cone(Vector3(cos(a) * 0.22, 0.18, sin(a) * 0.22), 0.04, 0.14, 4, Color(0.95, 0.9, 0.78))
	for i in 3:
		var a := i * TAU / 3.0
		hk.xf = Transform3D(Basis(Vector3(-sin(a), 0, cos(a)), -0.5), Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3))
		hk.cone(Vector3.ZERO, 0.07, 0.45, 5, col.darkened(0.25))
	hk.xf = Transform3D.IDENTITY
	var head := m._part("head", parent, Vector3(0, 0.32, 0), hk)
	head.rotation.x = 0.6
	# Kopiec piasku u podstawy.
	var sk := MeshKit.new(261)
	sk.jitter = 0.05
	sk.blob(Vector3(0, -0.02, 0), Vector3(0.75, 0.2, 0.75), Color(0.86, 0.72, 0.48), 3, 9, 0.2)
	m._attach_mesh(root, sk)
	m.height = 2.3


# --- Smok Żarogniew / drake --------------------------------------------------------------

static func _dragon(m: CharacterModel, small: bool) -> void:
	m.type = "dragon"
	var col := Color(0.32, 0.1, 0.08) if not small else Color(0.45, 0.14, 0.1)
	var belly := Color(0.7, 0.45, 0.2)
	var root := m._part("root", m, Vector3.ZERO)
	var leg := 0.34
	var L := 1.1
	var W := 0.5
	var H := 0.42
	var bk := MeshKit.new(270)
	bk.jitter = 0.03
	bk.box(Vector3(0, -H / 2.0, 0), Vector3(W, H, L), col, Vector2(0.85, 0.9))
	bk.box(Vector3(0, -H / 2.0 - 0.01, 0.05), Vector3(W * 0.75, H * 0.35, L * 0.85), belly)
	for i in 6:
		bk.cone(Vector3(0, H / 2.0 - 0.02, L / 2.4 - i * L / 6.0), 0.06, 0.16, 4, Color(0.15, 0.06, 0.05))
	bk.glow = 1.0
	for i in 5:
		bk.box(Vector3((i % 2 - 0.5) * 0.14, H / 2.0 - 0.005, -L / 3.0 + i * L / 6.0), Vector3(0.04, 0.012, 0.14), Color(1.0, 0.45, 0.1))
	bk.glow = 0.0
	if small:
		bk.box(Vector3(0, H / 2.0 - 0.03, 0.05), Vector3(W * 1.05, 0.05, 0.34), Color(0.25, 0.15, 0.1))
	var body := m._part("body", root, Vector3(0, leg + H / 2.0, 0), bk)
	# Szyja i głowa.
	var nk := MeshKit.new(271)
	for i in 3:
		nk.box(Vector3(0, i * 0.16, i * 0.08), Vector3(0.24 - i * 0.02, 0.18, 0.22 - i * 0.02), col.darkened(0.05 * i))
	var neck := m._part("neck", body, Vector3(0, H * 0.2, L / 2.0 - 0.05), nk)
	neck.rotation.x = 0.45
	var hk := MeshKit.new(272)
	hk.jitter = 0.03
	hk.box(Vector3(0, -0.1, 0), Vector3(0.26, 0.22, 0.3), col, Vector2(0.85, 0.85))
	hk.box(Vector3(0, -0.12, 0.2), Vector3(0.2, 0.14, 0.2), col.lightened(0.05), Vector2(0.8, 0.8))
	for side in [-1, 1]:
		hk.xf = Transform3D(Basis(Vector3(1, 0, 0), -0.9), Vector3(side * 0.08, 0.0, -0.08))
		hk.cone(Vector3.ZERO, 0.04, 0.3, 5, Color(0.85, 0.78, 0.6))
		hk.xf = Transform3D.IDENTITY
		hk.cone(Vector3(side * 0.06, -0.2, 0.26), 0.02, 0.07, 4, Color(0.95, 0.92, 0.8))
	hk.glow = 1.0
	for side in [-1, 1]:
		hk.box(Vector3(side * 0.09, -0.04, 0.12), Vector3(0.05, 0.03, 0.02), Color(1.0, 0.6, 0.1))
	hk.box(Vector3(0, -0.19, 0.3), Vector3(0.12, 0.02, 0.01), Color(1.0, 0.4, 0.05))
	hk.glow = 0.0
	var head := m._part("head", neck, Vector3(0, 0.45, 0.2), hk)
	head.rotation.x = -0.4
	# Skrzydła.
	for side in [-1, 1]:
		var wk := MeshKit.new(273 + side)
		var wc := Color(0.45, 0.14, 0.1)
		wk.box(Vector3(side * 0.45, 0, 0), Vector3(0.9, 0.05, 0.05), col.darkened(0.2))
		wk.box(Vector3(side * 0.9, 0.1, -0.3), Vector3(0.04, 0.04, 0.6), col.darkened(0.2))
		wk.blade(Vector3.ZERO, Vector3(side * 0.9, 0, 0), Vector3(side * 0.55, -0.02, -0.7), wc)
		wk.blade(Vector3(side * 0.9, 0, 0), Vector3(side * 0.9, 0.1, -0.6), Vector3(side * 0.55, -0.02, -0.7), wc.darkened(0.1))
		wk.blade(Vector3.ZERO, Vector3(side * 0.55, -0.02, -0.7), Vector3(0, 0, -0.5), wc.darkened(0.2))
		m._part("wing_l" if side < 0 else "wing_r", body, Vector3(side * W * 0.4, H * 0.45, 0.1), wk)
	# Ogon.
	var tk := MeshKit.new(275)
	for i in 5:
		tk.box(Vector3(0, -0.02 * i, -0.12 - i * 0.2), Vector3(0.24 - i * 0.04, 0.2 - i * 0.03, 0.22), col.darkened(0.04 * i))
	tk.cone(Vector3(0, -0.1, -1.1), 0.05, 0.18, 4, Color(0.15, 0.06, 0.05))
	var tail := m._part("tail", body, Vector3(0, 0, -L / 2.0), tk)
	tail.rotation.x = 0.15
	# Nogi.
	var i := 0
	for fz in [1, -1]:
		for side in [-1, 1]:
			var lk := MeshKit.new(280 + i)
			lk.box(Vector3(0, -leg - 0.02, 0), Vector3(0.14, leg + 0.06, 0.16), col.darkened(0.1))
			lk.box(Vector3(0, -leg - 0.02, 0.05), Vector3(0.16, 0.05, 0.22), col.darkened(0.3))
			for c in 3:
				lk.cone(Vector3((c - 1) * 0.05, -leg, 0.16), 0.015, 0.06, 3, Color(0.9, 0.85, 0.7))
			m._part(["leg_fl", "leg_fr", "leg_bl", "leg_br"][i], root, Vector3(side * W * 0.4, leg + 0.04, fz * L * 0.33), lk)
			i += 1
	m.height = leg + H + 0.7
	m.riding_height = leg + H + 0.05
	if not small:
		var p := CPUParticles3D.new()
		p.amount = 16
		p.lifetime = 1.0
		p.position = Vector3(0, leg + H, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(W * 0.4, 0.02, L * 0.4)
		p.direction = Vector3.UP
		p.spread = 20
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 0.8
		p.gravity = Vector3(0, 0.5, 0)
		p.mesh = _spark_mesh(Color(1, 0.5, 0.1))
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		root.add_child(p)


static func _spark_mesh(col: Color) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.radial_segments = 4
	sm.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	sm.material = mat
	return sm


# --- Żywiołak ognia ----------------------------------------------------------------------

static func _elemental(m: CharacterModel) -> void:
	m.type = "blob"
	var root := m._part("root", m, Vector3.ZERO)
	var k := MeshKit.new(290)
	k.glow = 1.0
	k.blob(Vector3(0, 0.55, 0), Vector3(0.26, 0.3, 0.26), Color(1.0, 0.45, 0.1), 3, 7, 0.25, Color(1.0, 0.75, 0.3))
	k.cone(Vector3(0, 0.75, 0), 0.18, 0.5, 6, Color(1.0, 0.6, 0.15))
	k.cone(Vector3(0, 0.25, 0), 0.16, 0.3, 6, Color(0.9, 0.3, 0.05))
	k.glow = 0.3
	for side in [-1, 1]:
		k.box(Vector3(side * 0.08, 0.62, 0.22), Vector3(0.06, 0.05, 0.02), Color(0.2, 0.05, 0.02))
	k.glow = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	for side in [-1, 1]:
		var hk := MeshKit.new(291 + side)
		hk.glow = 1.0
		hk.blob(Vector3.ZERO, Vector3(0.1, 0.1, 0.1), Color(1.0, 0.55, 0.15), 2, 6, 0.2)
		m._part("hand_l" if side < 0 else "hand_r", body, Vector3(side * 0.36, 0.55, 0.05), hk)
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.8
	p.position = Vector3(0, 0.6, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.direction = Vector3.UP
	p.spread = 25
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, 0.6, 0)
	p.mesh = _spark_mesh(Color(1, 0.6, 0.15))
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	root.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 3.5
	light.light_energy = 1.2
	light.position = Vector3(0, 0.8, 0)
	root.add_child(light)
	m.height = 1.1


# --- Drzewiec i golem (części humanoida – animacja chodu jak u postaci) ---------------------

static func _humanoid_frame(m: CharacterModel, col: Color, limb: Color, head_kit: MeshKit, torso_kit: MeshKit, arm_w: float, leg_w: float, scale_y := 1.0) -> void:
	m.type = "humanoid"
	var root := m._part("root", m, Vector3.ZERO)
	for side in [-1, 1]:
		var lk := MeshKit.new(300 + side)
		lk.jitter = 0.04
		lk.box(Vector3(0, -0.42, 0), Vector3(leg_w, 0.44, leg_w), limb)
		m._part("leg_l" if side < 0 else "leg_r", root, Vector3(side * 0.12, 0.44, 0), lk)
	var torso := m._part("torso", root, Vector3(0, 0.44, 0), torso_kit)
	m._part("head", torso, Vector3(0, 0.5 * scale_y, 0), head_kit)
	for side in [-1, 1]:
		var ak := MeshKit.new(310 + side)
		ak.jitter = 0.04
		ak.box(Vector3(0, -0.42, 0), Vector3(arm_w, 0.46, arm_w), limb)
		ak.blob(Vector3(0, -0.45, 0), Vector3(arm_w * 0.8, arm_w * 0.7, arm_w * 0.8), col, 2, 6, 0.2)
		var arm := m._part("arm_l" if side < 0 else "arm_r", torso, Vector3(side * 0.3, 0.44 * scale_y, 0), ak)
		m._part("hand_l" if side < 0 else "hand_r", arm, Vector3(0, -0.45, 0.02))
	m.weapon_kind = "melee"
	m.height = 1.35


static func _treant(m: CharacterModel) -> void:
	var bark := Color(0.36, 0.26, 0.16)
	var leaf := Color(0.26, 0.45, 0.18)
	var tk := MeshKit.new(320)
	tk.jitter = 0.04
	tk.cyl(Vector3.ZERO, 0.24, 0.2, 0.55, 7, bark)
	tk.glow = 0.6
	for side in [-1, 1]:
		tk.box(Vector3(side * 0.07, 0.38, 0.2), Vector3(0.06, 0.05, 0.02), Color(0.7, 1.0, 0.3))
	tk.glow = 0.0
	tk.box(Vector3(0, 0.26, 0.2), Vector3(0.14, 0.03, 0.02), Color(0.15, 0.1, 0.05))
	var hk := MeshKit.new(321)
	hk.jitter = 0.05
	hk.blob(Vector3(0, 0.2, 0), Vector3(0.5, 0.35, 0.5), leaf, 3, 8, 0.2, leaf.lightened(0.1))
	hk.blob(Vector3(0.25, 0.35, 0.1), Vector3(0.28, 0.22, 0.28), leaf.lightened(0.06), 2, 6, 0.2)
	hk.blob(Vector3(-0.22, 0.3, -0.12), Vector3(0.26, 0.2, 0.26), leaf.darkened(0.05), 2, 6, 0.2)
	_humanoid_frame(m, leaf, bark, hk, tk, 0.13, 0.16)


static func _golem(m: CharacterModel) -> void:
	var stone := Color(0.5, 0.46, 0.42)
	var tk := MeshKit.new(330)
	tk.jitter = 0.05
	tk.box(Vector3(0, 0, 0), Vector3(0.5, 0.52, 0.34), stone, Vector2(1.15, 1.1))
	tk.glow = 1.0
	tk.box(Vector3(0, 0.25, 0.175), Vector3(0.12, 0.12, 0.01), Color(1.0, 0.55, 0.15))
	tk.box(Vector3(0.12, 0.15, 0.175), Vector3(0.03, 0.2, 0.01), Color(1.0, 0.45, 0.1))
	tk.glow = 0.0
	var hk := MeshKit.new(331)
	hk.jitter = 0.05
	hk.box(Vector3(0, 0, 0), Vector3(0.26, 0.22, 0.24), stone.darkened(0.08))
	hk.glow = 1.0
	hk.box(Vector3(0, 0.1, 0.125), Vector3(0.16, 0.03, 0.01), Color(1.0, 0.6, 0.2))
	hk.glow = 0.0
	_humanoid_frame(m, stone.lightened(0.05), stone.darkened(0.1), hk, tk, 0.17, 0.18)


## Kryształ obelisku terytorium: kolor gildii właściciela (szary, gdy niczyj).
static func obelisk(m: CharacterModel, owner: String) -> void:
	m.type = "crystal"
	var root := m._part("root", m, Vector3.ZERO)
	var col := Color(0.55, 0.5, 0.6)
	if owner != "":
		col = Color.from_hsv(float(absi(hash(owner)) % 360) / 360.0, 0.75, 1.0)
	var k := MeshKit.new(340)
	k.metal = 0.6
	k.glow = 0.9
	k.cyl(Vector3(0, 0, 0), 0.02, 0.22, 0.55, 6, col, false)
	k.cyl(Vector3(0, 0.55, 0), 0.22, 0.0, 0.7, 6, col.lightened(0.15), false)
	k.glow = 0.0
	k.metal = 0.0
	var crystal := m._part("crystal", root, Vector3(0, 0.75, 0), k)
	crystal.rotation.y = 0.3
	var light := OmniLight3D.new()
	light.light_color = col
	light.omni_range = 4.0
	light.light_energy = 1.4
	light.position = Vector3(0, 1.2, 0)
	root.add_child(light)
	m.height = 2.1


# ============================================================================
# Animacje
# ============================================================================

static func animate(m: CharacterModel, _delta: float) -> void:
	var t: float = m._idle_t
	var ph: float = m._phase
	var atk: float = m._attack_t / 0.45 if m._attack_t >= 0.0 else -1.0
	match m.type:
		"spider", "scorpion":
			var i := 0
			while m.parts.has("leg_%d" % i):
				var leg: Node3D = m.parts["leg_%d" % i]
				leg.rotation.y = sin(ph * 1.5 + i * 1.3) * (0.4 if m.moving else 0.05)
				leg.rotation.x = cos(ph * 1.5 + i * 1.3) * (0.2 if m.moving else 0.0)
				i += 1
			var body: Node3D = m.parts["body"]
			body.position.y = sin(t * 3.0) * 0.01 + (absf(sin(ph)) * 0.02 if m.moving else 0.0)
			body.position.z = sin(atk * PI) * 0.18 if atk >= 0.0 else 0.0
			if m.type == "scorpion":
				var tail: Node3D = m.parts["tail"]
				tail.rotation.x = -0.3 + (sin(atk * PI) * 1.2 if atk >= 0.0 else sin(t * 2.0) * 0.08)
				for side in ["claw_l", "claw_r"]:
					m.parts[side].rotation.x = sin(t * 4.0 + (1.0 if side == "claw_l" else 0.0)) * 0.1
		"toad":
			var body: Node3D = m.parts["body"]
			body.position.y = absf(sin(ph * 0.6)) * 0.14 if m.moving else sin(t * 2.0) * 0.01
			body.scale = Vector3(1.0 + sin(t * 3.0) * 0.03, 1.0 - sin(t * 3.0) * 0.03, 1.0)
			m.parts["head"].rotation.x = -sin(atk * PI) * 0.5 if atk >= 0.0 else 0.0
		"worm":
			var i := 0
			while m.parts.has("seg_%d" % i):
				var seg: Node3D = m.parts["seg_%d" % i]
				seg.rotation.x = sin(t * 1.8 + i * 0.7) * 0.12 + (sin(atk * PI) * 0.35 if atk >= 0.0 and i > 2 else 0.0)
				seg.rotation.z = cos(t * 1.4 + i * 0.6) * 0.1
				i += 1
		"dragon":
			m._animate_beast(_delta)
			m._flap(0.45 if not m.moving else 0.6, 2.5 if not m.moving else 5.0)
			var neck: Node3D = m.parts["neck"]
			neck.rotation.y = sin(t * 0.8) * 0.15
			neck.rotation.x = 0.45 + (sin(atk * PI) * 0.5 if atk >= 0.0 else 0.0)
		"blob":
			var body: Node3D = m.parts["body"]
			body.position.y = 0.15 + sin(t * 2.2) * 0.08
			body.rotation.y = t * 1.5
			var s := 1.0 + sin(t * 7.0) * 0.05
			body.scale = Vector3(s, 1.0 / s, s)
		"crystal":
			var c: Node3D = m.parts["crystal"]
			c.rotation.y = t * 0.8
			c.position.y = 0.75 + sin(t * 1.5) * 0.08
