## 1장 보스(숲의 군주) 처치 후 결말 대사(quest_stage==9 -> 10, main.gd:785)를
## 실제로 화면에 띄워 잘리거나 겹치지 않는지 확인하는 스크린샷. 10장 결말은
## shot_chapter10_ending.gd로 이미 확인됐지만 1장을 비롯한 나머지 챕터
## 결말 대사는 이 패턴으로 확인된 적이 없었다(STATUS 2b18e6f "다음 후보").
## village(촌장)에서 확인 - 마지막 줄이 두 문장으로 가장 길어 잘림 위험이 가장 크다.
extends Node


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.chapter = 1
	GameState.quest_stage = 9
	GameState.boss_defeated = true
	main._change_map("village", false)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position("village", "elder")
	main._interact_npc()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter1_ending_line1.png")
	print("SHOT chapter1_ending_line1")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter1_ending_line2.png")
	print("SHOT chapter1_ending_line2")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter1_ending_line3.png")
	print("SHOT chapter1_ending_line3")

	get_tree().quit()
