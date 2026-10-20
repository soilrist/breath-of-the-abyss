extends Node
## 인벤토리 상한/레벨 상한이 코드에 없어(발명 금지 규칙) 새 상한을 만드는
## 대신, 세이브 왕복 경로(JSON.stringify/parse_string, int() 변환)가 큰
## 수치도 정밀도 손실 없이 왕복하는지 확인한다. 기존 check_save_load_stats.gd는
## 두 자리 수 값만 써서 이 각도를 덮지 못했다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 5
	GameState.level = 9999
	GameState.gold = 999999999
	GameState.exp = 123456789
	GameState.next_exp = 987654321
	GameState.kills = 888888
	GameState.potions = 77777
	GameState.revive_potions = 55555

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("레벨 큰 수치 정확 복원", GameState.level == 9999) and ok
	ok = _check("골드 큰 수치 정확 복원", GameState.gold == 999999999) and ok
	ok = _check("경험치 큰 수치 정확 복원", GameState.exp == 123456789 and GameState.next_exp == 987654321) and ok
	ok = _check("처치 수 큰 수치 정확 복원", GameState.kills == 888888) and ok
	ok = _check("포션 큰 수치 정확 복원", GameState.potions == 77777 and GameState.revive_potions == 55555) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
