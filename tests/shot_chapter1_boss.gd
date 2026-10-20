extends Node
## INBOX: "보스가 실제 플레이에서 안 보인다"(사용자 보고) 재현용.
## 이전 버전은 main._advance_dialogue()를 코드로 직접 호출해 대화를 넘겼다
## (규칙③ 위반 소지: 코드가 도는 것과 사람이 누르는 것은 다르다).
## 이번 버전은 실제 E 키 입력(Input.parse_input_event)으로 대화를 전부
## 넘겨서, 대화창이 완전히 닫힌 "진짜 전투 화면"을 찍는다.

func _press_e() -> void:
	var down := InputEventKey.new()
	down.physical_keycode = KEY_E
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _ready() -> void:
	GameState.chapter = 1
	GameState.quest_stage = 3
	GameState.unlock_map("dungeon")
	GameState.unlock_map("cave_deep")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		await _press_e()
	main._change_map("cave_deep", false)
	await get_tree().create_timer(0.4).timeout
	# 입장 직후 뜨는 보스 조우 대화를 실제 E 입력으로 전부 넘긴다.
	var guard := 0
	while main.dialogue_open and guard < 20:
		await _press_e()
		guard += 1
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter1_boss_after_dialogue.png")
	print("SHOT chapter1_boss_after_dialogue dialogue_open=%s" % main.dialogue_open)

	main.get_node("Player").global_position = Vector2(216, 110)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chapter1_boss_close.png")
	print("SHOT chapter1_boss_close")
	get_tree().quit()
