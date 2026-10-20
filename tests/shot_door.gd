extends Node
func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.keys = []; GameState.opened_doors = []
	main._change_map("dungeon", false)
	var door = get_tree().get_nodes_in_group("doors")[0]
	var cam: Camera2D = main.get_node("Player/Camera2D")
	main.get_node("Player").global_position = door.global_position + Vector2(24, 40)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://door.png")
	print("SHOT door")
	get_tree().quit()
