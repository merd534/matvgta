extends Node

## DynamicAudio — music transitions with SHORT procedural tracks to avoid memory flood.
## Tracks are 4 seconds, not 30. ~2MB total instead of ~340MB.

signal music_state_changed(new_state: MusicState)

enum MusicState { EXPLORATION, ALERT, CHASE, STEALTH, MENU }

@export var crossfade_duration: float = 1.5

var current_state: MusicState = MusicState.EXPLORATION
var _player_bus: AudioStreamPlayer
var _layer_bus: AudioStreamPlayer
var _target_volume: float = 0.0
var _layer_target_volume: float = 0.0
var _transition_timer: float = 0.0
var _is_transitioning: bool = false

var _exploration_track: AudioStreamWAV
var _alert_track: AudioStreamWAV
var _chase_track: AudioStreamWAV
var _stealth_track: AudioStreamWAV

func _ready() -> void:
	_setup_buses()
	_setup_players()
	_generate_music()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")

func _setup_players() -> void:
	_player_bus = AudioStreamPlayer.new()
	_player_bus.name = "MusicPlayer"
	_player_bus.bus = "Music"
	add_child(_player_bus)

	_layer_bus = AudioStreamPlayer.new()
	_layer_bus.name = "MusicLayer"
	_layer_bus.bus = "Music"
	add_child(_layer_bus)

func _generate_music() -> void:
	_exploration_track = _gen_neon_jazz(90.0, 4.0)
	_exploration_track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_alert_track = _gen_tension(90.0, 4.0)
	_alert_track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_chase_track = _gen_electronic(140.0, 4.0)
	_chase_track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stealth_track = _gen_drone(4.0)
	_stealth_track.loop_mode = AudioStreamWAV.LOOP_FORWARD

	_player_bus.stream = _exploration_track
	_player_bus.play()
	_player_bus.volume_db = 0.0
	_layer_bus.volume_db = -80.0

func _process(delta: float) -> void:
	if _is_transitioning:
		_transition_timer += delta
		var t = clampf(_transition_timer / crossfade_duration, 0.0, 1.0)
		_player_bus.volume_db = lerpf(_player_bus.volume_db, _target_volume, t)
		_layer_bus.volume_db = lerpf(_layer_bus.volume_db, _layer_target_volume, t)
		if t >= 1.0:
			_is_transitioning = false
			_player_bus.volume_db = _target_volume
			_layer_bus.volume_db = _layer_target_volume

func set_state(new_state: MusicState) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	_transition_to(new_state)
	music_state_changed.emit(new_state)

func _transition_to(state: MusicState) -> void:
	_is_transitioning = true
	_transition_timer = 0.0
	match state:
		MusicState.EXPLORATION:
			_player_bus.stream = _exploration_track
			_player_bus.play()
			_target_volume = 0.0
			_layer_target_volume = -80.0
		MusicState.ALERT:
			_layer_bus.stream = _alert_track
			_layer_bus.play()
			_target_volume = -6.0
			_layer_target_volume = -3.0
		MusicState.CHASE:
			_player_bus.stream = _chase_track
			_player_bus.play()
			_target_volume = 0.0
			_layer_target_volume = -80.0
		MusicState.STEALTH:
			_player_bus.stream = _stealth_track
			_player_bus.play()
			_target_volume = -8.0
			_layer_target_volume = -80.0
		MusicState.MENU:
			_target_volume = -10.0
			_layer_target_volume = -80.0

func _gen_neon_jazz(bpm: float, duration: float) -> AudioStreamWAV:
	var sr = 22050  # half rate to save memory
	var n = int(duration * sr)
	var chords = [[261.63,329.63,392.0],[293.66,369.99,440.0],[329.63,415.3,493.88],[349.23,440.0,523.25]]
	var bl = 60.0 / bpm
	var buf = PackedByteArray()
	buf.resize(n * 4)
	for i in range(n):
		var t = float(i) / sr
		var cp = fmod(t, bl * 4) / (bl * 4)
		var chord = chords[int(cp * 4) % 4]
		var s = 0.0
		for f in chord:
			s += sin(TAU * f * t) * 0.08
		s += sin(TAU * 65.41 * t) * 0.1
		s *= 0.7
		var v = int(clampf(s, -1.0, 1.0) * 16000)
		buf[i * 4] = v & 0xFF
		buf[i * 4 + 1] = (v >> 8) & 0xFF
		buf[i * 4 + 2] = v & 0xFF
		buf[i * 4 + 3] = (v >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = true
	wav.data = buf
	return wav

func _gen_tension(bpm: float, duration: float) -> AudioStreamWAV:
	var sr = 22050
	var n = int(duration * sr)
	var bl = 60.0 / bpm
	var buf = PackedByteArray()
	buf.resize(n * 4)
	for i in range(n):
		var t = float(i) / sr
		var s = sin(TAU * 233.08 * t) * 0.06 + sin(TAU * 246.94 * t) * 0.04
		var pp = fmod(t, bl)
		if pp < 0.05:
			s += sin(TAU * 110 * t) * (1.0 - pp / 0.05) * 0.15
		s *= 0.8
		var v = int(clampf(s, -1.0, 1.0) * 16000)
		buf[i * 4] = v & 0xFF; buf[i * 4 + 1] = (v >> 8) & 0xFF
		buf[i * 4 + 2] = v & 0xFF; buf[i * 4 + 3] = (v >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = sr; wav.stereo = true; wav.data = buf
	return wav

func _gen_electronic(bpm: float, duration: float) -> AudioStreamWAV:
	var sr = 22050
	var n = int(duration * sr)
	var bl = 60.0 / bpm
	var buf = PackedByteArray()
	buf.resize(n * 4)
	var bass = [55.0, 55.0, 65.41, 73.42]
	for i in range(n):
		var t = float(i) / sr
		var s = 0.0
		var kp = fmod(t, bl)
		if kp < 0.1:
			var e = 1.0 - kp / 0.1
			s += sin(TAU * (150.0 * e + 40.0) * kp) * e * 0.3
		var bi = int(t / bl) % 4
		s += sin(TAU * bass[bi] * t) * 0.12
		s *= 0.85
		var v = int(clampf(s, -1.0, 1.0) * 16000)
		buf[i * 4] = v & 0xFF; buf[i * 4 + 1] = (v >> 8) & 0xFF
		buf[i * 4 + 2] = v & 0xFF; buf[i * 4 + 3] = (v >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = sr; wav.stereo = true; wav.data = buf
	return wav

func _gen_drone(duration: float) -> AudioStreamWAV:
	var sr = 22050
	var n = int(duration * sr)
	var buf = PackedByteArray()
	buf.resize(n * 4)
	for i in range(n):
		var t = float(i) / sr
		var lfo = sin(t * 0.3) * 0.5 + 0.5
		var s = sin(TAU * 55.0 * t) * 0.08 + sin(TAU * 110.0 * t + lfo * 3.0) * 0.04
		var v = int(clampf(s, -1.0, 1.0) * 16000)
		buf[i * 4] = v & 0xFF; buf[i * 4 + 1] = (v >> 8) & 0xFF
		buf[i * 4 + 2] = v & 0xFF; buf[i * 4 + 3] = (v >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = sr; wav.stereo = true; wav.data = buf
	return wav

func play_sfx(_sfx_name: String) -> void:
	pass

func set_master_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(0, volume_db)

func set_music_volume(volume_db: float) -> void:
	var bus = AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, volume_db)

func set_sfx_volume(volume_db: float) -> void:
	var bus = AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, volume_db)
