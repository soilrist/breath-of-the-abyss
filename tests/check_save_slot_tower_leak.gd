extends Node
## 탑 세션 상태(tower_active/tower_floor/tower_difficulty)는 to_dict()에
## 없어 슬롯별로 저장되지 않는다. 슬롯 A에서 탑 진행 중 타이틀로 돌아와
## (main.gd 일시정지 메뉴 "타이틀로"는 tower_active를 안 끈다) 슬롯 B를
## 불러오면 A의 탑 상태가 GameState(오토로드, 슬롯을 넘어 살아있음)에
## 그대로 남아 B로 새는 버그가 있었다. load_game()이 항상 탑 세션을
## 초기화하도록 고친 걸 검사한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	# 슬롯 B에 평범한(탑과 무관한) 저장을 만든다.
	GameState.reset()
	GameState.slot = 6
	GameState.level = 3
	ok = _check("슬롯 저장 성공", GameState.save_game(player)) and ok

	# 슬롯 A에서 탑 진행 중이던 상태를 흉내낸다(리셋 없이 타이틀로 돌아간 것과 동일).
	GameState.tower_active = true
	GameState.tower_floor = 42
	GameState.tower_difficulty = "hell"

	# 슬롯 B를 이어하기로 불러온다 - reset() 없이 곧바로 load_game()만 호출된다(main.gd:117~119).
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("탑 활성 상태 안 샘", not GameState.tower_active) and ok
	ok = _check("탑 층수 안 샘", GameState.tower_floor == 0) and ok
	ok = _check("탑 난이도 안 샘", GameState.tower_difficulty == "easy") and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
