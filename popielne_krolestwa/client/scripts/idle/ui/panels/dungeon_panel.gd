class_name DungeonPanel
extends IdlePanel
## Lochy Żaru: trzy lochy z kluczami, wybór poziomu, wejście, wynik ostatniego przejścia.

const ICONS := {"gold": "res://assets/ui/ash/ico_gold.png", "gems": "res://assets/ui/ash/nav_gem.png", "mats": "res://assets/ui/ash/nav_forge.png"}

var _box: VBoxContainer
## Wybrany poziom każdego lochu.
var _sel := {}


func build() -> void:
	add_child(IdleUI.title("Lochy Żaru", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var d := gm.dungeon
	if not d.unlocked():
		_box.add_child(IdleUI.label("Lochy otwierają się po dotarciu do etapu 15.", 20, IdleUI.BAD, true))
		return
	_box.add_child(IdleUI.label("Pokonaj %d strażników w %d s. Każdy strażnik daje łup, a pełne przejście – odłamki relikwii i wyższy poziom lochu. Klucze odnawiają się codziennie." % [DungeonManager.GUARDS, int(DungeonManager.TIME)], 18, UiTheme.TEXT, true))
	if not d.last_run.is_empty():
		_box.add_child(_last_run(d.last_run))
	for k in DungeonManager.ORDER:
		_box.add_child(_dungeon_card(k))


func _dungeon_card(k: String) -> Control:
	var d := gm.dungeon
	var info: Dictionary = DungeonManager.KINDS[k]
	var t := clampi(int(_sel.get(k, mini(d.max_tier(k), d.recommended_tier()))), 1, d.max_tier(k))
	_sel[k] = t
	var res := row_card(load(ICONS[k]), str(info.name), str(info.text), info.color, 72)
	var v: Control = res[2].get_parent()
	v.add_child(IdleUI.label("Klucze: %d / %d  •  rekord: poziom %d" % [d.keys(k), DungeonManager.DAILY_KEYS, d.best(k)], 18, IdleUI.GOOD if d.keys(k) > 0 else IdleUI.DIM))
	var row := IdleUI.hbox(6)
	v.add_child(row)
	var minus := IdleUI.button("−", Vector2(64, 64), 26)
	minus.disabled = t <= 1
	minus.pressed.connect(func():
		_sel[k] = t - 1
		request_refresh())
	row.add_child(minus)
	var lt := IdleUI.label("Poziom %d" % t, 22, UiTheme.ACCENT)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(lt)
	var plus := IdleUI.button("+", Vector2(64, 64), 26)
	plus.disabled = t >= d.max_tier(k)
	plus.pressed.connect(func():
		_sel[k] = t + 1
		request_refresh())
	row.add_child(plus)
	var need := d.guard_hp(t)
	var est := gm.stats.dps + gm.stats.click * 5.0
	var secs := need / maxf(est, 1.0)
	var hint := "Strażnik: %s zdrowia  •  ok. %.1f s na strażnika przy Twojej sile" % [IdleDB.fmt(need), minf(secs, 999.9)]
	v.add_child(IdleUI.label(hint, 16, IdleUI.GOOD if secs * DungeonManager.GUARDS < DungeonManager.TIME * 0.8 else IdleUI.BAD, true))
	v.add_child(IdleUI.label(_reward_hint(k, t), 16, IdleUI.GOLD_COL, true))
	var go := IdleUI.button("Wejdź" if d.keys(k) > 0 else "Wejdź za %d żarokr." % DungeonManager.EXTRA_COST, Vector2(0, 80), 24)
	IdleUI.set_affordable(go, d.can_enter() and (d.keys(k) > 0 or int(gm.s.gems) >= DungeonManager.EXTRA_COST))
	go.pressed.connect(func():
		if gm.dungeon.enter(k, t, true):
			ui.show_tab("fight")
		else:
			ui.toast_msg("Nie można wejść do lochu.", IdleUI.BAD))
	v.add_child(go)
	return res[0]


func _reward_hint(k: String, t: int) -> String:
	var st := DungeonManager.tier_stage(t)
	match k:
		"gold":
			return "Łup: ok. %s złota za strażnika" % IdleDB.fmt(ProgressionManager.gold_for(st) * 30.0 * gm.stats.gold_mult)
		"gems":
			return "Łup: %d żarokr. za strażnika, szansa na runę" % (1 + int(t / 6))
		_:
			return "Łup: %d× surowiec T%d za strażnika, szansa na skrzynię" % [(3 + int(t / 2)) * 2, gm.progression.loot_tier(st)]


func _last_run(lr: Dictionary) -> Control:
	var c := IdleUI.card()
	var v := IdleUI.vbox(4)
	c.add_child(v)
	var name: String = DungeonManager.KINDS[str(lr.kind)].name
	v.add_child(IdleUI.label("Ostatnie przejście: %s %d – %s" % [name, int(lr.tier), "oczyszczony!" if bool(lr.cleared) else "%d/%d strażników" % [int(lr.kills), DungeonManager.GUARDS]], 19, IdleUI.GOOD if bool(lr.cleared) else Color(1.0, 0.7, 0.4), true))
	var parts: Array = []
	if float(lr.gold) > 0.0:
		parts.append("%s złota" % IdleDB.fmt(float(lr.gold)))
	if int(lr.gems) > 0:
		parts.append("%d żarokr." % int(lr.gems))
	if int(lr.runes) > 0:
		parts.append("%d× runa" % int(lr.runes))
	if int(lr.mats) > 0:
		parts.append("%d surowców" % int(lr.mats))
	if int(lr.chests) > 0:
		parts.append("%d× skrzynia" % int(lr.chests))
	if int(lr.shards) > 0:
		parts.append("%d odłamków relikwii" % int(lr.shards))
	if bool(lr.get("next", false)):
		parts.append("odblokowano poziom %d" % (int(lr.tier) + 1))
	if not parts.is_empty():
		v.add_child(IdleUI.label(", ".join(PackedStringArray(parts)), 17, IdleUI.GOLD_COL, true))
	return c


func on_changed(what: String) -> void:
	if what in ["dungeon", "all"]:
		request_refresh()
