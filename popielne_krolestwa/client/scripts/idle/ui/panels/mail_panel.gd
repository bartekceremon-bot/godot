class_name MailPanel
extends IdlePanel
## Poczta: wiadomości Gildii (nowości wersji) z prezentami.

var _box: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Poczta", 28))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_box = sc[1]


func refresh() -> void:
	IdleUI.clear(_box)
	var m := gm.mail
	for i in MailManager.MESSAGES.size():
		var msg: Array = MailManager.MESSAGES[i]
		var unread := not m.is_read(str(msg[0]))
		var gift := m.has_gift(i)
		var res := row_card(Sprites.icon("book"), ("● " if unread else "") + str(msg[1]), str(msg[2]), UiTheme.ACCENT if unread or gift else IdleUI.DIM, 52)
		var idx := i
		if gift:
			var b := IdleUI.button("Odbierz\nprezent", Vector2(130, 80), 18)
			b.pressed.connect(func():
				for it in gm.mail.claim(idx):
					ui.toast_msg("+%d %s" % [int(it[1]), IdleUI.item_name(gm.db, str(it[0]))], IdleUI.GOLD_COL)
				request_refresh())
			res[1].add_child(b)
		elif unread:
			m.mark_read(idx)
		_box.add_child(res[0])


func on_changed(what: String) -> void:
	if what in ["mail", "all"] and is_visible_in_tree():
		request_refresh()
