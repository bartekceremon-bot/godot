class_name CharacterModel
extends Node3D
## Model istoty low-poly złożony z części (biodra, tułów, głowa, ręce, nogi…) i animowany w kodzie:
## chód, oddech, atak, zbieranie, śmierć. Wygląd zależy od założonego ekwipunku (tier = kolor/materiał).
##
## Rodzaje: humanoid (gracze, NPC, szkielet), beast (szczur, dzik, wilk, ogar), node (złoża surowców).

const TIER_METAL := [Color(0.62, 0.62, 0.64), Color(0.62, 0.62, 0.64), Color(0.74, 0.52, 0.3), Color(0.56, 0.67, 0.82), Color(0.3, 0.26, 0.38),
	Color(0.38, 0.7, 0.62), Color(0.55, 0.28, 0.32), Color(0.6, 0.48, 0.84), Color(0.95, 0.6, 0.25)]
const TIER_LEATHER := [Color(0.56, 0.37, 0.2), Color(0.56, 0.37, 0.2), Color(0.42, 0.3, 0.17), Color(0.3, 0.24, 0.22), Color(0.16, 0.13, 0.14),
	Color(0.36, 0.22, 0.12), Color(0.52, 0.54, 0.6), Color(0.3, 0.42, 0.24), Color(0.48, 0.12, 0.1)]
const TIER_CLOTH := [Color(0.84, 0.78, 0.62), Color(0.84, 0.78, 0.62), Color(0.28, 0.52, 0.33), Color(0.24, 0.36, 0.68), Color(0.44, 0.18, 0.52),
	Color(0.45, 0.62, 0.9), Color(0.85, 0.6, 0.2), Color(0.95, 0.85, 0.4), Color(0.7, 0.95, 0.92)]
const TIER_TRIM := [Color(0.5, 0.4, 0.3), Color(0.5, 0.4, 0.3), Color(0.35, 0.62, 0.3), Color(0.35, 0.52, 0.95), Color(0.95, 0.72, 0.25),
	Color(0.2, 0.8, 0.7), Color(0.85, 0.15, 0.2), Color(0.7, 0.4, 1.0), Color(1.0, 0.5, 0.1)]
const SKINS := [Color(0.96, 0.8, 0.66), Color(0.9, 0.7, 0.54), Color(0.78, 0.56, 0.4), Color(0.55, 0.38, 0.26)]
const HAIRS := [Color(0.3, 0.2, 0.12), Color(0.12, 0.1, 0.09), Color(0.82, 0.62, 0.3), Color(0.6, 0.25, 0.12), Color(0.85, 0.85, 0.82)]
const SHIRTS := [Color(0.62, 0.22, 0.18), Color(0.25, 0.4, 0.6), Color(0.3, 0.5, 0.3), Color(0.55, 0.45, 0.25), Color(0.45, 0.3, 0.55), Color(0.7, 0.55, 0.3), Color(0.3, 0.3, 0.32), Color(0.2, 0.45, 0.45)]

var type := "humanoid"
var material: ShaderMaterial
## Części: nazwa -> Node3D (pivot)
var parts: Dictionary = {}
var weapon_kind := ""
var height := 1.1

# Stan animacji.
var moving := false
var move_speed := 1.0
var _phase := 0.0
var _attack_t := -1.0
var _attack_kind := "melee"
var _gather_t := -1.0
var gathering := false
var _idle_t := 0.0
var _dead := false
## Lewitacja (zjawy) i wysokość siodła wierzchowca.
var float_mode := false
var riding_height := 0.0
## Jeździec na wierzchowcu: nogi rozkraczone, bez kroków.
var riding := false


func _init(mat: ShaderMaterial = null) -> void:
	material = mat


# ============================================================================
# Pomocnicze
# ============================================================================

func _part(name: String, parent: Node3D, pos: Vector3, kit: MeshKit = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	parts[name] = n
	if kit != null and not kit.is_empty():
		_attach_mesh(n, kit)
	return n


func _attach_mesh(n: Node3D, kit: MeshKit) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = material
	n.add_child(mi)
	return mi


static func split_item(id: String) -> Array:
	var i := id.rfind("_t")
	if i < 0:
		return [id, 1]
	return [id.substr(0, i), int(id.substr(i + 2))]


# ============================================================================
# Humanoid
# ============================================================================

## app: {skin, hair, hair_style, shirt, pants, boots, eq: [head, body, legs, feet, weapon, shield],
##       robe?, apron?, hat?, beard?, backpack?, skeleton?, held?}
func build_humanoid(app: Dictionary) -> void:
	type = "humanoid"
	var skel: bool = app.get("skeleton", false)
	var skin: Color = app.get("skin", SKINS[0])
	var eq: Array = app.get("eq", ["", "", "", "", "", ""])
	var head_it := split_item(str(eq[0])) if str(eq[0]) != "" else ["", 0]
	var body_it := split_item(str(eq[1])) if str(eq[1]) != "" else ["", 0]
	var legs_it := split_item(str(eq[2])) if str(eq[2]) != "" else ["", 0]
	var feet_it := split_item(str(eq[3])) if str(eq[3]) != "" else ["", 0]
	var shirt: Color = app.get("shirt", SHIRTS[0])
	var pants: Color = app.get("pants", Color(0.35, 0.27, 0.2))
	var boots: Color = app.get("boots", Color(0.25, 0.17, 0.12))
	var sleeve := shirt
	var metal_body := false
	var metal_arms := false
	var torso_col := shirt
	var body_base: String = body_it[0]
	var bt: int = body_it[1]
	if body_base.begins_with("plate"):
		torso_col = TIER_METAL[bt]
		sleeve = TIER_METAL[bt].darkened(0.1)
		metal_body = true
		metal_arms = true
	elif body_base.begins_with("leather"):
		torso_col = TIER_LEATHER[bt]
		sleeve = TIER_LEATHER[bt].darkened(0.08)
	elif body_base.begins_with("cloth"):
		torso_col = TIER_CLOTH[bt]
		sleeve = TIER_CLOTH[bt]
	var legs_base: String = legs_it[0]
	var metal_legs := false
	if legs_base.begins_with("plate"):
		pants = TIER_METAL[legs_it[1]]
		metal_legs = true
	elif legs_base.begins_with("leather"):
		pants = TIER_LEATHER[legs_it[1]].darkened(0.1)
	elif legs_base.begins_with("cloth"):
		pants = TIER_CLOTH[legs_it[1]].darkened(0.1)
	var feet_base: String = feet_it[0]
	var metal_feet := false
	var sandals := false
	if feet_base.begins_with("plate"):
		boots = TIER_METAL[feet_it[1]].darkened(0.05)
		metal_feet = true
	elif feet_base.begins_with("leather"):
		boots = TIER_LEATHER[feet_it[1]].darkened(0.2)
	elif feet_base.begins_with("cloth"):
		sandals = true
	if skel:
		torso_col = skin
		sleeve = skin
		pants = skin
		boots = skin

	var root := _part("root", self, Vector3.ZERO)
	var hip_y := 0.42
	var limb_w := 0.07 if skel else 0.13

	# --- Nogi ---
	for side in [-1, 1]:
		var lk := MeshKit.new(11 + side)
		lk.jitter = 0.02
		lk.metal = 0.8 if metal_legs else 0.0
		lk.box(Vector3(0, -0.34, 0), Vector3(limb_w, 0.34, limb_w + 0.01), pants)
		if metal_legs:
			lk.box(Vector3(0, -0.2, 0.05), Vector3(0.1, 0.08, 0.05), pants.lightened(0.15))
		lk.metal = 0.8 if metal_feet else 0.0
		if sandals:
			lk.box(Vector3(0, -0.42, 0.02), Vector3(0.12, 0.08, 0.18), skin)
			lk.box(Vector3(0, -0.425, 0.02), Vector3(0.13, 0.025, 0.19), Color(0.5, 0.35, 0.2))
			lk.box(Vector3(0, -0.39, 0.06), Vector3(0.13, 0.02, 0.03), Color(0.5, 0.35, 0.2))
		else:
			lk.box(Vector3(0, -0.42, 0.025), Vector3(0.14 if not skel else 0.09, 0.12, 0.2), boots, Vector2(1.0, 0.9))
		_part("leg_l" if side < 0 else "leg_r", root, Vector3(side * 0.085, hip_y, 0), lk)

	# --- Tułów ---
	var tk := MeshKit.new(21)
	tk.jitter = 0.02
	if skel:
		tk.box(Vector3(0, 0, 0), Vector3(0.06, 0.36, 0.06), skin)
		for i in 3:
			tk.box(Vector3(0, 0.12 + i * 0.075, 0.02), Vector3(0.28 - i * 0.02, 0.035, 0.16), skin)
		tk.box(Vector3(0, -0.02, 0), Vector3(0.24, 0.07, 0.12), skin)
	else:
		tk.metal = 0.85 if metal_body else 0.0
		tk.box(Vector3(0, 0, 0), Vector3(0.32, 0.37, 0.19), torso_col, Vector2(1.12, 1.05))
		if metal_body:
			tk.box(Vector3(0, 0.12, 0.08), Vector3(0.06, 0.2, 0.05), torso_col.lightened(0.15))
			for side in [-1, 1]:
				tk.blob(Vector3(side * 0.2, 0.34, 0), Vector3(0.1, 0.07, 0.12), torso_col.lightened(0.08), 2, 6, 0.0)
			if bt >= 3:
				tk.metal = 1.0
				tk.box(Vector3(0, 0.33, 0.0), Vector3(0.3, 0.04, 0.21), TIER_TRIM[bt])
		elif body_base.begins_with("leather"):
			tk.box(Vector3(0, 0.3, 0), Vector3(0.3, 0.07, 0.21), torso_col.lightened(0.12))
			if bt >= 2:
				tk.box(Vector3(0.08, 0.05, 0.1), Vector3(0.03, 0.3, 0.02), TIER_TRIM[bt])
		elif body_base.begins_with("cloth") or app.get("robe", false):
			var rc := torso_col if body_base.begins_with("cloth") else shirt
			tk.box(Vector3(0, -0.34, 0), Vector3(0.38, 0.36, 0.26), rc, Vector2(0.86, 0.75))
			if bt >= 2 or app.get("robe_trim", null) != null:
				var trim: Color = app.get("robe_trim", TIER_TRIM[bt])
				tk.box(Vector3(0, -0.345, 0), Vector3(0.39, 0.05, 0.27), trim)
				tk.box(Vector3(0, 0.0, 0.1), Vector3(0.05, 0.36, 0.01), trim)
		# Pas.
		tk.metal = 0.0
		tk.box(Vector3(0, 0.0, 0), Vector3(0.34, 0.06, 0.205), Color(0.28, 0.18, 0.1))
		tk.metal = 1.0
		tk.box(Vector3(0, 0.005, 0.1), Vector3(0.06, 0.05, 0.02), Color(0.85, 0.7, 0.3))
		tk.metal = 0.0
		if app.get("apron", null) != null:
			var ac: Color = app.apron
			tk.box(Vector3(0, -0.22, 0.1), Vector3(0.28, 0.5, 0.02), ac)
		if app.get("backpack", false):
			tk.box(Vector3(0, 0.08, -0.17), Vector3(0.28, 0.3, 0.14), Color(0.45, 0.32, 0.18))
			tk.box(Vector3(0, 0.38, -0.17), Vector3(0.3, 0.06, 0.16), Color(0.35, 0.25, 0.14))
	var torso := _part("torso", root, Vector3(0, hip_y, 0), tk)

	# --- Głowa ---
	var hk := MeshKit.new(31)
	hk.jitter = 0.015
	var hair: Color = app.get("hair", HAIRS[0])
	var style: int = app.get("hair_style", 0)
	var head_base: String = head_it[0]
	var ht: int = head_it[1]
	if skel:
		hk.box(Vector3(0, 0, 0), Vector3(0.26, 0.26, 0.26), skin, Vector2(1.05, 1.05))
		hk.box(Vector3(0, -0.05, 0.03), Vector3(0.18, 0.08, 0.2), skin.darkened(0.1))
		hk.glow = 1.0
		for side in [-1, 1]:
			hk.box(Vector3(side * 0.06, 0.1, 0.125), Vector3(0.06, 0.06, 0.02), Color(1.0, 0.25, 0.1))
		hk.glow = 0.0
	else:
		hk.box(Vector3(0, 0, 0), Vector3(0.29, 0.29, 0.27), skin, Vector2(1.0, 0.96))
		# Oczy, brwi, nos.
		for side in [-1, 1]:
			hk.box(Vector3(side * 0.065, 0.12, 0.135), Vector3(0.05, 0.055, 0.012), Color(0.98, 0.98, 0.95))
			hk.box(Vector3(side * 0.06, 0.125, 0.14), Vector3(0.028, 0.04, 0.012), Color(0.12, 0.1, 0.12))
			hk.box(Vector3(side * 0.065, 0.185, 0.135), Vector3(0.06, 0.018, 0.015), hair.darkened(0.2))
		hk.box(Vector3(0, 0.07, 0.135), Vector3(0.045, 0.06, 0.035), skin.darkened(0.08))
		hk.box(Vector3(0, 0.035, 0.137), Vector3(0.07, 0.012, 0.01), Color(0.55, 0.3, 0.28))
		if head_base == "":
			if app.get("hat", "") == "top":
				hk.cyl(Vector3(0, 0.27, 0), 0.2, 0.2, 0.03, 8, Color(0.12, 0.1, 0.12))
				hk.cyl(Vector3(0, 0.29, 0), 0.13, 0.13, 0.2, 8, Color(0.12, 0.1, 0.12))
				hk.cyl(Vector3(0, 0.3, 0), 0.135, 0.135, 0.04, 8, Color(0.7, 0.15, 0.12), false)
			elif app.get("hat", "") == "scarf":
				hk.box(Vector3(0, 0.2, -0.01), Vector3(0.32, 0.12, 0.31), app.get("hat_col", Color(0.8, 0.3, 0.2)))
				hk.box(Vector3(0, 0.0, -0.14), Vector3(0.3, 0.22, 0.04), app.get("hat_col", Color(0.8, 0.3, 0.2)))
			elif app.get("hat", "") == "hood":
				var hc: Color = app.get("hat_col", Color(0.9, 0.88, 0.8))
				hk.box(Vector3(0, 0.02, -0.02), Vector3(0.34, 0.32, 0.31), hc, Vector2(0.9, 0.9))
				hk.cone(Vector3(0, 0.3, -0.05), 0.12, 0.12, 5, hc)
				_cut_face(hk, skin, hair)
			elif app.get("hat", "") == "cap":
				hk.box(Vector3(0, 0.24, 0), Vector3(0.31, 0.08, 0.29), app.get("hat_col", Color(0.4, 0.3, 0.2)))
				hk.box(Vector3(0, 0.24, 0.16), Vector3(0.26, 0.02, 0.1), app.get("hat_col", Color(0.4, 0.3, 0.2)).darkened(0.2))
			if style != 2 and app.get("hat", "") != "hood":
				hk.box(Vector3(0, 0.25, -0.01), Vector3(0.31, 0.08, 0.29), hair)
				hk.box(Vector3(0, 0.05, -0.12), Vector3(0.31, 0.22, 0.06), hair)
				for side in [-1, 1]:
					hk.box(Vector3(side * 0.145, 0.12, -0.03), Vector3(0.03, 0.15, 0.2), hair)
				if style == 1:
					hk.box(Vector3(0, -0.15, -0.12), Vector3(0.3, 0.2, 0.06), hair)
				elif style == 3:
					hk.box(Vector3(0, -0.12, -0.17), Vector3(0.08, 0.2, 0.06), hair)
				elif style == 4:
					hk.box(Vector3(0, 0.22, 0.02), Vector3(0.12, 0.1, 0.12), hair)
		if app.get("beard", false):
			hk.box(Vector3(0, -0.07, 0.1), Vector3(0.26, 0.12, 0.08), hair, Vector2(0.8, 1.0))
			hk.box(Vector3(0, 0.035, 0.14), Vector3(0.12, 0.025, 0.02), hair)
		# Hełmy / kaptury.
		if head_base.begins_with("plate"):
			hk.metal = 0.85
			var mc: Color = TIER_METAL[ht]
			hk.box(Vector3(0, 0.02, 0), Vector3(0.33, 0.3, 0.31), mc, Vector2(0.92, 0.92))
			hk.box(Vector3(0, 0.1, 0.152), Vector3(0.22, 0.03, 0.01), Color(0.08, 0.08, 0.1))
			hk.box(Vector3(0, -0.02, 0.152), Vector3(0.03, 0.1, 0.012), Color(0.08, 0.08, 0.1))
			hk.box(Vector3(0, 0.31, 0), Vector3(0.05, 0.05, 0.3), mc.lightened(0.1))
			hk.metal = 0.0
			if ht >= 3:
				hk.box(Vector3(0, 0.34, -0.05), Vector3(0.04, 0.12, 0.2), TIER_TRIM[ht])
		elif head_base.begins_with("leather"):
			var lc: Color = TIER_LEATHER[ht]
			hk.box(Vector3(0, 0.02, -0.02), Vector3(0.33, 0.33, 0.3), lc, Vector2(0.9, 0.9))
			_cut_face(hk, skin, hair)
		elif head_base.begins_with("cloth"):
			var cc: Color = TIER_CLOTH[ht]
			hk.box(Vector3(0, 0.02, -0.02), Vector3(0.33, 0.33, 0.3), cc, Vector2(0.88, 0.88))
			hk.cone(Vector3(0, 0.32, -0.06), 0.13, 0.2, 5, cc)
			_cut_face(hk, skin, hair)
	var head := _part("head", torso, Vector3(0, 0.37, 0), hk)
	_head_extras(head, app, skin)
	_body_extras(torso, root, app)
	if app.get("float", false):
		# Lewitujące zjawy: bez nóg, długa szata.
		parts["leg_l"].visible = false
		parts["leg_r"].visible = false

	# --- Ręce ---
	for side in [-1, 1]:
		var ak := MeshKit.new(41 + side)
		ak.jitter = 0.02
		ak.metal = 0.85 if metal_arms else 0.0
		ak.box(Vector3(0, -0.29, 0), Vector3(0.1 if not skel else 0.06, 0.31, 0.11 if not skel else 0.06), sleeve)
		if metal_arms:
			ak.box(Vector3(0, -0.05, 0), Vector3(0.14, 0.09, 0.14), sleeve.lightened(0.1))
		ak.metal = 0.85 if metal_arms else 0.0
		ak.box(Vector3(0, -0.37, 0), Vector3(0.09, 0.09, 0.1), sleeve if metal_arms else skin)
		var arm := _part("arm_l" if side < 0 else "arm_r", torso, Vector3(side * 0.215, 0.33, 0), ak)
		_part("hand_l" if side < 0 else "hand_r", arm, Vector3(0, -0.33, 0.02))

	# --- Broń i tarcza ---
	var wid := str(eq[4])
	var held: String = app.get("held", "")
	if wid != "":
		_build_weapon(wid)
	elif held != "":
		_build_weapon(held)
	var sid := str(eq[5])
	if sid != "":
		_build_shield(sid)
	height = 1.12


## Otwór na twarz w kapturze (twarz rysowana ponownie z przodu kaptura).
func _cut_face(hk: MeshKit, skin: Color, hair: Color) -> void:
	hk.box(Vector3(0, -0.02, 0.143), Vector3(0.22, 0.22, 0.01), skin)
	for side in [-1, 1]:
		hk.box(Vector3(side * 0.06, 0.1, 0.15), Vector3(0.028, 0.04, 0.012), Color(0.12, 0.1, 0.12))
	hk.box(Vector3(0, 0.05, 0.155), Vector3(0.04, 0.05, 0.02), skin.darkened(0.08))
	if hair:
		pass


func _build_weapon(id: String) -> void:
	var it := split_item(id)
	var base: String = it[0]
	var t: int = clampi(it[1], 1, 8)
	var k := MeshKit.new(51)
	if t >= 8:
		k.glow = 0.25
	var metal: Color = TIER_METAL[t].lightened(0.1)
	var grip := Color(0.3, 0.2, 0.12)
	var trim: Color = TIER_TRIM[t]
	var parent: Node3D = parts["hand_r"]
	weapon_kind = "melee"
	match base:
		"sword", "sword_skeleton", "rusty_sword":
			k.box(Vector3(0, -0.03, 0), Vector3(0.035, 0.1, 0.035), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.06, 0), Vector3(0.18, 0.035, 0.05), trim if t >= 2 else metal.darkened(0.2))
			k.box(Vector3(0, 0.095, 0), Vector3(0.055, 0.46, 0.018), metal if base == "sword" else Color(0.5, 0.35, 0.25), Vector2(0.6, 1.0))
			k.blob(Vector3(0, -0.09, 0), Vector3(0.03, 0.03, 0.03), trim, 2, 4, 0.0)
		"axe", "woodaxe":
			k.box(Vector3(0, -0.05, 0), Vector3(0.035, 0.55, 0.035), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.36, 0.06), Vector3(0.025, 0.16, 0.14), metal, Vector2(1.0, 1.4))
			k.box(Vector3(0, 0.41, -0.03), Vector3(0.03, 0.06, 0.05), metal.darkened(0.2))
		"mace", "club":
			k.box(Vector3(0, -0.05, 0), Vector3(0.04, 0.46, 0.04), grip)
			k.metal = 1.0
			k.blob(Vector3(0, 0.45, 0), Vector3(0.09, 0.1, 0.09), metal, 2, 6, 0.0)
			for i in 4:
				var a := i * TAU / 4.0
				k.cone(Vector3(cos(a) * 0.07, 0.43, sin(a) * 0.07), 0.03, 0.06, 4, trim)
		"pickaxe":
			k.box(Vector3(0, -0.05, 0), Vector3(0.035, 0.5, 0.035), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.42, 0), Vector3(0.03, 0.04, 0.34), metal, Vector2(1.0, 0.6))
		"sickle":
			k.box(Vector3(0, -0.03, 0), Vector3(0.03, 0.14, 0.03), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.11, 0.06), Vector3(0.015, 0.03, 0.16), metal)
		"bow":
			weapon_kind = "bow"
			parent = parts["hand_l"]
			var wood := Color(0.5, 0.33, 0.18) if t < 3 else Color(0.25, 0.2, 0.22)
			var segs := 6
			for i in segs:
				var a0 := lerpf(-1.0, 1.0, float(i) / segs)
				var a1 := lerpf(-1.0, 1.0, float(i + 1) / segs)
				var p0 := Vector3(0, a0 * 0.36, 0.1 * (1.0 - a0 * a0) + 0.02)
				var p1 := Vector3(0, a1 * 0.36, 0.1 * (1.0 - a1 * a1) + 0.02)
				var d := Vector3(0.025, 0, 0)
				k.quad(p0 - d, p1 - d, p1 + d, p0 + d, wood, Vector3(0, 0, 1))
				k.quad(p0 + d, p1 + d, p1 - d, p0 - d, wood.darkened(0.2), Vector3(0, 0, -1))
			k.box(Vector3(0, -0.05, 0.12), Vector3(0.04, 0.1, 0.04), trim)
			var s := Vector3(0.004, 0, 0)
			k.quad(Vector3(0, -0.36, 0.02) - s, Vector3(0, 0.36, 0.02) - s, Vector3(0, 0.36, 0.02) + s, Vector3(0, -0.36, 0.02) + s, Color(0.9, 0.88, 0.8), Vector3(0, 0, 1))
			k.quad(Vector3(0, -0.36, 0.02) + s, Vector3(0, 0.36, 0.02) + s, Vector3(0, 0.36, 0.02) - s, Vector3(0, -0.36, 0.02) - s, Color(0.9, 0.88, 0.8), Vector3(0, 0, -1))
		"hammer":
			k.box(Vector3(0, -0.05, 0), Vector3(0.035, 0.4, 0.035), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.33, 0), Vector3(0.07, 0.08, 0.16), IRON())
		"staff":
			k.box(Vector3(0, -0.2, 0), Vector3(0.035, 0.85, 0.035), Color(0.35, 0.24, 0.14))
			k.glow = 1.0
			k.blob(Vector3(0, 0.7, 0), Vector3(0.07, 0.07, 0.07), trim if t > 1 else Color(0.5, 1.0, 0.4), 2, 6, 0.0)
			k.glow = 0.0
		"club_big":
			k.box(Vector3(0, -0.05, 0), Vector3(0.06, 0.3, 0.06), grip)
			k.jitter = 0.05
			k.cyl(Vector3(0, 0.22, 0), 0.07, 0.13, 0.45, 6, Color(0.42, 0.3, 0.2))
			k.jitter = 0.0
			for i in 4:
				k.cone(Vector3(0.1 * cos(i * 1.6), 0.45 + i * 0.05, 0.1 * sin(i * 1.6)), 0.03, 0.08, 4, Color(0.8, 0.8, 0.75))
		"greatsword":
			k.box(Vector3(0, -0.08, 0), Vector3(0.04, 0.2, 0.04), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.1, 0), Vector3(0.28, 0.05, 0.06), Color(0.2, 0.15, 0.15))
			k.box(Vector3(0, 0.14, 0), Vector3(0.09, 0.8, 0.025), Color(0.3, 0.26, 0.28), Vector2(0.5, 1.0))
			k.glow = 0.8
			k.box(Vector3(0, 0.2, 0.014), Vector3(0.02, 0.65, 0.005), Color(1.0, 0.35, 0.1))
			k.glow = 0.0
		_:
			return
	var holder := Node3D.new()
	holder.name = "weapon"
	parent.add_child(holder)
	parts["weapon"] = holder
	# Broń trzymana do przodu (oś Y siatki = kierunek ostrza).
	if weapon_kind == "bow":
		holder.rotation = Vector3(0, 0, 0)
	else:
		holder.rotation = Vector3(PI / 2.0 - 0.3, 0, 0)
	_attach_mesh(holder, k)


static func IRON() -> Color:
	return Color(0.34, 0.34, 0.37)


func _build_shield(id: String) -> void:
	var it := split_item(id)
	var t: int = clampi(it[1], 1, 4)
	var k := MeshKit.new(61)
	var face: Color = [Color(0.5, 0.33, 0.18), Color(0.5, 0.33, 0.18), Color(0.6, 0.18, 0.14), Color(0.2, 0.3, 0.6), Color(0.25, 0.14, 0.3)][t]
	var rim: Color = TIER_METAL[t]
	k.jitter = 0.02
	if t <= 1:
		# Okrągła drewniana tarcza z metalowym guzem.
		k.cyl(Vector3(0, 0, 0), 0.2, 0.2, 0.04, 8, face, true, face.lightened(0.05))
		k.metal = 1.0
		k.cyl(Vector3(0, 0.035, 0), 0.21, 0.19, 0.02, 8, rim, false)
		k.blob(Vector3(0, 0.05, 0), Vector3(0.05, 0.03, 0.05), rim, 2, 6, 0.0)
	else:
		# Tarcza migdałowa z herbem.
		var pts := [Vector3(-0.17, 0, 0.2), Vector3(0.17, 0, 0.2), Vector3(0.17, 0, -0.05), Vector3(0.0, 0, -0.28), Vector3(-0.17, 0, -0.05)]
		for layer in 2:
			var y := 0.04 * layer
			var col := face if layer == 1 else rim
			k.metal = 0.0 if layer == 1 else 1.0
			var sc := 1.0 if layer == 0 else 0.86
			var c0 := Vector3(0, y, 0)
			for i in pts.size():
				var a: Vector3 = pts[i] * sc + Vector3(0, y, 0)
				var b: Vector3 = pts[(i + 1) % pts.size()] * sc + Vector3(0, y, 0)
				k.tri(c0, a, b, col, Vector3.UP)
				if layer == 0:
					k.quad(a, b, b + Vector3(0, 0.04, 0), a + Vector3(0, 0.04, 0), rim, (a + b) / 2.0)
		k.metal = 1.0
		k.glow = 0.2 if t >= 4 else 0.0
		k.box(Vector3(0, 0.045, 0.0), Vector3(0.05, 0.02, 0.3), TIER_TRIM[t])
		k.box(Vector3(0, 0.045, 0.06), Vector3(0.22, 0.02, 0.05), TIER_TRIM[t])
	var holder := Node3D.new()
	holder.name = "shield"
	parts["arm_l"].add_child(holder)
	holder.position = Vector3(-0.07, -0.2, 0.03)
	# Płaszczyzna tarczy na zewnątrz ręki, lekko do przodu.
	holder.rotation = Vector3(0, 0, PI / 2.0)
	holder.rotate_y(-0.5)
	parts["shield"] = holder
	_attach_mesh(holder, k)


# ============================================================================
# Zwierzęta
# ============================================================================

func build_beast(look: String) -> void:
	type = "beast"
	var fur := Color(0.45, 0.4, 0.36)
	var belly := fur.lightened(0.2)
	var L := 0.4
	var W := 0.2
	var H := 0.15
	var leg := 0.08
	var head := Vector3(0.14, 0.12, 0.16)
	var ear := "round"
	var eye := Color(0.1, 0.08, 0.08)
	var eye_glow := 0.0
	var tail := "thin"
	var cracks := false
	var ear_col := Color(0.9, 0.62, 0.62)
	var extra := ""
	match look:
		"snow_fox":
			fur = Color(0.93, 0.95, 0.97)
			belly = Color(1, 1, 1)
			L = 0.5
			W = 0.2
			H = 0.17
			leg = 0.14
			head = Vector3(0.16, 0.14, 0.18)
			ear = "pointy"
			tail = "bushy"
		"snow_wolf":
			fur = Color(0.84, 0.87, 0.92)
			belly = Color(0.96, 0.97, 1.0)
			L = 0.76
			W = 0.3
			H = 0.3
			leg = 0.32
			head = Vector3(0.25, 0.23, 0.25)
			ear = "pointy"
			tail = "bushy"
			eye = Color(0.5, 0.85, 1.0)
			eye_glow = 0.8
		"bear":
			fur = Color(0.4, 0.27, 0.17)
			belly = Color(0.48, 0.34, 0.22)
			L = 0.92
			W = 0.52
			H = 0.46
			leg = 0.28
			head = Vector3(0.32, 0.3, 0.3)
			ear_col = fur.darkened(0.1)
			tail = "stub"
		"basilisk":
			fur = Color(0.3, 0.42, 0.22)
			belly = Color(0.62, 0.56, 0.3)
			L = 1.15
			W = 0.46
			H = 0.3
			leg = 0.17
			head = Vector3(0.32, 0.22, 0.42)
			ear = "none"
			tail = "thick"
			eye = Color(1.0, 0.85, 0.1)
			eye_glow = 1.0
			extra = "spikes"
		"mount_horse", "mount_elk", "mount_camel":
			fur = {"mount_horse": Color(0.45, 0.28, 0.16), "mount_elk": Color(0.42, 0.3, 0.2), "mount_camel": Color(0.8, 0.64, 0.4)}[look]
			belly = fur.lightened(0.12)
			L = 0.95
			W = 0.32
			H = 0.36
			leg = 0.56 if look != "mount_camel" else 0.62
			head = Vector3(0.18, 0.2, 0.36)
			ear = "pointy"
			tail = "flowing" if look == "mount_horse" else "stub"
			extra = look
		"mount_warwolf":
			fur = Color(0.3, 0.3, 0.33)
			belly = Color(0.5, 0.5, 0.52)
			L = 0.95
			W = 0.36
			H = 0.36
			leg = 0.46
			head = Vector3(0.3, 0.27, 0.3)
			ear = "pointy"
			tail = "bushy"
			eye = Color(1.0, 0.8, 0.2)
			eye_glow = 0.6
			extra = look
		"rat":
			fur = Color(0.46, 0.4, 0.37)
			belly = Color(0.7, 0.62, 0.58)
		"boar":
			fur = Color(0.36, 0.25, 0.18)
			belly = Color(0.46, 0.34, 0.26)
			L = 0.72
			W = 0.4
			H = 0.34
			leg = 0.2
			head = Vector3(0.3, 0.28, 0.3)
			ear = "pointy"
			tail = "stub"
		"wolf":
			fur = Color(0.5, 0.5, 0.52)
			belly = Color(0.78, 0.76, 0.72)
			L = 0.72
			W = 0.28
			H = 0.28
			leg = 0.3
			head = Vector3(0.24, 0.22, 0.24)
			ear = "pointy"
			tail = "bushy"
			eye = Color(0.95, 0.75, 0.2)
			eye_glow = 0.4
		"hound":
			fur = Color(0.17, 0.13, 0.12)
			belly = Color(0.3, 0.18, 0.12)
			L = 0.82
			W = 0.32
			H = 0.32
			leg = 0.34
			head = Vector3(0.27, 0.24, 0.27)
			ear = "pointy"
			tail = "flame"
			eye = Color(1.0, 0.5, 0.1)
			eye_glow = 1.0
			cracks = true
	var root := _part("root", self, Vector3.ZERO)
	# Tułów.
	var bk := MeshKit.new(71)
	bk.jitter = 0.03
	bk.box(Vector3(0, -H / 2.0, 0), Vector3(W, H, L), fur, Vector2(0.9, 0.95))
	bk.box(Vector3(0, -H / 2.0 - 0.005, 0), Vector3(W * 0.8, H * 0.3, L * 0.8), belly)
	if look == "boar":
		bk.box(Vector3(0, H / 2.0 - 0.02, -0.05), Vector3(0.08, 0.08, L * 0.8), fur.darkened(0.3))
	if look == "wolf" or look == "hound":
		bk.box(Vector3(0, -H / 2.0, L * 0.3), Vector3(W * 1.15, H * 1.15, L * 0.3), fur.lightened(0.05))
	if extra == "spikes":
		for i in 5:
			bk.cone(Vector3(0, H / 2.0 - 0.02, L / 2.5 - i * L / 6.0), 0.06, 0.14, 4, fur.darkened(0.35))
	if extra.begins_with("mount_"):
		# Siodło z czaprakiem.
		bk.box(Vector3(0, H / 2.0 - 0.03, 0.02), Vector3(W * 1.08, 0.05, 0.36), Color(0.55, 0.12, 0.1))
		bk.box(Vector3(0, H / 2.0, 0.02), Vector3(W * 0.8, 0.07, 0.26), Color(0.32, 0.2, 0.12))
		bk.metal = 1.0
		for side in [-1, 1]:
			bk.box(Vector3(side * W * 0.56, -0.05, 0.02), Vector3(0.02, 0.18, 0.02), Color(0.7, 0.62, 0.4))
		bk.metal = 0.0
		if extra == "mount_camel":
			bk.blob(Vector3(0, H / 2.0 + 0.06, -0.22), Vector3(0.15, 0.14, 0.18), fur, 3, 6, 0.1)
		if extra == "mount_warwolf":
			bk.metal = 0.9
			bk.box(Vector3(0, H / 2.0 - 0.06, L * 0.3), Vector3(W * 1.1, 0.12, 0.2), Color(0.45, 0.45, 0.5))
			bk.metal = 0.0
	if cracks:
		bk.glow = 1.0
		for i in 4:
			bk.box(Vector3((i % 2 - 0.5) * 0.08, H / 2.0 - 0.005, -L / 3.0 + i * L / 5.0), Vector3(0.03, 0.012, 0.1), Color(1.0, 0.4, 0.1))
		bk.glow = 0.0
	var body := _part("body", root, Vector3(0, leg + H / 2.0, 0), bk)
	# Głowa.
	var hk := MeshKit.new(72)
	hk.jitter = 0.03
	hk.box(Vector3(0, -head.y / 2.0, 0), head, fur, Vector2(0.9, 0.9))
	var snout := Vector3(head.x * 0.55, head.y * 0.5, head.z * 0.7)
	var snout_col := fur.lightened(0.1)
	if look == "rat":
		snout_col = fur
	if look == "boar":
		snout_col = Color(0.62, 0.45, 0.4)
	hk.box(Vector3(0, -head.y / 2.0, head.z / 2.0 + snout.z / 2.0 - 0.01), snout, snout_col, Vector2(0.9, 0.85))
	hk.box(Vector3(0, -head.y / 2.0 + snout.y * 0.55, head.z / 2.0 + snout.z - 0.005), Vector3(snout.x * 0.5, snout.y * 0.4, 0.02), Color(0.9, 0.55, 0.55) if look == "rat" else Color(0.1, 0.08, 0.08))
	if look == "boar":
		for side in [-1, 1]:
			hk.cone(Vector3(side * 0.08, -head.y / 2.0, head.z / 2.0 + 0.1), 0.02, 0.12, 4, Color(0.95, 0.92, 0.82))
	hk.glow = eye_glow
	for side in [-1, 1]:
		hk.box(Vector3(side * head.x * 0.3, head.y * 0.12, head.z / 2.0 + 0.002), Vector3(0.035, 0.035, 0.01), eye)
	hk.glow = 0.0
	if extra == "mount_elk":
		for side in [-1, 1]:
			for i in 3:
				hk.xf = Transform3D(Basis(Vector3(0, 0, 1), -side * (0.5 + i * 0.3)), Vector3(side * 0.07, head.y / 2.0, -0.05))
				hk.cone(Vector3.ZERO, 0.025, 0.28 - i * 0.05, 4, Color(0.88, 0.8, 0.62))
			hk.xf = Transform3D.IDENTITY
	if extra == "mount_horse":
		hk.box(Vector3(0, head.y / 2.0 - 0.02, -0.08), Vector3(0.05, 0.1, 0.2), Color(0.18, 0.12, 0.08))
	for side in [-1, 1]:
		if ear == "none":
			continue
		if ear == "round":
			hk.blob(Vector3(side * head.x * 0.42, head.y / 2.0 + 0.02, -0.02), Vector3(0.045, 0.045, 0.02) * (2.0 if look == "bear" else 1.0), ear_col, 2, 6, 0.0)
		else:
			hk.cone(Vector3(side * head.x * 0.3, head.y / 2.0 - 0.01, -head.z * 0.2), head.x * 0.2, head.y * 0.55, 4, fur.darkened(0.1))
	var head_node := _part("head", body, Vector3(0, H * 0.25, L / 2.0 + head.z * 0.35), hk)
	head_node.rotation.x = 0.1
	# Nogi.
	var i := 0
	for fz in [1, -1]:
		for side in [-1, 1]:
			var lk := MeshKit.new(80 + i)
			lk.jitter = 0.03
			lk.box(Vector3(0, -leg - 0.02, 0), Vector3(W * 0.28, leg + 0.04, W * 0.3), fur.darkened(0.1))
			lk.box(Vector3(0, -leg - 0.02, 0.01), Vector3(W * 0.3, 0.035, W * 0.36), fur.darkened(0.35))
			var nm: String = ["leg_fl", "leg_fr", "leg_bl", "leg_br"][i]
			_part(nm, root, Vector3(side * W * 0.32, leg + 0.02, fz * L * 0.36), lk)
			i += 1
	# Ogon.
	var tk := MeshKit.new(90)
	match tail:
		"thin":
			for s in 4:
				tk.box(Vector3(0, -0.01 - s * 0.0, -s * 0.09), Vector3(0.025 - s * 0.004, 0.025 - s * 0.004, 0.1), Color(0.85, 0.6, 0.6))
		"stub":
			tk.box(Vector3(0, -0.02, -0.04), Vector3(0.04, 0.04, 0.08), fur)
		"bushy":
			tk.box(Vector3(0, -0.05, -0.15), Vector3(0.1, 0.1, 0.3), fur.lightened(0.05), Vector2(0.6, 0.6))
		"flame":
			tk.box(Vector3(0, -0.05, -0.15), Vector3(0.09, 0.09, 0.3), fur, Vector2(0.5, 0.5))
			tk.glow = 1.0
			tk.cone(Vector3(0, 0.0, -0.3), 0.07, 0.2, 5, Color(1.0, 0.45, 0.1))
		"thick":
			for j in 4:
				tk.box(Vector3(0, -0.04 - j * 0.02, -0.12 - j * 0.2), Vector3(0.22 - j * 0.045, 0.16 - j * 0.03, 0.22), fur.darkened(0.05 * j))
		"flowing":
			tk.box(Vector3(0, -0.12, -0.1), Vector3(0.08, 0.3, 0.1), Color(0.18, 0.12, 0.08), Vector2(1.4, 0.6))
	var tail_node := _part("tail", body, Vector3(0, H * 0.2, -L / 2.0), tk)
	tail_node.rotation.x = -0.5 if tail == "bushy" or tail == "flame" else 0.1
	height = leg + H + head.y
	riding_height = leg + H + 0.05
	if extra == "mount_horse" or extra == "mount_camel" or extra == "mount_elk":
		# Długa szyja: głowa wyżej i dalej.
		head_node.position += Vector3(0, 0.2 if extra != "mount_camel" else 0.3, 0.05)
		head_node.rotation.x = -0.2
		var nk := MeshKit.new(95)
		nk.box(Vector3(0, -0.1, 0), Vector3(W * 0.55, 0.36 if extra != "mount_camel" else 0.46, W * 0.6), fur)
		if extra == "mount_horse":
			nk.box(Vector3(0, -0.05, -0.08), Vector3(0.06, 0.36, 0.08), Color(0.18, 0.12, 0.08))
		var neck := _part("neck", body, Vector3(0, H * 0.3, L / 2.0 - 0.02), nk)
		neck.rotation.x = 0.5
	if look == "hound":
		var p := CPUParticles3D.new()
		p.amount = 12
		p.lifetime = 0.8
		p.position = Vector3(0, leg + H, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(W * 0.3, 0.02, L * 0.4)
		p.direction = Vector3.UP
		p.spread = 15
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 0.6
		p.gravity = Vector3(0, 0.4, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		sm.radial_segments = 4
		sm.rings = 2
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 0.5, 0.1)
		m.vertex_color_use_as_albedo = true
		sm.material = m
		p.mesh = sm
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 0.8, 0.3), Color(1, 0.2, 0.05)])
		p.color_ramp = g
		p.scale_amount_min = 0.4
		p.scale_amount_max = 1.0
		root.add_child(p)


# ============================================================================
# Złoża surowców
# ============================================================================

func build_node(look: String) -> void:
	type = "node"
	var bits := look.split("_")
	var kind := bits[1] if bits.size() > 1 else "stone"
	var tier := int(bits[2]) if bits.size() > 2 else 1
	var root := _part("root", self, Vector3.ZERO)
	var k := MeshKit.new(100 + tier)
	k.jitter = 0.04
	match kind:
		"wood":
			k.sway_base = 0.0
			k.sway_height = 3.0
			match tier:
				1:
					# Brzoza.
					k.cyl(Vector3.ZERO, 0.09, 0.06, 1.3, 6, Color(0.92, 0.9, 0.84))
					for i in 4:
						k.box(Vector3(0.0, 0.2 + i * 0.28, 0.0), Vector3(0.19, 0.03, 0.19), Color(0.15, 0.13, 0.12), Vector2(0.95, 0.95))
					k.blob(Vector3(0, 1.4, 0), Vector3(0.5, 0.5, 0.5), Color(0.55, 0.75, 0.3), 3, 7, 0.2, Color(0.62, 0.8, 0.35))
					k.blob(Vector3(0.2, 1.1, 0.15), Vector3(0.3, 0.26, 0.3), Color(0.5, 0.72, 0.28), 3, 6, 0.15)
				2:
					# Kasztanowiec.
					k.cyl(Vector3.ZERO, 0.14, 0.09, 0.9, 6, Color(0.4, 0.27, 0.16))
					k.blob(Vector3(0, 1.3, 0), Vector3(0.8, 0.6, 0.8), Color(0.2, 0.45, 0.18), 3, 8, 0.2, Color(0.26, 0.52, 0.2))
					k.glow = 0.0
					for i in 6:
						var a := i * TAU / 6.0
						k.blob(Vector3(cos(a) * 0.6, 1.15, sin(a) * 0.6), Vector3(0.07, 0.07, 0.07), Color(0.95, 0.9, 0.85), 2, 4, 0.0)
				3:
					# Sosna.
					k.cyl(Vector3.ZERO, 0.12, 0.08, 1.0, 6, Color(0.45, 0.28, 0.18))
					for i in 4:
						k.cone(Vector3(0, 0.6 + i * 0.4, 0), 0.7 - i * 0.14, 0.7, 8, Color(0.12, 0.34, 0.24).lightened(i * 0.04), i * 0.3)
				_:
					# Cedr (płaskie piętra).
					k.cyl(Vector3.ZERO, 0.17, 0.1, 1.9, 7, Color(0.36, 0.2, 0.14))
					for i in 3:
						k.cyl(Vector3(0, 0.9 + i * 0.5, 0), 0.95 - i * 0.22, 0.6 - i * 0.18, 0.28, 8, Color(0.1, 0.3, 0.3).lightened(i * 0.05), true, null, i * 0.4)
			height = 2.2
		"stone":
			var col: Color = [Color.WHITE, Color(0.82, 0.8, 0.72), Color(0.82, 0.62, 0.4), Color(0.86, 0.8, 0.66), Color(0.42, 0.4, 0.44)][tier]
			k.blob(Vector3(0, 0.3, 0), Vector3(0.5, 0.36, 0.45), col, 3, 7, 0.2, col.lightened(0.08))
			k.blob(Vector3(0.35, 0.16, 0.25), Vector3(0.26, 0.2, 0.24), col.darkened(0.08), 2, 6, 0.2)
			k.blob(Vector3(-0.32, 0.12, 0.2), Vector3(0.2, 0.15, 0.2), col.darkened(0.04), 2, 6, 0.2)
			if tier == 3:
				k.box(Vector3(0, 0.3, 0.0), Vector3(0.9, 0.05, 0.8), col.darkened(0.2), Vector2(0.95, 0.95))
			if tier == 4:
				k.jitter = 0.0
				for i in 5:
					k.blob(Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.55), randf_range(-0.3, 0.3)), Vector3(0.04, 0.04, 0.04), Color(0.85, 0.82, 0.8), 2, 4, 0.0)
			height = 0.8
		"ore":
			var rock := Color(0.3, 0.28, 0.3)
			var ore: Color = [Color.WHITE, Color(0.9, 0.5, 0.22), Color(0.8, 0.84, 0.86), Color(0.62, 0.32, 0.26), Color(0.45, 0.75, 1.0)][tier]
			k.blob(Vector3(0, 0.32, 0), Vector3(0.52, 0.4, 0.46), rock, 3, 7, 0.22, rock.lightened(0.08))
			k.jitter = 0.0
			k.metal = 1.0
			k.glow = 0.35 if tier == 4 else 0.12
			for i in 6:
				var a := i * TAU / 6.0 + 0.3
				var p := Vector3(cos(a) * 0.38, 0.25 + (i % 3) * 0.12, sin(a) * 0.34)
				k.xf = Transform3D(Basis(Vector3(sin(a), 0.3, -cos(a)).normalized(), 0.5), Vector3.ZERO)
				k.cone(p, 0.07, 0.22, 5, ore)
			k.reset()
			height = 0.9
		"fiber":
			k.sway_base = 0.0
			k.sway_height = 0.9
			var stem := Color(0.35, 0.55, 0.22)
			var flower: Color = [Color.WHITE, Color(0.45, 0.55, 0.95), Color(0.4, 0.65, 0.25), Color(0.97, 0.97, 0.95), Color(1.0, 0.35, 0.1)][tier]
			if tier == 4:
				stem = Color(0.5, 0.25, 0.15)
			for i in 9:
				var a := i * TAU / 9.0 + randf() * 0.3
				var r := 0.12 + (i % 3) * 0.1
				var p := Vector3(cos(a) * r, 0, sin(a) * r)
				var tip := p * 1.4 + Vector3(0, 0.55 + (i % 4) * 0.1, 0)
				var side := Vector3(-sin(a), 0, cos(a)) * 0.05
				k.blade(p - side, p + side, tip, stem.lightened((i % 3) * 0.05))
				k.glow = 0.8 if tier == 4 else 0.0
				k.blob(tip, Vector3(0.05, 0.05, 0.05) * (1.4 if tier == 3 else 1.0), flower, 2, 5, 0.0)
				k.glow = 0.0
			height = 0.9
	_attach_mesh(root, k)


# ============================================================================
# Animacja
# ============================================================================

func play_attack(kind := "") -> void:
	_attack_t = 0.0
	_attack_kind = kind if kind != "" else weapon_kind


func play_hit() -> void:
	pass


func die() -> void:
	_dead = true


func _process(delta: float) -> void:
	if _dead:
		var r: Node3D = parts.get("root")
		if r:
			r.rotation.z = lerpf(r.rotation.z, PI / 2.0 if type == "humanoid" else PI / 2.0, minf(1.0, delta * 8.0))
			r.position.y = lerpf(r.position.y, 0.12, minf(1.0, delta * 8.0))
		return
	if type == "node":
		return
	_idle_t += delta
	if moving:
		_phase += delta * 10.0 * move_speed
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 8.0))
	if _attack_t >= 0.0:
		_attack_t += delta
		if _attack_t > 0.45:
			_attack_t = -1.0
	if gathering and _attack_t < 0.0:
		_gather_t += delta
		if _gather_t > 0.9 or _gather_t < 0.0:
			_gather_t = 0.0
			play_attack("melee")
	else:
		_gather_t = -1.0 if not gathering else _gather_t
	match type:
		"humanoid":
			_animate_humanoid(delta)
			if parts.has("wing_l"):
				_flap(0.25, 3.0)
			if float_mode:
				parts["root"].position.y = 0.18 + sin(_idle_t * 2.0) * 0.06
		"beast":
			_animate_beast(delta)
			if parts.has("wing_l"):
				_flap(0.5, 4.0 if moving else 2.0)
			if riding_height > 0.0:
				pass
		_:
			CreatureModels.animate(self, delta)


## Machanie skrzydłami.
func _flap(amp: float, speed: float) -> void:
	var a := sin(_idle_t * speed) * amp
	parts["wing_l"].rotation.z = 0.3 + a
	parts["wing_r"].rotation.z = -0.3 - a


func _animate_humanoid(_delta: float) -> void:
	var s := sin(_phase)
	var walk_amp := 0.65 if moving and not riding else 0.0
	var root: Node3D = parts["root"]
	root.position.y = absf(sin(_phase)) * 0.045 if moving else 0.0
	parts["leg_l"].rotation.x = s * walk_amp
	parts["leg_r"].rotation.x = -s * walk_amp
	if riding:
		root.position.y = 0.0
		parts["leg_l"].rotation = Vector3(-1.2, 0, -0.35)
		parts["leg_r"].rotation = Vector3(-1.2, 0, 0.35)
	var torso: Node3D = parts["torso"]
	var breathe := sin(_idle_t * 2.2) * 0.012
	torso.scale.y = 1.0 + breathe
	torso.rotation.y = s * 0.08 if moving else 0.0
	var arm_l: Node3D = parts["arm_l"]
	var arm_r: Node3D = parts["arm_r"]
	arm_l.rotation.x = -s * walk_amp * 0.8
	arm_r.rotation.x = s * walk_amp * 0.8
	arm_l.rotation.z = -0.08 - sin(_idle_t * 2.2) * 0.02
	arm_r.rotation.z = 0.08 + sin(_idle_t * 2.2) * 0.02
	if parts.has("head"):
		parts["head"].rotation.y = sin(_idle_t * 0.7) * 0.12 if not moving else 0.0
	if weapon_kind == "melee" and not moving:
		arm_r.rotation.x = -0.35
	if parts.has("shield") and not moving:
		arm_l.rotation.x = -0.3
	if _attack_t >= 0.0:
		var k := _attack_t / 0.45
		if _attack_kind == "bow":
			var raise := sin(minf(1.0, k * 2.0) * PI / 2.0)
			arm_l.rotation.x = lerpf(arm_l.rotation.x, -1.5, raise)
			arm_r.rotation.x = lerpf(arm_r.rotation.x, -1.4, raise)
			arm_r.rotation.z = 0.5 * raise * (1.0 - k)
		else:
			# Zamach: ręka do góry i szybki cios w dół do przodu.
			var a: float
			if k < 0.35:
				a = lerpf(-0.35, -2.7, k / 0.35)
			else:
				a = lerpf(-2.7, -0.2, minf(1.0, (k - 0.35) / 0.3))
			arm_r.rotation.x = a
			torso.rotation.y = (0.35 if k < 0.35 else -0.3) * sin(k * PI)
	# Łuk zawsze pionowo.
	if weapon_kind == "bow" and parts.has("weapon"):
		parts["weapon"].rotation.x = -arm_l.rotation.x


func _animate_beast(_delta: float) -> void:
	var s := sin(_phase)
	var amp := 0.6 if moving else 0.0
	parts["leg_fl"].rotation.x = s * amp
	parts["leg_br"].rotation.x = s * amp
	parts["leg_fr"].rotation.x = -s * amp
	parts["leg_bl"].rotation.x = -s * amp
	var body: Node3D = parts["body"]
	var base_y: float = body.get_meta("base_y", body.position.y)
	body.set_meta("base_y", base_y)
	body.position.y = base_y + (absf(s) * 0.03 if moving else sin(_idle_t * 2.5) * 0.006)
	parts["tail"].rotation.y = sin(_idle_t * (8.0 if moving else 3.0)) * 0.35
	var head: Node3D = parts["head"]
	head.rotation.x = 0.1 + sin(_idle_t * 1.3) * 0.05
	body.position.z = 0.0
	if _attack_t >= 0.0:
		var k := _attack_t / 0.45
		body.position.z = sin(k * PI) * 0.22
		head.rotation.x = 0.1 + sin(k * PI) * 0.5


# ============================================================================
# Dodatki humanoidów (potwory, NPC)
# ============================================================================

## Kły, rogi, świecące oczy, pysk jaszczura, twarz yeti, korona.
func _head_extras(head: Node3D, app: Dictionary, skin: Color) -> void:
	var k := MeshKit.new(33)
	if app.get("tusks", false):
		for side in [-1, 1]:
			k.cone(Vector3(side * 0.07, -0.02, 0.14), 0.025, 0.09, 4, Color(0.95, 0.92, 0.8))
	if app.has("horns"):
		var hc: Color = app.horns
		for side in [-1, 1]:
			k.xf = Transform3D(Basis(Vector3(0, 0, 1), -side * 0.6), Vector3(side * 0.12, 0.26, 0))
			k.cone(Vector3.ZERO, 0.05, 0.22, 5, hc)
		k.xf = Transform3D.IDENTITY
	match str(app.get("head_shape", "")):
		"lizard":
			k.box(Vector3(0, -0.02, 0.2), Vector3(0.2, 0.14, 0.18), skin.darkened(0.05), Vector2(0.8, 0.85))
			k.box(Vector3(0, 0.12, 0.05), Vector3(0.05, 0.1, 0.3), skin.darkened(0.25))
			for i in 3:
				k.cone(Vector3(0, 0.26 - i * 0.04, -0.02 - i * 0.08), 0.04, 0.1, 4, skin.darkened(0.3))
		"yeti":
			k.box(Vector3(0, 0.0, 0.14), Vector3(0.2, 0.2, 0.02), Color(0.45, 0.62, 0.8))
			k.box(Vector3(0, 0.2, 0.0), Vector3(0.34, 0.1, 0.32), skin.lightened(0.05))
		"skull":
			pass
	if app.has("eye_glow"):
		k.glow = 1.0
		for side in [-1, 1]:
			k.box(Vector3(side * 0.065, 0.12, 0.146), Vector3(0.05, 0.04, 0.012), app.eye_glow)
		k.glow = 0.0
	if app.has("crown"):
		k.glow = 0.7
		k.metal = 0.8
		for i in 7:
			var a := i * TAU / 7.0
			k.cone(Vector3(cos(a) * 0.14, 0.28, sin(a) * 0.14), 0.035, 0.2 + (i % 2) * 0.1, 4, app.crown)
		k.glow = 0.0
		k.metal = 0.0
	if app.has("bandana"):
		k.box(Vector3(0, 0.2, 0), Vector3(0.32, 0.08, 0.3), app.bandana)
		k.box(Vector3(0, -0.02, 0.13), Vector3(0.3, 0.1, 0.04), app.bandana)
	if not k.is_empty():
		_attach_mesh(head, k)


## Skrzydła, ogon, szata zjawy, bandaże mumii, płaszcz.
func _body_extras(torso: Node3D, root: Node3D, app: Dictionary) -> void:
	if app.has("wings"):
		var wc: Color = app.wings
		for side in [-1, 1]:
			var wk := MeshKit.new(34 + side)
			var o := Vector3.ZERO
			wk.blade(o, Vector3(side * 0.9, 0.35, -0.1), Vector3(side * 0.7, -0.35, -0.05), wc)
			wk.blade(o, Vector3(side * 0.7, -0.35, -0.05), Vector3(side * 0.3, -0.45, 0), wc.darkened(0.15))
			wk.box(Vector3(side * 0.45, 0.14, -0.05), Vector3(0.9, 0.04, 0.04), wc.darkened(0.4))
			_part("wing_l" if side < 0 else "wing_r", torso, Vector3(side * 0.1, 0.28, -0.12), wk)
	if app.has("tail"):
		var tk := MeshKit.new(36)
		var tc: Color = app.tail
		for i in 4:
			tk.box(Vector3(0, -0.02 * i, -0.08 - i * 0.14), Vector3(0.12 - i * 0.022, 0.1 - i * 0.018, 0.16), tc)
		var tail := _part("tail", root, Vector3(0, 0.38, -0.08), tk)
		tail.rotation.x = 0.35
	if app.get("float", false):
		float_mode = true
		var rk := MeshKit.new(37)
		var rc: Color = app.get("shirt", Color(0.7, 0.85, 0.95))
		rk.glow = float(app.get("robe_glow", 0.0))
		rk.box(Vector3(0, -0.45, 0), Vector3(0.36, 0.48, 0.26), rc, Vector2(0.9, 0.85))
		rk.cone(Vector3(0, -0.6, 0), 0.22, 0.2, 6, rc.darkened(0.1))
		_attach_mesh(torso, rk)
	if app.has("stripes"):
		var sk := MeshKit.new(38)
		for i in 4:
			sk.box(Vector3(0, 0.05 + i * 0.08, 0), Vector3(0.335, 0.015, 0.21), app.stripes)
		_attach_mesh(torso, sk)
	if app.has("cape"):
		var ck := MeshKit.new(39)
		ck.box(Vector3(0, -0.28, -0.12), Vector3(0.34, 0.62, 0.02), app.cape, Vector2(1.2, 1.0))
		_attach_mesh(torso, ck)
