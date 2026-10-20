extends Node
## 탑 Phase 1 - 쉬움 난이도 절차적 층 스케일링과 몬스터 풀 섞기를 확인한다.
## 자세한 설계: TOWER_DESIGN.md.

func _ready() -> void:
	var ok := true

	# 순수 함수 - 씬 없이 확인 가능한 것들 먼저.
	GameState.reset()
	ok = _check("스토리 클리어 전엔 쉬움 탑도 잠김", not GameState.tower_tier_unlocked("easy")) and ok
	GameState.game_cleared = true
	ok = _check("스토리 클리어하면 쉬움 탑 해금", GameState.tower_tier_unlocked("easy")) and ok
	ok = _check("보통 탑은 쉬움 100층 전엔 잠김", not GameState.tower_tier_unlocked("normal")) and ok
	GameState.tower_progress["easy"] = GameState.TOWER_FLOOR_COUNT
	ok = _check("쉬움 100층 클리어하면 보통 탑 해금", GameState.tower_tier_unlocked("normal")) and ok
	GameState.tower_progress["easy"] = 0

	var stats_1 := GameState.tower_floor_stats(1, "easy")
	var stats_9 := GameState.tower_floor_stats(9, "easy")
	var stats_10 := GameState.tower_floor_stats(10, "easy")
	var stats_100 := GameState.tower_floor_stats(100, "easy")
	ok = _check("층이 오르면 HP도 오름", int(stats_9["hp"]) > int(stats_1["hp"])) and ok
	ok = _check("층이 오르면 공격력도 오름", int(stats_9["damage"]) > int(stats_1["damage"])) and ok
	ok = _check("층이 오르면 방어력도 오름", int(stats_9["defense"]) > int(stats_1["defense"])) and ok
	ok = _check("10층은 미니보스라 9층보다 훨씬 셈",
		float(stats_10["hp"]) > float(stats_9["hp"]) * 1.3) and ok
	ok = _check("100층(고정 보스급)이 가장 셈",
		int(stats_100["hp"]) > int(stats_9["hp"])) and ok
	# Phase 6 밸런스 점검 - 탑은 스토리를 다 깨야 들어가는 엔드게임인데
	# 원래 1층 기준치가 1장 초반 잡몹(damage 14)과 똑같아서 사실상 도전이
	# 안 됐다. 최소 스토리 후반부(4장 잡몹, damage 58대) 수준은 돼야 한다.
	ok = _check("쉬움 탑 1층이 스토리 1장 초반 잡몹보다 확실히 셈",
		int(stats_1["damage"]) > 40) and ok

	var stats_normal := GameState.tower_floor_stats(1, "normal")
	ok = _check("같은 층이어도 난이도가 오르면 더 셈",
		int(stats_normal["hp"]) > int(stats_1["hp"])) and ok

	# 몬스터 풀 섞기 - 여러 층을 걸쳐 두 종류 이상 나오는지 확인.
	var seen: Dictionary = {}
	for floor_num in range(1, 21):
		for kind_id in GameState.tower_floor_monster_kinds(floor_num, "easy", 5):
			seen[kind_id] = true
	ok = _check("쉬움 풀 전부가 등장 후보", GameState.TOWER_MONSTER_POOLS["easy"].size() == 5) and ok
	ok = _check("여러 층에 걸쳐 몬스터 종류가 섞임(2종 이상 등장)", seen.size() >= 2) and ok
	ok = _check("같은 층은 재입장해도 같은 조합(결정론적)",
		GameState.tower_floor_monster_kinds(5, "easy", 5) == GameState.tower_floor_monster_kinds(5, "easy", 5)) and ok

	# 방어력 감쇄 공식 - enemy.gd 쪽.
	var probe_parent := Node2D.new()
	add_child(probe_parent)
	var probe: Node = preload("res://scenes/enemy.tscn").instantiate()
	probe_parent.add_child(probe)
	probe.max_health = 1000
	probe.health = 1000
	probe.defense = 32
	probe.take_damage(100, Vector2.ZERO)
	var taken_with_defense: int = 1000 - int(probe.health)
	probe.defense = 0
	probe.health = 1000
	probe.take_damage(100, Vector2.ZERO)
	var taken_without_defense: int = 1000 - int(probe.health)
	ok = _check("몬스터 방어력이 있으면 받는 피해가 줄어듦", taken_with_defense < taken_without_defense) and ok
	probe.queue_free()

	# 실제 씬을 통한 통합 확인 - 탑 입장부터 층 하나 클리어까지.
	GameState.reset()
	GameState.game_cleared = true
	GameState.unlock_map("tower")
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	main._change_map("tower", false)
	ok = _check("탑 입장하면 tower_active 켜짐", GameState.tower_active) and ok
	ok = _check("첫 입장은 1층부터", GameState.tower_floor == 1) and ok

	var tower_enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.area_id == "tower":
			tower_enemies.append(enemy)
	ok = _check("1층에 몬스터가 스폰됨", tower_enemies.size() == main.tower_enemies_remaining) and ok
	ok = _check("1층 몬스터 능력치가 공식과 일치", not tower_enemies.is_empty() and
		int(tower_enemies[0].max_health) == int(GameState.tower_floor_stats(1, "easy")["hp"])) and ok

	# "몇 층인지도 안 보이고 다음 층 이동도 안 보인다" 피드백 - 지역
	# 이름표에 층수·남은 몬스터가 항상 보이는지 확인.
	var area_label: Label = main.get_node("HUD/Area")
	ok = _check("입장하면 층수가 이름표에 뜸", area_label.text.contains("1층")) and ok
	ok = _check("입장하면 남은 몬스터 수가 이름표에 뜸",
		area_label.text.contains("남은 몬스터 %d" % main.tower_enemies_remaining)) and ok

	main._on_enemy_defeated(5, 3, "beast")
	ok = _check("몬스터 하나 잡으면 남은 몬스터 수가 바로 줄어듦",
		area_label.text.contains("남은 몬스터 %d" % main.tower_enemies_remaining)) and ok

	var to_clear: int = main.tower_enemies_remaining
	for i in to_clear:
		main._on_enemy_defeated(5, 3, "beast")
	ok = _check("층을 다 잡으면 다음 층으로 넘어감", GameState.tower_floor == 2) and ok
	ok = _check("클리어한 층이 최고 도달 층으로 기록됨", GameState.tower_progress["easy"] == 1) and ok
	ok = _check("다음 층으로 넘어가면 이름표도 2층으로 갱신됨", area_label.text.contains("2층")) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
