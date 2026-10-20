extends Node
## 레벨업 축제 연출(INBOX 2026-10-20 00:09) 3층 눈 검사용 캡처 하네스.
## `--headless` 로 돌리면 save_png 가 멈춘다 - 다른 shot_*.gd 와 같이 창을 띄워 실행.
## 0.3초(배너 튀어나오는 중)·1.0초(카드 쌓인 뒤) 두 장을 찍는다.

func _ready() -> void:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._on_enemy_defeated(GameState.next_exp, 0)

	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://levelup_fanfare_0.3s.png")
	print("SHOT levelup_fanfare_0.3s")

	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://levelup_fanfare_1.0s.png")
	print("SHOT levelup_fanfare_1.0s")
	get_tree().quit()
