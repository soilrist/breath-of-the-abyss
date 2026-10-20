extends Node
## 새로 배치한 하단 HUD(HP/MP/EXP/레벨)가 제대로 보이는지 한 장 찍는다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.level = 7
	GameState.gold = 1234
	GameState.exp = 120
	GameState.next_exp = 300
	main._apply_equipment_to_player()
	main.get_node("Player").health = 62
	main.get_node("Player").mana = 18
	main._on_health_changed(62, main.get_node("Player").max_health)
	main._on_mana_changed(18, main.get_node("Player").max_mana)
	main._update_stats()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://hud_bottom.png")
	print("SHOT hud")
	get_tree().quit()
