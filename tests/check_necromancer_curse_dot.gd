extends Node
## 강령술사 2차 전직 스킬 "저주"(necromancer_curse, dot: 3, dot_duration:
## 5.0)가 실제로 명중한 적에게 5초간 매초 지속 피해를 입히는지 검증한다.
## game_state.gd에 dot/dot_duration 필드는 있었지만 player.gd의
## cast_skill()과 enemy.gd 어디에도 지속 피해 시스템 자체가 없어서 desc
## ("주위 적에게 피해와 지속 저주")의 "지속 저주"가 실제로는 전혀 발동하지
## 않던 버그(2026-09-04 자율 루프 발견, execute_pct/heal_pct_on_hit/
## chain_count와 같은 계열 버그의 마지막 조각).

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
	GameState.change_job("mage")
	GameState.second_job = "necromancer"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var curse_idx := -1
	for i in skills.size():
		if str(skills[i].get("id", "")) == "necromancer_curse":
			curse_idx = i
	ok = _check("necromancer_curse 슬롯 존재", curse_idx >= 0) and ok
	ok = _check("dot_duration 값은 5.0", float(skills[curse_idx]["dot_duration"]) == 5.0) and ok

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 99999
	enemy.health = 99999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(30, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.cast_skill(curse_idx)
	await get_tree().process_frame

	ok = _check("시전 직후 dot_time > 0(저주 걸림)", enemy.dot_time > 0.0) and ok
	ok = _check("시전 직후 dot_damage_per_sec > 0", enemy.dot_damage_per_sec > 0) and ok
	var hp_after_cast: int = enemy.health

	# 3초(3틱) 동안 지속 피해가 실제로 들어오는지 physics_process를 돌린다.
	var elapsed := 0.0
	while elapsed < 3.1:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	ok = _check("3초 경과 후 HP가 즉시 시전 직후보다 줄어듦(틱 발동)", enemy.health < hp_after_cast) and ok

	# 5초(dot_duration) 넘게 기다리면 저주가 풀려 dot_time이 0이 된다.
	elapsed = 0.0
	while elapsed < 2.2:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	ok = _check("dot_duration(5초) 경과 후 dot_time == 0(저주 종료)", enemy.dot_time == 0.0) and ok

	print("시전 직후 HP: ", hp_after_cast, " / 최종 HP: ", enemy.health)
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
