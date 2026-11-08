class_name LoopMixer
extends Node
## Ambient loops for a room view, lifted from the Intake Office slice: every loop plays
## from the start at -80 dB and is faded toward a per-frame target. A room computes its
## targets (linear 0..1) from story state each frame and calls tick(); nothing here is saved.
##
##   var mixer := LoopMixer.new(); add_child(mixer)
##   mixer.add_loop("sea", game.load_audio("sea"))
##   mixer.tick({"sea": 0.75}, {"sea": 0.9}, dt)   # rates: linear units per second

var players := {}       # loop id -> AudioStreamPlayer
var mix := {}           # loop id -> current linear volume
var last_targets := {}  # the targets of the last tick (tests read these)
## A gain over every loop (linear 0..1): the core's hold_breath ducks it. Presentation only.
var duck := 1.0
## The room's bed trim (linear, GameView.ROOM_TRIM_DB), set by the core. It is faded out as
## `duck` falls, so a held breath ducks to the same floor in every room.
var trim := 1.0
var sources := {}       # loop id -> the stream's resource path (bed_loudness reads it)

static var _rms_cache := {}   # source path -> RMS (linear, full scale 1.0)

## Adds a seamless loop. A null stream (file not built yet) is skipped silently.
func add_loop(id: String, stream: AudioStream, bus := "Master") -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	sources[id] = wav.resource_path
	wav = wav.duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.volume_db = -80.0
	p.bus = bus
	add_child(p)
	p.play()
	players[id] = p
	mix[id] = 0.0

func tick(targets: Dictionary, rates: Dictionary, dt: float, default_rate := 0.8) -> void:
	last_targets = targets
	for id in players:
		mix[id] = move_toward(mix[id], targets.get(id, 0.0), dt * rates.get(id, default_rate))
	apply_duck()

## Snaps every loop to its target (on entering a room, a load or a jump).
func snap(targets: Dictionary) -> void:
	last_targets = targets
	for id in players:
		mix[id] = targets.get(id, 0.0)
	apply_duck()

## Sets every voice to its mix times `duck` and the trim (after a tick, a snap, or a duck or
## trim change). The trim is faded out with the duck: none of it while the beds are held.
func gain() -> float:
	return duck * lerpf(1.0, trim, clampf(duck, 0.0, 1.0))

func apply_duck() -> void:
	var k := gain()
	for id in players:
		players[id].volume_db = linear_to_db(maxf(mix[id] * k, 0.0001))

## The RMS (linear, full scale 1.0) of loop `id`'s source WAV, 0.0 when unknown.
func source_rms(id: String) -> float:
	return wav_rms(str(sources.get(id, "")))

## The RMS of a PCM WAV file (8/16/24-bit, any channels), read from the file itself: the
## imported stream may be compressed. Sampled every few frames; cached per path.
static func wav_rms(path: String) -> float:
	if path == "":
		return 0.0
	if _rms_cache.has(path):
		return _rms_cache[path]
	var out := 0.0
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var b := f.get_buffer(f.get_length())
		var bits := 16
		var at := 12
		while at + 8 <= b.size():
			var tag := b.slice(at, at + 4).get_string_from_ascii()
			var size := b.decode_u32(at + 4)
			if tag == "fmt ":
				bits = b.decode_u16(at + 22)
			elif tag == "data":
				var step := bits / 8
				var end := mini(at + 8 + size, b.size())
				var sum := 0.0
				var n := 0
				var i := at + 8
				var stride := step * 7
				while i + step <= end:
					var v := 0.0
					match bits:
						8: v = (b[i] - 128) / 128.0
						16: v = b.decode_s16(i) / 32768.0
						24:
							var w: int = (b[i + 2] << 16) | (b[i + 1] << 8) | b[i]
							v = float(w - 0x1000000 if w >= 0x800000 else w) / 8388608.0
						_: v = 0.0
					sum += v * v
					n += 1
					i += stride
				out = sqrt(sum / n) if n > 0 else 0.0
				break
			at += 8 + size + (size & 1)
	_rms_cache[path] = out
	return out

## Moves the mixer under `to` without a cut: the voices carry on from where they were (the
## core hands a room's loops over to itself when she leaves, to fade them out).
func carry_to(to: Node) -> void:
	var at := {}
	for id in players:
		if players[id].playing:
			at[id] = players[id].get_playback_position()
	keep_on_exit = true
	reparent(to)
	keep_on_exit = false
	for id in at:
		if not players[id].playing:
			players[id].play(at[id])

var keep_on_exit := false

## Stop every voice before the players go, so the audio server lets their playbacks go too.
func _exit_tree() -> void:
	if keep_on_exit:
		return
	for p in players.values():
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	players.clear()
