extends Node
## 타이틀 화면 TouchMenu의 ◀▶ 버튼으로 저장 슬롯을 실제 클릭 경로로 넘길 수
## 있는지 확인한다. 터치 기기엔 ←→ 키가 없어 이어하기 슬롯을 못 골랐다는
## 감독 지적(2026-09-08). 클릭은 check_mobile_title_click.gd처럼
## get_viewport().push_input()으로 넣는다(stretch 변환 때문).

func _ready() -> void:
	var ok := true
	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	var touch: Control = title.get_node("TouchMenu")
	touch.visible = true
	await get_tree().process_frame

	var prev: Button = touch.get_node("SlotPrev")
	var next: Button = touch.get_node("SlotNext")
	var slots: Label = title.get_node("Slots")
	ok = _check("◀▶ 버튼이 화면 안", prev.offset_left >= 0 and next.offset_right <= 320
		and next.offset_bottom <= 240) and ok
	ok = _check("◀▶ 버튼이 슬롯 목록 영역(오른쪽 열) 안", prev.offset_left >= slots.offset_left
		and next.offset_right <= slots.offset_right) and ok
	ok = _check("◀▶ 버튼이 슬롯 글자 4줄(font 7) 아래", prev.offset_top >= slots.offset_top + 4 * 11) and ok
	var choice1: Control = touch.get_node("Choice1")
	ok = _check("◀▶ 버튼이 메뉴 터치 영역과 안 겹침",
		not prev.get_rect().intersects(choice1.get_rect())
		and prev.offset_left >= choice1.offset_right) and ok
	ok = _check("시작 슬롯은 0", GameState.slot == 0) and ok

	await _click(next)
	ok = _check("▶ 클릭 -> 슬롯 1", GameState.slot == 1) and ok
	ok = _check("슬롯 목록에서 [2] 표시", slots.text.contains("[2]")) and ok
	ok = _check("클릭 뒤 버튼이 포커스를 안 잡음", get_viewport().gui_get_focus_owner() == null) and ok
	await _click(next)
	await _click(next)
	ok = _check("▶ 세 번 -> 0으로 순환", GameState.slot == 0) and ok
	await _click(prev)
	ok = _check("◀ 클릭 -> 슬롯 2로 순환", GameState.slot == 2) and ok
	ok = _check("슬롯 목록에서 [3] 표시", slots.text.contains("[3]")) and ok

	# 버튼 클릭 뒤에도 키보드 ↑↓가 메뉴를 움직여야 한다(포커스 누수 확인).
	var before: String = title.get_node("Menu").text
	var ev := InputEventAction.new()
	ev.action = "ui_down"
	ev.pressed = true
	title._unhandled_input(ev)
	ok = _check("클릭 뒤 ↓ 키로 메뉴 이동", title.get_node("Menu").text != before) and ok

	GameState.slot = 0
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = center
		ev.global_position = center
		button.get_viewport().push_input(ev, true)
		await get_tree().process_frame


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
