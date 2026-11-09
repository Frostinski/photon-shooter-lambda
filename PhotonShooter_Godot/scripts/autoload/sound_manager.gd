extends Node

var sfx_streams: Dictionary = {}
var sfx_volumes: Dictionary = {
	"menu_move": -11.0,
	"menu_confirm": -9.0,
	"menu_back": -10.5,
	"primary_fire": -12.5,
	"secondary_fire": -7.5,
	"dodge": -8.0,
	"dodge_ready": -12.5,
	"enemy_fire": -14.0,
	"enemy_hit": -11.0,
	"explosion": -6.0,
	"player_hit": -5.0,
	"boss_warning": -5.5,
	"boss_fire": -8.0
}

var sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 16
var sfx_pool_index: int = 0

var music_player: AudioStreamPlayer
var current_music_track: String = ""
var fade_tween: Tween = null


func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	_load_sfx()


func _load_wav(res_path: String) -> AudioStreamWAV:
	if ResourceLoader.exists(res_path):
		var res = ResourceLoader.load(res_path)
		if res is AudioStreamWAV:
			return res.duplicate()
	var global_path = ProjectSettings.globalize_path(res_path)
	if not global_path.is_empty() and FileAccess.file_exists(global_path):
		var stream = AudioStreamWAV.load_from_file(global_path)
		if stream != null:
			return stream
	return null


func _load_sfx() -> void:
	for sfx_name in sfx_volumes.keys():
		var path = "res://assets/sfx/" + sfx_name + ".wav"
		var stream = _load_wav(path)
		if stream != null:
			sfx_streams[sfx_name] = stream
	if not sfx_streams.has("dodge_ready"):
		sfx_streams["dodge_ready"] = _synthesize_dodge_ready_wav()


func _synthesize_dodge_ready_wav() -> AudioStreamWAV:
	var mix_rate: int = 44100
	var duration: float = 0.145
	var total_samples: int = int(mix_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(total_samples * 2)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(mix_rate)
		var is_second_note: bool = (t >= 0.055)
		var local_t: float = (t - 0.055) if is_second_note else t
		var note_dur: float = 0.090 if is_second_note else 0.055
		var base_freq: float = 1318.51 if is_second_note else 880.0
		var freq: float = base_freq + (18.0 * (local_t / note_dur) if is_second_note else 0.0)
		phase += TAU * freq / float(mix_rate)

		var attack: float = clampf(local_t / 0.0045, 0.0, 1.0)
		var decay_rate: float = 28.0 if is_second_note else 22.0
		var env: float = attack * exp(-decay_rate * local_t) * (1.0 - clampf((t - (duration - 0.012)) / 0.012, 0.0, 1.0))
		var sample_f: float = (
			sin(phase) * 0.74
			+ sin(phase * 2.0) * 0.20
			+ sin(phase * 3.0) * 0.06
		) * env * 0.56
		var sample_i: int = clampi(int(round(sample_f * 32767.0)), -32768, 32767)
		pcm.encode_s16(i * 2, sample_i)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = pcm
	return wav


func play(sfx_name: String) -> void:
	if not sfx_streams.has(sfx_name):
		return
	var player = sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = sfx_streams[sfx_name]
	player.volume_db = sfx_volumes.get(sfx_name, -8.0)
	player.play()


func play_music(track_name: String, loop: bool = true, volume_linear: float = 0.55, force_restart: bool = false) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
		fade_tween = null

	if current_music_track == track_name and music_player.playing and not force_restart:
		music_player.stream_paused = false
		music_player.volume_db = linear_to_db(clampf(volume_linear, 0.001, 1.0))
		return

	var res_path = "res://assets/audio/" + track_name
	var stream = _load_wav(res_path)
	if stream == null:
		return

	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		if stream.format in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
			var bytes_per_sample = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels = 2 if stream.stereo else 1
			if bytes_per_sample * channels > 0:
				stream.loop_end = int(stream.data.size() / (bytes_per_sample * channels))
		else:
			stream.loop_end = maxi(1, int(round(stream.get_length() * float(stream.mix_rate))))
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED

	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = linear_to_db(clampf(volume_linear, 0.001, 1.0))
	music_player.stream_paused = false
	music_player.play()
	current_music_track = track_name


func stop_music() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
		fade_tween = null
	music_player.stop()
	current_music_track = ""


func fadeout_music(millis: int = 2000) -> void:
	if not music_player.playing:
		current_music_track = ""
		return
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	var duration = maxf(0.05, float(millis) / 1000.0)
	fade_tween.tween_property(music_player, "volume_db", -60.0, duration)
	fade_tween.tween_callback(func():
		music_player.stop()
		current_music_track = ""
	)


func pause_music() -> void:
	if music_player.playing:
		music_player.stream_paused = true


func resume_music() -> void:
	if music_player.stream != null:
		music_player.stream_paused = false
