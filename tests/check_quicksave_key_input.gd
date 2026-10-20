extends Node
## STATUS.md "다음 후보"가 남긴 것: main.gd:_unhandled_input 이 처리하는
## 액션 중 실제 입력 경로 검사가 없는 곳을 찾아라(potion/skill 키는 이미
## 끝남). project.godot의 "quick_save"(F5)/"quick_load"(F6) 액션은
## `grep -rl` 결과 검사 파일 어디에도 등장하지 않았다 - 함수 직접 호출조차
## 없는, 완전히 미검증인 지점이었다(potion보다 더 심한 공백). 합격 기준①
## "껐다 켜도 이어진다"와 가장 직결되는 기능이라 이걸 고른다.
## check_skill_key_input.gd/check_potion_key_input.gd와 동일하게
## main._unhandled_input()에 진짜 InputEventKey(F5/F6)를 넣어 실제 키
## 입력 -> 저장/불러오기 전체 경로를 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _ready() -> void:
	var ok := true
	ok = (await _check_quicksave_writes_file()) and ok
	ok = (await _check_quickload_restores_state()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_quicksave_writes_file() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.reset()
	GameState.slot = 5  # 다른 저장/불러오기 검사와 동일하게 테스트 전용 슬롯을 쓴다.
	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)
	GameState.gold = 12345
	GameState.level = 7

	_send_key(main, KEY_F5)
	var ok := _check("F5 키 입력만으로 저장 파일 생성", FileAccess.file_exists(save_file))
	ok = _check("F5 키 입력 후 저장 완료 안내", main.get_node("HUD/Message").text == "저장 완료") and ok

	main.queue_free()
	return ok


func _check_quickload_restores_state() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.slot = 5
	GameState.gold = 54321
	GameState.potions = 4
	player.potions = 4
	ok_save(GameState.save_game(player))

	GameState.reset()
	GameState.gold = 0
	GameState.potions = 0
	player.potions = 0

	_send_key(main, KEY_F6)
	var ok := _check("F6 키 입력만으로 골드 복원", GameState.gold == 54321)
	ok = _check("F6 키 입력만으로 물약 개수 복원", GameState.potions == 4 and player.potions == 4) and ok
	ok = _check("F6 키 입력 후 불러오기 완료 안내", main.get_node("HUD/Message").text == "불러오기 완료") and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)
	main.queue_free()
	return ok


func ok_save(saved: bool) -> void:
	if not saved:
		push_error("사전 저장 실패 - 검사 준비 단계 문제")


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
