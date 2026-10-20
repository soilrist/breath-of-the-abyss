extends Node
## 타이틀 "이어하기" 클릭 -> main.tscn 로드 -> 실제 _load_current_game() 호출까지
## 이어지는 전체 흐름을 손상된 저장 파일로 태운다(STATUS "다음에 할 것" 95번).
## check_corrupt_save_load.gd는 GameState.load_game()을 직접 호출해서만
## 확인했고, check_title_choice_continue_click.gd는 GameState.pending_load가
## true로 설정되는 것까지만 확인했다 - 실제로 main.gd:_ready()가 pending_load를
## 보고 _load_current_game()을 부르는 지점(main.gd:117~119)은 아무도 손상 파일로
## 태운 적이 없었다. save_path()의 파일을 깨진 텍스트로 만들어 놓고
## main.tscn을 pending_load=true 상태로 띄워, 크래시 없이 안전하게 새 게임
## 상태 그대로 남는지 확인한다.

func _ready() -> void:
	GameState.reset()
	GameState.slot = 0
	var save_file := GameState.save_path()
	var had_backup := FileAccess.file_exists(save_file)
	var backup: PackedByteArray = []
	if had_backup:
		backup = FileAccess.get_file_as_bytes(save_file)

	var f := FileAccess.open(save_file, FileAccess.WRITE)
	f.store_string("{broken json")
	f.close()

	GameState.level = 1
	GameState.current_map = "village"
	GameState.pending_load = true

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var ok := true
	ok = _check("pending_load가 소비되어 false로 남음", not GameState.pending_load) and ok
	ok = _check("손상 파일 로드 실패로 레벨 값 안 바뀜(기본값 유지)", GameState.level == 1) and ok
	ok = _check("불러오기 완료 메시지 안 뜸(load_game이 false라 무시됨)",
		main.get_node("HUD/Message").text != "불러오기 완료") and ok
	ok = _check("맵이 그대로 유지됨(로드 실패로 맵 전환 없음)",
		GameState.current_map == "village") and ok
	ok = _check("Player 노드가 여전히 유효함(크래시 없음)",
		is_instance_valid(main.get_node("Player"))) and ok

	if had_backup:
		var restore := FileAccess.open(save_file, FileAccess.WRITE)
		restore.store_buffer(backup)
		restore.close()
	else:
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
