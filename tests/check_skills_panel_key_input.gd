extends Node
## STATUS.md "다음 후보"가 남긴 것: "skills" 액션(K 키, project.godot에서
## 물리 키코드 75에 바인딩)은 main.gd:_unhandled_input이 "skills" 액션을
## 받아 _toggle_skills()를 부르는데, 기존 검사(check_close_button.gd)는
## main._toggle_skills()를 코드로 직접 호출할 뿐 실제 K 키 입력 경로를
## 태운 적이 없었다. check_quest_key_input.gd와 동일하게
## main._unhandled_input()에 진짜 InputEventKey를 넣어 K 키 입력 ->
## _toggle_skills() 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_opens_and_closes()) and ok
	ok = (await _check_pauses_tree_and_refreshes()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_opens_and_closes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_K)
	await get_tree().process_frame
	var ok := _check("K 키 입력만으로 스킬 화면 열림", main.skills_open)
	ok = _check("스킬 패널 보임", main.get_node("HUD/Skills").visible) and ok

	_send_key(main, KEY_K)
	await get_tree().process_frame
	ok = _check("K 키 재입력만으로 스킬 화면 닫힘(토글)", not main.skills_open) and ok
	ok = _check("스킬 패널 숨김", not main.get_node("HUD/Skills").visible) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_pauses_tree_and_refreshes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_K)
	await get_tree().process_frame
	var ok := _check("K 키 입력으로 스킬 화면 연 동안 트리 일시정지", get_tree().paused)
	ok = _check("스킬 제목 텍스트 채워짐", main.get_node("HUD/Skills/Title").text != "") and ok
	ok = _check("스킬 안내 텍스트 채워짐", main.get_node("HUD/Skills/Help").text != "") and ok

	_send_key(main, KEY_K)
	await get_tree().process_frame
	ok = _check("K 키 재입력으로 트리 일시정지 해제", not get_tree().paused) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
