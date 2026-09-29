extends Node
## Proste efekty dźwiękowe syntezowane w kodzie (bez plików – własne, CC0).

const RATE := 22050
const POOL_SIZE := 6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_streams["hit"] = _noise_burst(0.09, 900.0)
	_streams["hurt"] = _tone_sweep(220.0, 110.0, 0.15, "square", 0.35)
	_streams["miss"] = _noise_burst(0.12, 2500.0, 0.25)
	_streams["heal"] = _tone_sweep(440.0, 880.0, 0.3, "sine", 0.5)
	_streams["levelup"] = _arpeggio([523.0, 659.0, 784.0, 1046.0], 0.1)
	_streams["pickup"] = _tone_sweep(660.0, 990.0, 0.07, "square", 0.25)
	_streams["drink"] = _tone_sweep(300.0, 500.0, 0.18, "sine", 0.5)
	_streams["death"] = _tone_sweep(300.0, 60.0, 0.5, "square", 0.35)
	_streams["click"] = _tone_sweep(800.0, 800.0, 0.03, "square", 0.2)
	_streams["shot"] = _noise_burst(0.07, 4000.0, 0.3)
	_streams["craft"] = _arpeggio([392.0, 523.0, 659.0], 0.07)
	_streams["gather"] = _noise_burst(0.06, 1500.0, 0.4)


func play(name: String) -> void:
	if not Config.sound_enabled or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _tone_sweep(f0: float, f1: float, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var v := sin(phase * TAU) if wave == "sine" else (1.0 if fmod(phase, 1.0) < 0.5 else -1.0)
		out[i] = v * vol * (1.0 - t) * minf(1.0, i / 200.0)
	return _make(out)


func _noise_burst(dur: float, cutoff: float, vol: float = 0.5) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff)
	var prev := 0.0
	var a := clampf(cutoff / RATE * 6.0, 0.01, 1.0)
	for i in n:
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), a)
		out[i] = prev * vol * 2.0 * (1.0 - float(i) / n)
	return _make(out)


func _arpeggio(freqs: Array, note_dur: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var note_n := int(note_dur * RATE)
	for f in freqs:
		for i in note_n:
			var t := float(i) / note_n
			out.append(sin(float(i) * f / RATE * TAU) * 0.4 * (1.0 - t * 0.6))
	return _make(out)
