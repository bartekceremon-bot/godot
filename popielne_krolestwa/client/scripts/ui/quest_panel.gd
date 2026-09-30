class_name QuestPanel
extends WindowPanel
## Okno zadań NPC (pakiet `quests`): opis, cele z postępem, nagroda i przyciski
## Przyjmij / Odbierz nagrodę / Porzuć.

const STATE_TEXT := {"available": "dostępne", "active": "w toku", "ready": "gotowe – odbierz nagrodę", "done": "ukończone", "locked": "zablokowane"}
const STATE_COL := {"available": Color(0.95, 0.85, 0.5), "active": Color(0.6, 0.8, 1.0), "ready": Color(0.5, 1.0, 0.5), "done": Color(0.6, 0.6, 0.6), "locked": Color(0.55, 0.5, 0.5)}

var hud
var _list: VBoxContainer


func _init() -> void:
	super._init("Zadania", Vector2(760, 0))


func _ready() -> void:
	var sc: Array = UiTheme.scroll_list(Vector2(720, 470))
	content.add_child(sc[0])
	_list = sc[1]


func open_quests(msg: Dictionary) -> void:
	set_title("Zadania – %s" % str(msg.npc))
	UiTheme.clear(_list)
	if msg.list.is_empty():
		_list.add_child(UiTheme.label("Nie mam teraz dla ciebie zadań.", 18))
	for q in msg.list:
		_list.add_child(_card(q))
	show()


func _card(q: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.07, 0.9)
	sb.border_color = Color(STATE_COL.get(str(q.state), Color.WHITE), 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.label(str(q.name), 22, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.TITLE_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.label("poz. %d  •  %s" % [int(q.level), STATE_TEXT.get(str(q.state), "")], 15, STATE_COL.get(str(q.state), Color.WHITE)))
	var txt := UiTheme.label(str(q.text), 16, Color(0.86, 0.84, 0.78))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(txt)
	for g in q.goals:
		var done := int(g[1]) >= int(g[2])
		box.add_child(UiTheme.label("%s  %s  (%d/%d)" % ["✔" if done else "•", g[0], int(g[1]), int(g[2])], 16, Color(0.6, 1.0, 0.6) if done else Color(0.9, 0.9, 0.9)))
	box.add_child(UiTheme.label("Nagroda: %s" % q.reward, 15, Color(1.0, 0.85, 0.4)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var id := str(q.id)
	match str(q.state):
		"available":
			var b := UiTheme.button("Przyjmij", "", Vector2(170, 52))
			b.pressed.connect(func(): Net.send({"t": "qaccept", "id": id}))
			row.add_child(b)
		"ready":
			var b := UiTheme.button("Odbierz nagrodę", "", Vector2(220, 52))
			b.pressed.connect(func(): Net.send({"t": "qdone", "id": id}))
			row.add_child(b)
		"active":
			var b := UiTheme.button("Porzuć", "", Vector2(140, 52))
			b.pressed.connect(func(): Net.send({"t": "qdrop", "id": id}))
			row.add_child(b)
	return panel
