class_name BestiaryPanel
extends IdlePanel
## Bestiariusz: wszystkie gatunki krain, liczba zabitych i stopnie (10 / 100 / 1000 / 10 000).

var _list: GridContainer
var _head: Label


func build() -> void:
	add_child(IdleUI.title("Bestiariusz", 28))
	_head = IdleUI.label("", 18, Color(0.9, 0.86, 0.78), true)
	add_child(_head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_list = GridContainer.new()
	_list.columns = 2
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	sc.add_child(_list)


func refresh() -> void:
	var b := gm.bestiary
	_head.text = "Stopnie: %d  •  premia na stałe: +%d%% obrażeń i +%d%% złota. Każdy gatunek: 10 / 100 / 1000 / 10 000 zabitych." % [b.total_tiers(), b.total_tiers(), b.total_tiers()]
	IdleUI.clear(_list)
	for id in b.all_species():
		var n := b.kills(str(id))
		var c := IdleUI.card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := IdleUI.vbox(4)
		c.add_child(v)
		var known := n > 0
		v.add_child(IdleUI.label(str(gm.db.monster(str(id)).get("name", id)) if known else "???", 19, UiTheme.ACCENT if known else IdleUI.DIM, true))
		var t := BestiaryManager.tier_of(n)
		var pips := IdleUI.hbox(4)
		for i in BestiaryManager.TIERS.size():
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(22, 8)
			p.color = IdleUI.EMBER if i < t else Color(0.2, 0.19, 0.19)
			pips.add_child(p)
		v.add_child(pips)
		var need: int = BestiaryManager.TIERS[mini(t, BestiaryManager.TIERS.size() - 1)]
		v.add_child(IdleUI.label("Zabici: %s%s" % [IdleDB.fmt(float(n)), "" if t >= BestiaryManager.TIERS.size() else " / %s" % IdleDB.fmt(float(need))], 15, Color(0.85, 0.82, 0.76)))
		_list.add_child(c)


func on_changed(what: String) -> void:
	if what in ["all"]:
		request_refresh()
