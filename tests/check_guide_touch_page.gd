extends Node
## INBOX 결함(2026-09-06 08:40) — 가이드(G) 창은 읽기 전용 정보 화면이라
## 선택 목록은 없지만, 쪽 넘김(←→)이 키보드 전용이었다. 조이스틱 드래그는
## move_left/right를 Input.action_press로만 흘려보내 _unhandled_input의
## is_action_pressed(event)에는 안 잡혀(virtual_joystick.gd 주석 참고) 폰에서는
## 1쪽에서 못 넘어가는 막다른 길이었다. 패널을 반으로 나눠 왼쪽 탭=이전 쪽,
## 오른쪽 탭=다음 쪽으로 고친 것을 실제 입력 경로(터치/마우스)로 검증한다.

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


## touch=true면 ScreenTouch(아이폰 재현), false면 MouseButton(데스크톱 재현).
func _check_input_path(touch: bool) -> bool:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true
	var kind := "ScreenTouch(터치)" if touch else "MouseButton(마우스)"

	main._toggle_guide()
	await get_tree().process_frame
	ok = _check("[%s] 가이드 열림" % kind, main.guide_open) and ok
	ok = _check("[%s] 초기 쪽은 0" % kind, main.guide_page == 0) and ok

	var panel: Control = main.get_node("HUD/Guide")
	var right_pos := Vector2(panel.size.x * 0.75, panel.size.y * 0.5)
	var left_pos := Vector2(panel.size.x * 0.25, panel.size.y * 0.5)

	if touch:
		await _touch(main, right_pos)
	else:
		await _click(main, right_pos)
	ok = _check("[%s] 오른쪽 탭으로 다음 쪽(0 -> 1)" % kind, main.guide_page == 1) and ok

	if touch:
		await _touch(main, left_pos)
	else:
		await _click(main, left_pos)
	ok = _check("[%s] 왼쪽 탭으로 이전 쪽(1 -> 0)" % kind, main.guide_page == 0) and ok

	# 0쪽에서 왼쪽 탭 -> 마지막 쪽으로 순환(_refresh_guide의 모듈로 랩어라운드).
	if touch:
		await _touch(main, left_pos)
	else:
		await _click(main, left_pos)
	ok = _check("[%s] 0쪽에서 왼쪽 탭하면 마지막 쪽으로 순환" % kind,
		main.guide_page == main.GUIDE_PAGE_COUNT - 1) and ok

	main.queue_free()
	return ok


## INBOX 보정(2026-09-06 17:50) — 겹침을 글자 6px 축소로 피했더니 폰에서
## 읽기 힘들 만큼 작아졌다. 근본 원인은 글자 크기가 아니라 가이드가 열린
## 동안에도 HUD/StatBar가 그 위에 그려지는 것이었다: 가이드는 화면 전체를
## 덮는 모달이라 미니바가 필요 없으므로 guide_open 동안 숨긴다(8px 원복).
## Info는 clip_text가 없어 rect 크기가 아니라 실제 줄 수*줄높이가 Help
## 라벨(안내줄) 위로 안 넘치는지를 봐야 진짜 겹침·잘림을 잡는다(정적
## rect끼리는 애초에 겹치게 배치돼 있어 grow(4) rect 교집합만으로는 항상
## 참이 나온다).
func _check_no_statbar_overlap() -> bool:
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	main.hud_stat_scale = 1.0
	main._apply_hud_scale()
	var statbar: Control = main.get_node("HUD/StatBar")
	var ok := true
	ok = _check("[가이드 닫힘] StatBar 보임", statbar.visible) and ok

	main._toggle_guide()
	await get_tree().process_frame
	ok = _check("[가이드 열림] StatBar 숨김", not statbar.visible) and ok

	var info: Label = main.get_node("HUD/Guide/Info")
	var help: Label = main.get_node("HUD/Guide/Help")
	var help_top: float = help.get_global_rect().position.y
	for p in main.GUIDE_PAGE_COUNT:
		main.guide_page = p
		main._refresh_guide()
		await get_tree().process_frame
		var line_height := info.get_line_height() + info.get_theme_constant("line_spacing")
		var needed := info.get_line_count() * line_height
		var text_bottom: float = info.get_global_rect().position.y + needed
		ok = _check("[가이드 %d/%d쪽] Info 텍스트 하단이 안내줄 위 2px 여백 안에 있음" %
			[p + 1, main.GUIDE_PAGE_COUNT], text_bottom <= help_top - 2) and ok
		if p == 15:
			# [직업·전직 1/2] 페이지가 인자 개수 불일치(String formatting error)로
			# 빈 값이 되던 회귀(GameState.JOB_UNLOCK_LEVEL 인자 누락) 재발 방지.
			ok = _check("[가이드 %d/%d쪽] 직업·전직 쪽에 전직 레벨 숫자가 실제로 채워짐" %
				[p + 1, main.GUIDE_PAGE_COUNT],
				info.text.contains("레벨 %d부터" % GameState.JOB_UNLOCK_LEVEL)) and ok

	main._toggle_guide()
	await get_tree().process_frame
	ok = _check("[가이드 닫힘] StatBar 다시 보임", statbar.visible) and ok
	main.queue_free()
	return ok


func _ready() -> void:
	var ok := true
	ok = (await _check_input_path(true)) and ok
	ok = (await _check_input_path(false)) and ok
	ok = (await _check_no_statbar_overlap()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
