extends Node
## HUD/MobileControls의 Quit 버튼은 check_mobile_button_click.gd가 일부러
## 빼뒀다(get_tree().quit()으로 프로세스 자체를 끝내므로 그때까지 쓰던
## "한 트리에서 여러 버튼을 순서대로 클릭" 패턴을 못 쓴다, docs/STATUS.md
## 참고). RESULT는 클릭 전에 이미 찍어 둔다. 클릭 뒤 프로세스가 종료 코드
## 0으로 끝나는 것 자체가 "_pause_quit()이 정말 호출됐다"는 증거다 — 혹시
## 버튼이 씹혀 quit()이 안 불렸다면(회귀) 몇 프레임 뒤 워치독이 FAIL로 강제
## 종료해 run_validation.sh가 무한 대기하지 않게 한다.

func _click_down(button: Button) -> void:
	# check_mobile_button_click.gd와 동일한 이유로 get_viewport().push_input()을
	# 쓴다: project.godot의 window/stretch/mode="canvas_items"가 320x240
	# 논리 뷰포트를 확대하므로 Input.parse_input_event()로는 stretch 변환을
	# 안 타 좌표가 어긋난다.
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	button.get_viewport().push_input(down, true)
	await get_tree().process_frame


func _click_up(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	button.get_viewport().push_input(up, true)
	await get_tree().process_frame


func _ready() -> void:
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	while game.dialogue_open: game._advance_dialogue()
	await get_tree().process_frame

	var mobile := game.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	var pause_button: Button = mobile.get_node("Pause")
	await _click_down(pause_button)
	await _click_up(pause_button)
	var ok := _check("Pause 클릭으로 일시정지가 열림", game.pause_open and get_tree().paused)

	var quit_button: Button = mobile.get_node("Quit")
	ok = _check("Quit 버튼이 일시정지 화면에서 보임", quit_button.visible) and ok
	print("RESULT ", "PASS" if ok else "FAIL")

	await _click_down(quit_button)
	await _click_up(quit_button)

	# 여기 도달했다는 건 get_tree().quit()이 이번 프레임 안에 안 불렸다는 뜻
	# (정상이라면 프로세스가 위 클릭 처리 도중 종료를 예약하고 곧 죽는다) —
	# 워치독으로 FAIL 처리하고 직접 끝내 무한 대기를 막는다.
	for i in range(5):
		await get_tree().process_frame
	print("RESULT FAIL - Quit 클릭 후에도 프로세스가 종료되지 않음(워치독)")
	get_tree().quit(1)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
