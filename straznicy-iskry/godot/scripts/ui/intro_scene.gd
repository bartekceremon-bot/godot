extends Control
## Scenka wprowadzająca, a po niej wybór klasy.

const CUTSCENE := preload("res://scripts/ui/cutscene_player.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	Audio.play_music("title")
	var cs: Control = CUTSCENE.new()
	add_child(cs)
	cs.play(Data.story.get("intro", []))
	await cs.finished
	Router.go("class_select")
