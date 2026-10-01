class_name TalentsPanel
extends IdlePanel
## Drzewko talentów: zakładki gałęzi (Wojownik / Dowódca / Mistyk), węzły jeden pod drugim
## połączone żarzącą się linią; zablokowane węzły pokazują wymaganie.

var _branch := 0
var _head: Label
var _list: VBoxContainer
var _tabs: Dictionary


func build() -> void:
	var h := IdleUI.hbox(10)
	add_child(h)
	var t := IdleUI.title("Talenty", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var rb := IdleUI.button("Reset", Vector2(130, 60), 20)
	rb.pressed.connect(func():
		var c := gm.talents.reset_cost()
		ui.confirm("Reset talentów", "Zwrócić wszystkie punkty talentów?" + (" Koszt: %d żarokryształów." % c if c > 0 else " Pierwszy reset jest darmowy."), func():
			if not gm.talents.reset():
				ui.toast_msg("Za mało żarokryształów.", IdleUI.BAD)
			request_refresh()))
	h.add_child(rb)
	_head = IdleUI.label("", 18, Color(0.92, 0.88, 0.8), true)
	add_child(_head)
	_tabs = sub_tabs([["0", "Wojownik"], ["1", "Dowódca"], ["2", "Mistyk"]], func(id):
		_branch = int(id)
		request_refresh())
	_tabs["0"].set_pressed_no_signal(true)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	_head.text = "Wolne punkty: %d  •  zdobyte: %d (połowa rekordu poziomu + 1 za każde 5 pięter Wieży Popiołu)" % [gm.talents.free_points(), gm.talents.earned()]
	IdleUI.clear(_list)
	var b: Dictionary = TalentManager.BRANCHES[_branch]
	var col: Color = b.color
	var spent := gm.talents.branch_spent(b)
	_list.add_child(IdleUI.label("Punkty w gałęzi: %d" % spent, 18, col))
	for i in b.nodes.size():
		var nd: Dictionary = b.nodes[i]
		if i > 0:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(6, 18)
			line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			line.color = col if spent >= TalentManager.node_req(i) else Color(0.25, 0.23, 0.22)
			_list.add_child(line)
		_list.add_child(_node_card(b, i, nd, spent))


func _node_card(b: Dictionary, i: int, nd: Dictionary, spent: int) -> Control:
	var id := str(nd.id)
	var r := gm.talents.rank(id)
	var mx := int(nd.max)
	var locked := spent < TalentManager.node_req(i)
	var c := IdleUI.card(Color(), b.color if r > 0 else Color(0, 0, 0, 0))
	if locked:
		c.modulate = Color(0.55, 0.55, 0.55)
	var h := IdleUI.hbox(12)
	c.add_child(h)
	h.add_child(IdleUI.icon_rect(Sprites.icon(str(b.icon)) if i < 5 else IdleUI.ash_tex("ico_skull"), 56))
	var v := IdleUI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(IdleUI.label("%s  %d/%d" % [nd.name, r, mx], 22, b.color if r > 0 else UiTheme.ACCENT, true))
	var per := float(nd.per)
	var fmt_v := func(x: float) -> String: return "%d%%" % roundi(x * 100.0)
	var now_t := str(nd.text) % fmt_v.call(per * r) if r > 0 else "Nieznany"
	var next_t := str(nd.text) % fmt_v.call(per * (r + 1))
	v.add_child(IdleUI.label("Teraz: %s" % now_t, 16, Color(0.85, 0.82, 0.76), true))
	if r < mx:
		v.add_child(IdleUI.label("Dalej: %s" % next_t, 16, IdleUI.GOOD if not locked else IdleUI.DIM, true))
	if locked:
		v.add_child(IdleUI.label("Wymaga %d punktów w gałęzi" % TalentManager.node_req(i), 16, IdleUI.BAD, true))
	var btn := IdleUI.button("+" if r < mx else "MAKS", Vector2(84, 84), 30)
	IdleUI.set_affordable(btn, gm.talents.can_learn(id))
	btn.pressed.connect(func():
		if gm.talents.learn(id):
			Sfx.play("click")
		request_refresh())
	h.add_child(btn)
	return c


func on_changed(what: String) -> void:
	if what in ["talents", "level", "tower", "all"]:
		request_refresh()
