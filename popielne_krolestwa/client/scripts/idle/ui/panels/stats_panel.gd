class_name StatsPanel
extends IdlePanel
## Postać: wszystkie statystyki, aktywne wzmocnienia i liczniki gry.

var _list: VBoxContainer


func build() -> void:
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	var s := gm.s
	_list.add_child(IdleUI.title("Bohater – poziom %d" % int(s.level), 28))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	_list.add_child(grid)
	for row in gm.stats.summary():
		grid.add_child(IdleUI.label(str(row[0]), 20, Color(0.85, 0.82, 0.76)))
		grid.add_child(IdleUI.label(str(row[1]), 20, UiTheme.ACCENT))
	var boosts := gm.crafting.active_boosts()
	if not boosts.is_empty():
		_list.add_child(IdleUI.title("Wzmocnienia", 22))
		for k in boosts:
			_list.add_child(IdleUI.label("+%d%% %s  –  jeszcze %s" % [roundi(float(boosts[k]) * 100), {"gold": "złota", "xp": "doświadczenia", "damage": "obrażeń", "click": "obrażeń kliknięcia"}.get(k, k), IdleDB.fmt_time(gm.crafting.boost_left(k))], 19, IdleUI.GOOD))
	_list.add_child(IdleUI.title("Kronika łowów", 22))
	var st: Dictionary = s.stats
	for r in [["Pokonani przeciwnicy", IdleDB.fmt(float(st.kills))], ["Pokonani bossowie", str(int(st.bosses))], ["Ciosy", IdleDB.fmt(float(st.taps))],
		["Trafienia krytyczne", IdleDB.fmt(float(st.crits))], ["Rzucone czary", IdleDB.fmt(float(st.spells))], ["Zdobyte złoto", IdleDB.fmt(float(st.gold))],
		["Najdalszy etap", str(int(s.max_stage))], ["Odrodzenia", str(int(s.rebirths))], ["Czas gry", IdleDB.fmt_time(float(s.play_time))], ["Poziom rzemiosła", str(int(s.craft_lvl))]]:
		var h := IdleUI.hbox(10)
		var a := IdleUI.label(str(r[0]), 19, Color(0.85, 0.82, 0.76))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(IdleUI.label(str(r[1]), 19, UiTheme.ACCENT))
		_list.add_child(h)


func on_changed(what: String) -> void:
	if what in ["stats", "level", "all"]:
		request_refresh()
