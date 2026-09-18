extends AudioStreamPlayer
## Autoload singleton registered as "BGM": plays the background music on loop
## for the whole session (it survives level changes because it lives outside
## the main scene).

const MUSIC_PATH: String = "res://assets/sounds/music.ogg"
const MUSIC_VOLUME_DB: float = -8.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_music()


func play_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		push_warning("BGM: music file not found: %s" % MUSIC_PATH)
		return

	var music: AudioStream = load(MUSIC_PATH)
	if music == null:
		push_warning("BGM: could not load %s" % MUSIC_PATH)
		return

	# Make sure the track loops even if the import does not say so.
	if music is AudioStreamOggVorbis:
		(music as AudioStreamOggVorbis).loop = true
	elif music is AudioStreamMP3:
		(music as AudioStreamMP3).loop = true

	stream = music
	volume_db = MUSIC_VOLUME_DB
	autoplay = true
	play()


func stop_music() -> void:
	stop()


func _exit_tree() -> void:
	# Let go of the stream so the audio server is not still holding it on shutdown.
	stop()
	stream = null
