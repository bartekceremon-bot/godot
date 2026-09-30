class_name GroundItems3D
extends Node3D
## Przedmioty leżące na ziemi (loot): unosząca się ikona przedmiotu z cieniem i poświatą rzadkości.

## id -> {x, y, it, c, q}
var items: Dictionary = {}
var overlay: Overlay2D
var _nodes: Dictionary = {}
var _t := 0.0


func set_items(list: Array) -> void:
	items.clear()
	for g in list:
		items[int(g.i)] = g
	for id in _nodes.keys():
		if not items.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)
	var stacks: Array = []
	for id in items:
		var g: Dictionary = items[id]
		if not _nodes.has(id):
			_nodes[id] = _make(g)
		var n: Node3D = _nodes[id]
		n.position = Vector3(int(g.x) + 0.5, 0.0, int(g.y) + 0.5) + _jitter(id)
		if int(g.c) > 1:
			stacks.append([n.position + Vector3(0, 0.25, 0), int(g.c)])
	if overlay:
		overlay.stacks = stacks


func _jitter(id: int) -> Vector3:
	return Vector3(float(id * 37 % 11) / 11.0 - 0.5, 0, float(id * 53 % 13) / 13.0 - 0.5) * 0.3


## Zwraca id przedmiotu na kafelku (ostatnio dodany na wierzchu) albo 0.
func item_at(tile: Vector2i) -> int:
	var found := 0
	for id in items:
		var g: Dictionary = items[id]
		if int(g.x) == tile.x and int(g.y) == tile.y:
			found = id
	return found


func _make(g: Dictionary) -> Node3D:
	var root := Node3D.new()
	var def := GameData.item_def(str(g.it))
	var spr := Sprite3D.new()
	spr.texture = Sprites.item_icon_for(def)
	spr.pixel_size = 0.016
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.position.y = 0.3
	spr.name = "Icon"
	root.add_child(spr)
	var shadow := MeshInstance3D.new()
	var k := MeshKit.new(1)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		k.tri(Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * 0.18, Vector3(cos(a1), 0, sin(a1)) * 0.18, Color.BLACK, Vector3.UP)
	shadow.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var q := int(g.get("q", 1))
	var tier := int(def.get("tier", 0))
	m.albedo_color = Color(0, 0, 0, 0.3)
	if q >= 3 or tier >= 3:
		m.albedo_color = Color(Sprites.QUALITY_COLORS[clampi(q, 0, 5)] if q >= 3 else Sprites.TIER_COLORS[tier], 0.55)
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shadow.material_override = m
	shadow.position.y = 0.04
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	add_child(root)
	root.scale = Vector3.ONE * 0.1
	create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


func _process(delta: float) -> void:
	_t += delta
	for id in _nodes:
		var n: Node3D = _nodes[id]
		var icon: Node3D = n.get_node("Icon")
		icon.position.y = 0.3 + sin(_t * 2.5 + id) * 0.04
