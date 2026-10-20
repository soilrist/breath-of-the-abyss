extends Node
## 10장(최종장) 근원 보스 처치 후 결말 대사(quest_stage==69 -> 70, main.gd:909)를
## 실제로 화면에 띄워 잘리거나 겹치지 않는지 확인하는 스크린샷. 이 대사는
## `dc8f7da`에서 새로 추가됐지만 그동안 shot_chapter10_clear.gd(보스방 HUD
## 문구)만 확인됐지, NPC와 대화해 뜨는 이 결말 대사 자체는 한 번도 화면으로
## 본 적이 없었다. rift_camp(정찰병 이든)에서 확인 - 마지막 줄이 두 문장으로
## 가장 길어 잘림 위험이 가장 크다.


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.chapter = 10
	GameState.quest_stage = 69
	GameState.boss_defeated = true
	GameState.unlock_map("rift_camp")
	main._change_map("rift_camp", false)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = World.town_npc_position("rift_camp", "elder")
	main._interact_npc()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter10_ending_line1.png")
	print("SHOT chapter10_ending_line1")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter10_ending_line2.png")
	print("SHOT chapter10_ending_line2")

	main._advance_dialogue()
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter10_ending_line3.png")
	print("SHOT chapter10_ending_line3")

	get_tree().quit()
