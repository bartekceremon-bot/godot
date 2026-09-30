class_name IdleCraftPanel
extends IdlePanel
## Zakładka CRAFT: Rafineria (surowiec → materiał), Kuźnia i Pracownia (ekwipunek T1–T8 z receptur MMO),
## Alchemia (mikstury i wzmocnienia). Receptury odblokowują się z postępem.

var _station := "refinery"
var _tier := 1
var _tiers_box: HBoxContainer
var _info: Label
var _list: VBoxContainer
var _rows: Array = []


func build() -> void:
	var tabs := sub_tabs([["refinery", "Rafineria"], ["forge", "Kuźnia"], ["workshop", "Pracownia"], ["alchemy", "Alchemia"]], func(id):
		_station = id
		request_refresh())
	tabs["refinery"].set_pressed_no_signal(true)
	_tiers_box = IdleUI.hbox(6)
	add_child(_tiers_box)
	_info = IdleUI.label("", 17, IdleUI.DIM, true)
	add_child(_info)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func _max_tier() -> int:
	return gm.progression.loot_tier(int(gm.s.max_stage))


func refresh() -> void:
	IdleUI.clear(_tiers_box)
	_tier = clampi(_tier, 1, _max_tier())
	_tiers_box.visible = _station != "alchemy"
	for t in range(1, _max_tier() + 1):
		var b := IdleUI.button("T%d" % t, Vector2(0, 58), 20)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(t == _tier)
		var tt: int = t
		b.pressed.connect(func():
			_tier = tt
			request_refresh())
		_tiers_box.add_child(b)
	_info.text = "Poziom rzemiosła %d – wyższy daje lepszą jakość wyrobów. Nowe tiery receptur odblokowujesz w kolejnych regionach." % int(gm.s.craft_lvl)
	IdleUI.clear(_list)
	_rows.clear()
	for r in gm.crafting.list_for(_station):
		if _station != "alchemy" and int(r.tier) != _tier:
			continue
		_add_row(r)
	if _rows.is_empty():
		_list.add_child(IdleUI.label("Brak receptur – pokonuj kolejne etapy, by je odblokować.", 20, IdleUI.DIM, true))
	tick_ui()


func _add_row(r: Dictionary) -> void:
	var out := str(r.get("output", ""))
	var tex: Texture2D = Sprites.item_icon_for(gm.db.item(out)) if out != "" else Sprites.icon("book")
	var title := str(r.name) + (" ×%d" % int(r.count) if int(r.get("count", 1)) > 1 else "")
	var rc := row_card(tex, title, "", UiTheme.ACCENT, 64)
	_list.add_child(rc[0])
	var btns: HBoxContainer = rc[1]
	var bs: Array = []
	for n in [1, 10, 0]:
		var b := IdleUI.button("×%d" % n if n > 0 else "Max", Vector2(84, 76), 20)
		var times: int = n
		var rid := str(r.id)
		b.pressed.connect(func():
			var t2 := times if times > 0 else gm.crafting.max_times(gm.crafting.recipe(rid))
			var got := gm.crafting.craft(rid, t2)
			if not got.is_empty():
				ui.toast_msg("Wytworzono: %s" % str(gm.crafting.recipe(rid).name), IdleUI.GOOD)
			request_refresh())
		btns.add_child(b)
		bs.append(b)
	_rows.append({"r": r, "desc": rc[2], "btns": bs})


func tick_ui() -> void:
	for row in _rows:
		var r: Dictionary = row.r
		var parts: Array = []
		for inp in r.inputs:
			var id := str(inp[0])
			parts.append("%d× %s (%d)" % [int(inp[1]), gm.db.item_name(id).get_slice(" (", 0), gm.inventory.count(id)])
		var extra := ""
		if r.has("text"):
			extra = str(r.text) + "\n"
		elif str(r.kind) == "gear":
			var it := {"id": str(r.output), "q": 1, "lvl": 0}
			extra = ", ".join(PackedStringArray(gm.equipment.describe(it))) + " (Zwykły)\n"
		row.desc.text = extra + "Potrzeba: " + ", ".join(PackedStringArray(parts))
		var mt := gm.crafting.max_times(r)
		var btns: Array = row.btns
		IdleUI.set_affordable(btns[0], mt >= 1)
		IdleUI.set_affordable(btns[1], mt >= 10)
		IdleUI.set_affordable(btns[2], mt >= 1)
		if mt >= 1:
			btns[2].text = "Max\n%d" % mt
		else:
			btns[2].text = "Max"
