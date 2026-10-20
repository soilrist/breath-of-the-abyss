extends Node
## 레벨 보상 상자(INBOX 2026-10-20 00:10) 3층 눈 검사용 캡처 하네스.
## `--headless` 로 돌리면 save_png 가 멈춘다 - 다른 shot_*.gd 와 같이 창을 띄워 실행.
## 닫힌 상자(열기 전) 1장 + "열기"를 직접 눌러 터지는 순간 1장을 찍는다.

func _ready() -> void:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	while GameState.level < 5:
		main._on_enemy_defeated(GameState.next_exp, 0)

	# 레벨업 축제(약 1.8초)가 끝나고 상자가 뜨는 지연(main.gd LEVEL_REWARD_BOX_DELAY=2.0)
	# 뒤에 찍는다.
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://level_reward_box_closed.png")
	print("SHOT level_reward_box_closed")

	main._level_reward_box._open()
	# 결함(감독, 2026-10-20 03:28): 흔들림(0.3초)+고리 빛(0.28초) 다 지나야
	# 보상 줄 글자가 보인다 - 그 전에 찍으면 빈 줄만 찍힌다.
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://level_reward_box_burst.png")
	print("SHOT level_reward_box_burst")
	get_tree().quit()
