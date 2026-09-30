class_name IdleInventoryPanel
extends IdlePanel
## Zakładka EKWIPUNEK: 6 slotów (głowa, tułów, nogi, stopy, broń, tarcza), plecak z ekwipunkiem
## (szczegóły, porównanie, ulepszanie, sprzedaż), surowce i mikstury, skrzynie i fragmenty.

const COLS := 5

var _tab := "gear"
var _body: VBoxContainer


func build() -> void:
	var tabs := sub_tabs([["gear", "Ekwipunek"], ["mats", "Surowce"], ["chests", "Skrzynie"]], func(id):
		_tab = id
		request_refresh())
	tabs["gear"].set_pressed_no_signal(true)
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_body = sc[1]


func refresh() -> void:
	IdleUI.clear(_body)
	match _tab:
		"gear":
			_build_gear()
		"mats":
			_build_mats()
		"chests":
			_build_chests()


func on_changed(what: String) -> void:
	if what in ["gear", "inventory", "all"]:
		request_refresh()


# --- Ekwipunek -------------------------------------------------------------------

func _build_gear() -> void:
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 10)
	slots.add_theme_constant_override("v_separation", 8)
	_body.add_child(slots)
	for slot in IdleDB.SLOTS:
		var it := gm.equipment.equipped(slot)
		var v := IdleUI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b: Button
		if it.is_empty():
			b = IdleUI.item_button(null, 0, "", 100)
			b.text = IdleDB.SLOT_NAMES[slot]
			b.add_theme_font_size_override("font_size", 16)
		else:
			b = IdleUI.item_button(Sprites.item_icon_for(gm.db.item(str(it.id))), int(it.q), ("+%d" % int(it.lvl)) if int(it.lvl) > 0 else "", 100)
			var item: Dictionary = it
			b.pressed.connect(func(): _item_popup(item))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
		var l := IdleUI.label(IdleDB.SLOT_NAMES[slot] if it.is_empty() else gm.equipment.gear_name(it), 15, IdleUI.DIM if it.is_empty() else IdleDB.RARITY_COLORS[int(it.q)])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.custom_minimum_size = Vector2(120, 0)
		v.add_child(l)
		slots.add_child(v)
	var st := gm.stats
	_body.add_child(IdleUI.label("Klik %s  •  DPS %s  •  Zdrowie %s  •  Obrona %d%%  •  Mana %s" % [IdleDB.fmt(st.click), IdleDB.fmt(st.dps), IdleDB.fmt(st.max_hp), roundi(st.defense * 100.0), IdleDB.fmt(st.max_mp)], 17, Color(0.9, 0.86, 0.76), true))
	var row := IdleUI.hbox(8)
	_body.add_child(row)
	var best := IdleUI.button("Załóż najlepsze", Vector2(0, 72), 20)
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.pressed.connect(func():
		gm.equipment.equip_best()
		ui.toast_msg("Założono najlepszy ekwipunek."))
	row.add_child(best)
	var junk := IdleUI.button("Sprzedaj słabe", Vector2(0, 72), 20)
	junk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	junk.pressed.connect(func():
		ui.confirm("Sprzedaż", "Sprzedać cały niezałożony i nieulepszony ekwipunek rzadkości Zwykły i Niezwykły (bez narzędzi)?", func():
			var r := gm.shop.sell_junk(2)
			ui.toast_msg("Sprzedano %d przedmiotów za %s zł" % [int(r[0]), IdleDB.fmt(float(r[1]))], IdleUI.GOLD_COL)))
	row.add_child(junk)
	var list: Array = gm.s.gear.duplicate()
	list.sort_custom(func(a, b): return gm.equipment.score(a) > gm.equipment.score(b))
	_body.add_child(IdleUI.label("Plecak: %d / %d" % [list.size(), InventoryManager.GEAR_LIMIT], 18, UiTheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	for it in list:
		var eq := gm.equipment.is_equipped(int(it.uid))
		var better := false
		if not eq and not gm.equipment.is_tool(str(it.id)):
			var cur := gm.equipment.equipped(gm.equipment.slot_of(str(it.id)))
			better = cur.is_empty() or gm.equipment.score(it) > gm.equipment.score(cur)
		var txt := ("+%d" % int(it.lvl)) if int(it.lvl) > 0 else ""
		var b := IdleUI.item_button(Sprites.item_icon_for(gm.db.item(str(it.id))), int(it.q), txt, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if eq or better:
			var tag := UiTheme.label("E" if eq else "▲", 16, UiTheme.ACCENT if eq else IdleUI.GOOD)
			tag.position = Vector2(6, 64)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tag)
		var item: Dictionary = it
		b.pressed.connect(func(): _item_popup(item))
		grid.add_child(b)


func _item_popup(it: Dictionary) -> void:
	var v := IdleUI.vbox(10)
	var id := str(it.id)
	var def := gm.db.item(id)
	var h := IdleUI.hbox(14)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(Sprites.item_icon_for(def), 110))
	var info := IdleUI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(IdleUI.label(gm.equipment.gear_name(it), 24, IdleDB.RARITY_COLORS[int(it.q)], true))
	info.add_child(IdleUI.label("%s  •  T%d  •  ulepszenie +%d" % [IdleDB.RARITY_NAMES[int(it.q)], IdleDB.tier_of(id), int(it.lvl)], 18, IdleUI.DIM))
	var slot := gm.equipment.slot_of(id)
	if gm.equipment.is_tool(id):
		info.add_child(IdleUI.label("Narzędzie zbierackie – najlepsze narzędzie każdego rodzaju działa samo z plecaka.", 16, IdleUI.DIM, true))
	for line in gm.equipment.describe(it):
		v.add_child(IdleUI.label("• " + str(line), 21, IdleUI.GOOD))
	var cur := gm.equipment.equipped(slot) if slot != "" else {}
	var equipped := gm.equipment.is_equipped(int(it.uid))
	if not cur.is_empty() and not equipped:
		v.add_child(IdleUI.label("Założone: %s" % gm.equipment.gear_name(cur), 17, IdleUI.DIM, true))
		for line in gm.equipment.describe(cur):
			v.add_child(IdleUI.label("   " + str(line), 16, IdleUI.DIM))
	# Ulepszenie.
	var cost := gm.equipment.upgrade_cost(it)
	var cost_txt := "Ulepszenie +%d:  %s zł" % [int(it.lvl) + 1, IdleDB.fmt(float(cost.gold))]
	for m in cost.mats:
		cost_txt += ",  %d× %s (%d)" % [int(m[1]), gm.db.item_name(str(m[0])).get_slice(" (", 0), gm.inventory.count(str(m[0]))]
	var ok := gm.equipment.can_upgrade(it)
	v.add_child(IdleUI.label(cost_txt, 18, IdleUI.GOOD if ok else IdleUI.BAD, true))
	var row := IdleUI.hbox(8)
	v.add_child(row)
	var m: Control
	if slot != "":
		var eb := IdleUI.button("Zdejmij" if equipped else "Załóż", Vector2(0, 84), 22)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.pressed.connect(func():
			if equipped:
				gm.equipment.unequip(slot)
			else:
				gm.equipment.equip(int(it.uid))
				gm.audio.play("pickup")
			ui.close_modal(m))
		row.add_child(eb)
	var ub := IdleUI.button("Ulepsz", Vector2(0, 84), 22)
	ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	IdleUI.set_affordable(ub, ok)
	ub.pressed.connect(func():
		if gm.equipment.upgrade(int(it.uid)):
			ui.toast_msg("%s!" % gm.equipment.gear_name(it), IdleUI.GOOD)
			ui.close_modal(m)
			_item_popup(it))
	row.add_child(ub)
	if not equipped:
		var sb := IdleUI.button("Sprzedaj\n%s zł" % IdleDB.fmt(gm.shop.sell_price_gear(it)), Vector2(0, 84), 18)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func():
			gm.shop.sell_gear(int(it.uid))
			ui.close_modal(m))
		row.add_child(sb)
	m = ui.modal(IdleDB.SLOT_NAMES.get(slot, "Narzędzie"), v)


# --- Surowce i mikstury --------------------------------------------------------------

func _build_mats() -> void:
	var groups := [["resource", "Surowce"], ["material", "Materiały"], ["consumable", "Mikstury i jedzenie"], ["misc", "Trofea i inne"]]
	for g in groups:
		var cat := str(g[0])
		var ids := gm.inventory.list_counted(func(id): return gm.inventory.category(id) == cat and id != "gold")
		if ids.is_empty():
			continue
		_body.add_child(IdleUI.label(str(g[1]), 22, UiTheme.ACCENT))
		var grid := GridContainer.new()
		grid.columns = COLS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_body.add_child(grid)
		for id in ids:
			var b := IdleUI.item_button(Sprites.item_icon_for(gm.db.item(id)), 0, UiTheme._short_count(gm.inventory.count(id)), 96)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var iid: String = id
			b.pressed.connect(func(): _mat_popup(iid))
			grid.add_child(b)
	if _body.get_child_count() == 0:
		_body.add_child(IdleUI.label("Plecak jest pusty. Surowce wypadają z przeciwników i skrzyń.", 20, IdleUI.DIM, true))


func _mat_popup(id: String) -> void:
	var def := gm.db.item(id)
	var v := IdleUI.vbox(10)
	var h := IdleUI.hbox(14)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(Sprites.item_icon_for(def), 96))
	var info := IdleUI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(IdleUI.label(str(def.name), 24, UiTheme.ACCENT, true))
	info.add_child(IdleUI.label("Masz: %d" % gm.inventory.count(id), 20))
	var uses := {"resource": "Surowiec: ulepszanie ekwipunku i rafinacja (CRAFT).", "material": "Materiał: wykuwanie ekwipunku (CRAFT).",
		"consumable": "Mikstura: użyj w walce z bossem (pasek na ekranie walki).", "misc": str(def.get("description", "Trofeum – sprzedaj albo użyj w alchemii."))}
	v.add_child(IdleUI.label(str(uses.get(str(def.category), "")), 18, IdleUI.DIM, true))
	var price := gm.shop.sell_price(id)
	var row := IdleUI.hbox(8)
	v.add_child(row)
	var m: Control
	if str(def.category) == "consumable":
		var ub := IdleUI.button("Użyj", Vector2(0, 80), 22)
		ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ub.pressed.connect(func():
			gm.combat.drink(id)
			ui.close_modal(m))
		row.add_child(ub)
	for n in [1, 10, 0]:
		var cnt: int = n if n > 0 else gm.inventory.count(id)
		var sb := IdleUI.button("Sprzedaj %s\n%s zł" % ["wszystko" if n == 0 else "×%d" % n, IdleDB.fmt(price * mini(cnt, gm.inventory.count(id)))], Vector2(0, 80), 17)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		IdleUI.set_affordable(sb, gm.inventory.count(id) >= maxi(1, mini(cnt, 1)) and price > 0.0)
		sb.pressed.connect(func():
			gm.shop.sell(id, cnt)
			ui.close_modal(m))
		row.add_child(sb)
	m = ui.modal("Przedmiot", v)


# --- Skrzynie ------------------------------------------------------------------------

func _build_chests() -> void:
	var any := false
	for r in range(5, 0, -1):
		var n := gm.inventory.count("chest_%d" % r)
		if n <= 0:
			continue
		any = true
		var rc := row_card(Sprites.icon("chest"), "%s  ×%d" % [gm.loot.chest_name(r), n], "Złoto, surowce, ekwipunek (%s), żarokryształy%s." % [IdleDB.RARITY_NAMES[r], ", mikstury" if r >= 2 else ""], IdleDB.RARITY_COLORS[r], 72)
		_body.add_child(rc[0])
		var rr: int = r
		var ob := IdleUI.button("Otwórz", Vector2(150, 80), 22)
		ob.pressed.connect(func(): _open(rr, 1))
		rc[1].add_child(ob)
		if n > 1:
			var all := IdleUI.button("Wszystkie", Vector2(150, 80), 20)
			all.pressed.connect(func(): _open(rr, gm.inventory.count("chest_%d" % rr)))
			rc[1].add_child(all)
	var frags := gm.inventory.list_counted(func(id): return id.begins_with("frag_"))
	if not frags.is_empty():
		_body.add_child(IdleUI.label("Fragmenty wierzchowców (Stajnia w menu)", 22, UiTheme.ACCENT))
		for id in frags:
			var mid: String = id.substr(5)
			var c := gm.mounts.next_cost(mid)
			var rc := row_card(Sprites.item_icon_for(gm.db.item(mid)), gm.db.item_name(mid), "Fragmenty: %d / %d" % [gm.inventory.count(id), int(c.frags)], UiTheme.ACCENT, 64)
			_body.add_child(rc[0])
	if not any and frags.is_empty():
		_body.add_child(IdleUI.label("Brak skrzyń. Skrzynie dają bossowie, elity, zadania i sklep.", 20, IdleUI.DIM, true))


func _open(r: int, n: int) -> void:
	var total: Dictionary = {}
	var rar: Dictionary = {}
	for i in mini(n, 25):
		for g in gm.loot.open_chest(r):
			var id := str(g[0])
			total[id] = float(total.get(id, 0.0)) + float(g[1])
			rar[id] = maxi(int(rar.get(id, 0)), int(g[2]))
	var v := IdleUI.vbox(8)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var i := 0
	for id in total:
		var b := IdleUI.item_button(IdleUI.item_tex(gm.db, id), int(rar[id]), IdleDB.fmt(float(total[id])), 110)
		b.tooltip_text = IdleUI.item_name(gm.db, id)
		b.scale = Vector2(0.2, 0.2)
		b.pivot_offset = Vector2(55, 55)
		grid.add_child(b)
		var tw := b.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	var names := IdleUI.label(", ".join(PackedStringArray(total.keys().map(func(id): return IdleUI.item_name(gm.db, str(id))))), 16, IdleUI.DIM, true)
	v.add_child(names)
	ui.modal(gm.loot.chest_name(r) + (" ×%d" % n if n > 1 else ""), v)
