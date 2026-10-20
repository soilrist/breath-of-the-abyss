extends Node
## 퀘스트 완료 배너(INBOX 2026-10-20 00:10 나머지 절반) 3층 눈 검사용 캡처.
## `--headless` 로 돌리면 save_png 가 멈춘다 - 다른 shot_*.gd 와 같이 창을
## 띄워 실행. 의뢰를 완료하고 대화를 닫은 뒤 상자가 터지는 순간을 찍는다.

func _ready() -> void:
	GameState.reset()
	GameState.quest_stage = 1
	GameState.take_bounty()
	GameState.bounty_progress = int(GameState.current_bounty()["count"])

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main.get_node("Player").global_position = World.town_npc_position(GameState.current_map, "elder")
	main._interact_npc()
	while main.dialogue_open: main._advance_dialogue()

	# 큐에 들어간 뒤 LEVEL_REWARD_BOX_DELAY(2.0초) 지나야 상자가 뜬다.
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://quest_complete_banner_closed.png")
	print("SHOT quest_complete_banner_closed")

	main._level_reward_box._open()
	# 결함(감독, 2026-10-20 03:28): 흔들림(0.3초)+고리 빛(0.28초) 다 지나야
	# 보상 줄 글자가 보인다 - 그 전에 찍으면 빈 줄만 찍힌다.
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://quest_complete_banner_burst.png")
	print("SHOT quest_complete_banner_burst")
	get_tree().quit()
