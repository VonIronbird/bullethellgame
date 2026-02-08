extends Node
class_name MidiMusicPlayer

@export var midi_path: String = ""
@export var loop: bool = true
@export var sample_rate: int = 44100
@export var buffer_length: float = 0.2

var _synth := SimpleSynth.new()
var _midi_data: Dictionary = {}
var _events: Array = []
var _event_index := 0
var _time := 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _playing := false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = buffer_length
	_player.stream = gen
	_player.play()
	_playback = _player.get_stream_playback()

	if midi_path != "":
		load_midi(midi_path)
		play()

func load_midi(path: String) -> void:
	_midi_data = MidiFile.load_midi(path)
	_events = _midi_data.get("events", [])
	_event_index = 0
	_time = 0.0
	_synth = SimpleSynth.new()

func play() -> void:
	if _events.is_empty():
		return
	_playing = true
	if not _player.playing:
		_player.play()
	_playback = _player.get_stream_playback()

func stop() -> void:
	_playing = false
	_event_index = 0
	_time = 0.0
	_synth = SimpleSynth.new()

func _process(_delta: float) -> void:
	if not _playing:
		return
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var dt := 1.0 / float(sample_rate)
	while frames > 0:
		# Fire MIDI events scheduled up to current time
		while _event_index < _events.size() and float(_events[_event_index].get("time", 0.0)) <= _time:
			var ev: Dictionary = _events[_event_index]
			if ev["type"] == "note_on":
				_synth.note_on(ev["note"], ev["velocity"])
			elif ev["type"] == "note_off":
				_synth.note_off(ev["note"])
			_event_index += 1

		var s := _synth.sample(dt)
		# Quantize to 16-bit then return to float range
		var q := float(int(round(s * 32767.0))) / 32767.0
		_playback.push_frame(Vector2(q, q))
		_time += dt
		frames -= 1

	var duration := _midi_data.get("duration", 0.0)
	if duration > 0.0 and _time >= duration and _event_index >= _events.size():
		if loop:
			load_midi(midi_path)
			play()
		else:
			stop()
