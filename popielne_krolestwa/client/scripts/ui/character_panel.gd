extends PanelContainer
## Okno postaci: poziom, doświadczenie, skille (rosną od używania).

var _info: Label
var _skills: VBoxContainer


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiTheme.label("Postać", 26, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiTheme.button("X", "", Vector2(56, 56))
	close.pressed.connect(hide)
	header.add_child(close)
	_info = UiTheme.label("", 20)
	root.add_child(_info)
	_skills = VBoxContainer.new()
	root.add_child(_skills)
	custom_minimum_size = Vector2(460, 0)


func set_stats(s: Dictionary) -> void:
	var to_next := int(s.expNext) - int(s.exp)
	_info.text = "%s\nPoziom: %d\nDoświadczenie: %d (do awansu: %d)\nZdrowie: %d/%d   Mana: %d/%d" % [
		GameData.my_name, int(s.lvl), int(s.exp), to_next, int(s.hp), int(s.mhp), int(s.mp), int(s.mmp)]
	for c in _skills.get_children():
		c.queue_free()
	for key in GameData.SKILL_LABELS:
		if not s.skills.has(key):
			continue
		var row := HBoxContainer.new()
		var name_l := UiTheme.label(GameData.SKILL_LABELS[key], 20)
		name_l.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_l)
		var lvl := UiTheme.label(str(int(s.skills[key][0])), 20, Color(1, 0.85, 0.4))
		lvl.custom_minimum_size = Vector2(50, 0)
		row.add_child(lvl)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(200, 18)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.value = float(s.skills[key][1])
		row.add_child(bar)
		_skills.add_child(row)
