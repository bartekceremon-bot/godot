class_name ClassPanel
extends IdlePanel
## Klasa bohatera: wybór Wojownika, Łowcy albo Maga – premie i umiejętność ostateczna.

const ICONS := {"warrior": "res://assets/ui/runes/fire.png", "hunter": "res://assets/ui/runes/wind.png", "mage": "res://assets/ui/runes/mind.png"}

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Klasa bohatera", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var h := gm.hero
	if not h.unlocked():
		_box.add_child(IdleUI.label("Klasy otwierają się po dotarciu do etapu %d." % ClassManager.UNLOCK_STAGE, 20, IdleUI.BAD, true))
		return
	_box.add_child(IdleUI.label("Ciosy i zabójstwa ładują Żar. Pełny Żar uruchamia umiejętność ostateczną klasy – przycisk obok ATAK!. Pierwszy wybór jest darmowy, zmiana klasy kosztuje %d żarokryształów." % ClassManager.CHANGE_COST, 18, UiTheme.TEXT, true))
	for id in ClassManager.ORDER:
		var d: Dictionary = ClassManager.CLASSES[id]
		var mine: bool = h.current() == str(id)
		var res := row_card(load(ICONS[id]), str(d.name) + ("  ✔" if mine else ""), str(d.text), d.color, 80)
		var v: Control = res[2].get_parent()
		v.add_child(IdleUI.label("%s: %s" % [d.ult, d.ult_text], 17, IdleUI.GOLD_COL, true))
		if not mine:
			var cost := h.change_cost()
			var b := IdleUI.button("Wybierz" if cost == 0 else "Zmień za %d żarokr." % cost, Vector2(0, 76), 21)
			IdleUI.set_affordable(b, cost == 0 or int(gm.s.gems) >= cost)
			var cid: String = id
			b.pressed.connect(func():
				if gm.hero.choose(cid):
					ui.banner(str(ClassManager.CLASSES[cid].name).to_upper(), str(ClassManager.CLASSES[cid].text), ClassManager.CLASSES[cid].color)
					request_refresh()
				else:
					ui.toast_msg("Za mało żarokryształów.", IdleUI.BAD))
			v.add_child(b)
		_box.add_child(res[0])


func on_changed(what: String) -> void:
	if what in ["class", "all"]:
		request_refresh()
