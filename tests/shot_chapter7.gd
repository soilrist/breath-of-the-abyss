extends Node


func _ready() -> void:
	GameState.chapter = 7
	GameState.chapter_kills = 0
	GameState.quest_stage = 31
	GameState.unlock_map("gilded_cloister")
	GameState.current_map = "gilded_cloister"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("gilded_cloister", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter7_cloister.png")
	print("SHOT chapter7_cloister")
	get_tree().quit()
