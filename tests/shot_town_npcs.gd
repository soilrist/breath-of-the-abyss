extends Node
## 마을 인물 5명(생존자 렌/등대지기 노아/등불지기 세인/정찰병 이든 x2:
## waystation_camp·rift_camp) 몸 스프라이트·초상화·필러 대사가 실제
## 대화창에서 잘리거나 겹치지 않는지 확인하는 스크린샷. 렌(remnant_village)/
## 이든의 rift_camp 쪽은 이전 바퀴가 임시 스크립트로만 확인하고 커밋하지
## 않아 영구 검사가 없었다 — 5곳 전부로 넓혀 빠짐없이 남긴다.

const TARGETS := ["remnant_village", "driftwood_pier", "lantern_village", "waystation_camp", "rift_camp"]


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	# 필러 대사(else 분기)만 보면 되므로 의뢰·전직 분기를 비켜 둔다.
	GameState.job = "warrior"
	GameState.bounty_index = GameState.BOUNTIES.size()
	GameState.bounty_taken = false
	GameState.quest_stage = 9999

	var player: CharacterBody2D = main.get_node("Player")
	for map_name in TARGETS:
		GameState.unlock_map(map_name)
		main._change_map(map_name, false)
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		player.global_position = World.town_npc_position(map_name, "elder")
		main._interact_npc()
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://town_npc_%s.png" % map_name)
		print("SHOT town_npc_", map_name)
		while main.dialogue_open: main._advance_dialogue()

	get_tree().quit()
