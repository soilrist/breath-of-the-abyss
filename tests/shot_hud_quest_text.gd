extends Node
## 결함(감독, 2026-10-20 01:30 → 02:28 재검수) ③ 3층 눈 검사용 캡처 하네스.
## HUD 위쪽 퀘스트 문구(`$HUD/Message`)가 x270(모바일 버튼 줄) 안에서 끝나는지
## 실제로 띄워 본다. `--headless` 로 돌리면 save_png 가 멈춘다 — 창을 띄워 실행.

func _ready() -> void:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	# quest_stage==0 -> "촌장에게 다가가 E키로 대화" -> 모바일 모드에선
	# _mob()이 "E키로"를 "대화 버튼으로"로 바꿔 지적된 문구 그대로 나온다.
	GameState.quest_stage = 0
	main._set_quest_message()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://hud_quest_text.png")
	print("SHOT hud_quest_text")
	get_tree().quit()
