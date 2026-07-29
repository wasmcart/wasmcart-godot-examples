extends Node

const GC = preload("res://game_constants.gd")

var snd_paddle: AudioStreamWAV
var snd_scream: AudioStreamWAV
var snd_countdown: AudioStreamWAV
var snd_explosions: Array = []
var _pool: Array = []

func _ready() -> void:
	snd_paddle = _load_wav("res://sounds/paddle.wav")
	snd_scream = _load_wav("res://sounds/scream.wav")
	snd_countdown = _load_wav("res://sounds/countdownBlip.wav")
	for snd_name in ["explosion5", "explosion7", "explosion8"]:
		var s := _load_wav("res://sounds/%s.wav" % snd_name)
		if s:
			snd_explosions.append(s)
	for i in range(GC.SFX_POOL_SIZE):
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_pool.append(pl)

func play_sound(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	for pl in _pool:
		if not pl.playing:
			pl.stream = stream
			pl.volume_db = volume_db
			pl.play()
			return

func play_explosion() -> void:
	if snd_explosions.size() > 0:
		play_sound(snd_explosions[randi() % snd_explosions.size()], -6.0)

func _load_wav(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	file.get_32()  # "RIFF"
	file.get_32()  # chunk size
	file.get_32()  # "WAVE"
	var sample_rate := 44100
	var bits := 16
	var channels := 1
	while file.get_position() < file.get_length():
		var chunk_id := file.get_32()
		var chunk_size := file.get_32()
		if chunk_id == 0x20746D66:  # "fmt "
			file.get_16()  # audio format
			channels = file.get_16()
			sample_rate = file.get_32()
			file.get_32()  # byte rate
			file.get_16()  # block align
			bits = file.get_16()
			if chunk_size > 16:
				file.seek(file.get_position() + chunk_size - 16)
		elif chunk_id == 0x61746164:  # "data"
			var data := file.get_buffer(chunk_size)
			var stream := AudioStreamWAV.new()
			stream.data = data
			stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
			stream.mix_rate = sample_rate
			stream.stereo = channels == 2
			return stream
		else:
			file.seek(file.get_position() + chunk_size)
	return null
