extends WindowPanel
## Drzewko specjalizacji: zbieractwo i rzemiosło. Poziom rośnie od używania,
## odblokowuje wyższe tiery i daje premie (więcej surowca, lepsza jakość).

var _box: VBoxContainer


func _init() -> void:
	super._init("Specjalizacje", Vector2(760, 0))
	var sl := UiTheme.scroll_list(Vector2(740, 460))
	content.add_child(sl[0])
	_box = sl[1]


## specs: [[id, poziom, procent], ...] z pakietu stats.
func set_specs(specs: Array) -> void:
	UiTheme.clear(_box)
	var by_id := {}
	for s in specs:
		by_id[str(s[0])] = s
	for group in [["gathering", "Zbieractwo"], ["crafting", "Rzemiosło"]]:
		_box.add_child(UiTheme.label(group[1], 22, UiTheme.ACCENT))
		for d in GameData.spec_defs:
			if d.group != group[0] or not by_id.has(d.id):
				continue
			var s: Array = by_id[d.id]
			var lvl := int(s[1])
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var name_l := UiTheme.label("%s  %d" % [d.name, lvl], 20)
			name_l.custom_minimum_size = Vector2(210, 0)
			row.add_child(name_l)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(140, 16)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.show_percentage = false
			bar.value = float(s[2])
			row.add_child(bar)
			var info := UiTheme.label("%s\n%s" % [d.description, _perks(d.group, lvl)], 15, Color(0.8, 0.75, 0.7))
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(info)
			_box.add_child(row)


func _perks(group: String, lvl: int) -> String:
	var max_tier := 0
	var next := ""
	for t in range(1, GameData.tier_spec_req.size()):
		if lvl >= int(GameData.tier_spec_req[t]):
			max_tier = t
		elif next.is_empty():
			next = "  •  T%d od poziomu %d" % [t, int(GameData.tier_spec_req[t])]
	var bonus := ("dodatkowy surowiec: %d%%" % mini(50, lvl * 2)) if group == "gathering" else "lepsza jakość z każdym poziomem"
	return "Odblokowane: do T%d%s  •  %s" % [max_tier, next, bonus]
