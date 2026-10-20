extends Node
## INBOX 결함(2026-09-07 12:40, 실기 아이폰 사용자 보고) — 대륙 이동도
## (WorldMap) 화면이 폰에서 완전히 먹통이었다(닫기 버튼만 반응, 왼쪽
## 목록/오른쪽 미니맵 둘 다 무반응). gui_input 연결이 아예 빠져 있던
## 것이 원인 - check_tower_select_touch_select.gd과 같은 방식으로 실제
## 입력 이벤트(ScreenTouch/MouseButton)를 주입해 목록 탭·탭 줄 탭·
## 미니맵 탭을 모두 확인한다.

func _line_height(info: Label) -> float:
	return info.get_line_height() + info.get_theme_constant("line_spacing")


## 목록 항목(row)은 한 줄만 쓴다(world_map.gd _refresh() 참고, 목록은
## 3번째 줄부터 시작한다).
func _row_local_pos(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/WorldMap/Graph/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var line_index := 3 + row
	var y: float = rect.position.y + line_index * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


## 탭 줄("≪ N장 / M장 ≫")은 목록 위 1번째 줄이다. left=true면 ≪ 글자 위.
## 좌/우 기준은 라벨 폭이 아니라 탭 글자 폭의 절반이다(감독 2026-09-09:
## 라벨 절반 기준이라 58px 글자의 ≫를 눌러도 이전 장으로 갔던 결함).
func _tab_local_pos(main: Node, left: bool) -> Vector2:
	var info: Label = main.get_node("HUD/WorldMap/Graph/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var y: float = rect.position.y + line_height + line_height / 2.0
	var tab_line: String = info.text.get_slice("\n", 1)
	var tab_width: float = info.get_theme_default_font().get_string_size(
		tab_line, HORIZONTAL_ALIGNMENT_LEFT, -1, info.get_theme_font_size("font_size")).x
	var x: float = rect.position.x + (3.0 if left else tab_width - 3.0)
	return Vector2(x, y)


func _minimap_local_pos(main: Node, area: String) -> Vector2:
	var atlas: Control = main.get_node("HUD/WorldMap/Graph/Atlas")
	var rect := atlas.get_global_rect()
	return rect.position + atlas._area_position(area)


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


## chapter=2로 대륙 1·2를 미니맵에서 해금 표시하고, hill(1장)·harbor(2장)를
## 개별 해금해 둔다 - 목록/미니맵 탭 대상으로 쓴다. hill_ridge(1장)는
## 잠긴 채로 남겨 "잠긴 지역 탭 -> 변화 없음"을 확인하는 데 쓴다.
func _setup_state() -> void:
	GameState.reset()
	GameState.scrolls = 99  # 지도 이동은 이동주문서를 쓴다
	GameState.chapter = 2
	GameState.unlock_map("hill")
	GameState.unlock_map("harbor")


## 목록 탭: 탭한 줄로 커서만 옮기고(원본+에뮬레이션 복제 한 탭에 선택+
## 이동까지 확정되지 않음 - 6be6d0b 회귀 클래스), 이미 선택된 줄을
## 다시 탭하면 이동을 시도한다.
func _check_list_tap(touch: bool) -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	main._toggle_world_map()
	await get_tree().process_frame
	var graph := main.get_node("HUD/WorldMap/Graph")
	ok = _check("[%s] 지도 열림" % kind, main.world_map_open) and ok
	ok = _check("[%s] 초기 커서는 0(현재 위치)" % kind, graph.cursor == 0) and ok

	var row1 := _row_local_pos(main, 1)  # 챕터1 목록 1번째 줄 = hill(해금됨)
	if touch: await _touch(main, row1)
	else: await _click(main, row1)
	ok = _check("[%s] 탭한 줄로 커서 이동(0 -> 1)" % kind, graph.cursor == 1) and ok
	ok = _check("[%s] 첫 탭(원본+에뮬레이션 복제)은 선택만, 아직 이동 안 함" % kind,
		main.world_map_open and GameState.current_map == "village") and ok

	if touch: await _touch(main, row1)
	else: await _click(main, row1)
	ok = _check("[%s] 이미 선택된 줄을 다시 탭하면 이동(hill, 지도 닫힘)" % kind,
		GameState.current_map == "hill" and not main.world_map_open) and ok

	main.queue_free()
	return ok


## 탭 줄(챕터 표시) 좌/우 절반을 탭하면 그 방향으로 챕터가 넘어간다.
func _check_tab_tap() -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var graph := main.get_node("HUD/WorldMap/Graph")

	main._toggle_world_map()
	await get_tree().process_frame
	var ok := _check("탭 전 챕터는 1", graph.chapter == 1)

	await _touch(main, _tab_local_pos(main, false))  # 오른쪽 절반
	ok = _check("탭 줄 오른쪽 탭 -> 챕터 2로 전환", graph.chapter == 2) and ok

	await _touch(main, _tab_local_pos(main, true))  # 왼쪽 절반
	ok = _check("탭 줄 왼쪽 탭 -> 챕터 1로 복귀", graph.chapter == 1) and ok

	main.queue_free()
	return ok


## 미니맵: 해금 지역 점을 탭하면 그 지역으로 챕터/커서가 맞춰지고, 잠긴
## 지역 점을 탭하면 아무 변화도 없어야 한다.
func _check_minimap_tap() -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var graph := main.get_node("HUD/WorldMap/Graph")

	main._toggle_world_map()
	await get_tree().process_frame
	var ok := true

	await _touch(main, _minimap_local_pos(main, "harbor"))
	ok = _check("미니맵에서 해금 지역(harbor) 탭 -> 챕터 2로 전환", graph.chapter == 2) and ok
	ok = _check("미니맵에서 해금 지역(harbor) 탭 -> 커서가 harbor를 가리킴",
		graph.selected_map() == "harbor") and ok

	var prev_chapter: int = graph.chapter
	var prev_cursor: int = graph.cursor
	await _touch(main, _minimap_local_pos(main, "hill_ridge"))  # 잠긴 지역
	ok = _check("미니맵에서 잠긴 지역 탭 -> 챕터 변화 없음", graph.chapter == prev_chapter) and ok
	ok = _check("미니맵에서 잠긴 지역 탭 -> 커서 변화 없음", graph.cursor == prev_cursor) and ok

	main.queue_free()
	return ok


func _ready() -> void:
	var ok := true
	ok = (await _check_list_tap(true)) and ok
	ok = (await _check_list_tap(false)) and ok
	ok = (await _check_tab_tap()) and ok
	ok = (await _check_minimap_tap()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
