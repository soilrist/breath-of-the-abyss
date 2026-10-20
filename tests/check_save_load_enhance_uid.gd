extends Node
## INBOX B(강화 인스턴스 분리)를 실제 저장/불러오기로 관통시킨다.
## 지금까지는 사람이 임시 스크립트로 1회성 확인만 하고 커밋하지
## 않은 검증이었다 - 영구 검사로 남긴다. 같은 이름 사본 2개 중 하나만
## 강화/착용/소켓해도 저장 후 다시 불러오면 그 사본에만 그대로
## 복원돼야 한다. 예전 저장 파일(이름 키 공유 방식)의 마이그레이션도
## 함께 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 2
	GameState.level = 20
	GameState.inventory = ["철검", "철검"]
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999

	var uid_a: int = GameState.uid_of("철검")
	var uid_b: int = GameState.item_uid[1]
	GameState.enhance_levels[uid_a] = 5
	GameState.equip("철검", uid_a)
	GameState.socketed[uid_a] = ["작은 힘의 마법돌"]

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("사본 A 강화 수치 복원", GameState.enhance_of("철검", uid_a) == 5) and ok
	ok = _check("사본 B는 강화 안 된 채로 복원", GameState.enhance_of("철검", uid_b) == 0) and ok
	ok = _check("착용 칸이 사본 A로 정확히 복원", int(GameState.equipped_uid.get("weapon", 0)) == uid_a) and ok
	ok = _check("소켓도 사본 A에만 복원",
		GameState.socketed.get(uid_a, []).size() == 1 and GameState.socketed.get(uid_b, []).size() == 0) and ok

	## 예전 세이브(강화 수치가 이름 키)를 불러오면 그 이름을 가진 모든
	## 칸에 같은 수치가 옮겨 붙어야 한다(예전에도 공유였으니 데이터
	## 손실이 아니다 - game_state.gd load_game() 주석 참고).
	var legacy := {
		"level": 20, "gold": 0, "inventory": ["철검", "철검"],
		"save_format": 1, "enhance_levels": {"철검": 7},
	}
	var f := FileAccess.open(GameState.save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	GameState.reset()
	ok = _check("예전 세이브 불러오기 성공", GameState.load_game(player)) and ok
	var legacy_uid_a: int = GameState.item_uid[0]
	var legacy_uid_b: int = GameState.item_uid[1]
	ok = _check("예전 세이브는 이름 공유 그대로 마이그레이션",
		GameState.enhance_of("철검", legacy_uid_a) == 7 and GameState.enhance_of("철검", legacy_uid_b) == 7) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
