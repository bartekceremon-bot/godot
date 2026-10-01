class_name DragonPanel
extends IdlePanel
## Smoczy towarzysz: jajo, wyklucie, karmienie złotem i ziołami, poziom i zionięcie.

const DIR := "res://assets/ui/modes/"

var _box: VBoxContainer
var _timer_l: Label
var _state := ""


func build() -> void:
	add_child(IdleUI.title("Smoczy towarzysz", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	_timer_l = null
	var d := gm.dragon
	_state = d.state()
	if not d.unlocked():
		_box.add_child(IdleUI.label("Smocze jajo czeka na bohatera, który dotrze do etapu %d." % DragonManager.UNLOCK_STAGE, 20, IdleUI.BAD, true))
		return
	match _state:
		"none":
			_box.add_child(IdleUI.label("W popiołach Świątyni Ognia kapłani znaleźli ciepłe jajo. Wykluje się z niego smok, który będzie walczył u Twojego boku – zieje ogniem i przynosi złoto.", 18, UiTheme.TEXT, true))
			var rc := row_card(load(DIR + "dragon_egg.png"), "Jajo Żarogniewa", "Wykluje się po %s." % IdleDB.fmt_time(DragonManager.HATCH_SEC), UiTheme.ACCENT, 96)
			var b := IdleUI.button("Odbierz jajo", Vector2(170, 70), 20)
			b.pressed.connect(func():
				gm.dragon.take_egg()
				request_refresh())
			rc[1].add_child(b)
			_box.add_child(rc[0])
		"egg", "ready":
			var rc := row_card(load(DIR + "dragon_egg.png"), "Jajo Żarogniewa", "", UiTheme.ACCENT, 96)
			_timer_l = rc[2]
			var bv := IdleUI.vbox(6)
			rc[1].add_child(bv)
			if _state == "ready":
				var b := IdleUI.button("Wykluj!", Vector2(170, 70), 22)
				b.pressed.connect(_hatch.bind(false))
				bv.add_child(b)
			else:
				var gb := IdleUI.button("Wykluj teraz\n%d żarokr." % DragonManager.HATCH_GEMS, Vector2(170, 70), 17)
				IdleUI.set_affordable(gb, d.can_hatch(true))
				gb.pressed.connect(_hatch.bind(true))
				bv.add_child(gb)
			_box.add_child(rc[0])
			tick_ui()
		"alive":
			_build_alive()


func _build_alive() -> void:
	var d := gm.dragon
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	var h := IdleUI.hbox(12)
	v.add_child(h)
	h.add_child(IdleUI.icon_rect(load(DIR + "dragon.png"), 110))
	var t := IdleUI.vbox(4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(IdleUI.label(tr("%s – poziom %d") % [tr(d.stage_name()), d.level()], 23, Color(1.0, 0.6, 0.3), true))
	t.add_child(IdleUI.label("Zionięcie co %d s: ×%s (DPS + cios) ≈ %s" % [int(DragonManager.BREATH_CD), str(snappedf(d.breath_mult(), 0.1)), IdleDB.fmt(d.breath_damage())], 17, Color(0.85, 0.82, 0.76), true))
	t.add_child(IdleUI.label("Premia: +%d%% złota" % d.level(), 17, IdleUI.GOLD_COL, true))
	var pb := IdleUI.bar(Color(1.0, 0.5, 0.2), 22)
	if d.level() >= DragonManager.MAX_LVL:
		pb.value = 1.0
		IdleUI.bar_label(pb, 15).text = "MAX"
	else:
		pb.value = float(d.xp()) / float(DragonManager.need(d.level()))
		IdleUI.bar_label(pb, 15).text = "%d / %d" % [d.xp(), DragonManager.need(d.level())]
	v.add_child(pb)
	var nxt := ""
	for s in DragonManager.STAGES:
		if int(s[0]) > d.level():
			nxt = tr("Następne stadium: %s (poziom %d)") % [tr(str(s[1])), int(s[0])]
			break
	if nxt != "":
		v.add_child(IdleUI.label(nxt, 16, IdleUI.DIM, true))
	_box.add_child(c)
	if d.level() >= DragonManager.MAX_LVL:
		return
	_box.add_child(IdleUI.label("Karmienie", 21, UiTheme.ACCENT))
	var rc := row_card(IdleUI.ash_tex("ico_gold"), "Złoto", "+10 PD  •  koszt %s zł  •  dziś zostało: %d" % [IdleDB.fmt(d.gold_cost()), d.gold_feeds_left()], IdleUI.GOLD_COL, 56)
	var gb := IdleUI.button("Nakarm", Vector2(140, 60), 18)
	IdleUI.set_affordable(gb, d.can_feed_gold())
	gb.pressed.connect(func():
		gm.dragon.feed_gold()
		request_refresh())
	rc[1].add_child(gb)
	_box.add_child(rc[0])
	for hb in GardenManager.HERB_ORDER:
		var have := gm.garden.herbs(hb)
		var hrc := row_card(GardenPanel.herb_tex(hb), GardenManager.herb_name(hb), "+%d PD za sztukę  •  masz: %d" % [int(DragonManager.HERB_XP[hb]), have], GardenManager.HERBS[hb][4], 56)
		var one := IdleUI.button("×1", Vector2(80, 60), 18)
		IdleUI.set_affordable(one, d.can_feed_herb(hb))
		one.pressed.connect(func():
			gm.dragon.feed_herb(hb, 1)
			request_refresh())
		hrc[1].add_child(one)
		var all := IdleUI.button("Wszystkie", Vector2(120, 60), 16)
		IdleUI.set_affordable(all, d.can_feed_herb(hb))
		all.pressed.connect(func():
			gm.dragon.feed_herb(hb, -1)
			request_refresh())
		hrc[1].add_child(all)
		_box.add_child(hrc[0])
	_box.add_child(IdleUI.label("Zioła zbierasz w Ogrodzie Alchemika (od etapu 20). Smocza Papryczka smakuje smokom najbardziej.", 16, IdleUI.DIM, true))


func _hatch(gems: bool) -> void:
	if gm.dragon.hatch(gems):
		ui.banner("SMOK SIĘ WYKLUŁ!", "Pisklę zieje już ogniem u Twego boku.", Color(1.0, 0.55, 0.25))
	request_refresh()


func tick_ui() -> void:
	if not is_visible_in_tree():
		return
	var st := gm.dragon.state()
	if st != _state:
		request_refresh()
		return
	if _timer_l and st == "egg":
		_timer_l.text = tr("Wykluje się za %s") % tr(IdleDB.fmt_time(gm.dragon.hatch_left()))
	elif _timer_l and st == "ready":
		_timer_l.text = tr("Jajo pęka – smok gotów do wyklucia!")


func on_changed(what: String) -> void:
	if what in ["dragon", "garden", "all"]:
		request_refresh()
