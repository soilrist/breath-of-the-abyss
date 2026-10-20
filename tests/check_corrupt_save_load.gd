extends Node
## 저장 파일이 손상됐을 때 load_game()이 안전하게 실패하는지 확인한다.
## scripts/game_state.gd:2011~2016의 typeof(data) != TYPE_DICTIONARY 분기(JSON
## 파싱 자체가 깨진 경우, 파싱은 되지만 dict가 아닌 값인 경우 둘 다)를 실제
## 손상 파일로 태운 검사가 없었다(STATUS "다음에 할 것" 94번). 기존
## check_real_save_load.gd/check_save_load_extreme_values.gd는 항상 정상
## 파일만 다뤘다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 5
	GameState.level = 42
	GameState.gold = 12345
	ok = _check("정상 저장 성공", GameState.save_game(player)) and ok

	var save_file := GameState.save_path()

	var f1 := FileAccess.open(save_file, FileAccess.WRITE)
	f1.store_string("{broken json")
	f1.close()
	var loaded1 := GameState.load_game(player)
	ok = _check("JSON 파싱 실패 파일 - load_game이 false 반환", not loaded1) and ok
	ok = _check("파싱 실패 후 레벨 값 안 건드림", GameState.level == 42) and ok
	ok = _check("파싱 실패 후 골드 값 안 건드림", GameState.gold == 12345) and ok

	var f2 := FileAccess.open(save_file, FileAccess.WRITE)
	f2.store_string("[1, 2, 3]")
	f2.close()
	var loaded2 := GameState.load_game(player)
	ok = _check("dict 아닌 값(배열) 파일 - load_game이 false 반환", not loaded2) and ok
	ok = _check("dict 아닌 값 처리 후 레벨 값 안 건드림", GameState.level == 42) and ok
	ok = _check("dict 아닌 값 처리 후 골드 값 안 건드림", GameState.gold == 12345) and ok

	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
