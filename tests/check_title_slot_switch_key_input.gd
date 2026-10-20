extends Node
## STATUS.md "다음 후보": check_title_slot_switch.gd는 슬롯 전환을
## InputEventAction("ui_left"/"ui_right")을 직접 만들어 확인했는데, 이건
## main.gd 18개 액션과 달리 project.godot에 커스텀 매핑이 없는 Godot 엔진
## 기본 UI 액션이라(`grep -n "ui_left\|ui_right" project.godot` 결과 없음)
## 물리 키(방향키 ←/→)→액션 매핑 자체를 건너뛴 것과 같다. 실제
## InputEventKey(KEY_LEFT/KEY_RIGHT)를 title._unhandled_input()에 넣어도 같은
## 결과가 나오는지 확인한다. 세이브 파일 백업/복원은 기존
## check_title_slot_switch.gd와 동일.
## 주의: main.gd의 커스텀 액션(move_left 등)은 physical_keycode로 매핑되지만
## ui_left/ui_right는 Godot 엔진 기본 액션이라 InputMap이 keycode로 매핑돼
## 있다(`InputMap.action_get_events("ui_right")`로 직접 확인, physical_keycode=0,
## keycode=4194321). physical_keycode를 넣으면 매칭이 안 된다.

func _send_key(title: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = key
	down.pressed = true
	title._unhandled_input(down)


func _ready() -> void:
	var ok := true
	var backups := {}
	for index in GameState.SLOT_COUNT:
		var path := GameState.save_path(index)
		if FileAccess.file_exists(path):
			backups[index] = FileAccess.get_file_as_bytes(path)

	_write_save(0, {"level": 7, "current_map": "village", "game_cleared": false})
	_delete_save(1)
	_delete_save(2)

	var title: Node = preload("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame

	ok = _check("시작 슬롯은 0", GameState.slot == 0) and ok

	_send_key(title, KEY_RIGHT)
	ok = _check("← → 실제 KEY_RIGHT 입력 -> GameState.slot이 1로 바뀜", GameState.slot == 1) and ok
	ok = _check("슬롯 1은 저장 없음 -> 이어하기에 (저장 없음) 표시",
		_continue_line(title).contains("저장 없음")) and ok

	_send_key(title, KEY_LEFT)
	ok = _check("실제 KEY_LEFT 입력 -> 슬롯 0으로 복귀", GameState.slot == 0) and ok
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
