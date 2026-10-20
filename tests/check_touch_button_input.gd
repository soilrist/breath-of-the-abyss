extends Node
## 안드로이드/터치 화면에서 유일한 조작 수단인 title.tscn의 TouchMenu 버튼이
## 진짜 눌림(마우스/터치)에 반응하는지 확인한다. 지금까지 있던 title 관련
## 검사(check_title_slot_switch.gd 등)는 title._unhandled_input()에
## InputEventAction을 직접 넣거나 함수를 호출했을 뿐, Godot의 Button 노드가
## 실제로 클릭 판정을 하는 경로(Viewport의 GUI 입력 처리)를 태운 적이
## 없었다. project.godot의 pointing/emulate_touch_from_mouse=true 설정대로
## 실기기 터치는 마우스 이벤트로 들어오므로, Input.parse_input_event()로
## 진짜 InputEventMouseButton을 버튼 위치에 주입해 Button.pressed 신호가
## 실제로 발생하는지까지 확인한다(⑥ 규칙: 코드가 도는 것과 사람이 누르는
## 것은 다른 문제).

func _click(button: Button) -> void:
	# project.godot는 window/stretch/mode="canvas_items"로 320x240 논리
	# 뷰포트를 실제 창(960x720)에 맞춰 확대한다. Input.parse_input_event()로
	# 마우스 좌표를 넣으면 이 stretch 변환을 타지 않아 버튼 판정 좌표가
	# 어긋난다 - get_viewport().push_input(event, true)를 써서 좌표가
	# 이미 뷰포트 로컬(논리 320x240) 공간이라고 명시해야 실제 터치/클릭과
	# 같은 경로로 들어간다.
	var center: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	get_viewport().push_input(down, true)
	await get_tree().process_frame

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	get_viewport().push_input(up, true)
	await get_tree().process_frame


func _ready() -> void:
	var ok := true

	var backup: PackedByteArray
	var had_save := FileAccess.file_exists(GameState.save_path())
	if had_save:
		backup = FileAccess.get_file_as_bytes(GameState.save_path())
	if FileAccess.file_exists(GameState.save_path()):
		DirAccess.remove_absolute(GameState.save_path())

	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title.get_node("TouchMenu").visible = true
	await get_tree().process_frame

	# "이어하기" - 저장 데이터가 없을 때는 화면 전환 없이 안내만 뜬다.
	# 화면 전환(새 게임/종료)이 없는 항목만 골라 이 검사 트리가 안 죽는다.
	var continue_button: Button = title.get_node("TouchMenu/Choice1")
	await _click(continue_button)
	ok = _check("진짜 마우스 클릭으로 '이어하기' 버튼이 눌림(selected=1)", title.selected == 1) and ok
	ok = _check("저장 없음 안내가 실제로 뜸",
		title.get_node("Notice").text == "저장 데이터가 없습니다.") and ok

	# "클리어 기록" - 클리어 전이면 역시 화면 전환 없이 안내만 뜬다.
	GameState.game_cleared = false
	var clear_button: Button = title.get_node("TouchMenu/Choice2")
	await _click(clear_button)
	ok = _check("진짜 마우스 클릭으로 '클리어 기록' 버튼이 눌림(selected=2)", title.selected == 2) and ok
	ok = _check("클리어 기록 없음 안내가 실제로 뜸",
		title.get_node("Notice").text == "아직 클리어 기록이 없습니다.") and ok

	title.queue_free()
	if had_save:
		var f := FileAccess.open(GameState.save_path(), FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
