extends Node2D
## Buduje obszar gry z pliku data/areas/<id>.json.

const ISLAND := preload("res://scripts/world/island.gd")
const BRIDGE := preload("res://scripts/world/bridge.gd")
const PROP := preload("res://scripts/world/prop.gd")
const GRASS := preload("res://scripts/world/grass.gd")
const WOBJ := preload("res://scripts/world/world_object.gd")
const INTER := preload("res://scripts/world/interactable.gd")
const ENEMY := preload("res://scripts/actors/enemy.gd")
const BOSS := preload("res://scripts/actors/boss.gd")
const CANOPY := preload("res://scripts/world/canopy.gd")

var id := ""
var def: Dictionary = {}
var ground: Node2D
var grass_layer: Node2D
var entities: Node2D
var effects: Node2D
var foreground: Node2D
var walls: StaticBody2D
var islands: Array = []
var bridges: Array = []
var walk_outer: Array = []
var walk_holes: Array = []
var bounds := Rect2()
var grass_material: ShaderMaterial
var boss: Node = null
var _triggers_fired: Dictionary = {}


func build(area_id: String) -> void:
	id = area_id
	def = Data.get_area(area_id)
	ground = _layer("Ground", -10)
	grass_layer = _layer("Grass", -9)
	entities = _layer("Entities", 0)
	entities.y_sort_enabled = true
	effects = _layer("Effects", 10)
	foreground = _layer("Foreground", 30)
	walls = StaticBody2D.new()
	walls.collision_layer = 1
	add_child(walls)
	var pal: Dictionary = def.get("palette", {})
	grass_material = ShaderMaterial.new()
	grass_material.shader = preload("res://assets/shaders/grass.gdshader")
	grass_material.set_shader_parameter("wind", 0.4 if Settings.reduced_motion else 1.0)
	for i in def.get("islands", []).size():
		var idef: Dictionary = def["islands"][i]
		var r := Rect2(idef["rect"][0], idef["rect"][1], idef["rect"][2], idef["rect"][3])
		var isl: Node2D = ISLAND.new()
		isl.setup(r, int(idef.get("seed", i + 1)), pal)
		ground.add_child(isl)
		islands.append(isl)
		bounds = r if i == 0 else bounds.merge(r)
		_scatter_grass(isl, r, int(idef.get("grass", 1)) , pal)
	for bdef in def.get("bridges", []):
		var b: Node2D = BRIDGE.new()
		b.setup(bdef)
		ground.add_child(b)
		bridges.append(b)
		b.built_changed.connect(rebuild_walls)
	for path in def.get("paths", []):
		var line := Line2D.new()
		for p in path:
			line.add_point(Vector2(p[0], p[1]))
		line.width = 46.0
		line.default_color = Data.col(pal.get("path", "#cbbf9f"), Color("#cbbf9f"))
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		ground.add_child(line)
	for o in def.get("objects", []):
		var w: Node2D = WOBJ.new()
		w.position = _v(o["pos"])
		w.setup(o)
		if o["type"] in ["water", "conveyor", "flowerbed"]:
			ground.add_child(w)
		else:
			entities.add_child(w)
	for pdef in def.get("props", []):
		_add_prop(pdef)
	for n in def.get("npcs", []):
		_add_inter("npc", n)
	for s in def.get("stations", []):
		var d: Dictionary = s.duplicate()
		d["id"] = s["mission"]
		_add_inter("station", d)
	for p in def.get("portals", []):
		_add_inter("portal", p)
	for c in def.get("chests", []):
		_add_inter("chest", c)
	for c in def.get("checkpoints", []):
		_add_inter("checkpoint", c)
	for s in def.get("secrets", []):
		_add_inter("secret", s)
	for s in def.get("class_spots", []):
		_add_inter("class_spot", s)
	for s in def.get("lore", []):
		_add_inter("lore", s)
	if def.has("pedestal"):
		_add_inter("pedestal", def["pedestal"])
	if def.has("altar"):
		_add_inter("altar", def["altar"])
	for c in def.get("foreground", []):
		var cn: Node2D = CANOPY.new()
		cn.position = _v(c["pos"])
		cn.kind = c.get("type", "leaves")
		foreground.add_child(cn)
	spawn_enemies()
	rebuild_walls()


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	add_child(l)
	return l


func _v(a: Variant) -> Vector2:
	return Vector2(a[0], a[1])


func _scatter_grass(isl: Node2D, r: Rect2, density: int, pal: Dictionary) -> void:
	if density <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.position.x * 3 + r.position.y)
	var n := int(r.size.x * r.size.y / 52000.0) * density
	if Settings.low_quality():
		n = int(n * 0.4)
	var tint: Color = Data.col(pal.get("grass", "#5aa854"))
	for i in n:
		var p := Vector2(rng.randf_range(r.position.x + 30, r.end.x - 30), rng.randf_range(r.position.y + 30, r.end.y - 30))
		if not Geometry2D.is_point_in_polygon(p, isl.poly):
			continue
		var g: Node2D = GRASS.new()
		g.position = p
		g.setup(12 if Settings.low_quality() else 20, rng.randf_range(24, 46), tint, rng.randi())
		g.material = grass_material
		grass_layer.add_child(g)


func _add_prop(pdef: Dictionary) -> void:
	var pr: Node2D = PROP.new()
	pr.position = _v(pdef["pos"])
	pr.setup(pdef)
	entities.add_child(pr)
	var r: float = pr.collide_radius()
	if r > 0.0 and pdef.get("collide", true):
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = r
		cs.shape = shape
		body.position = pr.position
		body.add_child(cs)
		add_child(body)


func _add_inter(kind: String, d: Dictionary) -> Node2D:
	var n: Node2D = INTER.new()
	n.position = _v(d["pos"])
	entities.add_child(n)
	n.setup(kind, d)
	return n


func spawn_enemies() -> void:
	for e in def.get("enemies", []):
		if not GameState.flags_met(e.get("requires", "")):
			continue
		if e.has("until") and GameState.has_flag(e["until"]):
			continue
		if e.get("chaos", false) and GameState.data.get("game_complete", false):
			continue
		var en: Node2D = ENEMY.new()
		en.setup(e["type"], _v(e["pos"]), e)
		entities.add_child(en)
	if def.has("boss"):
		var b: Dictionary = def["boss"]
		if GameState.flags_met(b.get("requires", "")) and not GameState.has_flag(b.get("until", "boss_defeated")):
			boss = BOSS.new()
			boss.position = _v(b["pos"])
			boss.set_process(false)
			boss.set_physics_process(false)
			entities.add_child(boss)


func wake_boss() -> void:
	if boss and is_instance_valid(boss) and not boss.is_physics_processing():
		boss.set_process(true)
		boss.set_physics_process(true)
		return


func rebuild_walls() -> void:
	## Kolizje = granica sumy wszystkich chodliwych wielokątów (wyspy + zbudowane mosty).
	var polys: Array = []
	for isl in islands:
		polys.append(isl.walk_polygon())
	for b in bridges:
		if b.is_built():
			polys.append(b.walk_polygon())
	var outer: Array = []
	var holes: Array = []
	for p in polys:
		var cur: PackedVector2Array = p
		var merged := true
		while merged:
			merged = false
			for i in outer.size():
				if Geometry2D.intersect_polygons(outer[i], cur).is_empty():
					continue
				var res := Geometry2D.merge_polygons(outer[i], cur)
				var best := 0
				for k in res.size():
					if absf(_area(res[k])) > absf(_area(res[best])):
						best = k
				for k in res.size():
					if k != best:
						holes.append(res[k])
				cur = res[best]
				outer.remove_at(i)
				merged = true
				break
		outer.append(cur)
	walk_outer = outer
	walk_holes = holes
	for c in walls.get_children():
		c.queue_free()
	for p in outer + holes:
		var cp := CollisionPolygon2D.new()
		cp.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		var closed: PackedVector2Array = p.duplicate()
		closed.append(p[0])
		cp.polygon = closed
		walls.add_child(cp)


func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


func is_walkable(p: Vector2) -> bool:
	for h in walk_holes:
		if Geometry2D.is_point_in_polygon(p, h):
			return false
	for o in walk_outer:
		if Geometry2D.is_point_in_polygon(p, o):
			return true
	return false


func spawn_point(name: String) -> Vector2:
	var sp: Dictionary = def.get("spawns", {})
	if sp.has(name):
		return _v(sp[name])
	if sp.has("start"):
		return _v(sp["start"])
	return Vector2.ZERO


func check_triggers(player_pos: Vector2) -> void:
	for i in def.get("triggers", []).size():
		var tr: Dictionary = def["triggers"][i]
		var key := "%s_%d" % [id, i]
		if _triggers_fired.has(key):
			continue
		var once: String = tr.get("once", "")
		if not once.is_empty() and GameState.has_flag(once):
			continue
		if not GameState.flags_met(tr.get("requires", "")):
			continue
		var r := Rect2(tr["rect"][0], tr["rect"][1], tr["rect"][2], tr["rect"][3])
		if r.has_point(player_pos):
			_triggers_fired[key] = true
			if not once.is_empty():
				GameState.set_flag(once)
			World.current.run_trigger(tr)
