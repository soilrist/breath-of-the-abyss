extends Node
## 창고(storage/storage_uid)는 to_dict()/from_dict()에 필드가 있지만
## 지금까지 저장/불러오기 왕복 검사가 하나도 없었다(grep 확인,
## check_save_load_enhance_uid/progress/materials 어디에도 storage 없음).
## 같은 이름 사본을 창고에 넣고 강화한 뒤 저장->로드->꺼내기까지
## uid가 흔들리지 않는지 확인한다.

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
	GameState.gold = 999999

	GameState.sync_uids()
	var uid_kept: int = GameState.item_uid[0]
	var uid_stored: int = GameState.item_uid[1]
	GameState.enhance_levels[uid_stored] = 3
	ok = _check("창고 보관 성공", GameState.store_item(1)) and ok
	ok = _check("보관 후 인벤토리 1개만 남음", GameState.inventory.size() == 1) and ok
	ok = _check("보관 후 창고 1개", GameState.storage.size() == 1 and GameState.storage_uid[0] == uid_stored) and ok

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("창고 개수 복원", GameState.storage.size() == 1 and GameState.storage[0] == "철검") and ok
	ok = _check("창고 uid 복원", GameState.storage_uid[0] == uid_stored) and ok
	ok = _check("창고 항목 강화 수치 복원", GameState.enhance_of("철검", uid_stored) == 3) and ok
	ok = _check("남은 인벤토리 사본은 강화 안 됨", GameState.enhance_of("철검", uid_kept) == 0) and ok

	ok = _check("창고에서 꺼내기 성공", GameState.withdraw_item(0)) and ok
	ok = _check("꺼낸 뒤 창고 비어있음", GameState.storage.is_empty() and GameState.storage_uid.is_empty()) and ok
	ok = _check("꺼낸 뒤 인벤토리 uid도 강화 수치 유지",
		GameState.item_uid.has(uid_stored) and GameState.enhance_of("철검", uid_stored) == 3) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
