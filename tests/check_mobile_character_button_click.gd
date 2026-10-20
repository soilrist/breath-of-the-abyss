extends Node
## 감독(2026-09-10) 메뉴 탭 개편: 필드의 "캐릭" 버튼은 없어지고 ☰ → 탭줄
## (HUD/MenuTabs) '캐릭' 탭으로 캐릭터(스탯) 창을 연다. 실기기 터치가 타는
## 경로(Input.parse_input_event + flush_buffered_events, InputEventScreenTouch)로
## ☰ → 캐릭 탭 → X 를 순서대로 누른다(6be6d0b 이중 발화 회귀 방지 겸).

func _screen_pos(main: Node, button: Control) -> Vector2:
	var local_center: Vector2 = button.get_global_rect().get_center()
	return main.get_viewport().get_final_transform() * local_center


func _touch(main: Node, button: Control) -> void:
	var pos := _screen_pos(main, button)
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


func _ready() -> void:
	var ok := true
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open:
		main._advance_dialogue()
		await get_tree().process_frame

	var mobile := main.get_node("HUD/MobileControls")
	mobile.force_visible = true
	mobile.show()
	mobile.set_modal_mode("")
	await get_tree().process_frame

	var tabs: Control = main.get_node("HUD/MenuTabs")
	ok = _check("필드 모드에서 '캐릭' 버튼은 안 보이고 탭줄도 숨어 있음",
		not mobile.get_node("Character").visible and not tabs.visible) and ok

	await _touch(mobile, mobile.get_node("Pause"))
	ok = _check("☰ 터치 한 번으로 설정 탭(일시정지)이 열리고 탭줄이 보임",
		main.pause_open and get_tree().paused and tabs.visible) and ok

	await _touch(mobile, tabs.get_node("Tab0"))
	ok = _check("탭줄 '캐릭' 터치 한 번으로 캐릭터 창이 열림(설정 탭은 닫힘, 이중 발화 없음)",
		main.character_open and not main.pause_open and get_tree().paused) and ok
	ok = _check("캐릭터 창이 보임", main.get_node("HUD/Character").visible) and ok
	ok = _check("'캐릭' 탭이 눌린 상태로 표시되고 Close 버튼이 뜸",
		tabs.get_node("Tab0").button_pressed and mobile.get_node("Close").visible) and ok

	await _touch(mobile, mobile.get_node("Close"))
	ok = _check("Close 버튼 터치로 캐릭터 창이 닫힘",
		not main.character_open and not get_tree().paused) and ok
	ok = _check("닫히면 탭줄도 숨고 ☰ 버튼이 다시 보임",
		not tabs.visible and mobile.get_node("Pause").visible) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
