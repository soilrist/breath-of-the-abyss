extends Node
## INBOX 결함(2026-09-06 08:40) — 특성 선택(Perk) 창이 폰에서 막다른 길이었다
## (닫기·확인·줄 터치 아무것도 없어 레벨업마다 실기 진행이 멈췄다). 인벤토리/
## 대장간과 같은 원리(check_forge_touch_select.gd 참고) - 목록 줄을 터치/클릭
## 으로 고르고, 이미 선택된 줄을 다시 누르면 그 특성을 확정한다. 여기에 더해
## Interact("결정") 버튼으로도 확정되는지 확인한다(둘 다 없으면 여전히 막다른
## 길이므로).

## main.gd의 PERK_LIST_START_LINE/PERK_LIST_LINES_PER_ROW을 값으로 복사해 두지
## 않고 스크립트를 프리로드해 직접 읽는다 - 복사본은 main.gd 값이 바뀌어도
## 따라가지 못한다(2026-09-06 INBOX 결함: c87d810/FORGE_LIST_START_LINE과 같은
## 재발 방지).
const _Main := preload("res://scripts/main.gd")
const PERK_LIST_START_LINE := _Main.PERK_LIST_START_LINE
const PERK_LIST_LINES_PER_ROW := _Main.PERK_LIST_LINES_PER_ROW


## 구현(_tapped_list_row())과는 별도로 여기서 직접 줄 간격을 계산한다 - 구현이
## 부르는 함수를 그대로 베끼면 구현이 line_spacing을 빼먹는 회귀가 나도 검사가
## 똑같이 틀려서 통과해 버린다(INBOX 2026-09-05 결함 원인).
func _line_height(info: Label) -> float:
	return info.get_line_height() + info.get_theme_constant("line_spacing")


## 특성 항목(row)의 첫 번째 줄(이름 줄) 한가운데 좌표. 특성 한 항목은
## PERK_LIST_LINES_PER_ROW(2)줄(이름+설명)을 쓴다.
func _row_local_pos(main: Node, row: int) -> Vector2:
	var info: Label = main.get_node("HUD/Perk/Info")
	var rect := info.get_global_rect()
	var line_height := _line_height(info)
	var line_index := PERK_LIST_START_LINE + row * PERK_LIST_LINES_PER_ROW
	var y: float = rect.position.y + line_index * line_height + line_height / 2.0
	var x := rect.position.x + 10.0
	return Vector2(x, y)


func _header_local_pos(main: Node) -> Vector2:
	var info: Label = main.get_node("HUD/Perk/Info")
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


## touch=true면 ScreenTouch(아이폰 재현), false면 MouseButton(데스크톱 재현)
## 경로로 "1탭=선택만, 재탭=확정(특성 획득), 제목줄은 무시"를 확인한다.
func _check_input_path(touch: bool) -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	GameState.reset()
	GameState.perks.clear()
	GameState.perk_picks = 1
	GameState.perk_offer = ["vigor", "edge", "guard"]
	main._open_perk_choice()
	await get_tree().process_frame
	ok = _check("[%s] 특성 창 열림" % kind, main.perk_open) and ok
	ok = _check("[%s] 초기 선택은 0번째" % kind, main.perk_index == 0) and ok

	# 아직 선택 안 된 2번째 항목(guard)을 실제 입력 경로로 탭.
	var row2 := _row_local_pos(main, 2)
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 탭한 항목으로 선택이 옮겨감(0 -> 2)" % kind, main.perk_index == 2) and ok
	ok = _check("[%s] 첫 탭(원본+에뮬레이션 복제)은 선택만 하고 특성은 아직 안 늘어남" % kind,
		GameState.perks.is_empty() and GameState.perk_picks == 1) and ok

	# 이미 선택된 2번째 항목을 다시 탭 - 확정(특성 획득)까지 간다.
	if touch:
		await _touch(main, row2)
	else:
		await _click(main, row2)
	ok = _check("[%s] 이미 선택된 항목을 다시 탭하면 확정(guard 획득, 창 닫힘)" % kind,
		int(GameState.perks.get("guard", 0)) == 1 and GameState.perk_picks == 0 and not main.perk_open) and ok

	main.queue_free()
	return ok


## 제목/구분선 줄(목록 바깥)을 탭해도 선택이 안 바뀌는지 별도로 확인한다
## (확정까지 가버리면 창이 닫혀 위 케이스와 섞이므로 따로 뗀다).
func _check_header_ignored() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.perk_picks = 1
	GameState.perk_offer = ["vigor", "edge", "guard"]
	main._open_perk_choice()
	main.perk_index = 1
	main._refresh_perk()
	await get_tree().process_frame

	await _touch(main, _header_local_pos(main))
	var ok := _check("제목 줄을 탭해도 선택 그대로(1)", main.perk_index == 1)
	ok = _check("제목 줄을 탭해도 창은 그대로 열림", main.perk_open) and ok

	main.queue_free()
	return ok


## Interact("결정") 버튼(터치 경로가 아닌 폰의 실제 확정 버튼)을 눌러도
## 선택된 특성이 확정되는지 - 2026-09-06 08:40 결함의 핵심(버튼이 아예 안
## 보였다)이라 라벨·확정 둘 다 확인한다.
func _check_interact_button() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.perks.clear()
	GameState.perk_picks = 1
	GameState.perk_offer = ["vigor", "edge", "guard"]
	main._open_perk_choice()
	main.perk_index = 0
	main._refresh_perk()
	await get_tree().process_frame

	var mc := main.get_node("HUD/MobileControls")
	mc.visible = true
	var ok := _check("Interact 버튼이 특성 창에서 보임", mc.get_node("Interact").visible)
	ok = _check("Interact 라벨이 결정으로 바뀜", mc.get_node("Interact").text == "결정") and ok

	await mc.tap("interact")
	ok = _check("Interact(결정) 버튼으로 특성 확정(vigor 획득, 창 닫힘)",
		int(GameState.perks.get("vigor", 0)) == 1 and not main.perk_open) and ok

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
