extends Node
## 터치 지시 2/3(대장간 창). 인벤토리와 같은 원리(check_inventory_touch_select.gd
## 참고) - 목록 줄을 터치/클릭으로 고르고, 이미 선택된 줄을 다시 누르면 확정한다.
## 처음부터 에뮬레이션 복제 이벤트 가드(_on_forge_gui_input의 DEVICE_ID_EMULATION
## 체크)와 Input.parse_input_event() 실제 입력 경로로 만들어, 인벤토리 때 겪은
## 시행착오(이중 발화)를 반복하지 않는다.

## main.gd의 FORGE_LIST_START_LINE을 값으로 복사해 두지 않고 스크립트를
## 프리로드해 직접 읽는다 - 복사본은 main.gd 값이 바뀌어도 따라가지 못해
## 검사가 헤더 줄 수를 잘못 계산한 채로 통과해 버린다(2026-09-06 INBOX 결함:
## c87d810이 4->3으로 바꿨는데 여기 복사본이 4로 남아 RESULT FAIL이 났었다).
const _Main := preload("res://scripts/main.gd")
const FORGE_LIST_START_LINE := _Main.FORGE_LIST_START_LINE


## 구현(_tapped_list_row())과는 별도로 여기서 직접 줄 간격을 계산한다 -
## 구현이 부르는 함수를 그대로 베끼면(get_line_height()만) 구현이 line_spacing을
## 빼먹는 회귀가 나도 검사가 똑같이 틀려서 통과해 버린다(INBOX 2026-09-05 결함
## 원인). Label이 실제로 그리는 줄 간격은 글꼴 높이 + 테마 상수 line_spacing.
func _line_height(info: Label) -> float:
	return info.get_line_height() + info.get_theme_constant("line_spacing")


func _row_local_pos(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/Forge/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	# _refresh_forge()의 "대장간 …\n강화석 … GOLD … 부적 …\n──────────\n%s"
	# 포맷대로 0~2번째 줄은 제목/강화석·골드·부적 한 줄/구분선, 아이템 줄은
	# FORGE_LIST_START_LINE(3)번째부터(2026-09-06 c87d810 이후 3줄 헤더).
	var y: float = rect.position.y + (FORGE_LIST_START_LINE + row) * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


## 줄 위 가장자리(+1px)나 아래 가장자리(-1px)를 눌러도 같은 줄이 골라지는지
## 보는 경계 검사용 - 오차가 14px 공식이면 반드시 실패한다(INBOX 지시).
func _row_edge_pos(main: Node, row: int, top_edge: bool) -> Vector2:
	var info: Label = main.get_node("HUD/Forge/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var line_top := rect.position.y + (FORGE_LIST_START_LINE + row) * line_height
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
## "1탭=선택만, 재탭=확정(강화 시도), 제목줄은 무시, 소켓 탭도 목록 선택이 됨,
## 대장간 밖 다른 창엔 영향 없음"을 확인한다.
func _check_input_path(touch: bool) -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	GameState.reset()
	# 강화 비용이 항상 감당되게 재료를 넉넉히 준다 - 성공/실패는 난수라 결과는
	# 상관없고, "두 번째 탭에서 확정 강화가 실제로 시도됐는지"(재료 차감)만 본다.
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	GameState.inventory = ["철검", "구리 반지", "용린 갑주"]
	main._toggle_forge()
	await get_tree().process_frame
	ok = _check("[%s] 대장간 열림" % kind, main.forge_open) and ok
	ok = _check("[%s] 기본 탭은 강화" % kind, main.forge_mode == "enhance") and ok
	ok = _check("[%s] 초기 선택은 0번째" % kind, main.forge_index == 0) and ok

	# 아직 선택 안 된 2번째 줄(용린 갑주)을 실제 입력 경로로 탭 - 에뮬레이션
	# 복제 이벤트가 같이 들어와도 선택만 옮기고 강화까지 가면 안 된다.
	var row2 := _row_local_pos(main, 2)
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 탭한 줄로 선택이 옮겨감(0 -> 2)" % kind, main.forge_index == 2) and ok
	ok = _check("[%s] 첫 탭(원본+에뮬레이션 복제)은 선택만 하고 강화는 시도 안 함" % kind,
		GameState.materials[GameState.MATERIAL] == 999 and GameState.gold == 999999) and ok

	# 이미 선택된 2번째 줄을 다시 탭 - 이번엔 확정(강화 시도)까지 간다. 성공/실패는
	# 난수라 결과는 안 보고, 강화석·골드가 차감돼 실제로 시도됐는지만 본다.
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 이미 선택된 줄을 다시 탭하면 강화 시도(재료 차감)" % kind,
		GameState.materials[GameState.MATERIAL] < 999 or GameState.gold < 999999) and ok

	# 제목/구분선 줄(아이템 목록 바깥)을 탭해도 선택이 안 바뀐다. row=-3은
	# FORGE_LIST_START_LINE(3) 기준 줄 인덱스 0(제목 줄) - 라벨 밖 빈 공간이
	# 아니라 실제 헤더 텍스트를 눌러도 안 바뀌는지 본다.
	var header_pos := _row_local_pos(main, -3)
	if touch:
		await _touch(main, header_pos)
	else:
		await _click(main, header_pos)
	ok = _check("[%s] 제목 줄을 탭해도 선택 그대로" % kind, main.forge_index == 2) and ok

	# Info에 줄바꿈이 생기면(autowrap) 줄 번호 환산이 통째로 어긋나므로, 헤더
	# FORGE_LIST_START_LINE(3)줄 + 아이템 줄수가 실제로 그려졌는지도 확인한다.
	var info: Label = main.get_node("HUD/Forge/Info")
	var items_count: int = main._forge_items().size()
	ok = _check("[%s] Info 줄바꿈 없음(헤더 3줄+목록 %d줄)" % [kind, items_count],
		info.get_line_count() == FORGE_LIST_START_LINE + items_count) and ok

	# 오차가 가장 크게 쌓이는 마지막 보이는 줄(2번째, "용린 갑주")의 위/아래
	# 가장자리를 눌러도 같은 줄이 골라지는지 - 14px(line_spacing 누락) 공식이면
	# 6줄 누적 오차로 반드시 다음 줄(밖)로 밀려나 실패한다.
	var last_row := items_count - 1
	main.forge_index = 0
	main._refresh_forge()
	await get_tree().process_frame
	var top_pos := _row_edge_pos(main, last_row, true)
	if touch:
		await _touch(main, top_pos)
	else:
		await _click(main, top_pos)
	ok = _check("[%s] 마지막 줄 위 가장자리(+1px)를 눌러도 그 줄이 선택됨" % kind,
		main.forge_index == last_row) and ok

	main.forge_index = 0
	main._refresh_forge()
	await get_tree().process_frame
	var bottom_pos := _row_edge_pos(main, last_row, false)
	if touch:
		await _touch(main, bottom_pos)
	else:
		await _click(main, bottom_pos)
	ok = _check("[%s] 마지막 줄 아래 가장자리(-1px)를 눌러도 그 줄이 선택됨" % kind,
		main.forge_index == last_row) and ok

	# 소켓 탭으로 바꿔도 같은 원리로 목록 선택이 된다(확정은 숫자키 몫이라 여기선
	# 선택 이동만 확인 - 키보드 interact도 소켓 탭에선 아무것도 안 함).
	main.forge_mode = "socket"
	main.forge_index = 0
	main._refresh_forge()
	await get_tree().process_frame
	var socket_row1 := _row_local_pos(main, 1)
	if touch:
		await _touch(main, socket_row1)
	else:
		await _click(main, socket_row1)
	ok = _check("[%s] 소켓 탭에서도 탭한 줄로 선택이 옮겨감(0 -> 1)" % kind, main.forge_index == 1) and ok

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
