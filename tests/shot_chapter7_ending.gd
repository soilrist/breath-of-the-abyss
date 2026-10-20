extends Node
## 7장(확장팩) 보스(빛바랜 사제왕) 처치 후 결말 대사(quest_stage==39 -> 40,
## main.gd:849)를 실제로 화면에 띄워 잘리거나 겹치지 않는지 확인하는 스크린샷.
## shot_chapter6_ending.gd와 같은 패턴 - lantern_village(세인)에서 확인.


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.chapter = 7
	GameState.quest_stage = 39
	GameState.boss_defeated = true
	GameState.unlock_map("lantern_village")
	main._change_map("lantern_village", false)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position("lantern_village", "elder")
	main._interact_npc()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter7_ending_line1.png")
	print("SHOT chapter7_ending_line1")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter7_ending_line2.png")
	print("SHOT chapter7_ending_line2")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter7_ending_line3.png")
	print("SHOT chapter7_ending_line3")

	get_tree().quit()
