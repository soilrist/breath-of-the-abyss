extends Node


func _ready() -> void:
	GameState.chapter = 6
	GameState.chapter_kills = 0
	GameState.quest_stage = 21
	GameState.unlock_map("current_maw")
	GameState.current_map = "current_maw"
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
	main._change_map("current_maw", false)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter6_maw.png")
	print("SHOT chapter6_maw")
	get_tree().quit()
