extends Node
## STATUS.md "다음 후보"가 남긴 것: inventory(I 키)는 project.godot에서 실제
## 키(물리 키코드 73=I)에 바인딩돼 있고 main.gd:_unhandled_input이
## "inventory" 액션을 받아 _toggle_inventory()를 부르는데, 기존 검사
## (check_inventory_clip.gd 등)는 main._toggle_inventory()를 코드로 직접
## 호출할 뿐 실제 I 키 입력 경로를 태운 적이 없었다(⑥ 규칙이 경고하는
## "함수는 돌지만 사람이 누르면 반응 안 함" 패턴과 같은 부류의 미검증
## 지대). check_guide_key_input.gd와 동일하게 main._unhandled_input()에
## 진짜 InputEventKey를 넣어 I 키 입력 -> _toggle_inventory() 전체 경로를
## 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_opens_and_closes()) and ok
	ok = (await _check_pauses_tree_and_side_panels()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_opens_and_closes() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_I)
	await get_tree().process_frame
	var ok := _check("I 키 입력만으로 인벤토리 열림", main.menu_open)
	ok = _check("인벤토리 패널 보임", main.get_node("HUD/Inventory").visible) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키 재입력만으로 인벤토리 닫힘(토글)", not main.menu_open) and ok
	ok = _check("인벤토리 패널 숨김", not main.get_node("HUD/Inventory").visible) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check_pauses_tree_and_side_panels() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_I)
	await get_tree().process_frame
	var ok := _check("I 키 입력으로 인벤토리 연 동안 트리 일시정지", get_tree().paused)
	ok = _check("스킬바 숨김", not main.get_node("HUD/SkillBar").visible) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키 재입력으로 트리 일시정지 해제", not get_tree().paused) and ok
	ok = _check("스킬바 다시 보임", main.get_node("HUD/SkillBar").visible) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
