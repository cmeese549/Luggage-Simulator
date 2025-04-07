extends Node

@onready var song_1 : AudioStreamPlayer = $Song1
@onready var song_2 : AudioStreamPlayer = $Song2
@onready var song_timer : Timer = $SongTimer

var skipping_intro : bool = true

func _ready() -> void:
	song_1.finished.connect(start_song_timer)
	song_2.finished.connect(start_song_timer)
	if skipping_intro: 
		start_game()
	
func start_song_timer() -> void:
	song_timer.start()

func start_game() -> void:
	play_song(song_1)

func play_song(song: AudioStreamPlayer) -> void:
	song.play()
	detach_all_connections(song_timer)
	if song == song_1:
		song_timer.timeout.connect(play_song.bind(song_2))
	else:
		song_timer.timeout.connect(play_song.bind(song_1))
	
func detach_all_connections(timer: Node) -> void:
	for cur_conn in timer.timeout.get_connections():
		cur_conn.signal.disconnect(cur_conn.callable)
