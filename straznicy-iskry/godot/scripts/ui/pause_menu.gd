extends Control
## Menu pauzy: Dziennik, Ekwipunek, Mapa, Postać, Ustawienia, Zapis.

signal closed

const MAP := preload("res://scripts/ui/map_view.gd")
const SETTINGS := preload("res://scripts/ui/settings_view.gd")
const SAVE := preload("res://scripts/ui/save_view.gd")
const CARD := preload("res://scripts/ui/class_card.gd")
const TABS := [["journal", "Dziennik"], ["items", "Ekwipunek"], ["map", "Mapa"], ["hero", "Postać"], ["settings", "Ustawienia"], ["save", "Zapis"]]

var panel: PanelContainer
var tabs: TabBar
var scroll: ScrollContainer
var content: VBoxContainer
var current := "journal"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.04, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UITheme.label("Pauza", "Header", false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := UITheme.button("Wróć do gry", close_menu, "Primary")
	head.add_child(back)
	tabs = TabBar.new()
	tabs.clip_tabs = false
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	for tab in TABS:
		tabs.add_tab(tab[1])
	tabs.tab_changed.connect(func(i: int) -> void:
		Audio.play("click", 0.05, -8.0)
		_show(TABS[i][0]))
	var tab_scroll := ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size.y = 56
	tab_scroll.add_child(tabs)
	v.add_child(tab_scroll)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	var quit := UITheme.button("Menu główne", func() -> void:
		GameState.save_game()
		Router.go("title"))
	quit.theme_type_variation = "Chip"
	foot.add_child(quit)


func apply_layout(narrow: bool) -> void:
	var vs := get_viewport_rect().size
	var m := Router.safe_margins()
	var pad := 8.0 if narrow else 40.0
	var w := minf(vs.x - pad * 2 - m["left"] - m["right"], 1100.0)
	var h := minf(vs.y - pad * 2 - m["top"] - m["bottom"], 900.0)
	panel.position = Vector2((vs.x - w) * 0.5, (vs.y - h) * 0.5)
	panel.size = Vector2(w, h)
	panel.custom_minimum_size = panel.size


func open(tab: String) -> void:
	visible = true
	apply_layout(Router.narrow)
	Audio.play("open")
	for i in TABS.size():
		if TABS[i][0] == tab:
			tabs.set_current_tab(i)
	_show(tab)


func close_menu() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("map") and current == "map"):
		close_menu()
		get_viewport().set_input_as_handled()


func _show(tab: String) -> void:
	current = tab
	for c in content.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0
	match tab:
		"journal": _journal()
		"items": _items()
		"map": _map()
		"hero": _hero()
		"settings":
			var s: VBoxContainer = SETTINGS.new()
			s.text_scale_changed.connect(func() -> void:
				var th := UITheme.build()
				for n in get_tree().get_nodes_in_group("themed"):
					n.theme = th
				theme = th
				World.current.hud.theme = th
				World.current.touch.theme = th
				World.current.dialog.theme = th
				World.current.puzzle.theme = th
				World.current.info.theme = th)
			content.add_child(s)
		"save": content.add_child(SAVE.new())


func _journal() -> void:
	var obj := "Odkrywaj Luminarę i szukaj sekretów."
	for o in Data.story.get("objectives", []):
		if not GameState.flags_met(o.get("done", "")):
			obj = o.get("text", "")
			break
	var cp := PanelContainer.new()
	cp.theme_type_variation = "Soft"
	content.add_child(cp)
	var cv := VBoxContainer.new()
	cp.add_child(cv)
	var l := UITheme.label("Główny cel", "Bold")
	l.add_theme_color_override("font_color", Art.GOLD)
	cv.add_child(l)
	cv.add_child(UITheme.label(obj))
	for area_id in Data.story.get("area_order", []):
		var ms := Data.missions_in_area(area_id)
		if ms.is_empty():
			continue
		var unlocked: bool = area_id in GameState.data["areas_unlocked"]
		content.add_child(UITheme.label(Data.area_name(area_id), "Header"))
		if not unlocked:
			content.add_child(UITheme.label("Obszar jeszcze niedostępny.", "Small"))
			continue
		for mid in ms:
			var m := Data.get_mission(mid)
			var done := GameState.is_mission_done(mid)
			var row := PanelContainer.new()
			row.theme_type_variation = "CardOk" if done else "Card"
			content.add_child(row)
			var rv := VBoxContainer.new()
			rv.add_theme_constant_override("separation", 2)
			row.add_child(rv)
			rv.add_child(UITheme.rich("[b]%s[/b]  [color=#b9c9bf]%s[/color]" % [m.get("title", ""), "— ukończone" if done else "— do zrobienia"]))
			if done:
				rv.add_child(UITheme.rich("[color=#e8b84a]Wiedza:[/color] " + str(m.get("lesson", ""))))
			else:
				rv.add_child(UITheme.label(str(m.get("where", m.get("goal", ""))), "Small"))


func _items() -> void:
	var inv: Dictionary = GameState.data["inventory"]
	if inv.is_empty():
		content.add_child(UITheme.label("Ekwipunek jest pusty."))
		return
	for id in inv:
		var it := Data.get_item(id)
		var row := PanelContainer.new()
		row.theme_type_variation = "Card"
		content.add_child(row)
		var h := HBoxContainer.new()
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		var nm := UITheme.label("%s  ×%d" % [it.get("name", id), int(inv[id])], "Bold")
		if it.get("key", false):
			nm.add_theme_color_override("font_color", Art.GOLD)
		v.add_child(nm)
		v.add_child(UITheme.label(it.get("desc", ""), "Small"))
		if it.get("use", "") != "":
			var item_id: String = id
			h.add_child(UITheme.button("Użyj", func() -> void:
				if GameState.use_item(item_id):
					_show("items")))


func _map() -> void:
	content.add_child(UITheme.label("Dotknij odkrytej wyspy, aby się tam przenieść. Fioletowa mgła oznacza miejsca, których jeszcze nie odwiedziłeś.", "Small"))
	var m: Control = MAP.new()
	m.custom_minimum_size = Vector2(0, maxf(340.0, panel.size.y - 260.0))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(m)
	m.travel_requested.connect(func(id: String) -> void:
		if World.current.area.boss and is_instance_valid(World.current.area.boss) and World.current._boss_awake:
			World.current.toast("Nie można podróżować w trakcie walki z Mirażem.", "warn")
			return
		close_menu()
		var spawn: String = Data.story.get("map", {}).get(id, {}).get("spawn", "start")
		World.current.travel(id, spawn))


func _hero() -> void:
	var cid := GameState.class_id()
	var d := Data.get_class_def(cid)
	var card: PanelContainer = CARD.new()
	content.add_child(card)
	card.setup(cid, false, true)
	content.add_child(UITheme.label("Ścieżka rozwoju", "Header"))
	var path: Dictionary = d.get("path", {})
	for lvl in ["2", "3", "4", "5"]:
		var have := GameState.level() >= int(lvl)
		content.add_child(UITheme.rich("[color=%s]Poziom %s:[/color] %s" % ["#7dffb0" if have else "#8a9a94", lvl, path.get(lvl, "")]))
	content.add_child(UITheme.label("Postęp", "Header"))
	var mins := int(float(GameState.data["play_time"]) / 60.0)
	var done: int = GameState.data["missions_done"].size()
	content.add_child(UITheme.label("Czas gry: %d min  •  Zadania: %d/%d  •  Skrzynie: %d  •  Sekrety: %d  •  Powroty do Kamienia: %d" % [
		mins, done, Data.missions.size(), GameState.data["chests"].size(), GameState.data["secrets"].size(), int(GameState.data["deaths"])]))
	content.add_child(UITheme.label("Klasę możesz zmienić przy Ołtarzu Klas w Latarni Wiedzy.", "Small"))
