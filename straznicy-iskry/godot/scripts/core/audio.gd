extends Node
## Dźwięk: magistrale Music/SFX, pula odtwarzaczy efektów, płynne przejścia muzyki.
## Wszystkie dźwięki są syntetyzowane skryptem tools/generate_audio.py.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 12

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _last_play: Dictionary = {}
## Muzyka startuje dopiero po kliknięciu „Graj” (wymóg przeglądarek).
var unlocked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	_load_sfx()
	apply_volumes()
	Settings.changed.connect(apply_volumes)


func _load_sfx() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var f := file.trim_suffix(".import").trim_suffix(".remap")
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			var key := f.get_basename()
			if not _sfx.has(key):
				var s: Variant = load(SFX_DIR + f)
				if s:
					_sfx[key] = s


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _db(Settings.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _db(Settings.music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _db(Settings.sfx_volume))


func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


func play(name: String, pitch_var := 0.06, volume_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	var now := Time.get_ticks_msec()
	# Ten sam dźwięk co najwyżej co 45 ms — chroni przed „ścianą dźwięku”.
	if now - int(_last_play.get(name, -1000)) < 45:
		return
	_last_play[name] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _sfx[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func play_music(name: String, fade := 1.2) -> void:
	if not unlocked or name == _current_music:
		return
	var path := MUSIC_DIR + name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	_current_music = name
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		t.tween_property(outgoing, "volume_db", -60.0, fade)
		t.chain().tween_callback(outgoing.stop)


func stop_music(fade := 1.0) -> void:
	_current_music = ""
	for m in [_music_a, _music_b]:
		if m.playing:
			var t := create_tween()
			t.tween_property(m, "volume_db", -60.0, fade)
			t.tween_callback(m.stop)


func unlock() -> void:
	unlocked = true
