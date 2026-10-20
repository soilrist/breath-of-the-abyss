extends Node
## 암살자 2차 전직 스킬 "처형"(assassin_execute, execute_pct: 0.3)이 실제로
## HP 30% 이하인 적을 즉시 처치하는지, 그 이상인 적에겐 일반 피해만 주는지
## 검증한다. game_state.gd에 execute_pct 필드는 있었지만 player.gd의
## cast_skill()에서 이를 읽어 처리하는 로직이 없어 desc("HP 30% 이하 적을
## 즉시 처형")와 다르게 그냥 밋밋한 단일 피해만 나가는 버그였다(2026-09-04
## 자율 루프에서 발견, INBOX에 기록 없던 신규 항목이라 여기서 직접 수정).

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("rogue")
	GameState.second_job = "assassin"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	# assassin_execute는 slot index 5 (1차 4개 + 2차 2번째).
	var skills: Array = GameState.active_skills()
	var execute_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "assassin_execute":
			execute_idx = i
	ok = _check("assassin_execute 슬롯 존재", execute_idx >= 0) and ok

	# 케이스 1: HP 30% 이하 -> 즉시 처치.
	var enemy_low: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy_low.max_health = 1000
	enemy_low.health = 250  # 25% <= 30%
	main.get_node("World").add_child(enemy_low)
	enemy_low.global_position = player.global_position + Vector2(20, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	player.cast_skill(execute_idx)
	ok = _check("HP 25%(30% 이하) 적이 처형으로 즉사함", enemy_low.health <= 0) and ok

	# 케이스 2: HP 30% 초과 -> 일반 피해만(즉사 아님).
	var enemy_high: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy_high.max_health = 1000
	enemy_high.health = 900  # 90% > 30%
	main.get_node("World").add_child(enemy_high)
	enemy_high.global_position = player.global_position + Vector2(20, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	player.cast_skill(execute_idx)
	ok = _check("HP 90%(30% 초과) 적은 즉사하지 않음", enemy_high.health > 0) and ok
	ok = _check("HP 90% 적도 일반 피해는 입음", enemy_high.health < 900) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
