extends Node
## 2026-09-04 자율 루프가 고친 2차 전직 스킬 4종(처형/영혼흡수/연쇄번개/저주)의
## 기존 검사(check_assassin_execute.gd 등)는 전부 player.cast_skill(idx)를
## 코드로 직접 호출했다 - 실제 플레이에서 이 스킬을 쓰는 유일한 경로인
## 숫자키 1~6(main.gd:_unhandled_input)을 태운 적이 한 번도 없었다(규칙⑥
## 위반 소지: Luvern 프로젝트에서 "코드는 돌지만 사람이 누르면 반응 안 함"
## 버그가 실제로 있었던 패턴). 이 검사는 main._unhandled_input()에 진짜
## InputEventKey를 넣어 키 입력 -> 슬롯 매핑 -> cast_skill() 전체 경로가
## 이어져 있는지 확인한다.

func _send_key(main: Node, key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	main._unhandled_input(down)


func _slot_key(idx: int) -> Key:
	match idx:
		0: return KEY_1
		1: return KEY_2
		2: return KEY_3
		3: return KEY_4
		4: return KEY_5
		_: return KEY_6


func _skill_idx(skills: Array, id: String) -> int:
	for i in skills.size():
		if str(skills[i].get("id", "")) == id:
			return i
	return -1


func _ready() -> void:
	var ok := true
	ok = (await _check_execute()) and ok
	ok = (await _check_chain_lightning()) and ok
	ok = (await _check_soul_drain()) and ok
	ok = (await _check_curse_dot()) and ok
	ok = (await _check_heart_pierce()) and ok
	ok = (await _check_meteor()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_execute() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("rogue")
	GameState.second_job = "assassin"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var idx := _skill_idx(skills, "assassin_execute")
	var ok := _check("assassin_execute 슬롯 존재", idx >= 0)

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 1000
	enemy.health = 250  # 25% <= execute_pct 30%
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(20, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 HP 25% 적이 처형됨(즉사)", enemy.health <= 0) and ok

	main.queue_free()
	return ok


func _check_chain_lightning() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("mage")
	GameState.second_job = "elementalist"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var idx := _skill_idx(skills, "elementalist_chain_lightning")
	var ok := _check("elementalist_chain_lightning 슬롯 존재", idx >= 0)
	var chain_count: int = int(skills[idx]["chain_count"])

	var enemies: Array = []
	for i in 10:
		var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
		enemy.max_health = 9999
		enemy.health = 9999
		enemy.defense = 0
		main.get_node("World").add_child(enemy)
		enemy.global_position = player.global_position + Vector2(30 + i * 20, 0)
		enemies.append(enemy)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))

	var hit_count := 0
	for enemy in enemies:
		if enemy.health < 9999: hit_count += 1
	ok = _check("숫자키 입력으로도 chain_count(%d)개 이하만 맞음" % chain_count, hit_count <= chain_count and hit_count > 0) and ok

	main.queue_free()
	return ok


func _check_soul_drain() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("mage")
	GameState.second_job = "necromancer"
	player.max_health = 200
	player.health = 100
	player.mana = 100
	player.max_mana = 200
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var idx := _skill_idx(skills, "necromancer_soul_drain")
	var ok := _check("necromancer_soul_drain 슬롯 존재", idx >= 0)

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 9999
	enemy.health = 9999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(20, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var hp_before: int = player.health
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 영혼 흡수 HP 회복 발생", player.health > hp_before) and ok

	main.queue_free()
	return ok


func _check_curse_dot() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("mage")
	GameState.second_job = "necromancer"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var idx := _skill_idx(skills, "necromancer_curse")
	var ok := _check("necromancer_curse 슬롯 존재", idx >= 0)

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 99999
	enemy.health = 99999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(30, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	await get_tree().process_frame
	ok = _check("숫자키 입력만으로 dot_time > 0(저주 걸림)", enemy.dot_time > 0.0) and ok

	main.queue_free()
	return ok


func _check_heart_pierce() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("rogue")
	GameState.second_job = "assassin"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var idx := _skill_idx(skills, "assassin_heart_pierce")
	var ok := _check("assassin_heart_pierce 슬롯 존재", idx >= 0)

	var near: Node = preload("res://scenes/enemy.tscn").instantiate()
	near.max_health = 9999
	near.health = 9999
	near.defense = 0
	main.get_node("World").add_child(near)
	near.global_position = player.global_position + Vector2(20, 0)

	var far: Node = preload("res://scenes/enemy.tscn").instantiate()
	far.max_health = 9999
	far.health = 9999
	far.defense = 0
	main.get_node("World").add_child(far)
	far.global_position = player.global_position + Vector2(60, 0)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 심장 관통이 가까운 적을 맞춤", near.health < 9999) and ok
	ok = _check("심장 관통은 단일 대상이라 먼 적은 안 맞음(single_target)", far.health == 9999) and ok

	main.queue_free()
	return ok


func _check_meteor() -> bool:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job("mage")
	GameState.second_job = "elementalist"
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT

	var skills: Array = GameState.active_skills()
	var idx := _skill_idx(skills, "elementalist_meteor")
	var ok := _check("elementalist_meteor 슬롯 존재", idx >= 0)

	var enemies: Array = []
	for i in 5:
		var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
		enemy.max_health = 9999
		enemy.health = 9999
		enemy.defense = 0
		main.get_node("World").add_child(enemy)
		enemy.global_position = player.global_position + Vector2(200 + i * 400, 0)
		enemies.append(enemy)
	await get_tree().process_frame

	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))

	var hit_count := 0
	for enemy in enemies:
		if enemy.health < 9999: hit_count += 1
	ok = _check("숫자키 입력만으로 메테오가 전 지역 적을 전부 맞춤(%d/5)" % hit_count, hit_count == 5) and ok

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
