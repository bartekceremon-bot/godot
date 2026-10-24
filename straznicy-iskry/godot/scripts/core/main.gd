extends Node
## Punkt startowy: przechodzi do ekranu tytułowego.
## Tylko w buildzie testowym (z katalogiem tests/): ?autotest=1 uruchamia
## automatyczne przejście gry, a ?tour=1 wycieczkę po ekranach do zrzutów.


func _ready() -> void:
	var target := "res://scenes/title.tscn"
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		var query := str(q) if typeof(q) == TYPE_STRING else ""
		if query.contains("autotest=1") and ResourceLoader.exists("res://tests/autotest_scene.tscn"):
			target = "res://tests/autotest_scene.tscn"
		elif query.contains("tour=1") and ResourceLoader.exists("res://tests/tour_scene.tscn"):
			target = "res://tests/tour_scene.tscn"
	get_tree().change_scene_to_file.call_deferred(target)
