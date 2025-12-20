extends Node


func play(audio:AudioStream,single=false,volume_db:float=0.0) -> void:
	if not audio:return
	if single:stop()
	
	for player: AudioStreamPlayer in get_children():
		if not player.playing:
			player.stream = audio
			player.volume_db = volume_db
			player.play()
			return

func stop()-> void:
	for player: AudioStreamPlayer in get_children():
		player.stop()
