extends Node
## STATUS.md "다음에 할 것" 104번: check_job_system.gd:55~95의 전직 탭 검사는
## main._toggle_character()를 함수로 직접 호출하고, 방향 전환/확정도
## InputEventAction을 직접 만들어 넣어(`ev.action = "move_right"`) 물리
## 키코드→액션 매핑(project.godot의 InputMap)을 건너뛴다.
## check_perk_pick_key_input.gd와 같은 패턴으로 실제 InputEventKey
## (C=능력치 화면 열기 → D×2=전직 탭 전환 → E=전직 확정 → C=닫기)를 태운다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999

	_send_key(main, KEY_C)
	await get_tree().process_frame
	ok = _check("C 키 입력만으로 능력치 화면 열림", main.character_open) and ok
	ok = _check("처음엔 능력치 탭", main.character_mode == "stats") and ok

	_send_key(main, KEY_D)
	await get_tree().process_frame
	_send_key(main, KEY_D)
	await get_tree().process_frame
	ok = _check("D 키(move_right 액션) 두 번으로 전직 탭 진입", main.character_mode == "job") and ok

	main.job_index = 0  # warrior
	main._refresh_character()
	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키(interact 액션)로 전사 전직 확정", GameState.job == "warrior") and ok

	main.job_index = 1  # mage, 재전직
	_send_key(main, KEY_E)
	await get_tree().process_frame
	ok = _check("E 키로 재전직도 됨", GameState.job == "mage") and ok

	_send_key(main, KEY_C)
	await get_tree().process_frame
	ok = _check("C 키로 능력치 화면 닫힘", not main.character_open) and ok

	get_tree().paused = false
	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
