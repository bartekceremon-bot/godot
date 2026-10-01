class_name RelicsPanel
extends IdlePanel
## Relikwiarz: odłamki, losowanie relikwii, kolekcja 12 relikwii w 4 zestawach z premiami.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Relikwiarz", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var r := gm.relics
	var c := IdleUI.card()
	var h := IdleUI.hbox(12)
	c.add_child(h)
	h.add_child(IdleUI.icon_rect(load("res://assets/ui/modes/shard.png"), 72))
	var v := IdleUI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(IdleUI.label("Odłamki relikwii: %d" % r.shards(), 24, Color(0.85, 0.65, 1.0)))
	v.add_child(IdleUI.label("Kolekcja: %d / %d  •  odłamki z Lochów Żaru, Areny i nagród tygodnia." % [r.owned_count(), RelicManager.RELICS.size()], 17, IdleUI.DIM, true))
	var pb := IdleUI.button("Odkryj relikwię (%d odłamków)" % RelicManager.PULL_COST, Vector2(0, 84), 23)
	IdleUI.set_affordable(pb, r.can_pull())
	pb.pressed.connect(func():
		var got := gm.relics.pull()
		if got.is_empty():
			return
		var id := str(got[0])
		var lv := int(got[1])
		ui.banner(RelicManager.relic_name(id).to_upper(), ("Nowa relikwia!" if lv == 1 else "Poziom %d" % lv) + "  •  " + RelicManager.describe(id, lv), Color(0.85, 0.6, 1.0))
		gm.audio.play("levelup")
		request_refresh())
	v.add_child(pb)
	_box.add_child(c)
	for sid in RelicManager.SET_ORDER:
		var s: Array = RelicManager.SETS[sid]
		var sl := r.set_level(sid)
		_box.add_child(IdleUI.label("%s  •  komplet: +%d%% %s, komplet 5+: +%d%%%s" % [s[0], roundi(float(s[2]) * 100), s[4], roundi(float(s[3]) * 100), ["", "  ✔", "  ✔✔"][sl]], 19, IdleUI.GOOD if sl > 0 else UiTheme.ACCENT, true))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for id in RelicManager.RELICS:
			if str(RelicManager.RELICS[id][1]) != sid:
				continue
			grid.add_child(_relic_tile(id))
		_box.add_child(grid)


func _relic_tile(id: String) -> Control:
	var lv := gm.relics.level(id)
	var c := IdleUI.card(Color(0.07, 0.06, 0.09, 0.9), Color(0.8, 0.55, 1.0, 0.35) if lv > 0 else Color(1, 1, 1, 0.08))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := IdleUI.vbox(2)
	c.add_child(v)
	var ic := IdleUI.icon_rect(load("res://assets/ui/modes/relic_%s.png" % id), 72)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if lv == 0:
		ic.modulate = Color(0.15, 0.13, 0.17, 0.85)
	v.add_child(ic)
	var n := IdleUI.label(RelicManager.relic_name(id), 15, Color(0.95, 0.9, 0.82) if lv > 0 else IdleUI.DIM, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var d := IdleUI.label(("poz. %d  •  " % lv + RelicManager.describe(id, lv)) if lv > 0 else "nieodkryta", 14, IdleUI.GOOD if lv > 0 else IdleUI.DIM, true)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	return c


func on_changed(what: String) -> void:
	if what in ["relics", "all"]:
		request_refresh()
