extends WindowPanel
## Rozmowa z NPC: tekst NPC + przyciski słów kluczowych (jak w Tibii, ale bez pisania).
## Słowa można też wpisywać w czacie.

var npc_id := 0
var _text: Label
var _words: HFlowContainer


func _init() -> void:
	super._init("", Vector2(560, 0))
	_text = UiTheme.label("", 20)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(520, 0)
	content.add_child(_text)
	_words = HFlowContainer.new()
	_words.add_theme_constant_override("h_separation", 8)
	_words.add_theme_constant_override("v_separation", 8)
	content.add_child(_words)
	# Okno rozmowy u góry ekranu, żeby nie zasłaniać otwieranych okien handlu.
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_vertical = Control.GROW_DIRECTION_END
	position.y = 110


func show_dialog(msg: Dictionary) -> void:
	npc_id = int(msg.id)
	set_title(str(msg.name))
	_text.text = str(msg.text)
	UiTheme.clear(_words)
	for w in msg.keywords:
		var b := UiTheme.button(str(w), "", Vector2(0, 56))
		b.pressed.connect(func(): Net.send({"t": "npc", "id": npc_id, "word": w}))
		_words.add_child(b)
	show()
