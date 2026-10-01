class_name QuestsPanel
extends IdlePanel
## Zakładka QUESTY: Zlecenia (3 odnawiane cele) i Kronika – zadania mistrzów gildii,
## rzemieślników i kapłanów trzech miast z gry MMO.

var _list: VBoxContainer


func build() -> void:
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	var qs: Dictionary = gm.s.quests
	_list.add_child(IdleUI.title("Zlecenia", 26))
	for i in qs.tasks.size():
		var t: Dictionary = qs.tasks[i]
		var ready := float(t.prog) >= float(t.need)
		var r := gm.quests.task_reward(t)
		var idx: int = i
		_card(Sprites.icon("quest"), str(t.text), "", float(t.prog), float(t.need), _reward_text(r), ready, func(): gm.quests.claim_task(idx))
	_list.add_child(IdleUI.spacer(6))
	_list.add_child(IdleUI.title("Kronika Popielnych Królestw", 26))
	_list.add_child(IdleUI.label("Ukończone: %d / %d  •  zadania pojawiają się same, gdy odkryjesz ich krainę." % [qs.done.size(), gm.db.quests.size()], 17, IdleUI.DIM, true))
	for id in qs.active:
		var q := gm.quests.def(str(id))
		var p := gm.quests.progress(str(id))
		var lines: Array = []
		var done := 0.0
		var total := 0.0
		for gi in q.goals.size():
			var g: Dictionary = q.goals[gi]
			lines.append("%s %s (%d/%d)" % ["✔" if int(p[gi]) >= gm.quests.need(g) else "•", g.label, int(p[gi]), gm.quests.need(g)])
			done += float(p[gi])
			total += float(gm.quests.need(g))
		var city: Dictionary = gm.db.cities.get(str(q.city), {})
		var giver := str(city.get("npcNames", {}).get({"guild": "guild", "crafter": "crafter", "priest": "priest"}.get(str(q.giver), "guild"), ""))
		var qid := str(id)
		_card(Sprites.icon("book"), str(q.name), "%s — %s\n%s\n%s" % [giver, city.get("name", ""), q.text, "\n".join(PackedStringArray(lines))], done, total,
			_reward_text(gm.quests.quest_reward(qid)), gm.quests.is_ready(qid), func(): gm.quests.claim(qid))
	if qs.active.is_empty():
		_list.add_child(IdleUI.label("Brak aktywnych zadań Kroniki – odkrywaj nowe krainy.", 19, IdleUI.DIM, true))


func _reward_text(r: Dictionary) -> String:
	var parts: Array = ["%s zł" % IdleDB.fmt(float(r.gold) * gm.stats.gold_mult), "%s XP" % IdleDB.fmt(float(r.xp)), "%d żarokr." % int(r.gems)]
	for it in r.get("items", []):
		parts.append("%d× %s" % [int(it[1]), gm.db.item_name(str(it[0]))])
	if int(r.get("chest", 0)) > 0:
		parts.append(gm.loot.chest_name(int(r.chest)))
	return "Nagroda: " + ", ".join(PackedStringArray(parts))


func _card(tex: Texture2D, title_text: String, desc: String, prog: float, need: float, reward: String, ready: bool, on_claim: Callable) -> void:
	var c := IdleUI.card(Color(0.05, 0.1, 0.05, 0.94) if ready else Color(0.06, 0.065, 0.085, 0.94), IdleUI.GOOD if ready else Color(0.45, 0.35, 0.2, 0.9))
	_list.add_child(c)
	var v := IdleUI.vbox(6)
	c.add_child(v)
	var h := IdleUI.hbox(12)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(tex, 56))
	var t := IdleUI.label(title_text, 22, UiTheme.ACCENT, true)
	h.add_child(t)
	if desc != "":
		v.add_child(IdleUI.label(desc, 17, Color(0.85, 0.82, 0.76), true))
	var pb := IdleUI.bar(Color(0.35, 0.75, 0.3) if ready else Color(0.85, 0.65, 0.25), 24)
	pb.value = clampf(prog / maxf(1.0, need), 0.0, 1.0)
	var pl := IdleUI.bar_label(pb, 15)
	pl.text = "%s / %s" % [IdleDB.fmt(prog), IdleDB.fmt(need)]
	v.add_child(pb)
	v.add_child(IdleUI.label(reward, 17, IdleUI.GOLD_COL, true))
	if ready:
		var b := IdleUI.button("Odbierz nagrodę", Vector2(0, 80), 24)
		b.pressed.connect(func():
			on_claim.call()
			request_refresh())
		v.add_child(b)


func on_changed(what: String) -> void:
	if what in ["quests", "all"]:
		request_refresh()
