extends Node
## STATUS.md "다음 후보"가 남긴 것: sell_item(X 키, project.godot에서 물리
## 키코드 88에 바인딩)은 main.gd:_unhandled_input의 menu_open 분기가
## "sell_item" 액션을 받아 "판매는 마을 상인에게" 안내만 띄우는데,
## integration_test.gd:34는 press_action()으로 InputEventAction을 직접
## 만들어 넣을 뿐 실제 물리 키(InputEventKey) 입력 경로를 태운 적이
## 없었다. check_quest_key_input.gd와 동일하게 main._unhandled_input()에
## 진짜 InputEventKey를 넣어 I 키(인벤토리 열기) -> X 키(sell_item) 전체
## 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_field_notice_only()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_field_notice_only() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	_send_key(main, KEY_I)
	await get_tree().process_frame
	var ok := _check("I 키 입력으로 인벤토리 화면 열림", main.menu_open)

	_send_key(main, KEY_X)
	await get_tree().process_frame
	ok = _check("X 키(sell_item) 입력 후에도 인벤토리 화면 유지(안 팔림)", main.menu_open) and ok
	# (감독 2026-09-10) 재료 탭이 생기며 ←→는 탭 전환. 가방은 항상 희귀도순이라
	# X는 아무 일도 안 한다. 판매는 여전히 안 되고 상인만 한다.
	ok = _check("들판 인벤토리에서 X 키 입력 시 장비 탭 유지", main.inventory_tab == "items") and ok
	ok = _check("X 키 입력으로 트리 일시정지 유지", get_tree().paused) and ok

	_send_key(main, KEY_I)
	await get_tree().process_frame
	ok = _check("I 키 재입력으로 인벤토리 화면 닫힘", not main.menu_open) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
