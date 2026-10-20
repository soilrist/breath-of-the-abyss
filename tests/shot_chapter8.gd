extends Node


func _ready() -> void:
	GameState.chapter = 8
	GameState.chapter_kills = 0
	GameState.quest_stage = 41
	GameState.unlock_map("silent_archive")
	GameState.current_map = "silent_archive"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("silent_archive", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter8_archive.png")
	print("SHOT chapter8_archive")
	get_tree().quit()
