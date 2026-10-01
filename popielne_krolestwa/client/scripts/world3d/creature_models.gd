class_name CreatureModels
extends RefCounted
## Stworzenia o nietypowej budowie: pająk, skorpion, skarabeusz, ropucha (i Matka Moczarów),
## Pustynny Czerw, smok Żarogniew (i drake-wierzchowiec), żywiołak ognia, drzewiec, golem,
## kryształ obelisku. Budują gładkie części (elipsoidy, pierścieniowe bryły, stożkowe człony)
## w CharacterModel i animują je w kodzie.


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


# --- Gładkie prymitywy --------------------------------------------------------------

## Stożkowy człon od punktu a do b (kończyny, szczypce, rogi, kolce). r1 = 0 daje ostry szpic.
static func _seg(k: MeshKit, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, sides := 7) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return
	var y := d / l
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	var saved := k.xf
	k.xf = saved * Transform3D(Basis(x, y, z), a)
	k.loft([[Vector3.ZERO, Vector2(r0, r0)], [Vector3(0, l, 0), Vector2(maxf(r1, 0.002), maxf(r1, 0.002))]], col, sides, true)
	k.xf = saved


## Łańcuch członów z przegubami (kulka w każdym stawie).
static func _chain(k: MeshKit, pts: Array, radii: Array, col: Color, sides := 7, joint_col = null) -> void:
	for i in pts.size() - 1:
		_seg(k, pts[i], pts[i + 1], float(radii[i]), float(radii[i + 1]), col, sides)
		if i > 0:
			var r := float(radii[i]) * 1.15
			k.ellipsoid(pts[i], Vector3(r, r, r), joint_col if joint_col != null else col.darkened(0.08), 4, sides)


## Pierścieniowa bryła biegnąca wzdłuż osi Z: rings = [[z, Vector2(szer., wys.), y], ...].
static func _body(k: MeshKit, rings: Array, col: Color, sides := 12) -> void:
	CharacterModel._zloft(k, rings, col, sides)


## Odnóża stawonogów: udo w górę i na zewnątrz, goleń do ziemi. Tylne odchylone do tyłu, przednie do przodu.
static func _legs(m: CharacterModel, root: Node3D, count: int, body_y: float, spread: float, length: float, col: Color, thick := 0.028, prefix := "leg_") -> void:
	var rows := count / 2
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		var z := (row - (rows - 1) / 2.0) * spread
		var a := lerpf(-0.75, 0.85, float(row) / maxf(1.0, rows - 1.0))
		var h := Vector3(side * cos(a), 0.0, sin(a))
		var k := MeshKit.new(200 + i)
		var knee := h * length * 0.48 + Vector3(0, length * 0.42, 0)
		var ankle := h * length * 0.92 + Vector3(0, -body_y * 0.45, 0)
		var foot := h * length * 1.02 + Vector3(0, -body_y + 0.005, 0)
		_chain(k, [Vector3.ZERO, knee, ankle, foot], [thick, thick * 0.85, thick * 0.55, thick * 0.2], col, 6, col.darkened(0.25))
		m._part(prefix + str(i), root, Vector3(side * 0.08, body_y, z), k)


# --- Pająk -------------------------------------------------------------------------

static func _spider(m: CharacterModel) -> void:
	m.type = "spider"
	var root := m._part("root", m, Vector3.ZERO)
	var col := Color(0.16, 0.13, 0.12)
	var hair := Color(0.3, 0.24, 0.2)
	var k := MeshKit.new(210)
	# Odwłok z czerwonym znakiem klepsydry.
	k.ellipsoid(Vector3(0, 0.34, -0.3), Vector3(0.25, 0.21, 0.31), col, 7, 12)
	k.ellipsoid(Vector3(0, 0.41, -0.33), Vector3(0.18, 0.13, 0.22), hair, 5, 10)
	k.glow = 0.25
	k.ellipsoid(Vector3(0, 0.535, -0.26), Vector3(0.05, 0.02, 0.07), Color(0.85, 0.12, 0.08), 3, 8)
	k.ellipsoid(Vector3(0, 0.52, -0.4), Vector3(0.06, 0.02, 0.08), Color(0.85, 0.12, 0.08), 3, 8)
	k.glow = 0.0
	k.ellipsoid(Vector3(0, 0.27, -0.03), Vector3(0.06, 0.06, 0.07), col.darkened(0.2), 4, 8)
	# Głowotułów.
	k.ellipsoid(Vector3(0, 0.26, 0.1), Vector3(0.15, 0.1, 0.17), col.lightened(0.04), 6, 12)
	k.ellipsoid(Vector3(0, 0.31, 0.12), Vector3(0.08, 0.05, 0.1), hair, 4, 8)
	# Osiem oczu.
	k.glow = 1.0
	k.metal = 0.6
	for side in [-1, 1]:
		k.ellipsoid(Vector3(side * 0.045, 0.32, 0.24), Vector3(0.028, 0.028, 0.02), Color(1.0, 0.18, 0.1), 3, 6)
		k.ellipsoid(Vector3(side * 0.09, 0.3, 0.22), Vector3(0.016, 0.016, 0.014), Color(1.0, 0.25, 0.1), 3, 5)
		k.ellipsoid(Vector3(side * 0.03, 0.35, 0.21), Vector3(0.014, 0.014, 0.012), Color(1.0, 0.25, 0.1), 3, 5)
		k.ellipsoid(Vector3(side * 0.08, 0.34, 0.19), Vector3(0.012, 0.012, 0.01), Color(1.0, 0.25, 0.1), 3, 5)
	k.glow = 0.0
	k.metal = 0.0
	# Szczękoczułki z kłami i nogogłaszczki.
	for side in [-1, 1]:
		_seg(k, Vector3(side * 0.04, 0.24, 0.24), Vector3(side * 0.04, 0.16, 0.3), 0.035, 0.028, col.darkened(0.1))
		k.metal = 0.5
		_seg(k, Vector3(side * 0.04, 0.16, 0.3), Vector3(side * 0.015, 0.1, 0.28), 0.018, 0.0, Color(0.85, 0.8, 0.66), 5)
		k.metal = 0.0
		_chain(k, [Vector3(side * 0.08, 0.22, 0.22), Vector3(side * 0.13, 0.26, 0.32), Vector3(side * 0.1, 0.12, 0.38)], [0.018, 0.015, 0.01], col, 5)
	var body := m._part("body", root, Vector3.ZERO, k)
	_legs(m, body, 8, 0.26, 0.07, 0.46, col, 0.03)
	m.height = 0.6


# --- Skorpion ----------------------------------------------------------------------

static func _scorpion(m: CharacterModel) -> void:
	m.type = "scorpion"
	var root := m._part("root", m, Vector3.ZERO)
	var col := Color(0.62, 0.42, 0.2)
	var dark := col.darkened(0.35)
	var k := MeshKit.new(220)
	k.metal = 0.25
	# Pancerz z płytkami (pierścienie odwłoka).
	_body(k, [[0.26, Vector2(0.06, 0.04), 0.13], [0.2, Vector2(0.14, 0.07), 0.14], [0.08, Vector2(0.17, 0.08), 0.15], [-0.08, Vector2(0.18, 0.08), 0.15],
		[-0.2, Vector2(0.15, 0.07), 0.15], [-0.28, Vector2(0.08, 0.05), 0.16]], col, 12)
	for i in 5:
		var z := 0.14 - i * 0.09
		k.ellipsoid(Vector3(0, 0.2, z), Vector3(0.16 - absf(i - 1.5) * 0.02, 0.035, 0.045), col.darkened(0.12 + (i % 2) * 0.06), 3, 10)
	k.metal = 0.0
	k.glow = 0.7
	for side in [-1, 1]:
		k.ellipsoid(Vector3(side * 0.04, 0.2, 0.22), Vector3(0.018, 0.018, 0.012), Color(0.9, 0.2, 0.05), 3, 5)
	k.glow = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	_legs(m, body, 8, 0.13, 0.08, 0.3, col.darkened(0.12), 0.024)
	for side in [-1, 1]:
		var ck := MeshKit.new(221 + side)
		ck.metal = 0.25
		_chain(ck, [Vector3.ZERO, Vector3(side * 0.07, 0.02, 0.1), Vector3(side * 0.04, 0.0, 0.2)], [0.03, 0.035, 0.035], col, 7, dark)
		# Szczypce: gruba dłoń i dwa zakrzywione palce.
		ck.ellipsoid(Vector3(side * 0.04, 0.0, 0.27), Vector3(0.06, 0.045, 0.08), col.lightened(0.05), 5, 10)
		_seg(ck, Vector3(side * 0.06, 0.01, 0.32), Vector3(side * 0.035, 0.0, 0.42), 0.022, 0.0, dark, 6)
		_seg(ck, Vector3(side * 0.02, 0.0, 0.32), Vector3(side * 0.045, 0.0, 0.41), 0.018, 0.0, dark, 6)
		var claw := m._part("claw_l" if side < 0 else "claw_r", body, Vector3(side * 0.13, 0.14, 0.2), ck)
		claw.rotation.y = -side * 0.35
	# Ogon: łuk z członów nad grzbietem, zakończony jadowym kolcem.
	var tk := MeshKit.new(223)
	tk.metal = 0.25
	var R := 0.17
	var prev := Vector3.ZERO
	var n := 6
	for i in n + 1:
		var th := deg_to_rad(15.0 + i * 33.0)
		var p := Vector3(0, R - R * cos(th), -R * sin(th))
		var r := 0.065 - i * 0.006
		tk.ellipsoid(p, Vector3(r, r * 0.9, r * 1.2), col.darkened(0.04 * (i % 2)), 5, 9)
		prev = p
	tk.metal = 0.0
	tk.glow = 0.55
	var tip := prev + Vector3(0, -0.02, 0.05)
	tk.ellipsoid(tip, Vector3(0.045, 0.04, 0.055), Color(0.4, 0.85, 0.3), 4, 8)
	tk.glow = 0.0
	_seg(tk, tip + Vector3(0, -0.02, 0.03), tip + Vector3(0, -0.11, 0.11), 0.022, 0.0, Color(0.15, 0.1, 0.06), 6)
	var tail := m._part("tail", body, Vector3(0, 0.15, -0.28), tk)
	tail.rotation.x = -0.3
	m.height = 0.75


# --- Skarabeusz ----------------------------------------------------------------------

static func _scarab(m: CharacterModel) -> void:
	m.type = "spider"
	var root := m._part("root", m, Vector3.ZERO)
	var shell := Color(0.12, 0.34, 0.3)
	var k := MeshKit.new(230)
	k.metal = 0.9
	# Pokrywy skrzydeł z rowkiem pośrodku.
	for side in [-1, 1]:
		k.ellipsoid(Vector3(side * 0.085, 0.15, -0.05), Vector3(0.1, 0.1, 0.19), shell.lerp(Color(0.3, 0.6, 0.5), 0.2 if side > 0 else 0.1), 6, 10)
	k.ellipsoid(Vector3(0, 0.14, 0.12), Vector3(0.14, 0.08, 0.07), shell.darkened(0.2), 5, 10)
	k.metal = 0.6
	k.ellipsoid(Vector3(0, 0.1, 0.2), Vector3(0.08, 0.05, 0.05), Color(0.1, 0.12, 0.1), 4, 8)
	k.metal = 1.0
	# Złoty róg i znaki.
	_seg(k, Vector3(0, 0.12, 0.23), Vector3(0, 0.22, 0.3), 0.025, 0.0, Color(0.9, 0.72, 0.3), 6)
	k.glow = 0.4
	for side in [-1, 1]:
		k.ellipsoid(Vector3(side * 0.09, 0.245, -0.05), Vector3(0.025, 0.01, 0.05), Color(0.95, 0.78, 0.3), 3, 6)
	k.glow = 0.0
	k.metal = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	_legs(m, body, 6, 0.1, 0.1, 0.22, Color(0.08, 0.1, 0.09), 0.02)
	m.height = 0.35


# --- Ropucha / Matka Moczarów -------------------------------------------------------------

static func _toad(m: CharacterModel, s: float, col: Color, boss := false) -> void:
	m.type = "toad"
	var root := m._part("root", m, Vector3.ZERO)
	var belly := Color(0.72, 0.68, 0.46)
	var k := MeshKit.new(240)
	k.ellipsoid(Vector3(0, 0.22, -0.02) * s, Vector3(0.3, 0.19, 0.32) * s, col, 7, 14)
	k.ellipsoid(Vector3(0, 0.15, 0.06) * s, Vector3(0.24, 0.1, 0.24) * s, belly, 5, 12)
	# Brodawki.
	var rng := RandomNumberGenerator.new()
	rng.seed = 241
	for i in (18 if boss else 10):
		var a := rng.randf() * TAU
		var e := rng.randf_range(0.25, 0.9)
		var p := Vector3(cos(a) * sin(e) * 0.28, 0.22 + cos(e) * 0.18, sin(a) * sin(e) * 0.3 - 0.02)
		var r := rng.randf_range(0.018, 0.035)
		k.ellipsoid(p * s, Vector3(r, r * 0.7, r) * s, col.darkened(0.22), 3, 6)
	if boss:
		# Mech, grzyby i świecące wrzody Matki Moczarów.
		for i in 8:
			var p := Vector3(cos(i * 0.8) * 0.2, 0.37 + (i % 3) * 0.02, sin(i * 0.8) * 0.2)
			k.ellipsoid(p, Vector3(0.07, 0.035, 0.07), Color(0.3, 0.45, 0.15), 3, 8)
		for i in 4:
			var p := Vector3(cos(i * 1.7) * 0.12, 0.4, sin(i * 1.7) * 0.14 - 0.04)
			_seg(k, p, p + Vector3(0, 0.07, 0), 0.012, 0.01, Color(0.9, 0.86, 0.75), 5)
			k.ellipsoid(p + Vector3(0, 0.08, 0), Vector3(0.04, 0.02, 0.04), Color(0.75, 0.3, 0.2), 3, 7)
		k.glow = 0.9
		for i in 5:
			k.ellipsoid(Vector3(cos(i * 1.3) * 0.26, 0.26, sin(i * 1.3) * 0.22), Vector3(0.03, 0.03, 0.03), Color(0.6, 1.0, 0.3), 3, 6)
		k.glow = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	var hk := MeshKit.new(241)
	hk.ellipsoid(Vector3(0, 0.0, 0.07), Vector3(0.2, 0.11, 0.15), col, 6, 12)
	hk.ellipsoid(Vector3(0, -0.05, 0.1), Vector3(0.18, 0.06, 0.12), belly.darkened(0.1), 4, 10)
	# Szeroka paszcza.
	hk.ellipsoid(Vector3(0, -0.03, 0.19), Vector3(0.15, 0.012, 0.035), Color(0.25, 0.08, 0.08), 3, 10)
	for side in [-1, 1]:
		hk.ellipsoid(Vector3(side * 0.11, 0.08, 0.11), Vector3(0.06, 0.055, 0.055), col.lightened(0.05), 4, 8)
		hk.glow = 0.6 if boss else 0.15
		hk.metal = 0.7
		hk.ellipsoid(Vector3(side * 0.12, 0.1, 0.14), Vector3(0.042, 0.042, 0.035), Color(0.95, 0.78, 0.2), 4, 8)
		hk.glow = 0.0
		hk.ellipsoid(Vector3(side * 0.125, 0.1, 0.172), Vector3(0.012, 0.03, 0.008), Color(0.03, 0.03, 0.03), 3, 6)
		hk.metal = 0.0
	m._part("head", body, Vector3(0, 0.27, 0.2), hk)
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := i < 2
		var lk := MeshKit.new(242 + i)
		if front:
			_chain(lk, [Vector3.ZERO, Vector3(side * 0.05, -0.08, 0.04), Vector3(side * 0.06, -0.14, 0.08)], [0.045, 0.035, 0.03], col.darkened(0.08), 8)
			for t in 3:
				_seg(lk, Vector3(side * 0.06, -0.14, 0.08), Vector3(side * 0.06 + (t - 1) * 0.04, -0.15, 0.14), 0.014, 0.01, col.darkened(0.1), 5)
		else:
			# Złożone, masywne tylne udo.
			lk.ellipsoid(Vector3(side * 0.03, -0.02, -0.02), Vector3(0.09, 0.08, 0.13), col.darkened(0.04), 5, 10)
			lk.ellipsoid(Vector3(side * 0.06, -0.1, 0.04), Vector3(0.05, 0.04, 0.1), col.darkened(0.1), 4, 8)
			lk.ellipsoid(Vector3(side * 0.07, -0.13, 0.14), Vector3(0.06, 0.012, 0.08), col.darkened(0.15), 3, 8)
		m._part(["leg_fl", "leg_fr", "leg_bl", "leg_br"][i], root, Vector3(side * 0.22, 0.15, 0.14 if front else -0.14), lk)
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
		var r := 0.36 - i * 0.022
		var r2 := r - 0.011
		# Gładki człon z wybrzuszeniem i ciemniejszym pierścieniem chitynowym u góry.
		k.loft([[Vector3(0, -0.02, 0), Vector2(r, r)], [Vector3(0, 0.12, 0), Vector2(r * 1.05, r * 1.05)], [Vector3(0, 0.26, 0), Vector2(r2, r2)]],
			col.lerp(col.darkened(0.15), float(i % 2)), 14, i == 0)
		k.metal = 0.3
		k.loft([[Vector3(0, 0.25, 0), Vector2(r2 * 1.02, r2 * 1.02)], [Vector3(0, 0.29, 0), Vector2(r2 * 1.06, r2 * 1.06)], [Vector3(0, 0.34, 0), Vector2(r2 * 0.98, r2 * 0.98)]],
			col.darkened(0.32), 14, false)
		k.metal = 0.0
		if i % 2 == 1:
			for j in 6:
				var a := j * TAU / 6.0 + i
				var p := Vector3(cos(a) * r2 * 1.02, 0.29, sin(a) * r2 * 1.02)
				_seg(k, p, p + Vector3(cos(a), 0.3, sin(a)).normalized() * 0.08, 0.025, 0.0, Color(0.5, 0.34, 0.22), 5)
		var seg := m._part("seg_%d" % i, parent, Vector3(0, 0.0 if i == 0 else 0.32, 0), k)
		parent = seg
	# Głowa: rozwarta paszcza z pierścieniami zębów i trzema żuwaczkami.
	var hk := MeshKit.new(260)
	hk.loft([[Vector3(0, 0, 0), Vector2(0.23, 0.23)], [Vector3(0, 0.12, 0), Vector2(0.29, 0.29)], [Vector3(0, 0.2, 0), Vector2(0.32, 0.32)]], col.darkened(0.15), 14, false)
	hk.loft([[Vector3(0, 0.2, 0), Vector2(0.29, 0.29)], [Vector3(0, 0.08, 0), Vector2(0.18, 0.18)], [Vector3(0, -0.02, 0), Vector2(0.05, 0.05)]], Color(0.35, 0.1, 0.08), 14, true)
	hk.metal = 0.5
	for ring in 2:
		for i in 12:
			var a := i * TAU / 12.0 + ring * 0.26
			var rr := 0.28 - ring * 0.07
			var p := Vector3(cos(a) * rr, 0.19 - ring * 0.05, sin(a) * rr)
			_seg(hk, p, p + Vector3(-cos(a) * 0.08, 0.06, -sin(a) * 0.08), 0.025, 0.0, Color(0.95, 0.9, 0.78), 5)
	hk.metal = 0.0
	for i in 3:
		var a := i * TAU / 3.0
		var base := Vector3(cos(a) * 0.3, 0.14, sin(a) * 0.3)
		_chain(hk, [base, base + Vector3(cos(a) * 0.14, 0.24, sin(a) * 0.14), base + Vector3(cos(a) * 0.02, 0.48, sin(a) * 0.02)], [0.07, 0.045, 0.0], col.darkened(0.3), 7)
	hk.glow = 0.8
	hk.ellipsoid(Vector3(0, 0.04, 0), Vector3(0.1, 0.03, 0.1), Color(1.0, 0.55, 0.2), 3, 8)
	hk.glow = 0.0
	var head := m._part("head", parent, Vector3(0, 0.32, 0), hk)
	head.rotation.x = 0.6
	# Kopiec piasku i rozrzucone grudy u podstawy.
	var sk := MeshKit.new(261)
	sk.ellipsoid(Vector3(0, -0.04, 0), Vector3(0.8, 0.2, 0.8), Color(0.86, 0.72, 0.48), 5, 16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 262
	for i in 7:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.7, 1.0)
		sk.ellipsoid(Vector3(cos(a) * d, 0.0, sin(a) * d), Vector3(0.12, 0.06, 0.1) * rng.randf_range(0.7, 1.3), Color(0.8, 0.66, 0.44), 3, 7)
	m._attach_mesh(root, sk)
	m.height = 2.3


# --- Smok Żarogniew / drake --------------------------------------------------------------

static func _dragon(m: CharacterModel, small: bool) -> void:
	m.type = "dragon"
	var col := Color(0.3, 0.09, 0.07) if not small else Color(0.45, 0.16, 0.1)
	var belly := Color(0.72, 0.46, 0.22)
	var horn := Color(0.86, 0.78, 0.6)
	var ember := Color(1.0, 0.45, 0.1)
	var root := m._part("root", m, Vector3.ZERO)
	var leg := 0.34
	var L := 1.1
	var W := 0.5
	var H := 0.42
	var bk := MeshKit.new(270)
	bk.metal = 0.2
	_body(bk, [[0.62, Vector2(0.11, 0.11), 0.07], [0.48, Vector2(0.2, 0.19), 0.03], [0.25, Vector2(0.26, 0.23), 0.0], [-0.05, Vector2(0.27, 0.22), 0.0],
		[-0.35, Vector2(0.21, 0.18), 0.02], [-0.58, Vector2(0.12, 0.11), 0.03]], col, 14)
	bk.metal = 0.1
	# Łuskowy brzuch z poprzecznymi płytami.
	for i in 7:
		var z := 0.4 - i * 0.14
		bk.ellipsoid(Vector3(0, -0.16 + absf(z) * 0.06, z), Vector3(0.17 - absf(z) * 0.1, 0.06, 0.08), belly.darkened((i % 2) * 0.08), 3, 10)
	# Kolce grzbietowe.
	bk.metal = 0.4
	for i in 7:
		var z := 0.5 - i * 0.16
		var base := Vector3(0, 0.2 - absf(z) * 0.08, z)
		_seg(bk, base, base + Vector3(0, 0.15 - absf(z) * 0.05, -0.07), 0.04, 0.0, Color(0.14, 0.06, 0.05), 6)
	bk.metal = 0.0
	# Żarzące się szczeliny między łuskami.
	bk.glow = 1.0
	for i in 6:
		var z := -0.35 + i * 0.14
		for side in [-1, 1]:
			bk.ellipsoid(Vector3(side * 0.2, 0.1, z), Vector3(0.012, 0.035, 0.05), ember, 3, 6)
	bk.glow = 0.0
	if small:
		# Siodło.
		bk.ellipsoid(Vector3(0, 0.21, 0.05), Vector3(0.24, 0.05, 0.2), Color(0.28, 0.16, 0.1), 4, 10)
		bk.metal = 0.8
		bk.ellipsoid(Vector3(0, 0.24, 0.2), Vector3(0.06, 0.05, 0.04), Color(0.75, 0.6, 0.3), 3, 8)
		bk.metal = 0.0
	var body := m._part("body", root, Vector3(0, leg + H / 2.0, 0), bk)
	# Szyja: łagodny łuk.
	var nk := MeshKit.new(271)
	nk.metal = 0.2
	nk.loft([[Vector3(0, -0.05, -0.02), Vector2(0.15, 0.16)], [Vector3(0, 0.12, 0.05), Vector2(0.13, 0.14)], [Vector3(0, 0.3, 0.12), Vector2(0.11, 0.12)], [Vector3(0, 0.48, 0.18), Vector2(0.09, 0.1)]], col, 12, false)
	for i in 4:
		var y := 0.02 + i * 0.13
		_seg(nk, Vector3(0, y, y * 0.37 - 0.1), Vector3(0, y + 0.06, y * 0.37 - 0.2), 0.025, 0.0, Color(0.14, 0.06, 0.05), 5)
	nk.metal = 0.0
	var neck := m._part("neck", body, Vector3(0, H * 0.2, L / 2.0 - 0.05), nk)
	neck.rotation.x = 0.45
	# Głowa: wydłużony pysk, żuchwa, rogi, żarzące się oczy i paszcza.
	var hk := MeshKit.new(272)
	hk.metal = 0.2
	_body(hk, [[-0.12, Vector2(0.1, 0.1), -0.08], [0.0, Vector2(0.14, 0.12), -0.06], [0.15, Vector2(0.11, 0.08), -0.08], [0.3, Vector2(0.075, 0.055), -0.1], [0.36, Vector2(0.04, 0.03), -0.11]], col, 12)
	_body(hk, [[-0.05, Vector2(0.1, 0.05), -0.17], [0.15, Vector2(0.08, 0.04), -0.19], [0.32, Vector2(0.05, 0.025), -0.18]], col.darkened(0.12), 10)
	hk.metal = 0.5
	for side in [-1, 1]:
		_chain(hk, [Vector3(side * 0.07, -0.0, -0.06), Vector3(side * 0.12, 0.06, -0.2), Vector3(side * 0.13, 0.04, -0.36)], [0.04, 0.028, 0.0], horn, 7)
		_seg(hk, Vector3(side * 0.1, -0.08, -0.02), Vector3(side * 0.18, -0.06, -0.12), 0.02, 0.0, horn.darkened(0.1), 5)
		for t in 3:
			_seg(hk, Vector3(side * 0.05, -0.14, 0.12 + t * 0.07), Vector3(side * 0.045, -0.18, 0.13 + t * 0.07), 0.012, 0.0, Color(0.95, 0.92, 0.8), 4)
	hk.metal = 0.0
	hk.glow = 1.0
	for side in [-1, 1]:
		hk.ellipsoid(Vector3(side * 0.085, -0.03, 0.08), Vector3(0.028, 0.018, 0.03), Color(1.0, 0.7, 0.15), 3, 6)
		hk.ellipsoid(Vector3(side * 0.03, -0.07, 0.35), Vector3(0.012, 0.01, 0.01), ember, 2, 5)
	hk.ellipsoid(Vector3(0, -0.15, 0.2), Vector3(0.06, 0.015, 0.12), ember, 3, 8)
	hk.glow = 0.0
	var head := m._part("head", neck, Vector3(0, 0.5, 0.2), hk)
	head.rotation.x = -0.4
	# Skrzydła: kości z palcami i błona.
	for side in [-1, 1]:
		var wk := MeshKit.new(273 + side)
		var wc := Color(0.42, 0.13, 0.1) if not small else Color(0.52, 0.2, 0.12)
		var sh := Vector3.ZERO
		var el := Vector3(side * 0.45, 0.12, -0.05)
		var wr := Vector3(side * 0.9, 0.08, -0.12)
		var tips := [Vector3(side * 1.05, -0.05, -0.55), Vector3(side * 0.75, -0.04, -0.7), Vector3(side * 0.42, -0.03, -0.62)]
		_chain(wk, [sh, el, wr], [0.05, 0.04, 0.03], col.darkened(0.15), 7)
		_seg(wk, wr, wr + Vector3(side * 0.12, 0.08, 0.05), 0.025, 0.0, horn, 5)
		for t in tips:
			_seg(wk, wr, t, 0.022, 0.008, col.darkened(0.2), 5)
		wk.blade(sh, wr, tips[0], wc)
		wk.blade(wr, tips[0], tips[1], wc.darkened(0.08))
		wk.blade(sh, tips[1], tips[2], wc.darkened(0.12))
		wk.blade(sh, wr, tips[1], wc.darkened(0.05))
		wk.blade(sh, tips[2], Vector3(0, -0.02, -0.5), wc.darkened(0.18))
		m._part("wing_l" if side < 0 else "wing_r", body, Vector3(side * W * 0.35, H * 0.4, 0.12), wk)
	# Ogon: stożkowa bryła z kolcami i ostrzem na końcu.
	var tk := MeshKit.new(275)
	tk.metal = 0.2
	_body(tk, [[0.05, Vector2(0.12, 0.11), 0.0], [-0.3, Vector2(0.09, 0.085), -0.03], [-0.6, Vector2(0.06, 0.055), -0.06], [-0.9, Vector2(0.035, 0.03), -0.08], [-1.1, Vector2(0.015, 0.015), -0.08]], col, 10)
	tk.metal = 0.4
	for i in 5:
		var z := -0.1 - i * 0.2
		_seg(tk, Vector3(0, 0.1 - i * 0.022, z), Vector3(0, 0.18 - i * 0.03, z - 0.06), 0.03 - i * 0.004, 0.0, Color(0.14, 0.06, 0.05), 5)
	tk.blade(Vector3(0, -0.08, -1.0), Vector3(0.14, -0.08, -1.08), Vector3(0, -0.08, -1.25), Color(0.18, 0.07, 0.05))
	tk.blade(Vector3(0, -0.08, -1.0), Vector3(-0.14, -0.08, -1.08), Vector3(0, -0.08, -1.25), Color(0.18, 0.07, 0.05))
	tk.metal = 0.0
	var tail := m._part("tail", body, Vector3(0, 0, -L / 2.0), tk)
	tail.rotation.x = 0.15
	# Nogi: masywne udo, goleń, łapa z pazurami.
	var i := 0
	for fz in [1, -1]:
		for side in [-1, 1]:
			var lk := MeshKit.new(280 + i)
			lk.ellipsoid(Vector3(side * 0.02, -0.02, 0), Vector3(0.1, 0.14, 0.12), col.darkened(0.05), 5, 10)
			var knee := Vector3(side * 0.03, -leg * 0.5, 0.05 if fz > 0 else -0.06)
			var ankle := Vector3(side * 0.02, -leg + 0.04, 0.0)
			_chain(lk, [Vector3(0, -0.06, 0), knee, ankle], [0.08, 0.06, 0.05], col.darkened(0.1), 8)
			lk.ellipsoid(ankle + Vector3(0, -0.03, 0.05), Vector3(0.07, 0.035, 0.09), col.darkened(0.2), 4, 8)
			lk.metal = 0.5
			for c in 3:
				_seg(lk, ankle + Vector3((c - 1) * 0.04, -0.03, 0.1), ankle + Vector3((c - 1) * 0.05, -0.06, 0.17), 0.015, 0.0, horn, 4)
			lk.metal = 0.0
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
	# Rozżarzony rdzeń i języki płomieni.
	k.ellipsoid(Vector3(0, 0.55, 0), Vector3(0.22, 0.28, 0.22), Color(1.0, 0.72, 0.28), 6, 12)
	_seg(k, Vector3(0, 0.7, 0), Vector3(0, 1.15, -0.04), 0.17, 0.0, Color(1.0, 0.55, 0.12), 10)
	for i in 6:
		var a := i * TAU / 6.0
		var b := Vector3(cos(a) * 0.12, 0.72, sin(a) * 0.12)
		_seg(k, b, b + Vector3(cos(a) * 0.1, 0.25 + (i % 2) * 0.12, sin(a) * 0.1), 0.07, 0.0, Color(1.0, 0.42 + (i % 3) * 0.08, 0.08), 7)
	_seg(k, Vector3(0, 0.35, 0), Vector3(0, 0.05, 0), 0.15, 0.0, Color(0.95, 0.32, 0.05), 10)
	k.glow = 0.0
	# Pływające płyty zastygłej lawy z żarem w szczelinach.
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	for i in 7:
		var a := i * TAU / 7.0 + rng.randf() * 0.3
		var y := 0.4 + rng.randf() * 0.35
		k.ellipsoid(Vector3(cos(a) * 0.22, y, sin(a) * 0.22), Vector3(0.07, 0.06, 0.07) * rng.randf_range(0.8, 1.3), Color(0.16, 0.08, 0.06), 3, 6)
	# Oczy i paszcza – ciemne dziury w płomieniu.
	k.glow = 0.2
	for side in [-1, 1]:
		k.ellipsoid(Vector3(side * 0.08, 0.64, 0.19), Vector3(0.04, 0.025, 0.02), Color(0.2, 0.05, 0.02), 3, 6)
	k.ellipsoid(Vector3(0, 0.52, 0.2), Vector3(0.06, 0.018, 0.02), Color(0.25, 0.06, 0.02), 3, 6)
	k.glow = 0.0
	var body := m._part("body", root, Vector3.ZERO, k)
	for side in [-1, 1]:
		var hk := MeshKit.new(291 + side)
		hk.glow = 1.0
		hk.ellipsoid(Vector3.ZERO, Vector3(0.1, 0.1, 0.1), Color(1.0, 0.6, 0.18), 4, 8)
		_seg(hk, Vector3(0, 0.05, 0), Vector3(side * 0.03, 0.22, 0), 0.06, 0.0, Color(1.0, 0.45, 0.1), 7)
		hk.glow = 0.0
		hk.ellipsoid(Vector3(side * 0.05, -0.02, 0.03), Vector3(0.05, 0.04, 0.05), Color(0.16, 0.08, 0.06), 3, 6)
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
	m.height = 1.2


# --- Drzewiec i golem (części humanoida – animacja chodu jak u postaci) ---------------------

## Szkielet humanoida z gotowych kończyn: legs/arms = [lewa, prawa] (MeshKit każda).
static func _humanoid_frame(m: CharacterModel, head_kit: MeshKit, torso_kit: MeshKit, legs: Array, arms: Array, shoulder: float, scale_y := 1.0) -> void:
	m.type = "humanoid"
	var root := m._part("root", m, Vector3.ZERO)
	for i in 2:
		var side := -1 if i == 0 else 1
		m._part("leg_l" if side < 0 else "leg_r", root, Vector3(side * 0.13, 0.44, 0), legs[i])
	var torso := m._part("torso", root, Vector3(0, 0.44, 0), torso_kit)
	m._part("head", torso, Vector3(0, 0.5 * scale_y, 0), head_kit)
	for i in 2:
		var side := -1 if i == 0 else 1
		var arm := m._part("arm_l" if side < 0 else "arm_r", torso, Vector3(side * shoulder, 0.44 * scale_y, 0), arms[i])
		m._part("hand_l" if side < 0 else "hand_r", arm, Vector3(0, -0.48, 0.02))
	m.weapon_kind = "melee"
	m.height = 1.4


static func _treant(m: CharacterModel) -> void:
	var bark := Color(0.34, 0.24, 0.15)
	var dark := bark.darkened(0.3)
	var moss := Color(0.3, 0.42, 0.16)
	var leaf := Color(0.24, 0.44, 0.17)
	var rng := RandomNumberGenerator.new()
	rng.seed = 320
	# Pień-tułów: skręcona kora z mchem, dziuple oczu i ust.
	var tk := MeshKit.new(320)
	tk.loft([[Vector3(0, -0.04, 0), Vector2(0.2, 0.17)], [Vector3(0.01, 0.18, 0.01), Vector2(0.22, 0.18)], [Vector3(-0.01, 0.4, 0), Vector2(0.25, 0.2)], [Vector3(0, 0.56, 0), Vector2(0.21, 0.17)]], bark, 12, true)
	for i in 7:
		var a := i * TAU / 7.0 + 0.3
		_seg(tk, Vector3(cos(a) * 0.2, -0.02, sin(a) * 0.16), Vector3(cos(a) * 0.23, 0.55, sin(a) * 0.19), 0.035, 0.025, bark.darkened(0.12 + (i % 2) * 0.08), 5)
	tk.ellipsoid(Vector3(-0.12, 0.47, 0.1), Vector3(0.12, 0.05, 0.1), moss, 4, 8)
	tk.ellipsoid(Vector3(0.15, 0.1, -0.08), Vector3(0.08, 0.06, 0.09), moss.darkened(0.1), 3, 7)
	tk.ellipsoid(Vector3(0, 0.26, 0.17), Vector3(0.08, 0.035, 0.03), Color(0.08, 0.05, 0.03), 3, 8)
	tk.glow = 0.9
	for side in [-1, 1]:
		tk.ellipsoid(Vector3(side * 0.075, 0.4, 0.18), Vector3(0.035, 0.028, 0.02), Color(0.75, 1.0, 0.3), 3, 6)
	tk.glow = 0.0
	# Korona: gęste kępy liści i gałęzie.
	var hk := MeshKit.new(321)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		_seg(hk, Vector3(0, -0.05, 0), Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.25), 0.06, 0.02, bark.darkened(0.1), 6)
	hk.ellipsoid(Vector3(0, 0.28, 0), Vector3(0.42, 0.28, 0.4), leaf, 6, 12)
	for i in 7:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 0.3, 0.2 + rng.randf() * 0.25, sin(a) * 0.28)
		hk.ellipsoid(p, Vector3(0.2, 0.15, 0.2) * rng.randf_range(0.8, 1.2), leaf.lerp(Color(0.4, 0.55, 0.2), rng.randf() * 0.5), 4, 9)
	hk.glow = 0.6
	for i in 5:
		var a := rng.randf() * TAU
		hk.ellipsoid(Vector3(cos(a) * 0.38, 0.3 + rng.randf() * 0.15, sin(a) * 0.34), Vector3(0.025, 0.025, 0.025), Color(1.0, 0.8, 0.4), 2, 5)
	hk.glow = 0.0
	var legs: Array = []
	var arms: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var lk := MeshKit.new(322 + i)
		_seg(lk, Vector3(0, 0.02, 0), Vector3(side * 0.02, -0.36, 0), 0.13, 0.15, bark.darkened(0.05), 9)
		# Korzenie zamiast stóp.
		for r in 4:
			var a := r * TAU / 4.0 + 0.5 * side
			_chain(lk, [Vector3(side * 0.02, -0.34, 0), Vector3(cos(a) * 0.14, -0.42, sin(a) * 0.14 + 0.03), Vector3(cos(a) * 0.24, -0.45, sin(a) * 0.22 + 0.05)], [0.05, 0.035, 0.0], dark, 5)
		legs.append(lk)
		var ak := MeshKit.new(324 + i)
		_chain(ak, [Vector3.ZERO, Vector3(side * 0.04, -0.24, 0.02), Vector3(side * 0.02, -0.46, 0.05)], [0.1, 0.08, 0.06], bark, 8, dark)
		# Palce-gałązki i listki.
		for f in 4:
			var d := Vector3(side * (f - 1.5) * 0.04, -0.16, 0.04 + (f % 2) * 0.03)
			_seg(ak, Vector3(side * 0.02, -0.48, 0.05), Vector3(side * 0.02, -0.48, 0.05) + d, 0.025, 0.0, dark, 5)
		ak.ellipsoid(Vector3(side * 0.08, -0.12, 0.0), Vector3(0.08, 0.06, 0.08), leaf, 3, 8)
		arms.append(ak)
	_humanoid_frame(m, hk, tk, legs, arms, 0.3)


static func _golem(m: CharacterModel) -> void:
	var stone := Color(0.5, 0.46, 0.42)
	var rune := Color(1.0, 0.55, 0.15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 330
	# Tułów: masywne głazy spięte żarzącymi się runami.
	var tk := MeshKit.new(330)
	tk.jitter = 0.05
	tk.ellipsoid(Vector3(0, 0.3, 0), Vector3(0.32, 0.3, 0.22), stone, 5, 8)
	tk.ellipsoid(Vector3(0, 0.02, 0), Vector3(0.22, 0.12, 0.17), stone.darkened(0.08), 4, 7)
	for side in [-1, 1]:
		tk.ellipsoid(Vector3(side * 0.3, 0.46, 0), Vector3(0.14, 0.12, 0.14), stone.lightened(0.05), 4, 7)
	for i in 5:
		var a := rng.randf_range(-1.2, 1.2)
		tk.ellipsoid(Vector3(sin(a) * 0.28, rng.randf_range(0.15, 0.5), cos(a) * 0.16), Vector3(0.07, 0.06, 0.05), stone.darkened(rng.randf_range(0.0, 0.2)), 3, 5)
	tk.glow = 1.0
	tk.ellipsoid(Vector3(0, 0.36, 0.2), Vector3(0.07, 0.07, 0.025), rune, 3, 8)
	_seg(tk, Vector3(0, 0.36, 0.205), Vector3(0.1, 0.18, 0.19), 0.012, 0.008, rune, 4)
	_seg(tk, Vector3(0, 0.36, 0.205), Vector3(-0.12, 0.5, 0.17), 0.012, 0.008, rune, 4)
	_seg(tk, Vector3(0, 0.36, 0.205), Vector3(-0.06, 0.12, 0.19), 0.01, 0.006, rune, 4)
	tk.glow = 0.0
	var hk := MeshKit.new(331)
	hk.jitter = 0.05
	hk.ellipsoid(Vector3(0, 0.08, 0), Vector3(0.14, 0.12, 0.13), stone.darkened(0.08), 4, 7)
	hk.ellipsoid(Vector3(0, 0.13, -0.02), Vector3(0.15, 0.05, 0.14), stone.darkened(0.15), 3, 7)
	hk.glow = 1.0
	hk.ellipsoid(Vector3(0, 0.1, 0.12), Vector3(0.08, 0.018, 0.02), rune, 3, 8)
	hk.glow = 0.0
	var legs: Array = []
	var arms: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var lk := MeshKit.new(332 + i)
		lk.jitter = 0.05
		lk.ellipsoid(Vector3(0, -0.1, 0), Vector3(0.13, 0.14, 0.13), stone.darkened(0.05), 4, 7)
		lk.ellipsoid(Vector3(0, -0.3, 0.0), Vector3(0.11, 0.12, 0.11), stone.darkened(0.12), 4, 7)
		lk.ellipsoid(Vector3(0, -0.42, 0.04), Vector3(0.14, 0.05, 0.16), stone.darkened(0.2), 3, 7)
		legs.append(lk)
		var ak := MeshKit.new(334 + i)
		ak.jitter = 0.05
		ak.ellipsoid(Vector3(side * 0.03, -0.1, 0), Vector3(0.11, 0.14, 0.11), stone, 4, 7)
		ak.ellipsoid(Vector3(side * 0.03, -0.3, 0.01), Vector3(0.1, 0.12, 0.1), stone.darkened(0.08), 4, 7)
		ak.ellipsoid(Vector3(side * 0.03, -0.47, 0.03), Vector3(0.15, 0.12, 0.14), stone.lightened(0.04), 4, 7)
		ak.glow = 1.0
		ak.ellipsoid(Vector3(side * 0.03, -0.2, 0.1), Vector3(0.02, 0.05, 0.015), rune, 2, 5)
		ak.glow = 0.0
		arms.append(ak)
	_humanoid_frame(m, hk, tk, legs, arms, 0.38)


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
