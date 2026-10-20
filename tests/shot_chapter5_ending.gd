extends Node
## 5장(확장팩) 보스(태초의 심연) 처치 후 결말 대사(quest_stage==19 -> 20,
## main.gd:809)를 실제로 화면에 띄워 잘리거나 겹치지 않는지 확인하는 스크린샷.
## shot_chapter1_ending.gd/shot_chapter10_ending.gd와 같은 패턴 - 1·10장은
## 이미 확인됐지만 5~9장(확장팩 챕터) 결말 대사는 아직 화면으로 본 적이 없다.
## remnant_village(생존자 렌)에서 확인 - 가장 긴 마지막 줄까지 본다.


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.chapter = 5
	GameState.quest_stage = 19
	GameState.boss_defeated = true
	GameState.unlock_map("remnant_village")
	main._change_map("remnant_village", false)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position("remnant_village", "elder")
	main._interact_npc()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter5_ending_line1.png")
	print("SHOT chapter5_ending_line1")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter5_ending_line2.png")
	print("SHOT chapter5_ending_line2")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter5_ending_line3.png")
	print("SHOT chapter5_ending_line3")

	get_tree().quit()
