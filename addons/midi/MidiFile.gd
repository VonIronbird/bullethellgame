extends RefCounted
class_name MidiFile

class MidiEvent:
	var tick: int
	var type: String
	var channel: int
	var note: int
	var velocity: int

	func _init(p_tick: int, p_type: String, p_channel: int, p_note: int, p_velocity: int) -> void:
		tick = p_tick
		type = p_type
		channel = p_channel
		note = p_note
		velocity = p_velocity

const DEFAULT_TEMPO_US_PER_QUARTER := 500000

class MidiReader:
	var data: PackedByteArray
	var pos: int = 0

	func _init(p_data: PackedByteArray) -> void:
		data = p_data
		pos = 0

	func read_u8() -> int:
		var v := data[pos]
		pos += 1
		return v

	func read_u16() -> int:
		var v := (data[pos] << 8) | data[pos + 1]
		pos += 2
		return v

	func read_u32() -> int:
		var v := (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3]
		pos += 4
		return v

	func read_varlen() -> int:
		var value := 0
		while true:
			var b := read_u8()
			value = (value << 7) | (b & 0x7f)
			if (b & 0x80) == 0:
				break
		return value

	func read_ascii(len: int) -> String:
		var s := data.slice(pos, pos + len).get_string_from_ascii()
		pos += len
		return s

static func load_midi(path: String) -> Dictionary:
	var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if data.size() < 14:
		push_error("MIDI file too small: %s" % path)
		return {}
	var r := MidiReader.new(data)

	# Header
	if r.read_ascii(4) != "MThd":
		push_error("Invalid MIDI header: %s" % path)
		return {}
	var header_len := r.read_u32()
	if header_len < 6:
		push_error("Invalid MIDI header length: %d" % header_len)
		return {}
	var format := r.read_u16()
	var track_count := r.read_u16()
	var division := r.read_u16()
	if division & 0x8000:
		push_error("SMPTE timing not supported: %s" % path)
		return {}
	var ppq := division & 0x7fff
	# Jump to end of header (in case of extra header bytes)
	r.pos = 8 + header_len

	var tempo_events: Array = []
	var events: Array[MidiEvent] = []

	for _i in range(track_count):
		if r.pos + 8 > data.size():
			break
		if r.read_ascii(4) != "MTrk":
			push_error("Invalid track header in: %s" % path)
			return {}
		var track_len := r.read_u32()
		var track_end := r.pos + track_len
		var tick := 0
		var running_status := 0
		while r.pos < track_end:
			var delta := r.read_varlen()
			tick += delta
			var status := r.read_u8()
			if status < 0x80:
				# Running status
				r.pos -= 1
				status = running_status
			else:
				running_status = status

			if status == 0xFF:
				var meta_type := r.read_u8()
				var len := r.read_varlen()
				if meta_type == 0x51 and len == 3:
					var us_per_quarter := (r.read_u8() << 16) | (r.read_u8() << 8) | r.read_u8()
					tempo_events.append({"tick": tick, "us_per_quarter": us_per_quarter})
				else:
					r.pos += len
				continue
			elif status == 0xF0 or status == 0xF7:
				var len := r.read_varlen()
				r.pos += len
				continue
			else:
				var event_type := status & 0xF0
				var channel := status & 0x0F
				match event_type:
					0x80:
						var note := r.read_u8()
						var vel := r.read_u8()
						events.append(MidiEvent.new(tick, "note_off", channel, note, vel))
					0x90:
						var note := r.read_u8()
						var vel := r.read_u8()
						var typ := "note_on" if vel > 0 else "note_off"
						events.append(MidiEvent.new(tick, typ, channel, note, vel))
					0xC0:
						# Program change (skip)
						r.pos += 1
					0xA0, 0xB0, 0xE0:
						# Skip 2-byte channel events
						r.pos += 2
					0xD0:
						# Skip 1-byte channel events
						r.pos += 1
					_:
						# Unknown, try to skip 1 byte to avoid infinite loop
						r.pos += 1

	# Ensure tempo map has default at tick 0
	var has_tick0 := false
	for te in tempo_events:
		if te["tick"] == 0:
			has_tick0 = true
			break
	if not has_tick0:
		tempo_events.append({"tick": 0, "us_per_quarter": DEFAULT_TEMPO_US_PER_QUARTER})
	tempo_events.sort_custom(Callable(MidiFile, "_sort_by_tick"))

	# Convert ticks to seconds using tempo map
	var events_with_time: Array = []
	for ev in events:
		events_with_time.append({
			"time": _tick_to_seconds(ev.tick, ppq, tempo_events),
			"type": ev.type,
			"channel": ev.channel,
			"note": ev.note,
			"velocity": ev.velocity
		})

	events_with_time.sort_custom(Callable(MidiFile, "_sort_by_time"))
	var duration := 0.0
	if events_with_time.size() > 0:
		duration = events_with_time[events_with_time.size() - 1]["time"]

	return {
		"ppq": ppq,
		"format": format,
		"events": events_with_time,
		"duration": duration
	}

static func _tick_to_seconds(t: int, ppq: int, tempo_events: Array) -> float:
	var total: float = 0.0
	var last_tick: int = 0
	var last_tempo: int = int(tempo_events[0]["us_per_quarter"])
	for te in tempo_events:
		var te_tick: int = int(te["tick"])
		if te_tick >= t:
			break
		var delta_ticks: int = te_tick - last_tick
		total += (delta_ticks / float(ppq)) * (last_tempo / 1000000.0)
		last_tick = te_tick
		last_tempo = int(te["us_per_quarter"])
	# Remaining
	var remaining := t - last_tick
	if remaining > 0:
		total += (remaining / float(ppq)) * (last_tempo / 1000000.0)
	return total

static func _sort_by_tick(a: Dictionary, b: Dictionary) -> bool:
	return a["tick"] < b["tick"]

static func _sort_by_time(a: Dictionary, b: Dictionary) -> bool:
	return a["time"] < b["time"]
