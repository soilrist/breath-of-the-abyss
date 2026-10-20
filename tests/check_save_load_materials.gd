extends Node
## check_save_load_progress(직업/퀘스트 등)와 check_save_load_enhance_uid(강화 인스턴스)에
## 이어, to_dict()엔 있지만 실제 저장/불러오기 왕복 검사가 없던 재료 계열 필드
## (materials/enhance_wards/stone_inventory/tower_material_counts)를 확인한다.
## tower_titles는 check_tower_titles.gd가 이미 왕복 검사한다(중복 불필요).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 4
	GameState.materials[GameState.MATERIAL] = 123
	GameState.materials[GameState.BOSS_FRAGMENT] = 7
	GameState.enhance_wards = 3
	GameState.stone_inventory = {"작은 힘의 마법돌": 5, "작은 수호의 마법돌": 2}
	GameState.tower_material_counts = {"easy": 4, "normal": 2, "hard": 0, "hell": 0, "abyss": 1}

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("재료 복원",
		GameState.materials[GameState.MATERIAL] == 123 and GameState.materials[GameState.BOSS_FRAGMENT] == 7) and ok
	ok = _check("강화 부적 복원", GameState.enhance_wards == 3) and ok
	ok = _check("마법돌 보유량 복원",
		GameState.stone_inventory.get("작은 힘의 마법돌", 0) == 5
		and GameState.stone_inventory.get("작은 수호의 마법돌", 0) == 2) and ok
	ok = _check("탑 재료 보유량 복원",
		GameState.tower_material_counts["easy"] == 4
		and GameState.tower_material_counts["normal"] == 2
		and GameState.tower_material_counts["abyss"] == 1) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
