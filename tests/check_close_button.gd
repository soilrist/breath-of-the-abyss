extends Node
## 화면마다 X(닫기) 버튼이 실제로 닫는지, 그 화면 패널 안쪽에 놓이는지 확인한다.
## 하나라도 빠뜨리면 그 화면만 닫기가 안 먹는 채로 남기 때문에 전부 돈다.
## INBOX 결함(2026-09-06 08:40) 마무리 - 예전엔 mc._close_modal()을 코드에서
## 직접 불러서 "닫힘"을 확인했는데, 그건 X 버튼을 사람이 눌렀을 때 실제로
## 터지는 입력 경로(터치/마우스가 버튼을 맞히는지)를 안 태운다. 이제 X 버튼의
## 실제 화면 좌표를 Input.parse_input_event()로 터치/클릭해 같은 결과를 낸다.

func _screen_pos(main: Node, local_pos: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * local_pos


func _tap_close_touch(main: Node, close: Control) -> void:
	var pos := _screen_pos(main, close.get_global_rect().get_center())
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


func _tap_close_click(main: Node, close: Control) -> void:
	var pos := _screen_pos(main, close.get_global_rect().get_center())
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

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var mc: Control = main.get_node("HUD/MobileControls")
	mc.force_visible = true

	var cases := [
		["inventory", func() -> void: main._toggle_inventory(), "menu_open"],
		["shop", func() -> void: main._open_shop(), "shop_open"],
		["storage", func() -> void: main._toggle_storage(), "storage_open"],
		["forge", func() -> void: main._toggle_forge(), "forge_open"],
		["character", func() -> void: main._toggle_character(), "character_open"],
		["map", func() -> void: main._toggle_world_map(), "world_map_open"],
		["pause", func() -> void: main.set_pause_open(true), "pause_open"],
		["dialogue", func() -> void: main._open_dialogue("테스트"), "dialogue_open"],
		["skills", func() -> void: main._toggle_skills(), "skills_open"],
		["quest", func() -> void: main._toggle_quest(), "quest_open"],
		["guide", func() -> void: main._toggle_guide(), "guide_open"],
		["tower_select", func() -> void: main._toggle_tower_select(), "tower_select_open"],
	]
	var ok := true
	for touch in [true, false]:
		for c in cases:
			var r: bool = await _case(main, mc, c[0], c[1], c[2], touch)
			ok = r and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _case(main: Node, mc: Control, mode: String, open: Callable, flag_name: String, touch: bool) -> bool:
	var kind := "터치" if touch else "마우스"
	open.call()
	await get_tree().process_frame
	var opened: bool = main.get(flag_name)
	if not opened:
		print(mode, "[", kind, "] 열기 실패 FAIL")
		return false
	# 패널 안쪽에 X가 놓였는지 확인한다.
	var panel_name: String = mc.MODE_PANEL.get(mode, "")
	var placed_ok := true
	var close: Control = mc.get_node("Close")
	if mode in mc.TAB_MODES:
		# 메뉴 탭 창(감독 2026-09-10): X는 패널 안이 아니라 위 탭줄(HUD/MenuTabs)
		# 오른쪽 옆, 같은 높이에 놓인다(▶ 다음 칸). 탭줄과 겹치면 안 된다.
		var tabs: Control = main.get_node("HUD/MenuTabs")
		placed_ok = (close.offset_left >= tabs.offset_right
			and close.offset_right <= 320.0
			and close.offset_top >= tabs.offset_top
			and close.offset_bottom <= tabs.offset_bottom)
	elif panel_name != "":
		var panel: Control = main.get_node("HUD/%s" % panel_name)
		placed_ok = (close.offset_right <= panel.offset_right + 0.01
			and close.offset_left >= panel.offset_left
			and close.offset_top >= panel.offset_top)
	# X 버튼을 실제 화면 좌표에 터치/클릭해 사람이 누르는 것과 같은 경로로 닫는다
	# (mc._close_modal() 직접 호출은 버튼이 그 좌표에서 실제로 맞는지를 안 본다).
	if touch:
		await _tap_close_touch(main, close)
	else:
		await _tap_close_click(main, close)
	var closed: bool = not main.get(flag_name)
	get_tree().paused = false
	print(mode, "[", kind, "] 열림=", opened, " 닫힘=", closed, " X위치정상=", placed_ok,
		" ", "OK" if (opened and closed and placed_ok) else "FAIL")
	return opened and closed and placed_ok
