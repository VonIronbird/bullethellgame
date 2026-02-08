extends RefCounted
class_name SimpleSynth

const MAX_VOICES := 16
const TWO_PI := 6.283185307179586

# ADSR in seconds
var attack := 0.01
var decay := 0.12
var sustain := 0.7
var release := 0.2

# Simple high-pass to reduce low-end buildup and improve clarity.
var hp_cutoff := 120.0
var _hp_x := 0.0
var _hp_y := 0.0

class Voice:
	var active := false
	var note := 0
	var freq := 0.0
	var phase := 0.0
	var velocity := 0.0
	var env := 0.0
	var state := 0 # 0 attack,1 decay,2 sustain,3 release

	func reset(p_note: int, p_freq: float, p_velocity: float) -> void:
		active = true
		note = p_note
		freq = p_freq
		velocity = p_velocity
		phase = 0.0
		env = 0.0
		state = 0

var voices: Array[Voice] = []

func _init() -> void:
	voices.resize(MAX_VOICES)
	for i in range(MAX_VOICES):
		voices[i] = Voice.new()

static func midi_note_to_freq(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

func note_on(note: int, velocity: int) -> void:
	var v := _find_voice(note)
	v.reset(note, midi_note_to_freq(note), velocity / 127.0)

func note_off(note: int) -> void:
	for v in voices:
		if v.active and v.note == note and v.state != 3:
			v.state = 3

func _find_voice(note: int) -> Voice:
	for v in voices:
		if not v.active:
			return v
	# Voice stealing: pick the quietest
	var best := voices[0]
	for v in voices:
		if v.env < best.env:
			best = v
	return best

func _step_envelope(v: Voice, dt: float) -> void:
	match v.state:
		0:
			v.env += dt / max(attack, 0.0001)
			if v.env >= 1.0:
				v.env = 1.0
				v.state = 1
		1:
			var target := sustain
			v.env -= dt / max(decay, 0.0001) * (1.0 - target)
			if v.env <= target:
				v.env = target
				v.state = 2
		2:
			# sustain
			v.env = sustain
		3:
			v.env -= dt / max(release, 0.0001)
			if v.env <= 0.0:
				v.env = 0.0
				v.active = false

func sample(dt: float) -> float:
	var out := 0.0
	var voice_count := 0
	for v in voices:
		if not v.active:
			continue
		_step_envelope(v, dt)
		if not v.active:
			continue
		voice_count += 1
		v.phase = fmod(v.phase + v.freq * dt, 1.0)
		# Simple triangle wave
		var wave: float = 2.0 * abs(2.0 * v.phase - 1.0) - 1.0
		out += wave * v.env * v.velocity
	if voice_count > 0:
		out /= sqrt(float(voice_count))
	out = _highpass(out, dt)
	# Soft saturation to avoid harsh clipping when voices stack.
	return out / (1.0 + absf(out))

func _highpass(x: float, dt: float) -> float:
	if hp_cutoff <= 0.0:
		return x
	var rc := 1.0 / (TWO_PI * hp_cutoff)
	var alpha := rc / (rc + dt)
	var y := alpha * (_hp_y + x - _hp_x)
	_hp_x = x
	_hp_y = y
	return y
