class_name AchievementsPanel
extends IdlePanel
## Osiągnięcia (menu): progi statystyk całej gry z nagrodami w żarokryształach
## oraz podgląd serii codziennych nagród.

var _list: VBoxContainer


func build() -> void:
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	_list.add_child(IdleUI.title("Osiągnięcia", 28))
	var all: Array = gm.achievements.entries()
	var total := 0
	var got := 0
	for e in all:
		total += int(e.tiers)
		got += int(e.tier)
	_list.add_child(IdleUI.label("Zdobyte stopnie: %d / %d  •  liczą się całe dzieje bohatera, także sprzed odrodzeń." % [got, total], 17, IdleUI.DIM, true))
	# Gotowe do odebrania na górze.
	all.sort_custom(func(a, b): return int(a.ready) > int(b.ready))
	for e in all:
		_card(e)


func _card(e: Dictionary) -> void:
	var ready: bool = e.ready
	var c := IdleUI.card(Color(), IdleUI.GOOD if ready else Color(0, 0, 0, 0))
	_list.add_child(c)
	var v := IdleUI.vbox(6)
	c.add_child(v)
	var h := IdleUI.hbox(12)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(Sprites.icon("quest" if not e.done else "book"), 52))
	var tv := IdleUI.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(IdleUI.label(str(e.name), 22, UiTheme.ACCENT if not e.done else IdleUI.GOOD, true))
	tv.add_child(IdleUI.label("Ukończono wszystkie stopnie" if e.done else str(e.text), 17, Color(0.85, 0.82, 0.76), true))
	# Kamienie stopni: zdobyte świecą.
	var pips := IdleUI.hbox(4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in int(e.tiers):
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(12, 12)
		p.rotation = PI / 4.0
		p.color = IdleUI.EMBER if i < int(e.tier) else Color(0.2, 0.19, 0.19)
		pips.add_child(p)
	h.add_child(pips)
	if e.done:
		return
	var pb := IdleUI.bar(Color(0.35, 0.75, 0.3) if ready else Color(0.85, 0.65, 0.25), 22)
	pb.value = clampf(float(e.prog) / maxf(1.0, float(e.need)), 0.0, 1.0)
	IdleUI.bar_label(pb, 14).text = "%s / %s" % [IdleDB.fmt(minf(float(e.prog), float(e.need))), IdleDB.fmt(float(e.need))]
	v.add_child(pb)
	if ready:
		var b := IdleUI.button("Odbierz: +%d żarokryształów" % int(e.gems), Vector2(0, 76), 22)
		var key := str(e.key)
		b.pressed.connect(func():
			gm.achievements.claim(key)
			request_refresh())
		v.add_child(b)
	else:
		v.add_child(IdleUI.label("Nagroda: %d żarokryształów" % int(e.gems), 16, IdleUI.GEM_COL))


func on_changed(what: String) -> void:
	if what in ["quests", "all"]:
		request_refresh()
