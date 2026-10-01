class_name RecordsPanel
extends IdlePanel
## Rekordy: najlepsze wyniki całej gry i przycisk „Udostępnij” (tekst do schowka).

const STORE_URL := "https://play.google.com/store/apps/details?id=pl.popielnekrolestwa.gra"

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Rekordy", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func rows() -> Array:
	var s := gm.s
	var st: Dictionary = s.stats
	var ar: Dictionary = s.get("arena", {})
	var dn: Dictionary = s.get("dungeon", {}).get("best", {})
	var dbest := 0
	for k in dn:
		dbest = maxi(dbest, int(dn[k]))
	return [
		["Tytuł", tr(TitleManager.title_name(gm.titles.active())) if gm.titles.active() != "" else "—"],
		["Najdalszy etap", str(int(gm.achievements.value("best_stage")))],
		["Najwyższy poziom", str(int(gm.achievements.value("best_level")))],
		["Odrodzenia / przebudzenia Feniksa", "%d / %d" % [int(s.rebirths), gm.phoenix.count()]],
		["Wieża Popiołu – piętro", str(gm.tower.best())],
		["Sen Popielnika – piętro", str(gm.dream.best())],
		["Arena – najwyższy ranking", "%d (%s)" % [int(ar.get("best", 1000)), ArenaManager.league_name(int(ar.get("best", 1000)))]],
		["Lochy Żaru – najwyższy poziom", str(dbest)],
		["Relikwie", "%d / %d" % [gm.relics.owned_count(), RelicManager.RELICS.size()]],
		["Stopnie bestiariusza", str(gm.bestiary.total_tiers())],
		["Zebrane plony", str(gm.garden.harvests())],
		["Złote Gobliny", str(gm.goblin.kills())],
		["Twierdza – suma poziomów", str(gm.stronghold.total_levels())],
		["Mistrzostwo broni – suma poziomów", str(gm.mastery.total_levels())],
		["Pokonani przeciwnicy", IdleDB.fmt(float(st.kills))],
		["Pokonani bossowie i elity", IdleDB.fmt(float(st.bosses))],
		["Zadane ciosy", IdleDB.fmt(float(st.taps))],
		["Najwyższe combo", str(int(st.get("best_combo", 0)))],
		["Trafienia krytyczne", IdleDB.fmt(float(st.crits))],
		["Zdobyte złoto", IdleDB.fmt(float(st.gold))],
		["Czas gry", IdleDB.fmt_time(float(s.play_time))],
	]


func refresh() -> void:
	IdleUI.clear(_box)
	var c := IdleUI.card()
	var v := IdleUI.vbox(6)
	c.add_child(v)
	_box.add_child(c)
	for r in rows():
		var h := IdleUI.hbox(8)
		var a := IdleUI.label(str(r[0]), 19, Color(0.88, 0.85, 0.78), true)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(IdleUI.label(str(r[1]), 20, IdleUI.GOLD_COL))
		v.add_child(h)
	var sh := IdleUI.button("Udostępnij rekordy", Vector2(0, 84), 23)
	sh.pressed.connect(func():
		DisplayServer.clipboard_set(share_text())
		ui.toast_msg("Rekordy skopiowane – wklej je znajomym!", IdleUI.GOOD))
	_box.add_child(sh)


func share_text() -> String:
	var lines: Array = [SmartTranslation.t("Moje rekordy w Popielnych Królestwach:")]
	for r in rows().slice(0, 7):
		lines.append("• %s: %s" % [SmartTranslation.t(str(r[0])), r[1]])
	lines.append(STORE_URL)
	return "\n".join(PackedStringArray(lines))


func on_changed(what: String) -> void:
	if what == "all":
		request_refresh()
