extends Node
## 가상 조이스틱이 드래그 방향에 맞는 move_* 액션을 누르고 떼는지 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	var stick: Control = main.get_node("HUD/MobileControls/Joystick")
	var center: Vector2 = stick.get_global_rect().get_center()
	var ok := true

	# 오른쪽으로 드래그 -> move_right 만 눌려야 한다.
	stick._update_knob(center + Vector2(30, 0))
	ok = ok and _check("오른쪽 드래그", Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"))

	# 오른쪽 아래 대각선 -> move_right + move_down 둘 다.
	stick._update_knob(center + Vector2(20, 20))
	ok = ok and _check("오른쪽 아래 대각선", Input.is_action_pressed("move_right") and Input.is_action_pressed("move_down") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_up"))

	# 중앙 근처(죽은 영역) -> 아무것도 안 눌림.
	stick._update_knob(center + Vector2(2, 1))
	ok = ok and _check("죽은 영역", not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_down"))

	# 손을 떼면 전부 풀려야 한다.
	stick._update_knob(center + Vector2(-30, 0))
	ok = ok and _check("왼쪽 드래그", Input.is_action_pressed("move_left"))
	stick._end_drag()
	ok = ok and _check("뗀 뒤 전부 해제", not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"))

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
