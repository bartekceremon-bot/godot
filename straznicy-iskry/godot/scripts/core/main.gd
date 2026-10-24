extends Node
## Punkt startowy: ustawia stan i przechodzi do ekranu tytułowego.
## Parametr URL ?autotest=1 (tylko do testów) uruchamia automatyczny przegląd gry.


func _ready() -> void:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and str(q).contains("autotest=1"):
			get_tree().change_scene_to_file.call_deferred("res://tests/autotest_scene.tscn")
			return
	get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")
