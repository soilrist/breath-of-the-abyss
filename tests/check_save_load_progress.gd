extends Node
## to_dict()/save_game()/load_game()이 강화·아이템 칸(check_save_load_enhance_uid)
## 말고 진행도 필드(직업·전직·챕터·퀘스트·탑·특성·선택지·현상금)까지 실제
## 저장/불러오기로 정확히 복원하는지 확인한다. 지금까지 이 필드들은
## to_dict()에 들어 있을 뿐 실제 저장→불러오기 왕복 검사가 없었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.slot = 3
	GameState.job = "mage"
	GameState.second_job = "elementalist"
	GameState.chapter = 6
	GameState.quest_stage = 41
	GameState.chapter_kills = 9
	GameState.current_map = "driftwood_pier"
	GameState.boss_defeated = true
	GameState.game_cleared = false
	GameState.dash_unlocked = true
	GameState.unlocked_maps = ["village", "harbor", "driftwood_pier"]
	GameState.opened_chests = ["forest_a"]
	GameState.keys = ["ruins_key"]
	GameState.opened_doors = ["ruins_w_gate"]
	GameState.choices = ["chapter3_mercy"]
	GameState.stats = {"strength": 3, "agility": 1, "vitality": 2, "will": 4}
	GameState.stat_points = 5
	GameState.perks = {"crit_up": 2}
	GameState.perk_picks = 3
	GameState.bounty_index = 7
	GameState.bounty_progress = 4
	GameState.bounty_taken = true
	GameState.tower_progress = {"easy": 20, "normal": 15, "hard": 0, "hell": 0, "abyss": 0}

	ok = _check("저장 성공", GameState.save_game(player)) and ok

	GameState.reset()
	ok = _check("불러오기 성공", GameState.load_game(player)) and ok
	ok = _check("직업/전직 복원", GameState.job == "mage" and GameState.second_job == "elementalist") and ok
	ok = _check("챕터/퀘스트 진행 복원",
		GameState.chapter == 6 and GameState.quest_stage == 41 and GameState.chapter_kills == 9) and ok
	ok = _check("현재 맵/보스 처치 복원",
		GameState.current_map == "driftwood_pier" and GameState.boss_defeated) and ok
	ok = _check("해금된 맵/상자/열쇠/문/선택지 복원",
		GameState.unlocked_maps == ["village", "harbor", "driftwood_pier"]
		and GameState.opened_chests == ["forest_a"]
		and GameState.keys == ["ruins_key"]
		and GameState.opened_doors == ["ruins_w_gate"]
		and GameState.choices == ["chapter3_mercy"]) and ok
	ok = _check("스탯/특성 복원",
		GameState.stats["will"] == 4 and GameState.stat_points == 5
		and GameState.perks.get("crit_up", 0) == 2 and GameState.perk_picks == 3) and ok
	ok = _check("현상금 진행 복원",
		GameState.bounty_index == 7 and GameState.bounty_progress == 4 and GameState.bounty_taken) and ok
	ok = _check("탑 층 진행 복원",
		GameState.tower_progress["easy"] == 20 and GameState.tower_progress["normal"] == 15) and ok

	var save_file := GameState.save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
