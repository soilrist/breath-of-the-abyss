extends Node
## INBOX(2026-09-05 16:15, 결함): 실기 아이폰에서는 인벤토리 항목을 한 번
## 탭하면 선택과 착용이 동시에 확정돼 버렸다. 이전 판 이 검사는
## `get_viewport().push_input(event, true)`로 Input 싱글턴을 건너뛰어
## 넣었는데, 그 경로는 project.godot의 `pointing/emulate_touch_from_mouse`
## (및 기본값 `emulate_mouse_from_touch`) 에뮬레이션을 타지 않아 실기기
## 재현을 놓쳤다. `Input.parse_input_event()` + `Input.flush_buffered_events()`로
## 넣어야 원본 이벤트와 함께 에뮬레이션 복제 이벤트(device ==
## InputEvent.DEVICE_ID_EMULATION)까지 같이 들어와 실제 버그를 태운다.
## 좌표는 project.godot의 window/stretch/mode="canvas_items"(320x240 논리
## 뷰포트를 960x720 창으로 확대)를 감안해 `get_viewport().get_final_transform()`으로
## 논리 좌표를 실제 창 좌표로 바꿔서 넣는다(그대로 넣으면 엉뚱한 곳을 누른다 -
## Input.parse_input_event()는 push_input(event, true)와 달리 창 좌표를 기대한다).

## 구현(_tapped_list_row())과는 별도로 여기서 직접 줄 간격을 계산한다 -
## 구현이 부르는 함수를 그대로 베끼면(get_line_height()만) 구현이 line_spacing을
## 빼먹는 회귀가 나도 검사가 똑같이 틀려서 통과해 버린다(INBOX 2026-09-05 결함
## 원인). Label이 실제로 그리는 줄 간격은 글꼴 높이 + 테마 상수 line_spacing.
func _line_height(info: Label) -> float:
	return info.get_line_height() + info.get_theme_constant("line_spacing")


func _row_local_pos(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/Inventory/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	# _refresh_inventory()의 "인벤토리 …\n%s\n──────────\n%s%s" 포맷대로
	# 0~2번째 줄은 제목/재료 요약/구분선, 아이템 줄은 3번째부터.
	var y := rect.position.y + (3 + row) * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


## 줄 위 가장자리(+1px)나 아래 가장자리(-1px)를 눌러도 같은 줄이 골라지는지
## 보는 경계 검사용 - 오차가 14px 공식이면 반드시 실패한다(INBOX 지시).
func _row_edge_pos(main: Node, row: int, top_edge: bool) -> Vector2:
	var info: Label = main.get_node("HUD/Inventory/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var line_top := rect.position.y + (3 + row) * line_height
	var y := line_top + 1.0 if top_edge else line_top + line_height - 1.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


func _screen_pos(main: Node, local_pos: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * local_pos


func _touch(main: Node, local_pos: Vector2) -> void:
	var pos := _screen_pos(main, local_pos)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = pos
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = pos
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _click(main: Node, local_pos: Vector2) -> void:
	var pos := _screen_pos(main, local_pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame


## touch=true면 ScreenTouch(아이폰 재현), false면 MouseButton(데스크톱 재현) 경로로
## "1탭=선택만, 재탭=착용, 재탭=해제, 제목줄은 무시" 4가지를 전부 확인한다.
func _check_input_path(touch: bool) -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	GameState.reset()
	GameState.level = 20
	GameState.inventory = ["철검", "정령의 부적", "구리 반지", "용린 갑주"]
	main._toggle_inventory()
	await get_tree().process_frame
	ok = _check("[%s] 인벤토리 열림" % kind, main.menu_open) and ok
	ok = _check("[%s] 초기 선택은 0번째" % kind, main.inventory_index == 0) and ok

	# 아직 선택 안 된 2번째 줄을 실제 입력 경로로 탭 - 에뮬레이션
	# 복제 이벤트가 같이 들어와도 선택만 옮기고 착용까지 가면 안 된다(결함 재현).
	# 가방은 항상 희귀도순으로 보이므로(2026-09-10) 2번째 줄이 실제 배열의
	# 몇 번째 물건인지는 _inventory_order()로 환산한다(여기서는 철검).
	var idx2: int = main._inventory_order()[2]
	var name2: String = GameState.inventory[idx2]
	var row2 := _row_local_pos(main, 2)
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 탭한 줄로 선택이 옮겨감(0 -> 2)" % kind, main.inventory_index == 2) and ok
	ok = _check("[%s] 첫 탭(원본+에뮬레이션 복제)은 선택만 하고 착용은 안 함" % kind,
		not GameState.is_equipped_at(idx2)) and ok

	# 이미 선택된 2번째 줄을 다시 탭 - 이번엔 확정(착용)까지 간다.
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 이미 선택된 줄을 다시 탭하면 착용 확정" % kind, GameState.is_equipped_at(idx2)) and ok
	ok = _check("[%s] 착용 안내 메시지 표시" % kind,
		main.get_node("HUD/Inventory/Notice").text == name2 + " 착용") and ok

	# 착용된 줄을 한 번 더 탭하면 토글로 해제된다(키보드 interact와 동일 동작).
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 착용된 줄을 다시 탭하면 해제" % kind, not GameState.is_equipped_at(idx2)) and ok
	ok = _check("[%s] 해제 안내 메시지 표시" % kind,
		main.get_node("HUD/Inventory/Notice").text == name2 + " 해제") and ok

	# 제목/구분선 줄(아이템 목록 바깥)을 탭해도 선택이 안 바뀐다.
	var info: Label = main.get_node("HUD/Inventory/Info")
	var line_height := info.get_line_height()
	var header_pos := Vector2(info.get_global_rect().position.x + 10.0, info.get_global_rect().position.y + line_height / 2.0)
	if touch:
		await _touch(main, header_pos)
	else:
		await _click(main, header_pos)
	ok = _check("[%s] 제목 줄을 탭해도 선택 그대로" % kind, main.inventory_index == 2) and ok

	# Info에 줄바꿈이 생기면(autowrap) 줄 번호 환산이 통째로 어긋나므로, 헤더
	# 3줄 + 아이템 4줄 = 7줄이 실제로 그려졌는지도 같이 확인한다.
	ok = _check("[%s] Info 줄바꿈 없음(헤더 3줄+목록 4줄=7줄)" % kind,
		info.get_line_count() == 3 + GameState.inventory.size()) and ok

	# 오차가 가장 크게 쌓이는 마지막 보이는 줄(3번째, "용린 갑주")의 위/아래
	# 가장자리를 눌러도 같은 줄이 골라지는지 - 14px(line_spacing 누락) 공식이면
	# 6줄 누적 오차로 반드시 다음 줄(밖)로 밀려나 실패한다. (희귀도순이라
	# 마지막 줄은 구리 반지지만 줄 번호만 보므로 상관없다.)
	var last_row := 3
	main.inventory_index = 0
	main._refresh_inventory()
	await get_tree().process_frame
	var top_pos := _row_edge_pos(main, last_row, true)
	if touch:
		await _touch(main, top_pos)
	else:
		await _click(main, top_pos)
	ok = _check("[%s] 마지막 줄 위 가장자리(+1px)를 눌러도 그 줄이 선택됨" % kind,
		main.inventory_index == last_row) and ok

	main.inventory_index = 0
	main._refresh_inventory()
	await get_tree().process_frame
	var bottom_pos := _row_edge_pos(main, last_row, false)
	if touch:
		await _touch(main, bottom_pos)
	else:
		await _click(main, bottom_pos)
	ok = _check("[%s] 마지막 줄 아래 가장자리(-1px)를 눌러도 그 줄이 선택됨" % kind,
		main.inventory_index == last_row) and ok

	get_tree().paused = false
	main.queue_free()
	return ok


func _ready() -> void:
	var ok := true
	ok = (await _check_input_path(true)) and ok
	ok = (await _check_input_path(false)) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
