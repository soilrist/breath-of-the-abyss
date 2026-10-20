extends Node
## STATUS.md "다음 후보"가 남긴 것: guide(G 키)는 project.godot에서 실제
## 키(물리 키코드 71=G)에 바인딩돼 있고 main.gd:_unhandled_input이
## "guide" 액션을 받아 _toggle_guide()를 부르는데, 기존 검사
## (check_close_button.gd/check_guide_screen.gd)는 main._toggle_guide()를
## 코드로 직접 호출할 뿐 실제 G 키 입력 경로를 태운 적이 없었다(⑥ 규칙이
## 경고하는 "함수는 돌지만 사람이 누르면 반응 안 함" 패턴과 같은 부류의
## 미검증 지대). check_world_map_key_input.gd와 동일하게 main._unhandled_input()에
## 진짜 InputEventKey를 넣어 G 키 입력 -> _toggle_guide() 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_opens_and_closes()) and ok
	ok = (await _check_pauses_tree()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_opens_and_closes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_G)
	await get_tree().process_frame
	var ok := _check("G 키 입력만으로 도감 열림", main.guide_open)
	ok = _check("도감 패널 보임", main.get_node("HUD/Guide").visible) and ok

	_send_key(main, KEY_G)
	await get_tree().process_frame
	ok = _check("G 키 재입력만으로 도감 닫힘(토글)", not main.guide_open) and ok
	ok = _check("도감 패널 숨김", not main.get_node("HUD/Guide").visible) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_pauses_tree() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_G)
	await get_tree().process_frame
	var ok := _check("G 키 입력으로 도감 연 동안 트리 일시정지", get_tree().paused)

	_send_key(main, KEY_G)
	await get_tree().process_frame
	ok = _check("G 키 재입력으로 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
