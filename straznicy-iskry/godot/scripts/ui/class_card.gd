extends PanelContainer
## Karta klasy z animowanym podglądem postaci i opisem umiejętności.

signal chosen(class_id: String)

var class_id := "tkacz"
var preview: Control
var _t := 0.0
var _compact := false


func setup(cid: String, compact: bool, current := false) -> void:
	class_id = cid
	_compact = compact
	theme_type_variation = "Card"
	var d := Data.get_class_def(cid)
	var pal := Art.palette(cid)
	add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), pal["glow"] if not current else Art.GOLD, 16, 3 if current else 2, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	preview = Control.new()
	preview.custom_minimum_size = Vector2(110, 130) if not compact else Vector2(80, 96)
	preview.draw.connect(_draw_preview)
	top.add_child(preview)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 2)
	top.add_child(tv)
	var n := UITheme.label(d.get("name", cid), "Header")
	n.add_theme_color_override("font_color", pal["glow"])
	tv.add_child(n)
	tv.add_child(UITheme.label(d.get("title", ""), "Bold"))
	tv.add_child(UITheme.label(d.get("short", ""), "Small"))
	if not compact:
		var skills := VBoxContainer.new()
		skills.add_theme_constant_override("separation", 2)
		v.add_child(skills)
		for slot in ["basic", "skill1", "skill2", "passive"]:
			var s: Dictionary = d.get(slot, {})
			var label = {"basic": "Atak", "skill1": "Umiejętność", "skill2": "Umiejętność", "passive": "Pasywna"}[slot]
			skills.add_child(UITheme.rich("[color=#e8b84a]%s:[/color] [b]%s[/b] — %s" % [label, s.get("name", ""), s.get("desc", "")]))
		var teach := UITheme.rich("[color=#3fd1c1]Uczy:[/color] " + str(d.get("teaches", "")))
		v.add_child(teach)
	var b := UITheme.button("Obecna klasa" if current else "Wybierz: " + str(d.get("name", cid)), func() -> void: chosen.emit(class_id), "Primary" if not current else "")
	b.disabled = current
	v.add_child(b)


func _process(delta: float) -> void:
	_t += delta
	preview.queue_redraw()


func _draw_preview() -> void:
	var s := preview.size
	preview.draw_circle(Vector2(s.x * 0.5, s.y * 0.62), s.x * 0.42, Color(Art.palette(class_id)["glow"], 0.12))
	var k := s.y / 85.0
	var attack := maxf(0.0, sin(_t * 1.3)) if fmod(_t, 4.0) > 3.0 else 0.0
	Art.with_parent(Transform2D(0, Vector2(k, k), 0, Vector2(s.x * 0.5, s.y * 0.92)))
	Art.hero(preview, class_id, {"t": _t, "aim": Vector2.RIGHT, "attack": attack, "reduced": Settings.reduced_motion})
	Art.with_parent(Transform2D.IDENTITY)
	preview.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
