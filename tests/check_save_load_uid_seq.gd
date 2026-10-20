extends Node
## GameState.to_dict()의 "uid_seq"(_uid_seq, 아이템 고유 번호 발급 카운터) 필드는
## 지금까지 어떤 check_save_load_*.gd도 직접 확인한 적이 없었다(grep -n 전수
## 대조로 확인, docs/STATUS.md "다음 후보"). 저장/불러오기 후 카운터가 복원되지
## 않으면 새로 얻는 아이템의 uid가 이미 보유 중인 인벤토리/창고 아이템의 uid와
## 충돌해 INBOX B와 같은 "강화 수치 공유" 버그가 다시 생길 수 있다.

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
	GameState.inventory = ["철검", "철검", "철검"]
	GameState.materials[GameState.MATERIAL] = 999
	GameState.gold = 999999
	var existing_uids: Array[int] = GameState.item_uid.duplicate()

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("불러온 뒤 기존 uid 3개 유지", GameState.item_uid.size() == 3) and ok

	GameState.add_item("낡은 검")
	var new_uid: int = GameState.item_uid[GameState.item_uid.size() - 1]
	ok = _check("새 아이템 uid가 0이 아님", new_uid != 0) and ok
	ok = _check("새 아이템 uid가 불러온 기존 uid와 충돌하지 않음",
		not existing_uids.has(new_uid)) and ok
	ok = _check("새 아이템 uid가 불러온 인벤토리 uid와도 충돌하지 않음",
		GameState.item_uid.slice(0, 3).count(new_uid) == 0) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
