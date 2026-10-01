class_name IdleMusic
extends Node
## Muzyka (assets/music, tools/audio/gen_music.py): dwa odtwarzacze z płynnym przejściem.
## Utwory: menu, walka, boss (boss regionu, elita, Wieża Popiołu). Wyłączana w ustawieniach.

const TRACKS := {"menu": "res://assets/music/menu.wav", "walka": "res://assets/music/walka.wav", "boss": "res://assets/music/boss.wav"}
const VOLUME_DB := -9.0
const FADE := 1.6

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current := ""
var _enabled := true


func _ready() -> void:
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.volume_db = -80.0
		add_child(p)


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		for p in [_a, _b]:
			p.stop()
	elif _current != "":
		var t := _current
		_current = ""
		play(t)


func play(track: String) -> void:
	if track == _current or not TRACKS.has(track):
		return
	_current = track
	if not _enabled:
		return
	var stream: AudioStream = load(TRACKS[track])
	# Nowy utwór na wolnym odtwarzaczu, stary wycisza się.
	var old := _a if _a.playing and _a.volume_db > -60.0 else _b
	var nxt := _b if old == _a else _a
	nxt.stream = stream
	nxt.volume_db = -60.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", VOLUME_DB, FADE).set_trans(Tween.TRANS_SINE)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(old.stop)


func current() -> String:
	return _current
