class_name CharacterModel
extends Node3D
## Model istoty low-poly złożony z części (biodra, tułów, głowa, ręce, nogi…) i animowany w kodzie:
## chód, oddech, atak, zbieranie, śmierć. Wygląd zależy od założonego ekwipunku (tier = kolor/materiał).
##
## Rodzaje: humanoid (gracze, NPC, szkielet), beast (szczur, dzik, wilk, ogar), node (złoża surowców).

## Materiały tierów (wspólne z ikonami tools/textures/gen_icons.py): żelazo, brąz, stal, fiolet,
## złoto, szkarłat, mithril, obsydian.
const TIER_METAL := [Color(0.62, 0.62, 0.64), Color(0.62, 0.62, 0.64), Color(0.74, 0.52, 0.3), Color(0.62, 0.72, 0.86), Color(0.42, 0.34, 0.56),
	Color(0.95, 0.76, 0.3), Color(0.72, 0.25, 0.16), Color(0.86, 0.9, 0.96), Color(0.24, 0.22, 0.27)]
const TIER_LEATHER := [Color(0.56, 0.37, 0.2), Color(0.56, 0.37, 0.2), Color(0.42, 0.3, 0.17), Color(0.3, 0.24, 0.22), Color(0.16, 0.13, 0.14),
	Color(0.36, 0.22, 0.12), Color(0.52, 0.54, 0.6), Color(0.3, 0.42, 0.24), Color(0.48, 0.12, 0.1)]
const TIER_CLOTH := [Color(0.84, 0.78, 0.62), Color(0.84, 0.78, 0.62), Color(0.28, 0.52, 0.33), Color(0.24, 0.36, 0.68), Color(0.44, 0.18, 0.52),
	Color(0.45, 0.62, 0.9), Color(0.85, 0.6, 0.2), Color(0.95, 0.85, 0.4), Color(0.7, 0.95, 0.92)]
const TIER_TRIM := [Color(0.5, 0.4, 0.3), Color(0.5, 0.4, 0.3), Color(0.35, 0.62, 0.3), Color(0.35, 0.52, 0.95), Color(0.75, 0.35, 1.0),
	Color(0.62, 0.1, 0.1), Color(1.0, 0.72, 0.25), Color(0.4, 0.85, 1.0), Color(1.0, 0.35, 0.08)]
## Kolor poświaty/klejnotów tieru.
const TIER_GLOW := [Color(0.9, 0.8, 0.5), Color(0.8, 0.8, 0.8), Color(0.4, 0.85, 0.35), Color(0.35, 0.6, 1.0), Color(0.75, 0.35, 1.0),
	Color(1.0, 0.8, 0.25), Color(1.0, 0.4, 0.1), Color(0.6, 0.95, 1.0), Color(1.0, 0.25, 0.05)]
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
## Wysokość bioder nad stopami (osadzanie jeźdźca w siodle).
var hip_y := 0.42


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
	# Ludzie (gracze, NPC, bandyci) – realistyczne proporcje i gładkie kształty.
	if _is_human(app):
		build_human(app)
		return
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


static func _is_human(app: Dictionary) -> bool:
	for k in ["skeleton", "tusks", "horns", "head_shape", "float", "wings", "tail", "stripes"]:
		if app.get(k, false):
			return false
	return true


## Gładki pierścień pancerza/ubrania wokół bryły: kopia pierścieni powiększona o `grow`.
static func _grow(rings: Array, grow: float) -> Array:
	var out: Array = []
	for r in rings:
		out.append([r[0], Vector2(r[1].x + grow, r[1].y + grow)])
	return out


## Człowiek: nogi 0,55, tułów 0,46, głowa 0,19 (razem ~1,2 – mieści się w drzwiach domów).
func build_human(app: Dictionary) -> void:
	var skin: Color = app.get("skin", SKINS[0])
	var eq: Array = app.get("eq", ["", "", "", "", "", ""])
	var head_it := split_item(str(eq[0])) if str(eq[0]) != "" else ["", 0]
	var body_it := split_item(str(eq[1])) if str(eq[1]) != "" else ["", 0]
	var legs_it := split_item(str(eq[2])) if str(eq[2]) != "" else ["", 0]
	var feet_it := split_item(str(eq[3])) if str(eq[3]) != "" else ["", 0]
	var shirt: Color = app.get("shirt", SHIRTS[0])
	var pants: Color = app.get("pants", Color(0.35, 0.27, 0.2))
	var boots: Color = app.get("boots", Color(0.25, 0.17, 0.12))
	var hair: Color = app.get("hair", HAIRS[0])
	var style: int = app.get("hair_style", 0)
	var body_base: String = body_it[0]
	var bt: int = body_it[1]
	var torso_col := shirt
	var sleeve := shirt
	var forearm := skin
	var hand_col := skin
	var metal_body := body_base.begins_with("plate")
	if metal_body:
		torso_col = TIER_METAL[bt]
		sleeve = TIER_METAL[bt].darkened(0.08)
		forearm = sleeve
		hand_col = TIER_METAL[bt].darkened(0.2)
	elif body_base.begins_with("leather"):
		torso_col = TIER_LEATHER[bt]
		sleeve = TIER_LEATHER[bt].darkened(0.08)
		forearm = sleeve.darkened(0.1)
		hand_col = Color(0.3, 0.2, 0.13)
	elif body_base.begins_with("cloth"):
		torso_col = TIER_CLOTH[bt]
		sleeve = torso_col
		forearm = torso_col
	var legs_base: String = legs_it[0]
	var metal_legs := legs_base.begins_with("plate")
	if metal_legs:
		pants = TIER_METAL[legs_it[1]]
	elif legs_base.begins_with("leather"):
		pants = TIER_LEATHER[legs_it[1]].darkened(0.1)
	elif legs_base.begins_with("cloth"):
		pants = TIER_CLOTH[legs_it[1]].darkened(0.1)
	var feet_base: String = feet_it[0]
	var metal_feet := feet_base.begins_with("plate")
	var sandals := feet_base.begins_with("cloth")
	if metal_feet:
		boots = TIER_METAL[feet_it[1]].darkened(0.05)
	elif feet_base.begins_with("leather"):
		boots = TIER_LEATHER[feet_it[1]].darkened(0.2)
	var trim: Color = TIER_TRIM[bt]

	hip_y = 0.55
	var root := _part("root", self, Vector3.ZERO)

	# --- Nogi ---
	var leg_rings := [[Vector3(0, -0.51, 0.005), Vector2(0.032, 0.036)], [Vector3(0, -0.45, 0.0), Vector2(0.038, 0.042)],
		[Vector3(0, -0.34, -0.005), Vector2(0.05, 0.056)], [Vector3(0, -0.25, 0.005), Vector2(0.045, 0.05)],
		[Vector3(0, -0.12, 0.0), Vector2(0.062, 0.066)], [Vector3(0, 0.02, 0.0), Vector2(0.068, 0.075)]]
	for side in [-1, 1]:
		var lk := MeshKit.new(11 + side)
		lk.metal = 0.0
		var boot_top := boots if not sandals else skin
		lk.loft(leg_rings, pants, 10, true, [boot_top, boot_top, pants, pants, pants])
		if metal_legs:
			lk.metal = 0.85
			lk.loft(_grow(leg_rings.slice(2, 6), 0.012), pants, 10, true)
			lk.ellipsoid(Vector3(0, -0.25, 0.04), Vector3(0.05, 0.045, 0.035), pants.lightened(0.12), 5, 8)
		lk.metal = 0.85 if metal_feet else 0.0
		if metal_feet:
			lk.loft(_grow(leg_rings.slice(0, 3), 0.01), boots, 10, true)
		lk.ellipsoid(Vector3(0, -0.525, 0.035), Vector3(0.042, 0.032, 0.085), boots if not sandals else skin, 5, 10)
		if sandals:
			lk.box(Vector3(0, -0.555, 0.035), Vector3(0.09, 0.012, 0.18), Color(0.45, 0.3, 0.18))
		lk.metal = 0.0
		_part("leg_l" if side < 0 else "leg_r", root, Vector3(side * 0.075, hip_y, 0), lk)

	# --- Tułów ---
	var tk := MeshKit.new(21)
	var torso_rings := [[Vector3(0, -0.02, 0), Vector2(0.125, 0.085)], [Vector3(0, 0.06, 0), Vector2(0.13, 0.086)],
		[Vector3(0, 0.14, 0), Vector2(0.115, 0.078)], [Vector3(0, 0.24, 0.005), Vector2(0.135, 0.086)],
		[Vector3(0, 0.31, 0.01), Vector2(0.15, 0.095)], [Vector3(0, 0.36, 0), Vector2(0.158, 0.085)],
		[Vector3(0, 0.39, 0), Vector2(0.1, 0.065)], [Vector3(0, 0.415, 0), Vector2(0.042, 0.04)], [Vector3(0, 0.47, 0.005), Vector2(0.04, 0.04)]]
	tk.loft(torso_rings, torso_col, 12, true, [pants, torso_col, torso_col, torso_col, torso_col, torso_col, skin, skin])
	if metal_body:
		tk.metal = 0.85
		tk.loft(_grow(torso_rings.slice(1, 7), 0.016), torso_col, 12, true)
		# Naramienniki (warstwowe) i napierśnik.
		for side in [-1, 1]:
			tk.ellipsoid(Vector3(side * 0.165, 0.365, 0), Vector3(0.075, 0.058, 0.082), torso_col.lightened(0.06), 5, 10)
			tk.ellipsoid(Vector3(side * 0.18, 0.325, 0), Vector3(0.065, 0.045, 0.075), torso_col.darkened(0.05), 5, 10)
		tk.ellipsoid(Vector3(0, 0.27, 0.07), Vector3(0.11, 0.09, 0.04), torso_col.lightened(0.1), 5, 10)
		# Fartuch płytowy (tasiemki) na biodrach.
		tk.loft([[Vector3(0, -0.13, 0), Vector2(0.15, 0.105)], [Vector3(0, 0.1, 0), Vector2(0.14, 0.095)]], torso_col.darkened(0.08), 12, false)
		if bt >= 3:
			tk.metal = 1.0
			tk.glow = 0.9 if bt >= 8 else 0.0
			tk.loft([[Vector3(0, 0.345, 0), Vector2(0.176, 0.106)], [Vector3(0, 0.365, 0), Vector2(0.17, 0.1)]], trim, 12, false)
			tk.loft([[Vector3(0, 0.085, 0), Vector2(0.148, 0.104)], [Vector3(0, 0.1, 0), Vector2(0.147, 0.103)]], trim, 12, false)
			tk.glow = 0.0
		tk.metal = 0.0
	elif body_base.begins_with("leather"):
		tk.loft([[Vector3(0, 0.37, 0), Vector2(0.11, 0.075)], [Vector3(0, 0.41, 0), Vector2(0.075, 0.06)]], torso_col.lightened(0.1), 12, false)
		tk.box(Vector3(0.05, 0.08, 0.085), Vector3(0.025, 0.28, 0.01), torso_col.darkened(0.25))
		if bt >= 2:
			tk.box(Vector3(-0.05, 0.08, 0.085), Vector3(0.025, 0.28, 0.01), trim)
	if body_base.begins_with("cloth") or app.get("robe", false):
		var rc := torso_col if body_base.begins_with("cloth") else shirt
		tk.loft([[Vector3(0, -0.53, 0), Vector2(0.21, 0.17)], [Vector3(0, -0.2, 0), Vector2(0.16, 0.12)], [Vector3(0, 0.08, 0), Vector2(0.135, 0.09)]], rc, 12, true)
		if bt >= 2 or app.get("robe_trim", null) != null:
			var rt: Color = app.get("robe_trim", trim)
			tk.loft([[Vector3(0, -0.53, 0), Vector2(0.214, 0.174)], [Vector3(0, -0.49, 0), Vector2(0.205, 0.166)]], rt, 12, false)
			tk.box(Vector3(0, -0.2, 0.125), Vector3(0.04, 0.6, 0.01), rt)
	# Pas ze sprzączką.
	tk.loft([[Vector3(0, 0.075, 0), Vector2(0.138, 0.094)], [Vector3(0, 0.115, 0), Vector2(0.133, 0.09)]], Color(0.26, 0.17, 0.1), 12, false)
	tk.metal = 1.0
	tk.box(Vector3(0, 0.08, 0.092), Vector3(0.04, 0.035, 0.012), Color(0.85, 0.7, 0.3))
	tk.metal = 0.0
	if app.get("apron", null) != null:
		var ac: Color = app.apron
		tk.loft([[Vector3(0, -0.4, 0.05), Vector2(0.13, 0.07)], [Vector3(0, 0.2, 0.03), Vector2(0.12, 0.08)]], ac, 10, false)
	if app.get("backpack", false):
		tk.ellipsoid(Vector3(0, 0.22, -0.13), Vector3(0.12, 0.14, 0.07), Color(0.45, 0.32, 0.18), 5, 10)
		tk.ellipsoid(Vector3(0, 0.33, -0.13), Vector3(0.12, 0.04, 0.08), Color(0.35, 0.25, 0.14), 4, 10)
	# Peleryna: rycerze od T4 i postacie z płaszczem.
	var cape_col = app.get("cape", null)
	if cape_col == null and metal_body and bt >= 4:
		cape_col = [Color(0.5, 0.08, 0.08), Color(0.12, 0.14, 0.32), Color(0.1, 0.1, 0.12), Color(0.35, 0.08, 0.3)][bt % 4]
	if cape_col != null:
		var cc: Color = cape_col
		var top_l := Vector3(-0.15, 0.37, -0.075)
		var top_r := Vector3(0.15, 0.37, -0.075)
		var mid_l := Vector3(-0.19, -0.05, -0.14)
		var mid_r := Vector3(0.19, -0.05, -0.14)
		var bot_l := Vector3(-0.2, -0.42, -0.16)
		var bot_r := Vector3(0.2, -0.42, -0.16)
		for face in [1, -1]:
			tk.quad(top_l, top_r, mid_r, mid_l, cc if face > 0 else cc.darkened(0.3), Vector3(0, 0, -face))
			tk.quad(mid_l, mid_r, bot_r, bot_l, cc.darkened(0.08) if face > 0 else cc.darkened(0.35), Vector3(0, 0, -face))
		if bt >= 3 and metal_body:
			tk.metal = 1.0
			for side in [-1, 1]:
				tk.ellipsoid(Vector3(side * 0.12, 0.37, 0.05), Vector3(0.018, 0.018, 0.012), trim, 3, 6)
			tk.metal = 0.0
	var torso := _part("torso", root, Vector3(0, hip_y, 0), tk)

	# --- Głowa ---
	var hk := MeshKit.new(31)
	var head_base: String = head_it[0]
	var ht: int = head_it[1]
	hk.ellipsoid(Vector3(0, 0.09, 0), Vector3(0.064, 0.08, 0.072), skin, 7, 12)
	hk.ellipsoid(Vector3(0, 0.04, 0.018), Vector3(0.052, 0.045, 0.056), skin, 6, 10)
	hk.ellipsoid(Vector3(0, 0.078, 0.07), Vector3(0.011, 0.02, 0.016), skin.darkened(0.06), 4, 6)
	for side in [-1, 1]:
		hk.ellipsoid(Vector3(side * 0.064, 0.082, 0.0), Vector3(0.01, 0.02, 0.014), skin.darkened(0.05), 4, 6)
		hk.ellipsoid(Vector3(side * 0.024, 0.097, 0.061), Vector3(0.012, 0.008, 0.006), Color(0.95, 0.95, 0.92), 4, 6)
		if app.has("eye_glow"):
			hk.glow = 1.0
			hk.ellipsoid(Vector3(side * 0.024, 0.097, 0.066), Vector3(0.009, 0.007, 0.003), app.eye_glow, 3, 6)
			hk.glow = 0.0
		else:
			hk.ellipsoid(Vector3(side * 0.024, 0.097, 0.0655), Vector3(0.0065, 0.0065, 0.0025), Color(0.15, 0.12, 0.1), 3, 6)
		hk.box(Vector3(side * 0.025, 0.108, 0.064), Vector3(0.024, 0.005, 0.006), hair.darkened(0.25))
	hk.box(Vector3(0, 0.046, 0.071), Vector3(0.026, 0.004, 0.004), Color(0.5, 0.26, 0.24))
	var hat: String = str(app.get("hat", ""))
	if head_base == "" and hat != "hood":
		match style:
			2:
				pass
			_:
				hk.ellipsoid(Vector3(0, 0.112, -0.01), Vector3(0.07, 0.068, 0.077), hair, 6, 12)
				if style == 1:
					hk.ellipsoid(Vector3(0, 0.03, -0.045), Vector3(0.068, 0.1, 0.045), hair, 5, 10)
				elif style == 3:
					hk.ellipsoid(Vector3(0, 0.05, -0.085), Vector3(0.024, 0.06, 0.024), hair, 4, 8)
				elif style == 4:
					hk.ellipsoid(Vector3(0, 0.19, -0.015), Vector3(0.03, 0.025, 0.03), hair, 4, 8)
	if app.get("beard", false):
		hk.ellipsoid(Vector3(0, 0.02, 0.042), Vector3(0.055, 0.045, 0.04), hair, 5, 10)
		hk.ellipsoid(Vector3(0, 0.055, 0.068), Vector3(0.03, 0.008, 0.008), hair, 3, 8)
	if head_base == "":
		match hat:
			"top":
				hk.cyl(Vector3(0, 0.155, 0), 0.1, 0.1, 0.012, 10, Color(0.12, 0.1, 0.12))
				hk.cyl(Vector3(0, 0.16, 0), 0.068, 0.068, 0.12, 10, Color(0.12, 0.1, 0.12))
				hk.cyl(Vector3(0, 0.165, 0), 0.07, 0.07, 0.02, 10, Color(0.7, 0.15, 0.12), false)
			"scarf":
				var sc: Color = app.get("hat_col", Color(0.8, 0.3, 0.2))
				hk.ellipsoid(Vector3(0, 0.12, -0.005), Vector3(0.074, 0.06, 0.08), sc, 5, 10)
				hk.ellipsoid(Vector3(0, 0.03, -0.05), Vector3(0.07, 0.07, 0.04), sc, 5, 10)
			"hood":
				var hc: Color = app.get("hat_col", Color(0.9, 0.88, 0.8))
				hk.ellipsoid(Vector3(0, 0.1, -0.018), Vector3(0.08, 0.095, 0.083), hc, 6, 12)
				hk.cone(Vector3(0, 0.16, -0.06), 0.05, 0.09, 6, hc)
			"cap":
				var cc2: Color = app.get("hat_col", Color(0.4, 0.3, 0.2))
				hk.ellipsoid(Vector3(0, 0.14, -0.005), Vector3(0.072, 0.045, 0.078), cc2, 5, 10)
				hk.box(Vector3(0, 0.135, 0.07), Vector3(0.1, 0.01, 0.05), cc2.darkened(0.2))
	if head_base.begins_with("plate"):
		var mc: Color = TIER_METAL[ht]
		hk.metal = 0.85
		hk.ellipsoid(Vector3(0, 0.095, -0.003), Vector3(0.08, 0.094, 0.086), mc, 7, 12)
		hk.metal = 0.0
		hk.box(Vector3(0, 0.094, 0.079), Vector3(0.1, 0.012, 0.012), Color(0.05, 0.05, 0.06))
		hk.metal = 0.85
		hk.box(Vector3(0, 0.06, 0.083), Vector3(0.012, 0.06, 0.01), mc.lightened(0.1))
		hk.loft([[Vector3(0, 0.02, 0), Vector2(0.078, 0.083)], [Vector3(0, 0.05, 0), Vector2(0.082, 0.087)]], mc.darkened(0.1), 12, false)
		if ht >= 3:
			hk.metal = 1.0
			hk.box(Vector3(0, 0.185, -0.005), Vector3(0.016, 0.03, 0.15), trim)
		if ht >= 5:
			hk.metal = 0.0
			hk.ellipsoid(Vector3(0, 0.215, -0.04), Vector3(0.018, 0.035, 0.09), Color(0.7, 0.1, 0.08), 4, 8)
		hk.metal = 0.0
	elif head_base.begins_with("leather"):
		var lc: Color = TIER_LEATHER[ht]
		hk.ellipsoid(Vector3(0, 0.1, -0.02), Vector3(0.08, 0.096, 0.083), lc, 6, 12)
		hk.cone(Vector3(0, 0.15, -0.07), 0.045, 0.08, 6, lc)
	elif head_base.begins_with("cloth"):
		var ccl: Color = TIER_CLOTH[ht]
		hk.cyl(Vector3(0, 0.14, 0), 0.12, 0.12, 0.012, 12, ccl.darkened(0.1))
		hk.cyl(Vector3(0, 0.15, 0), 0.075, 0.0, 0.2, 10, ccl, false)
	if app.has("crown"):
		hk.glow = 0.7
		hk.metal = 0.8
		for i in 7:
			var a := i * TAU / 7.0
			hk.cone(Vector3(cos(a) * 0.065, 0.16, sin(a) * 0.065), 0.018, 0.08 + (i % 2) * 0.04, 4, app.crown)
		hk.glow = 0.0
		hk.metal = 0.0
	if app.has("bandana"):
		hk.loft([[Vector3(0, 0.1, -0.003), Vector2(0.071, 0.078)], [Vector3(0, 0.14, -0.006), Vector2(0.068, 0.075)]], app.bandana, 12, false)
		hk.ellipsoid(Vector3(0, 0.035, 0.05), Vector3(0.058, 0.035, 0.035), app.bandana, 4, 10)
	var head := _part("head", torso, Vector3(0, 0.455, 0), hk)
	head.set_meta("human", true)

	# --- Ręce ---
	var arm_rings := [[Vector3(0, -0.425, 0.005), Vector2(0.026, 0.028)], [Vector3(0, -0.32, 0.005), Vector2(0.034, 0.036)],
		[Vector3(0, -0.22, 0), Vector2(0.033, 0.035)], [Vector3(0, -0.1, 0), Vector2(0.042, 0.044)], [Vector3(0, 0.02, 0), Vector2(0.046, 0.049)]]
	for side in [-1, 1]:
		var ak := MeshKit.new(41 + side)
		ak.metal = 0.85 if metal_body else 0.0
		ak.loft(arm_rings, sleeve, 10, true, [forearm, forearm, sleeve, sleeve])
		if metal_body:
			ak.ellipsoid(Vector3(0, -0.22, -0.02), Vector3(0.04, 0.035, 0.035), sleeve.lightened(0.1), 4, 8)
		ak.metal = 0.6 if metal_body else 0.0
		ak.ellipsoid(Vector3(0, -0.46, 0.008), Vector3(0.03, 0.045, 0.034), hand_col, 5, 8)
		ak.metal = 0.0
		var arm := _part("arm_l" if side < 0 else "arm_r", torso, Vector3(side * 0.19, 0.35, 0), ak)
		_part("hand_l" if side < 0 else "hand_r", arm, Vector3(0, -0.47, 0.02))

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
		parts["shield"].position = Vector3(-0.07, -0.3, 0.03)
	height = 1.2


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
			if base == "sword":
				_sword(k, t, metal, trim)
			else:
				k.box(Vector3(0, -0.03, 0), Vector3(0.035, 0.1, 0.035), grip)
				k.metal = 1.0
				k.box(Vector3(0, 0.06, 0), Vector3(0.18, 0.035, 0.05), metal.darkened(0.2))
				k.box(Vector3(0, 0.095, 0), Vector3(0.055, 0.46, 0.018), Color(0.5, 0.35, 0.25), Vector2(0.6, 1.0))
		"axe", "woodaxe":
			_axe(k, t, metal, trim, base == "axe")
		"mace", "club":
			_mace(k, t, metal, trim)
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
			_bow(k, t, trim)
		"hammer":
			k.box(Vector3(0, -0.05, 0), Vector3(0.035, 0.4, 0.035), grip)
			k.metal = 1.0
			k.box(Vector3(0, 0.33, 0), Vector3(0.07, 0.08, 0.16), IRON())
		"staff":
			# Kostur: sękate drzewce, szpony z metalu tieru, świecący klejnot.
			var wood := Color(0.34, 0.22, 0.13) if t < 7 else Color(0.2, 0.17, 0.22)
			k.loft([[Vector3(0, -0.45, 0), Vector2(0.016, 0.016)], [Vector3(0.01, 0.1, 0), Vector2(0.02, 0.02)], [Vector3(-0.01, 0.55, 0), Vector2(0.017, 0.017)]], wood, 7)
			k.metal = 1.0
			for a in 3:
				var ang := TAU * a / 3.0
				k.xf = Transform3D(Basis(Vector3.UP, ang), Vector3(0, 0.55, 0))
				k.loft([[Vector3(0, 0, 0.012), Vector2(0.01, 0.01)], [Vector3(0, 0.1, 0.05), Vector2(0.007, 0.007)], [Vector3(0, 0.18, 0.02), Vector2(0.003, 0.003)]], metal, 5)
				k.xf = Transform3D.IDENTITY
			k.metal = 0.0
			k.glow = 1.0
			k.ellipsoid(Vector3(0, 0.64, 0), Vector3(0.045, 0.05, 0.045), TIER_GLOW[t] if t > 1 else Color(0.5, 1.0, 0.4), 5, 8)
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


## Miecz: głowica, owinięty trzon, jelec, głownia o przekroju soczewki ze zbroczem, sztych.
func _sword(k: MeshKit, t: int, metal: Color, trim: Color) -> void:
	var grip := Color(0.22, 0.14, 0.08)
	var guard_col: Color = TIER_TRIM[t] if t >= 3 else metal.darkened(0.15)
	k.loft([[Vector3(0, -0.13, 0), Vector2(0.017, 0.017)], [Vector3(0, 0.0, 0), Vector2(0.019, 0.019)]], grip, 8)
	for i in 4:
		k.loft([[Vector3(0, -0.115 + i * 0.03, 0), Vector2(0.021, 0.021)], [Vector3(0, -0.105 + i * 0.03, 0), Vector2(0.021, 0.021)]], grip.lightened(0.2), 8, false)
	k.metal = 1.0
	k.ellipsoid(Vector3(0, -0.155, 0), Vector3(0.03, 0.03, 0.03), guard_col, 5, 8)
	# Jelec: belka z rozszerzonymi końcami, od T5 skrzydła.
	k.loft([[Vector3(0, -0.005, 0), Vector2(0.03, 0.025)], [Vector3(0, 0.025, 0), Vector2(0.03, 0.025)]], guard_col, 8)
	k.box(Vector3(0, 0.0, 0), Vector3(0.22 + t * 0.008, 0.028, 0.035), guard_col, Vector2(1.0, 0.8))
	for sd in [-1, 1]:
		k.ellipsoid(Vector3(sd * (0.115 + t * 0.004), 0.012, 0), Vector3(0.022, 0.022, 0.022), guard_col.lightened(0.1), 4, 8)
		if t >= 5:
			k.cone(Vector3(sd * 0.1, 0.02, 0), 0.02, 0.07, 5, guard_col)
	# Głownia.
	var ln := 0.5 + t * 0.012
	var wdt := 0.03 + (0.006 if t >= 6 else 0.0)
	var blade_col := metal.lightened(0.15) if t != 8 else Color(0.12, 0.11, 0.14)
	k.metal = 1.0
	k.loft([[Vector3(0, 0.025, 0), Vector2(wdt, 0.008)], [Vector3(0, ln * 0.6, 0), Vector2(wdt * 0.92, 0.007)],
		[Vector3(0, ln, 0), Vector2(wdt * 0.62, 0.005)], [Vector3(0, ln + 0.07, 0), Vector2(0.001, 0.001)]], blade_col, 8, false)
	k.metal = 0.6
	k.box(Vector3(0, 0.04, 0), Vector3(0.008, ln * 0.7, 0.0165), blade_col.darkened(0.35))
	# Runy / ognista krawędź.
	if t >= 6:
		k.glow = 1.0
		for i in 5:
			k.box(Vector3(0, 0.08 + i * ln * 0.12, 0.0), Vector3(0.012, 0.03, 0.0175), TIER_GLOW[t])
		k.glow = 0.0
	if t == 8:
		k.glow = 1.0
		for sd in [-1, 1]:
			k.box(Vector3(sd * wdt * 0.95, 0.03, 0), Vector3(0.004, ln * 0.95, 0.006), Color(1.0, 0.35, 0.08))
		k.glow = 0.0
	if t >= 4:
		k.glow = 1.0
		k.ellipsoid(Vector3(0, 0.012, 0.02), Vector3(0.012, 0.012, 0.008), TIER_GLOW[t], 4, 6)
		k.ellipsoid(Vector3(0, -0.155, 0.026), Vector3(0.01, 0.01, 0.006), TIER_GLOW[t], 4, 6)
		k.glow = 0.0
	k.metal = 0.0


## Topór: drzewce z okuciami, półksiężycowe ostrze (od T4 dwusieczne), kolec na szczycie.
func _axe(k: MeshKit, t: int, metal: Color, trim: Color, battle: bool) -> void:
	var wood := Color(0.36, 0.23, 0.13) if t < 7 else Color(0.2, 0.17, 0.2)
	k.loft([[Vector3(0, -0.28, 0), Vector2(0.019, 0.019)], [Vector3(0, 0.46, 0), Vector2(0.017, 0.017)]], wood, 8)
	k.metal = 1.0
	for y in [-0.28, 0.2]:
		k.loft([[Vector3(0, y, 0), Vector2(0.023, 0.023)], [Vector3(0, y + 0.04, 0), Vector2(0.023, 0.023)]], trim if t >= 3 else metal.darkened(0.3), 8)
	var sides := [1, -1] if (battle and t >= 4) else [1]
	for sd: int in sides:
		var z0 := 0.02 * sd
		var pts := []
		for i in 9:
			var a := lerpf(-1.1, 1.1, i / 8.0)
			pts.append(Vector3(0, 0.36 + sin(a) * 0.13, sd * (0.1 + cos(a) * 0.08)))
		var th := Vector3(0.008, 0, 0)
		var inner_top := Vector3(0, 0.42, z0)
		var inner_bot := Vector3(0, 0.3, z0)
		for i in 8:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			var q0 := inner_bot.lerp(inner_top, i / 8.0)
			var q1 := inner_bot.lerp(inner_top, (i + 1) / 8.0)
			for f in [1, -1]:
				k.quad(q0 + th * f * 1.6, q1 + th * f * 1.6, p1 + th * f * 0.3, p0 + th * f * 0.3, metal if f > 0 else metal.darkened(0.12), Vector3(f, 0, 0))
			k.quad(p0 + th * 0.3, p1 + th * 0.3, p1 - th * 0.3, p0 - th * 0.3, metal.lightened(0.35), Vector3(0, p0.y - 0.36, sd))
		if t >= 6:
			k.glow = 1.0
			k.box(Vector3(0, 0.36, sd * 0.1), Vector3(0.019, 0.05, 0.04), TIER_GLOW[t])
			k.glow = 0.0
	k.cone(Vector3(0, 0.46, 0), 0.02, 0.1, 5, metal)
	if t >= 5:
		k.glow = 1.0
		k.ellipsoid(Vector3(0.022, 0.36, 0), Vector3(0.008, 0.016, 0.016), TIER_GLOW[t], 4, 6)
		k.glow = 0.0
	k.metal = 0.0


## Buława z piórami (od T5 świecący klejnot na szczycie).
func _mace(k: MeshKit, t: int, metal: Color, trim: Color) -> void:
	var wood := Color(0.34, 0.22, 0.12)
	k.loft([[Vector3(0, -0.12, 0), Vector2(0.02, 0.02)], [Vector3(0, 0.38, 0), Vector2(0.02, 0.02)]], wood if t < 5 else metal.darkened(0.4), 8)
	k.metal = 1.0
	k.ellipsoid(Vector3(0, -0.14, 0), Vector3(0.03, 0.025, 0.03), trim, 4, 8)
	k.ellipsoid(Vector3(0, 0.44, 0), Vector3(0.055, 0.075, 0.055), metal, 5, 10)
	var flanges := 6 + (2 if t >= 4 else 0)
	for i in flanges:
		var a := TAU * i / flanges
		k.xf = Transform3D(Basis(Vector3.UP, a), Vector3(0, 0.44, 0))
		k.box(Vector3(0.05, -0.07, 0), Vector3(0.06, 0.14, 0.012), metal.lightened(0.12), Vector2(0.4, 1.0))
		k.xf = Transform3D.IDENTITY
	k.cone(Vector3(0, 0.51, 0), 0.02, 0.06, 5, metal)
	if t >= 5:
		k.glow = 1.0
		k.ellipsoid(Vector3(0, 0.57, 0), Vector3(0.018, 0.018, 0.018), TIER_GLOW[t], 4, 8)
		k.glow = 0.0
	k.metal = 0.0


## Łuk refleksyjny: dwie gładkie łopatki, owinięty uchwyt, cięciwa (T8 – żarząca się).
func _bow(k: MeshKit, t: int, trim: Color) -> void:
	var wood: Color = [Color(0.5, 0.33, 0.18), Color(0.5, 0.33, 0.18), Color(0.45, 0.28, 0.15), Color(0.35, 0.25, 0.2), Color(0.25, 0.16, 0.2),
		Color(0.4, 0.22, 0.1), Color(0.3, 0.1, 0.06), Color(0.85, 0.82, 0.75), Color(0.12, 0.1, 0.12)][t]
	var segs := 10
	var pts: Array = []
	for i in segs + 1:
		var a := lerpf(-1.0, 1.0, float(i) / segs)
		# Refleks: końce wygięte do przodu.
		var z := 0.1 * (1.0 - a * a) + 0.02 - 0.04 * pow(absf(a), 6.0)
		pts.append(Vector3(0, a * 0.4, z))
	for i in segs:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var r0 := lerpf(0.022, 0.009, absf(lerpf(-1.0, 1.0, float(i) / segs)))
		var r1 := lerpf(0.022, 0.009, absf(lerpf(-1.0, 1.0, float(i + 1) / segs)))
		var d := (p1 - p0).normalized()
		k.xf = Transform3D(Basis(Vector3.RIGHT, -atan2(d.z, d.y)), p0)
		k.loft([[Vector3.ZERO, Vector2(r0, r0 * 0.7)], [Vector3(0, (p1 - p0).length(), 0), Vector2(r1, r1 * 0.7)]], wood, 6, false)
		k.xf = Transform3D.IDENTITY
	k.loft([[Vector3(0, -0.07, 0.12), Vector2(0.026, 0.026)], [Vector3(0, 0.05, 0.12), Vector2(0.026, 0.026)]], Color(0.25, 0.15, 0.08), 8)
	k.metal = 1.0
	if t >= 3:
		for e in [pts[0], pts[segs]]:
			k.ellipsoid(e, Vector3(0.016, 0.016, 0.016), trim, 4, 6)
	k.metal = 0.0
	var top: Vector3 = pts[segs]
	var bot: Vector3 = pts[0]
	k.glow = 1.0 if t >= 8 else 0.0
	var sc := Color(1.0, 0.4, 0.1) if t >= 8 else Color(0.9, 0.88, 0.8)
	var s := Vector3(0.003, 0, 0)
	k.quad(bot - s, top - s, top + s, bot + s, sc, Vector3(0, 0, 1))
	k.quad(bot + s, top + s, top - s, bot - s, sc, Vector3(0, 0, -1))
	k.glow = 0.0


static func IRON() -> Color:
	return Color(0.34, 0.34, 0.37)


func _build_shield(id: String) -> void:
	var it := split_item(id)
	var t: int = clampi(it[1], 1, 8)
	var k := MeshKit.new(61)
	var face: Color = TIER_CLOTH[t] if t >= 2 else Color(0.5, 0.33, 0.18)
	var rim: Color = TIER_METAL[t]
	var trim: Color = TIER_TRIM[t]
	if t <= 1:
		# Okrągła drewniana tarcza z metalowym guzem i okuciem.
		k.cyl(Vector3(0, 0, 0), 0.2, 0.2, 0.035, 12, face, true, face.lightened(0.05))
		k.metal = 1.0
		k.cyl(Vector3(0, 0.03, 0), 0.21, 0.195, 0.015, 12, rim, false)
		k.ellipsoid(Vector3(0, 0.04, 0), Vector3(0.055, 0.03, 0.055), rim, 4, 8)
		k.metal = 0.0
	else:
		# Tarcza herbowa: metalowa obwódka, pole w barwie tieru, krzyż/herb, guz z klejnotem.
		var pts := [Vector3(-0.19, 0, 0.21), Vector3(0.19, 0, 0.21), Vector3(0.19, 0, -0.02), Vector3(0.12, 0, -0.18), Vector3(0.0, 0, -0.27), Vector3(-0.12, 0, -0.18), Vector3(-0.19, 0, -0.02)]
		for layer in 2:
			var y := 0.035 * layer
			var col := face if layer == 1 else rim
			k.metal = 0.0 if layer == 1 else 1.0
			var sc := 1.0 if layer == 0 else 0.85
			var c0 := Vector3(0, y + 0.012 * layer, 0)
			for i in pts.size():
				var a: Vector3 = pts[i] * sc + Vector3(0, y, 0)
				var b: Vector3 = pts[(i + 1) % pts.size()] * sc + Vector3(0, y, 0)
				k.tri(c0, a, b, col, Vector3.UP)
				if layer == 0:
					k.quad(a, b, b + Vector3(0, 0.04, 0), a + Vector3(0, 0.04, 0), rim, (a + b) / 2.0)
		k.metal = 1.0
		k.box(Vector3(0, 0.05, -0.02), Vector3(0.045, 0.015, 0.36), trim)
		k.box(Vector3(0, 0.05, 0.07), Vector3(0.26, 0.015, 0.045), trim)
		k.ellipsoid(Vector3(0, 0.06, 0.07), Vector3(0.045, 0.025, 0.045), rim.lightened(0.1), 4, 8)
		if t >= 4:
			k.glow = 1.0
			k.ellipsoid(Vector3(0, 0.08, 0.07), Vector3(0.018, 0.012, 0.018), TIER_GLOW[t], 4, 6)
			k.glow = 0.0
		if t >= 6:
			for sd in [-1, 1]:
				k.cone(Vector3(sd * 0.19, 0.03, 0.21), 0.02, 0.06, 4, rim)
		k.metal = 0.0
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
	# Tułów: gładka bryła wzdłuż osi Z (klatka piersiowa szersza niż zad).
	var bk := MeshKit.new(71)
	var prof := [[-0.5, 0.55, 0.6], [-0.38, 0.9, 0.92], [-0.1, 0.95, 0.95], [0.18, 1.0, 1.0], [0.38, 0.98, 1.02], [0.5, 0.6, 0.7]]
	var rings: Array = []
	for pr in prof:
		rings.append([float(pr[0]) * L, Vector2(W / 2.0 * float(pr[1]), H / 2.0 * float(pr[2])), 0.0])
	_zloft(bk, rings, fur, 12)
	bk.ellipsoid(Vector3(0, -H * 0.2, 0.02), Vector3(W * 0.42, H * 0.36, L * 0.4), belly, 5, 10)
	if look == "boar":
		for j in 6:
			bk.cone(Vector3(0, H / 2.0 - 0.03, L * 0.3 - j * L * 0.1), 0.03, 0.09, 4, fur.darkened(0.35))
	if look == "wolf" or look == "hound" or look == "mount_warwolf" or look == "snow_wolf":
		# Grzywa/kryza na karku.
		bk.ellipsoid(Vector3(0, H * 0.08, L * 0.3), Vector3(W * 0.6, H * 0.62, L * 0.22), fur.lightened(0.06), 5, 10)
	if look == "bear":
		bk.ellipsoid(Vector3(0, H * 0.22, L * 0.18), Vector3(W * 0.46, H * 0.4, L * 0.25), fur.darkened(0.05), 5, 10)
	if extra == "spikes":
		for j in 5:
			bk.cone(Vector3(0, H / 2.0 - 0.02, L / 2.5 - j * L / 6.0), 0.06, 0.14, 4, fur.darkened(0.35))
	if extra.begins_with("mount_"):
		# Czaprak i skórzane siodło z łękiem, strzemiona.
		bk.loft([[Vector3(0, H / 2.0 - 0.16, 0.02), Vector2(W * 0.56, 0.2)], [Vector3(0, H / 2.0 + 0.005, 0.02), Vector2(W * 0.52, 0.19)]], Color(0.55, 0.12, 0.1), 12, false)
		bk.ellipsoid(Vector3(0, H / 2.0 + 0.02, 0.02), Vector3(W * 0.36, 0.05, 0.16), Color(0.32, 0.2, 0.12), 4, 10)
		bk.ellipsoid(Vector3(0, H / 2.0 + 0.06, 0.14), Vector3(W * 0.2, 0.05, 0.04), Color(0.28, 0.17, 0.1), 4, 8)
		bk.metal = 1.0
		for side in [-1, 1]:
			bk.box(Vector3(side * W * 0.56, -0.08, 0.02), Vector3(0.015, 0.2, 0.015), Color(0.3, 0.2, 0.12))
			bk.box(Vector3(side * W * 0.56, -0.1, 0.02), Vector3(0.05, 0.02, 0.06), Color(0.75, 0.66, 0.42))
		bk.metal = 0.0
		if extra == "mount_camel":
			bk.ellipsoid(Vector3(0, H / 2.0 + 0.05, -0.22), Vector3(0.14, 0.14, 0.17), fur, 5, 10)
		if extra == "mount_warwolf":
			bk.metal = 0.9
			bk.loft([[Vector3(0, H / 2.0 - 0.1, L * 0.28), Vector2(W * 0.6, 0.12)], [Vector3(0, H / 2.0 + 0.02, L * 0.28), Vector2(W * 0.55, 0.11)]], Color(0.45, 0.45, 0.5), 10, false)
			bk.metal = 0.0
	if cracks:
		bk.glow = 1.0
		for j in 4:
			bk.box(Vector3((j % 2 - 0.5) * 0.08, H / 2.0 - 0.005, -L / 3.0 + j * L / 5.0), Vector3(0.03, 0.012, 0.1), Color(1.0, 0.4, 0.1))
		bk.glow = 0.0
	var body := _part("body", root, Vector3(0, leg + H / 2.0, 0), bk)
	# Głowa: czaszka, pysk zwężający się do nosa, oczy.
	var hk := MeshKit.new(72)
	var snout_col := fur.lightened(0.1)
	if look == "rat":
		snout_col = fur
	if look == "boar":
		snout_col = Color(0.62, 0.45, 0.4)
	hk.ellipsoid(Vector3(0, -head.y / 2.0, 0), head * 0.55, fur, 6, 10)
	var sn_len := head.z * (0.75 if extra.begins_with("mount_") and extra != "mount_warwolf" else 0.6)
	_zloft(hk, [[head.z * 0.1, Vector2(head.x * 0.38, head.y * 0.34), -head.y * 0.58], [head.z * 0.3 + sn_len * 0.5, Vector2(head.x * 0.3, head.y * 0.27), -head.y * 0.66],
		[head.z * 0.3 + sn_len, Vector2(head.x * 0.2, head.y * 0.2), -head.y * 0.7]], snout_col, 10)
	var nose_col := Color(0.9, 0.55, 0.55) if look == "rat" else Color(0.08, 0.06, 0.06)
	hk.ellipsoid(Vector3(0, -head.y * 0.66, head.z * 0.3 + sn_len), Vector3(head.x * 0.16, head.y * 0.12, 0.02), nose_col, 4, 8)
	if look == "boar":
		for side in [-1, 1]:
			hk.cone(Vector3(side * 0.07, -head.y * 0.75, head.z * 0.3 + sn_len * 0.7), 0.018, 0.11, 5, Color(0.95, 0.92, 0.82))
	if ear == "pointy" or look in ["wolf", "hound", "snow_wolf", "mount_warwolf"]:
		# Kły w pysku drapieżników.
		if not extra.begins_with("mount_") or extra == "mount_warwolf":
			for side in [-1, 1]:
				hk.cone(Vector3(side * head.x * 0.1, -head.y * 0.86, head.z * 0.3 + sn_len * 0.85), 0.008, -0.03, 4, Color(0.95, 0.93, 0.85))
	hk.glow = eye_glow
	for side in [-1, 1]:
		hk.ellipsoid(Vector3(side * head.x * 0.27, -head.y * 0.34, head.z * 0.24), Vector3(0.022, 0.018, 0.012), eye, 4, 6)
	hk.glow = 0.0
	if extra == "mount_elk":
		for side in [-1, 1]:
			for j in 3:
				hk.xf = Transform3D(Basis(Vector3(0, 0, 1), -side * (0.5 + j * 0.3)), Vector3(side * 0.07, head.y / 2.0 - head.y * 0.5, -0.05))
				hk.cone(Vector3.ZERO, 0.02, 0.3 - j * 0.05, 5, Color(0.88, 0.8, 0.62))
			hk.xf = Transform3D.IDENTITY
	if extra == "mount_horse":
		hk.ellipsoid(Vector3(0, -head.y * 0.05, -0.02), Vector3(0.03, 0.08, 0.12), Color(0.18, 0.12, 0.08), 4, 8)
		# Uzda.
		hk.loft([[Vector3(0, -head.y * 0.66, head.z * 0.3 + sn_len * 0.55), Vector2(head.x * 0.33, head.y * 0.3)], [Vector3(0, -head.y * 0.62, head.z * 0.3 + sn_len * 0.6), Vector2(head.x * 0.33, head.y * 0.3)]], Color(0.25, 0.15, 0.08), 10, false)
	for side in [-1, 1]:
		if ear == "none":
			continue
		if ear == "round":
			hk.ellipsoid(Vector3(side * head.x * 0.36, -head.y * 0.02, -0.02), Vector3(0.045, 0.045, 0.02) * (2.0 if look == "bear" else 1.0), ear_col, 4, 8)
		else:
			hk.cone(Vector3(side * head.x * 0.25, -head.y * 0.12, -head.z * 0.12), head.x * 0.13, head.y * 0.5, 5, fur.darkened(0.1))
	var head_node := _part("head", body, Vector3(0, H * 0.25, L / 2.0 + head.z * 0.35), hk)
	head_node.rotation.x = 0.1
	# Nogi: udo szersze u góry, zwężające się do pęciny; kopyta lub łapy.
	var i := 0
	var hooves := extra.begins_with("mount_") and extra != "mount_warwolf"
	for fz in [1, -1]:
		for side in [-1, 1]:
			var lk := MeshKit.new(80 + i)
			var top_r := W * (0.2 if fz < 0 else 0.17)
			lk.loft([[Vector3(0, -leg - 0.02, 0.0), Vector2(W * 0.08, W * 0.09)], [Vector3(0, -leg * 0.55, 0.0), Vector2(W * 0.1, W * 0.11)],
				[Vector3(0, -leg * 0.2, 0.0), Vector2(top_r * 0.8, top_r)], [Vector3(0, 0.04, 0.0), Vector2(top_r, top_r * 1.1)]], fur.darkened(0.08), 8, true)
			if hooves:
				lk.loft([[Vector3(0, -leg - 0.05, 0.01), Vector2(W * 0.11, W * 0.12)], [Vector3(0, -leg - 0.0, 0.0), Vector2(W * 0.09, W * 0.1)]], Color(0.15, 0.12, 0.1), 8, true)
			else:
				lk.ellipsoid(Vector3(0, -leg - 0.035, 0.025), Vector3(W * 0.12, 0.03, W * 0.16), fur.darkened(0.3), 4, 8)
			var nm: String = ["leg_fl", "leg_fr", "leg_bl", "leg_br"][i]
			_part(nm, root, Vector3(side * W * 0.3, leg + 0.02, fz * L * 0.34), lk)
			i += 1
	# Ogon.
	var tk := MeshKit.new(90)
	match tail:
		"thin":
			_zloft(tk, [[0.0, Vector2(0.02, 0.02), 0.0], [-0.2, Vector2(0.012, 0.012), -0.03], [-0.38, Vector2(0.004, 0.004), -0.02]], Color(0.85, 0.6, 0.6), 6)
		"stub":
			tk.ellipsoid(Vector3(0, -0.01, -0.03), Vector3(0.035, 0.035, 0.05), fur, 4, 8)
		"bushy":
			tk.ellipsoid(Vector3(0, -0.04, -0.16), Vector3(0.07, 0.07, 0.18), fur.lightened(0.05), 5, 10)
			tk.ellipsoid(Vector3(0, -0.05, -0.3), Vector3(0.045, 0.045, 0.07), fur.lightened(0.25), 4, 8)
		"flame":
			tk.ellipsoid(Vector3(0, -0.04, -0.15), Vector3(0.05, 0.05, 0.16), fur, 5, 8)
			tk.glow = 1.0
			tk.cone(Vector3(0, 0.0, -0.3), 0.07, 0.2, 5, Color(1.0, 0.45, 0.1))
		"thick":
			_zloft(tk, [[0.0, Vector2(0.12, 0.09), -0.03], [-0.3, Vector2(0.08, 0.06), -0.08], [-0.6, Vector2(0.04, 0.03), -0.12], [-0.8, Vector2(0.005, 0.005), -0.12]], fur.darkened(0.05), 10)
		"flowing":
			_zloft(tk, [[0.0, Vector2(0.05, 0.05), -0.02], [-0.1, Vector2(0.06, 0.06), -0.15], [-0.14, Vector2(0.05, 0.05), -0.32], [-0.12, Vector2(0.01, 0.01), -0.42]], Color(0.18, 0.12, 0.08), 8)
	var tail_node := _part("tail", body, Vector3(0, H * 0.2, -L / 2.0), tk)
	tail_node.rotation.x = -0.5 if tail == "bushy" or tail == "flame" else 0.1
	height = leg + H + head.y
	riding_height = leg + H + 0.05
	if extra == "mount_horse" or extra == "mount_camel" or extra == "mount_elk":
		# Długa szyja: głowa wyżej i dalej.
		head_node.position += Vector3(0, 0.2 if extra != "mount_camel" else 0.3, 0.05)
		head_node.rotation.x = -0.2
		var nk := MeshKit.new(95)
		var nl := 0.36 if extra != "mount_camel" else 0.46
		nk.loft([[Vector3(0, -0.28, 0), Vector2(W * 0.34, W * 0.4)], [Vector3(0, -0.28 + nl * 0.6, 0.01), Vector2(W * 0.25, W * 0.3)], [Vector3(0, -0.28 + nl, 0.02), Vector2(W * 0.22, W * 0.26)]], fur, 10, true)
		if extra == "mount_horse":
			nk.ellipsoid(Vector3(0, -0.08, -0.07), Vector3(0.03, nl * 0.5, 0.05), Color(0.18, 0.12, 0.08), 5, 8)
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


## Gładka bryła wzdłuż osi Z: rings = [[z, Vector2(promień poziomy, pionowy), wysokość środka], ...].
static func _zloft(k: MeshKit, rings: Array, col: Color, sides := 10) -> void:
	var saved := k.xf
	k.xf = saved * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	var lr: Array = []
	for r in rings:
		lr.append([Vector3(0, float(r[0]), -float(r[2])), r[1]])
	k.loft(lr, col, sides, true)
	k.xf = saved


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
		if _attack_kind == "cast":
			# Rzucanie czaru: obie ręce unoszą się do przodu.
			var up := sin(minf(1.0, k * 1.6) * PI / 2.0) * (1.0 - maxf(0.0, k - 0.7) / 0.3)
			arm_l.rotation.x = lerpf(arm_l.rotation.x, -1.6, up)
			arm_r.rotation.x = lerpf(arm_r.rotation.x, -1.7, up)
			arm_l.rotation.z = -0.25 * up
			arm_r.rotation.z = 0.25 * up
		elif _attack_kind == "bow":
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
