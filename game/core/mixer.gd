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

## Adds a seamless loop. A null stream (file not built yet) is skipped silently.
func add_loop(id: String, stream: AudioStream, bus := "Master") -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
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
		players[id].volume_db = linear_to_db(maxf(mix[id], 0.0001))

## Snaps every loop to its target (on entering a room, a load or a jump).
func snap(targets: Dictionary) -> void:
	last_targets = targets
	for id in players:
		mix[id] = targets.get(id, 0.0)
		players[id].volume_db = linear_to_db(maxf(mix[id], 0.0001))

## Stop every voice before the players go, so the audio server lets their playbacks go too.
func _exit_tree() -> void:
	for p in players.values():
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	players.clear()
