extends Node
## 타이틀 화면에서 ←→ 로 저장 슬롯(0~2)을 실제 입력 경로로 전환할 때
## 슬롯끼리 데이터가 안 섞이는지 확인한다. 이전엔 슬롯 3칸 "레이아웃"만
## 검사했지(check_title_slots_layout.gd), 슬롯을 실제로 넘나들며 데이터가
## 슬롯별로 독립적으로 보이는지는 아무 검사도 없었다.
## 실제 플레이어 저장 파일(save0~2.json)을 건드릴 수 있으므로 시작 전
## 백업하고 끝나면 그대로 복원한다.

func _ready() -> void:
	var ok := true
	var backups := {}
	for index in GameState.SLOT_COUNT:
		var path := GameState.save_path(index)
		if FileAccess.file_exists(path):
			backups[index] = FileAccess.get_file_as_bytes(path)

	# 슬롯 0 = 저장 있음(레벨 7), 슬롯 1/2 = 저장 없음.
	_write_save(0, {"level": 7, "current_map": "village", "game_cleared": false})
	_delete_save(1)
	_delete_save(2)

	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	ok = _check("시작 슬롯은 0", GameState.slot == 0) and ok
	ok = _check("슬롯 0은 저장 있음 -> 이어하기 텍스트에 (저장 없음) 없음",
		not _continue_line(title).contains("저장 없음")) and ok
	ok = _check("슬롯 목록에서 [1]이 선택 표시", title.get_node("Slots").text.contains("[1]")) and ok

	_press(title, "ui_right")
	ok = _check("→ 한 번 -> GameState.slot이 1로 바뀜", GameState.slot == 1) and ok
	ok = _check("슬롯 1은 저장 없음 -> 이어하기에 (저장 없음) 표시",
		_continue_line(title).contains("저장 없음")) and ok
	ok = _check("슬롯 목록에서 [2]가 선택 표시", title.get_node("Slots").text.contains("[2]")) and ok

	_press(title, "ui_right")
	ok = _check("→ 한 번 더 -> 슬롯 2", GameState.slot == 2) and ok
	ok = _check("슬롯 2도 저장 없음", _continue_line(title).contains("저장 없음")) and ok

	_press(title, "ui_left")
	_press(title, "ui_left")
	ok = _check("← 두 번 -> 슬롯 0으로 복귀", GameState.slot == 0) and ok
	ok = _check("슬롯 0으로 돌아오면 다시 저장 있음(섞이지 않음)",
		not _continue_line(title).contains("저장 없음")) and ok
	ok = _check("슬롯 0 요약에 레벨 7이 그대로 보임", title.get_node("Slots").text.contains("Lv7")) and ok

	for index in GameState.SLOT_COUNT:
		_delete_save(index)
	for index in backups:
		var f := FileAccess.open(GameState.save_path(index), FileAccess.WRITE)
		f.store_buffer(backups[index])
		f.close()

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _continue_line(title: Node) -> String:
	for line in title.get_node("Menu").text.split("\n"):
		if line.contains("이어하기"):
			return line
	return ""


func _press(title: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	title._unhandled_input(ev)


func _write_save(index: int, data: Dictionary) -> void:
	var f := FileAccess.open(GameState.save_path(index), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _delete_save(index: int) -> void:
	var path := GameState.save_path(index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
