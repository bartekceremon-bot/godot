class_name RaidPanel
extends IdlePanel
## Boss tygodnia: boss bieżącego tygodnia, suma obrażeń, progi nagród, próby, wejście.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Boss tygodnia", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var r := gm.raid
	var b := r.boss()
	var days_left := 7 - (int(floor(Time.get_unix_time_from_system() / 86400.0 + 3.0)) % 7)
	var ev := gm.events.current()
	_box.add_child(IdleUI.label("Wydarzenie tygodnia – %s: %s." % [ev.name, ev.text], 19, Color(1.0, 0.75, 0.35), true))
	_box.add_child(IdleUI.label("W tym tygodniu: %s. Każda próba trwa 30 s – zadaj jak najwięcej obrażeń. Suma ze wszystkich prób w tygodniu odblokowuje nagrody. Nowy boss za %d dni." % [b.name, days_left], 18, UiTheme.TEXT, true))
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	_box.add_child(c)
	v.add_child(IdleUI.label("Suma obrażeń: %s" % IdleDB.fmt(r.damage()), 24, UiTheme.ACCENT))
	v.add_child(IdleUI.label("Próby na dziś: %d / %d" % [r.attempts(), RaidManager.DAILY], 19, IdleUI.GOOD if r.attempts() > 0 else IdleUI.BAD))
	var go := IdleUI.button("Walcz z bossem tygodnia", Vector2(0, 90), 26)
	IdleUI.set_affordable(go, r.attempts() > 0 and not gm.tower.active)
	go.pressed.connect(func():
		if gm.raid.enter():
			ui.show_tab("fight"))
	v.add_child(go)
	var claimed := int(gm.s.raid.claimed)
	for i in RaidManager.TIER_MULT.size():
		var need := r.threshold(i)
		var done := i < claimed
		var ready := not done and r.damage() >= need and i == claimed
		var res := row_card(Sprites.icon("chest"), "Próg %d: %s obrażeń" % [i + 1, IdleDB.fmt(need)], _reward_text(RaidManager.REWARDS[i]), IdleUI.GOOD if done else UiTheme.ACCENT, 52)
		var pb := IdleUI.bar(Color(0.85, 0.45, 0.2), 18)
		pb.value = clampf(r.damage() / need, 0.0, 1.0)
		res[2].get_parent().add_child(pb)
		if done:
			res[1].add_child(IdleUI.label("✔", 30, IdleUI.GOOD))
		elif ready:
			var cb := IdleUI.button("Odbierz", Vector2(130, 72), 20)
			cb.pressed.connect(func():
				var got := gm.raid.claim()
				for it in got:
					ui.toast_msg("+%s %s" % [IdleDB.fmt(float(it[1])), IdleUI.item_name(gm.db, str(it[0]))], IdleUI.GOLD_COL)
				request_refresh())
			res[1].add_child(cb)
		_box.add_child(res[0])


func _reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("gems"):
		parts.append("%d żarokr." % int(r.gems))
	if r.has("chest"):
		parts.append(LootManager.CHEST_NAMES[int(r.chest)])
	if r.has("runes"):
		parts.append("%d× runa" % r.runes.size())
	if r.has("egg"):
		parts.append("jajo chowańca")
	return "Nagroda: " + ", ".join(PackedStringArray(parts))


func on_changed(what: String) -> void:
	if what in ["raid", "all"]:
		request_refresh()
