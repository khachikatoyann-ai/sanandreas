class_name AudioManagerCore
extends Node

## AudioManager: Production procedural audio synthesizer for Godot 4.
## Provides real-time synthesized engine roar, tire screeches, gunshots,
## police sirens, collisions, horns, and UI cash chimes without external assets.

var _sample_rate: float = 22050.0
var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _siren_player: AudioStreamPlayer
var _siren_playback: AudioStreamGeneratorPlayback
var _engine_player: AudioStreamPlayer
var _engine_playback: AudioStreamGeneratorPlayback

var _siren_active: bool = false
var _siren_phase: float = 0.0
var _engine_active: bool = false
var _engine_rpm: float = 0.2
var _engine_phase: float = 0.0

# Sound event buffer queue
var _active_one_shots: Array[Dictionary] = []

static var instance: AudioManagerCore = null

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_generator()

func _exit_tree() -> void:
	if instance == self:
		instance = null
	_playback = null
	_siren_playback = null
	_engine_playback = null

func _setup_generator() -> void:
	# One-shot player
	_audio_player = AudioStreamPlayer.new()
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = 0.1
	_audio_player.stream = gen
	_audio_player.volume_db = -4.0
	add_child(_audio_player)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Siren player
	_siren_player = AudioStreamPlayer.new()
	var siren_gen: AudioStreamGenerator = AudioStreamGenerator.new()
	siren_gen.mix_rate = _sample_rate
	siren_gen.buffer_length = 0.15
	_siren_player.stream = siren_gen
	_siren_player.volume_db = -8.0
	add_child(_siren_player)
	_siren_player.play()
	_siren_playback = _siren_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Engine player
	_engine_player = AudioStreamPlayer.new()
	var engine_gen: AudioStreamGenerator = AudioStreamGenerator.new()
	engine_gen.mix_rate = _sample_rate
	engine_gen.buffer_length = 0.12
	_engine_player.stream = engine_gen
	_engine_player.volume_db = -10.0
	add_child(_engine_player)
	_engine_player.play()
	_engine_playback = _engine_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	_fill_one_shot_buffer()
	_fill_siren_buffer(delta)
	_fill_engine_buffer(delta)

func _fill_one_shot_buffer() -> void:
	if not _playback:
		return
	var frames_needed: int = _playback.get_frames_available()
	if frames_needed <= 0:
		return

	for _i in range(frames_needed):
		var mixed_sample: float = 0.0
		var remaining_shots: Array[Dictionary] = []
		for shot: Dictionary in _active_one_shots:
			shot["time"] += 1.0 / _sample_rate
			var t: float = shot["time"]
			var dur: float = shot["duration"]
			if t < dur:
				var s: float = 0.0
				var envelope: float = 1.0 - (t / dur)
				match shot["type"]:
					"gunshot":
						# Sharp noise impulse + punchy low frequency thump
						var noise: float = randf_range(-1.0, 1.0) * exp(-t * 28.0)
						var thud: float = sin(t * 180.0 * TAU) * exp(-t * 12.0)
						s = (noise * 0.75 + thud * 0.45) * shot["vol"]
					"skid":
						# Filtered high noise for tire screech
						var noise: float = randf_range(-1.0, 1.0)
						var screech: float = sin(t * (1200.0 + sin(t * 80.0) * 300.0) * TAU) * 0.35
						s = (noise * 0.4 + screech) * envelope * shot["vol"]
					"horn":
						# Dual-tone car horn (F# and A#)
						var f1: float = sin(t * 370.0 * TAU)
						var f2: float = sin(t * 466.0 * TAU)
						s = (f1 + f2) * 0.35 * envelope * shot["vol"]
					"cash":
						# Arpeggio chime
						var freq: float = 587.33
						if t > 0.08: freq = 880.0
						if t > 0.16: freq = 1174.66
						s = sin(t * freq * TAU) * envelope * shot["vol"]
					"impact":
						var crunch: float = randf_range(-1.0, 1.0) * exp(-t * 18.0)
						var sub: float = sin(t * 65.0 * TAU) * exp(-t * 8.0)
						s = (crunch * 0.6 + sub * 0.5) * shot["vol"]
				mixed_sample += s
				remaining_shots.append(shot)
		_active_one_shots = remaining_shots
		var clamped: float = clampf(mixed_sample, -1.0, 1.0)
		_playback.push_frame(Vector2(clamped, clamped))

func _fill_siren_buffer(_delta: float) -> void:
	if not _siren_playback:
		return
	var frames: int = _siren_playback.get_frames_available()
	if frames <= 0:
		return

	for _i in range(frames):
		if not _siren_active:
			_siren_playback.push_frame(Vector2.ZERO)
			continue
		_siren_phase += 1.0 / _sample_rate
		# Wailing siren from 650Hz to 1100Hz with 1.6s period
		var cycle: float = fmod(_siren_phase, 1.6) / 1.6
		var freq: float = 650.0 + (0.5 + 0.5 * sin(cycle * TAU)) * 450.0
		var sample: float = sin(_siren_phase * freq * TAU) * 0.25
		_siren_playback.push_frame(Vector2(sample, sample))

func _fill_engine_buffer(_delta: float) -> void:
	if not _engine_playback:
		return
	var frames: int = _engine_playback.get_frames_available()
	if frames <= 0:
		return

	for _i in range(frames):
		if not _engine_active:
			_engine_playback.push_frame(Vector2.ZERO)
			continue
		_engine_phase += 1.0 / _sample_rate
		var base_freq: float = 45.0 + _engine_rpm * 130.0
		var h1: float = sin(_engine_phase * base_freq * TAU) * 0.25
		var h2: float = sin(_engine_phase * base_freq * 2.0 * TAU) * 0.15
		var h3: float = (randf_range(-0.1, 0.1)) * (0.05 + _engine_rpm * 0.1)
		var s: float = (h1 + h2 + h3) * 0.35
		_engine_playback.push_frame(Vector2(s, s))

# Public Static API
static func play_gunshot(volume: float = 0.9) -> void:
	if not instance: return
	instance._active_one_shots.append({
		"type": "gunshot",
		"time": 0.0,
		"duration": 0.28,
		"vol": volume
	})

static func play_tire_screech(volume: float = 0.6) -> void:
	if not instance or instance._active_one_shots.size() > 8:
		return
	instance._active_one_shots.append({
		"type": "skid",
		"time": 0.0,
		"duration": 0.2,
		"vol": volume
	})

static func play_car_horn(volume: float = 0.7) -> void:
	if not instance: return
	instance._active_one_shots.append({
		"type": "horn",
		"time": 0.0,
		"duration": 0.45,
		"vol": volume
	})

static func play_cash_pickup(volume: float = 0.8) -> void:
	if not instance: return
	instance._active_one_shots.append({
		"type": "cash",
		"time": 0.0,
		"duration": 0.35,
		"vol": volume
	})

static func play_impact(volume: float = 0.85) -> void:
	if not instance: return
	instance._active_one_shots.append({
		"type": "impact",
		"time": 0.0,
		"duration": 0.25,
		"vol": volume
	})

static func set_siren_active(active: bool) -> void:
	if instance:
		instance._siren_active = active

static func set_engine_state(active: bool, rpm_norm: float = 0.0) -> void:
	if instance:
		instance._engine_active = active
		instance._engine_rpm = clampf(rpm_norm, 0.0, 1.0)
