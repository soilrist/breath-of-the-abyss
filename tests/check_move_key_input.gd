extends Node
## STATUS.md "다음 후보"가 남긴 마지막 공백: 이동(move_left/right/up/down)은
## player.gd:150의 _physics_process가 매 프레임
## Input.get_vector("move_left","move_right","move_up","move_down")로 직접
## 폴링하는 지속 입력(analog vector)이다. attack/dash(just_pressed)와 달리
## 눌렀다 떼는 한 번짜리 입력이 아니라 누르고 있는 동안 계속 이동해야 하므로
## 키를 누른 채로 여러 physics_frame을 넘기고, 뗀 뒤 멈추는지까지 확인한다.
## check_attack_dash_key_input.gd와 동일하게 Input.parse_input_event()로
## 진짜 InputEventKey를 주입한다.

const KEY_MOVE_RIGHT := KEY_D


func _hold_key(key: Key, frames: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	for i in range(frames):
		await get_tree().physics_frame


func _release_key(key: Key) -> void:
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().physics_frame


func _ready() -> void:
	var ok := await _check_move()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_move() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var start_pos: Vector2 = player.global_position
	var ok := true

	await _hold_key(KEY_MOVE_RIGHT, 5)
	ok = _check("D 키(move_right) 실제 입력으로 오른쪽 이동", player.global_position.x > start_pos.x) and ok
	ok = _check("D 키(move_right) 실제 입력으로 facing이 오른쪽", player.facing.x > 0.0) and ok

	await _release_key(KEY_MOVE_RIGHT)
	# parse_input_event()가 액션 상태에 반영되는 데 걸리는 프레임 수가
	# 고정이 아니다(실측: 보통 1프레임이지만, 시스템 부하가 있으면 2프레임
	# 걸릴 때가 있었다 - 전체 검사 스위트를 돌릴 때 산발적으로 흔들리던
	# 원인). 고정 프레임 수 대신 velocity가 실제로 0이 될 때까지 기다린다.
	var settle_frames := 0
	while player.velocity != Vector2.ZERO and settle_frames < 10:
		await get_tree().physics_frame
		settle_frames += 1
	var released_pos: Vector2 = player.global_position
	await get_tree().physics_frame
	ok = _check("D 키를 떼면 더 이동하지 않음", player.global_position == released_pos) and ok

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
