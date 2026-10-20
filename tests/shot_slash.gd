extends Node
## 칼질 궤적이 네 방향으로 제대로 나오는지 본다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	GameState.level = 20
	GameState.equipped = {"weapon": "철검", "armor": "", "helmet": "", "trinket": ""}
	GameState._recalc_bonuses()
	main._apply_equipment_to_player()
	main._change_map("forest_w", false)
	for pair in [[Vector2.RIGHT, "east"], [Vector2.UP, "north"], [Vector2.DOWN, "south"], [Vector2.LEFT, "west"]]:
		player.facing = pair[0]
		player.cooldown_time = 0.0
		player._update_sprite(Vector2.ZERO)
		player.attack()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://slash_%s.png" % pair[1])
		print("SHOT ", pair[1])
	get_tree().quit()
