Simple MIDI (Type 0/1) reader and lightweight synth for Godot 4.x.

Usage
1. Add a Node and attach `addons/midi/MidiMusicPlayer.gd`.
2. Set `midi_path` to a `.mid` file (res://...).
3. Call `play()` or enable autoplay by setting the path before `_ready()`.

Notes
- Only basic note on/off events are used.
- Output is quantized to 16-bit and sent to `AudioStreamGenerator`.
- No SoundFont or samples; triangle wave synth with ADSR.
