extends Node
## INBOX 결함(2026-09-06 08:40) — Perk에 이어 TowerSelect(탑 난이도 선택)도
## 폰에서 목록 줄 터치·Interact 확정 경로가 없었다(막다른 길은 아니었으나
## ←→/방향키로만 층을 고를 수 있어 폰에서는 사실상 못 골랐다). 인벤토리/
## 특성 선택과 같은 원리(check_perk_touch_select.gd 참고) - 목록 줄을
## 터치/클릭으로 고르고, 이미 선택된 줄을 다시 누르면 그 난이도로 입장한다.
## Interact("입장") 버튼으로도 확정되는지 확인한다.

## main.gd의 TOWER_SELECT_LIST_START_LINE을 값으로 복사해 두지 않고 스크립트를
## 프리로드해 직접 읽는다 - 복사본은 main.gd 값이 바뀌어도 따라가지 못한다
## (2026-09-06 INBOX 결함: c87d810/FORGE_LIST_START_LINE과 같은 재발 방지).
const _Main := preload("res://scripts/main.gd")
const TOWER_SELECT_LIST_START_LINE := _Main.TOWER_SELECT_LIST_START_LINE


func _line_height(info: Label) -> float:
	return info.get_line_height() + info.get_theme_constant("line_spacing")


## 난이도 항목(row)은 한 줄만 쓴다(_refresh_tower_select() 참고).
func _row_local_pos(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/TowerSelect/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var line_index := TOWER_SELECT_LIST_START_LINE + row
	var y: float = rect.position.y + line_index * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


func _header_local_pos(main: Node) -> Vector2:
	var info: Label = main.get_node("HUD/TowerSelect/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	return Vector2(rect.position.x + 10.0, rect.position.y + line_height / 2.0)


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


## easy/normal 둘 다 잠금 해제해 둔다 - "탭한 줄로 선택만 옮겨감" 과
## "이미 선택된 줄을 다시 탭하면 그 난이도로 입장" 을 같은 두 항목으로
## 다 확인하려면 목표 줄(정상)도 열려 있어야 한다.
func _setup_state() -> void:
	GameState.reset()
	GameState.unlock_map("tower")
	GameState.game_cleared = true  # easy 잠금 해제
	GameState.tower_progress["easy"] = GameState.TOWER_FLOOR_COUNT  # normal 잠금 해제


## touch=true면 ScreenTouch(아이폰 재현), false면 MouseButton(데스크톱 재현)
## 경로로 "1탭=선택만, 재탭=확정(입장)"을 확인한다.
func _check_input_path(touch: bool) -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	main._toggle_tower_select()
	await get_tree().process_frame
	ok = _check("[%s] 탑 선택 화면 열림" % kind, main.tower_select_open) and ok
	ok = _check("[%s] 초기 선택은 0번째(easy)" % kind, main.tower_select_index == 0) and ok

	# 아직 선택 안 된 1번째 항목(normal, 잠금 해제됨)을 실제 입력 경로로 탭.
	var row1 := _row_local_pos(main, 1)
	if touch:
		await _touch(main, row1)
	else:
		await _click(main, row1)
	ok = _check("[%s] 탭한 항목으로 선택이 옮겨감(0 -> 1)" % kind, main.tower_select_index == 1) and ok
	ok = _check("[%s] 첫 탭(원본+에뮬레이션 복제)은 선택만 하고 아직 입장 안 함" % kind,
		main.tower_select_open and GameState.current_map != "tower") and ok

	# 이미 선택된 1번째 항목을 다시 탭 - 확정(normal 난이도로 입장)까지 간다.
	if touch:
		await _touch(main, row1)
	else:
		await _click(main, row1)
	ok = _check("[%s] 이미 선택된 항목을 다시 탭하면 확정(normal 난이도 입장, 창 닫힘)" % kind,
		GameState.tower_difficulty == "normal" and GameState.current_map == "tower"
		and not main.tower_select_open) and ok

	main.queue_free()
	return ok


## 제목/구분선 줄(목록 바깥)을 탭해도 선택이 안 바뀌는지 별도로 확인한다.
func _check_header_ignored() -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._toggle_tower_select()
	main.tower_select_index = 1
	main._refresh_tower_select()
	await get_tree().process_frame

	await _touch(main, _header_local_pos(main))
	var ok := _check("제목 줄을 탭해도 선택 그대로(1)", main.tower_select_index == 1)
	ok = _check("제목 줄을 탭해도 창은 그대로 열림", main.tower_select_open) and ok

	main.queue_free()
	return ok


## Interact("입장") 버튼으로도 현재 선택된 난이도가 확정되는지.
func _check_interact_button() -> bool:
	_setup_state()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._toggle_tower_select()
	main.tower_select_index = 0
	main._refresh_tower_select()
	await get_tree().process_frame

	var mc := main.get_node("HUD/MobileControls")
	mc.visible = true
	var ok := _check("Interact 버튼이 탑 선택 화면에서 보임", mc.get_node("Interact").visible)
	ok = _check("Interact 라벨이 입장으로 바뀜", mc.get_node("Interact").text == "입장") and ok

	await mc.tap("interact")
	ok = _check("Interact(입장) 버튼으로 확정(easy 난이도 입장, 창 닫힘)",
		GameState.tower_difficulty == "easy" and GameState.current_map == "tower"
		and not main.tower_select_open) and ok

	main.queue_free()
	return ok


func _ready() -> void:
	var ok := true
	ok = (await _check_input_path(true)) and ok
	ok = (await _check_input_path(false)) and ok
	ok = (await _check_header_ignored()) and ok
	ok = (await _check_interact_button()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
