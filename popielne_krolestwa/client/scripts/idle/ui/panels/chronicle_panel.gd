class_name ChroniclePanel
extends IdlePanel
## Opowieść: przeczytane sceny fabuły (do ponownego przeczytania) i zapowiedź kolejnych rozdziałów.

var _list: VBoxContainer


func build() -> void:
	add_child(IdleUI.title("Opowieść", 28))
	add_child(IdleUI.label("Dzieje Popielnika – dotknij sceny, by przeczytać ją jeszcze raz.", 17, IdleUI.DIM, true))
	var sc := IdleUI.scroll()
	add_child(sc[0])
	_list = sc[1]


func refresh() -> void:
	IdleUI.clear(_list)
	var seen: Array = gm.story.seen()
	for c in gm.db.story.chapters:
		var rid := str(c.region)
		var any := false
		for part in ["intro", "outro"]:
			var scene := "%s:%s" % [part, rid]
			if seen.has(scene):
				any = true
				var b := IdleUI.button("%s – %s" % [c.title, "początek" if part == "intro" else "zakończenie"], Vector2(0, 76), 19)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.pressed.connect(func(): ui.show_story(scene))
				_list.add_child(b)
		if not any:
			_list.add_child(IdleUI.label("%s – odkryj krainę, by poznać ten rozdział." % c.title, 18, IdleUI.DIM, true))
	for sc in seen:
		if str(sc).begins_with("circle:"):
			var scene := str(sc)
			var b := IdleUI.button(gm.story.title(scene), Vector2(0, 76), 19)
			b.pressed.connect(func(): ui.show_story(scene))
			_list.add_child(b)
