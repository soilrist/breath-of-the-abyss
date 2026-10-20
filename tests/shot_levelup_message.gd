extends Node
## 레벨업 메시지(INBOX 2026-10-19 23:40) 3층 눈 검사용 캡처 하네스.
## `--headless` 로 돌리면 save_png 가 멈춘다 — 다른 shot_*.gd 와 같이 창을 띄워 실행.

func _ready() -> void:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._on_enemy_defeated(GameState.next_exp, 0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://levelup_message.png")
	print("SHOT levelup_message")
	get_tree().quit()
