extends Node
## 8장 보스(감독관) 전신 + 물약 30 표시 눈으로 확인용 캡처.
func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open:
		main._advance_dialogue()
	GameState.chapter = 8
	GameState.potions = GameState.MAX_POTIONS
	main._change_map("chamber_of_wardens", false)
	main.get_node("Player").potions = GameState.potions
	main._on_potion_changed(GameState.potions)
	while main.dialogue_open:
		main._advance_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss:
			main.get_node("Player").global_position = e.global_position + Vector2(-60, 20)
			print("BOSS ", e.kind["id"], " hframes=", e.get_node("Sprite").hframes, " pos=", e.global_position)
	for i in 6:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://shot_boss8_potion.png")
	print("SHOT ", ProjectSettings.globalize_path("user://shot_boss8_potion.png"))
	get_tree().quit()
