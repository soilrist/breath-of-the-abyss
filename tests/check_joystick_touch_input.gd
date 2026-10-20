extends Node
## check_joystick.gd는 `stick._update_knob()`/`stick._end_drag()`를 코드로
## 직접 호출해서만 검증한다 — 실제로 손가락이 화면을 누르고 끌 때 타는
## `virtual_joystick.gd:_input()`(InputEventMouseButton/InputEventMouseMotion)
## 경로는 한 번도 탄 적이 없었다. 안드로이드에서 조이스틱은 이동의 유일한
## 조작 수단이라 check_mobile_button_click.gd 등이 이미 쓴
## `get_viewport().push_input(event, true)` 패턴을 그대로 재사용해 실제
## 입력 경로로 채운다.

func _push_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame


func _push_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await get_tree().process_frame


func _ready() -> void:
	var ok := true
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

	var stick: Control = mobile.get_node("Joystick")
	ok = _check("Joystick이 실제로 화면에 보임", stick.visible) and ok
	var center: Vector2 = stick.get_global_rect().get_center()

	# 진짜 마우스 다운으로 조이스틱을 누른다 (InputEventMouseButton -> _input()).
	await _push_button(center, true)
	ok = _check("진짜 마우스 다운으로 드래그 시작(_dragging)", stick._dragging) and ok

	# 진짜 마우스 이동으로 오른쪽으로 끈다 (InputEventMouseMotion -> _input()).
	await _push_motion(center + Vector2(30, 0))
	ok = _check("진짜 드래그(오른쪽)로 move_right만 눌림",
		Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left")
		and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down")) and ok

	# 대각선(오른쪽 아래)으로 이동 -> 두 축 모두 눌려야 한다.
	await _push_motion(center + Vector2(20, 20))
	ok = _check("진짜 드래그(오른쪽 아래 대각선)로 move_right+move_down 둘 다 눌림",
		Input.is_action_pressed("move_right") and Input.is_action_pressed("move_down")
		and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_up")) and ok

	# 죽은 영역(중앙 근처) -> 아무 것도 안 눌림.
	await _push_motion(center + Vector2(2, 1))
	ok = _check("진짜 드래그(죽은 영역)로 전부 해제",
		not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_down")) and ok

	# 손을 뗀다 (InputEventMouseButton pressed=false -> _input() -> _end_drag()).
	await _push_motion(center + Vector2(-30, 0))
	ok = _check("떼기 전 마지막 위치(왼쪽)로 move_left가 눌림",
		Input.is_action_pressed("move_left")) and ok
	await _push_button(center + Vector2(-30, 0), false)
	ok = _check("진짜 마우스 업으로 드래그 종료(_dragging 해제)", not stick._dragging) and ok
	ok = _check("진짜 마우스 업 뒤 전부 해제",
		not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right")
		and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
