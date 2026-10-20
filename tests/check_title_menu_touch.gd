extends Node
## 타이틀 TouchMenu 왼쪽 ▲▼/확인 버튼이 키보드 ↑↓/Enter와 같은 경로로 메뉴를
## 움직이는지 확인한다(감독 요청 2026-09-10: 터치 기기에 상하 방향키가 없었다).

func _ready() -> void:
	var ok := true
	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	var touch: Control = title.get_node("TouchMenu")
	touch.visible = true
	title._refresh()  # 헤드리스엔 터치가 없어 Help/Slots 문구를 터치 기준으로 다시 만든다
	await get_tree().process_frame

	var up: Button = touch.get_node("MenuUp")
	var down: Button = touch.get_node("MenuDown")
	var okb: Button = touch.get_node("MenuOk")
	var menu: Label = title.get_node("Menu")
	var choice0: Control = touch.get_node("Choice0")
	ok = _check("▲▼ 버튼이 화면 안", up.offset_left >= 0 and down.offset_bottom <= 240) and ok
	ok = _check("▲▼ 버튼이 메뉴 글자 왼쪽", up.offset_right <= choice0.offset_left
		and down.offset_right <= choice0.offset_left) and ok
	# 감독 피드백 2026-09-10: 메뉴 글자에 붙이지 말 것(손가락). 화면 왼쪽 가장자리 쪽에.
	ok = _check("▲▼ 버튼이 메뉴 글자와 40px 이상 떨어짐", choice0.offset_left - up.offset_right >= 40.0
		and choice0.offset_left - down.offset_right >= 40.0) and ok
	ok = _check("▲▼ 버튼이 화면 왼쪽 가장자리(<=8px)", up.offset_left <= 8.0 and down.offset_left <= 8.0) and ok
	ok = _check("▲(위) < 확인 < ▼(아래) 순서, 안 겹침", up.offset_bottom <= okb.offset_top
		and okb.offset_bottom <= down.offset_top) and ok
	# 감독 스케치 2026-09-10: ▲/확인/▼는 화면 왼쪽 아래, ▼가 오른쪽 ◀▶와 같은 줄(하단 정렬).
	var prev: Button = title.get_node("TouchMenu/SlotPrev")
	var help: Label = title.get_node("Help")
	ok = _check("▼ 버튼이 ◀▶와 같은 줄(하단 정렬)", is_equal_approx(down.offset_top, prev.offset_top)
		and is_equal_approx(down.offset_bottom, prev.offset_bottom)) and ok
	ok = _check("▲ 버튼이 메뉴 첫 줄보다 아래(왼쪽 아래 구석)", up.offset_top >= menu.offset_top + 30.0
		and down.offset_bottom <= help.offset_top) and ok
	# 안내: ▲ 바로 위 "메뉴 선택" 캡션 + 하단 Help는 터치 표현(▲▼/확인/◀▶)이어야 한다.
	var guide: Label = title.get_node("TouchMenu/MenuGuide")
	ok = _check("'메뉴 선택' 캡션이 ▲ 바로 위", guide.text == "메뉴 선택" and guide.offset_bottom <= up.offset_top
		and up.offset_top - guide.offset_bottom <= 6.0 and guide.offset_left <= up.offset_left
		and guide.offset_right >= up.offset_right) and ok
	ok = _check("하단 안내가 터치 버튼 기준", help.text.begins_with("▲▼") and "확인" in help.text
		and "◀▶" in help.text) and ok
	for b in [up, down, okb]:
		ok = _check("%s 폭 28px 이상(엄지)" % b.name, b.size.x >= 28 and b.size.y >= 22) and ok

	ok = _check("시작 커서 새 게임", menu.text.begins_with("▶ 새 게임")) and ok
	await _click(down)
	ok = _check("▼ 클릭 -> 이어하기", menu.text.split("\n")[1].begins_with("▶ 이어하기")) and ok
	await _click(down)
	await _click(down)
	ok = _check("▼ 세 번 -> 종료", menu.text.split("\n")[3].begins_with("▶ 종료")) and ok
	await _click(down)
	ok = _check("▼ 네 번 -> 새 게임으로 순환", menu.text.begins_with("▶ 새 게임")) and ok
	await _click(up)
	ok = _check("▲ 클릭 -> 종료로 순환", menu.text.split("\n")[3].begins_with("▶ 종료")) and ok
	ok = _check("클릭 뒤 포커스 없음", get_viewport().gui_get_focus_owner() == null) and ok

	# 확인 버튼 = _activate: 커서 '클리어 기록'(클리어 전) -> 안내문이 뜬다.
	await _click(up)
	ok = _check("▲ -> 클리어 기록", menu.text.split("\n")[2].begins_with("▶ 클리어 기록")) and ok
	GameState.game_cleared = false
	await _click(okb)
	ok = _check("확인 클릭 -> '클리어 기록 없음' 안내", title.get_node("Notice").text.contains("클리어 기록")) and ok

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
