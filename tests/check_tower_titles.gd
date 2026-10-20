extends Node
## 탑 Phase 5 - 난이도를 100층까지 클리어하면 칭호(별)가 쌓이고, 상태바
## 레벨 표시줄에 별로 표시되는지 확인한다. 자세한 설계: TOWER_DESIGN.md 8절.

func _ready() -> void:
	GameState.reset()
	var ok := true

	ok = _check("처음엔 칭호 없음", GameState.tower_titles.is_empty()) and ok
	GameState.add_tower_title("easy")
	ok = _check("100층 클리어하면 칭호 쌓임", GameState.tower_titles.size() == 1) and ok
	GameState.add_tower_title("easy")
	ok = _check("같은 난이도 중복 추가 안 됨", GameState.tower_titles.size() == 1) and ok
	for tier in GameState.TOWER_TIERS:
		GameState.add_tower_title(tier)
	ok = _check("5개 난이도 다 클리어하면 칭호도 5개", GameState.tower_titles.size() == 5) and ok

	# 실제 씬에서 100층 클리어 흐름 확인.
	GameState.reset()
	GameState.game_cleared = true
	GameState.tower_active = true
	GameState.tower_difficulty = "easy"
	GameState.tower_floor = GameState.TOWER_FLOOR_COUNT
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._advance_tower_floor()
	ok = _check("100층 클리어하면 실제로 칭호가 쌓임", GameState.tower_titles.has("easy")) and ok
	ok = _check("100층 클리어하면 탑에서 나가 마을로", not GameState.tower_active and GameState.current_map == "village") and ok
	ok = _check("상태바 레벨 표시줄에 별이 붙음",
		main.get_node("HUD/StatBar/Level").text.contains("★")) and ok

	# 별 개수만큼만 붙는지, 최대 5개(글자 수 세어 확인).
	GameState.tower_titles = ["easy", "normal", "hard"]
	main._update_stats()
	var level_text: String = main.get_node("HUD/StatBar/Level").text
	var star_count: int = level_text.count("★")
	ok = _check("별 개수가 정확히 칭호 개수와 일치(3개)", star_count == 3) and ok

	# 저장/불러오기에도 남는지.
	GameState.tower_titles = ["easy", "abyss"]
	GameState.slot = 0
	var player := main.get_node("Player")
	GameState.save_game(player)
	GameState.tower_titles = []
	GameState.load_game(player)
	ok = _check("칭호가 저장/불러오기에도 남음", GameState.tower_titles.size() == 2) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
