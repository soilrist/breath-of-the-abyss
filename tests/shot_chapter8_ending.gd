extends Node
## 8장 보스(말없는 감독관) 처치 후 결말 대사(quest_stage==49 -> 50,
## main.gd:870)를 실제로 화면에 띄워 잘리거나 겹치지 않는지 확인하는 스크린샷.
## shot_chapter7_ending.gd와 같은 패턴 - waystation_camp(정찰병 이든)에서 확인.


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.chapter = 8
	GameState.quest_stage = 49
	GameState.boss_defeated = true
	GameState.unlock_map("waystation_camp")
	main._change_map("waystation_camp", false)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position("waystation_camp", "elder")
	main._interact_npc()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter8_ending_line1.png")
	print("SHOT chapter8_ending_line1")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter8_ending_line2.png")
	print("SHOT chapter8_ending_line2")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter8_ending_line3.png")
	print("SHOT chapter8_ending_line3")

	get_tree().quit()
