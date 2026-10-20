extends Node
## check_job_skill_effects.gd(1차 전직 스킬 효과 검사)는 전부 player.cast_skill(idx)를
## 코드로 직접 호출한다 - 실제 플레이에서 스킬을 쓰는 유일한 경로인 숫자키
## 1~6(main.gd:_unhandled_input)을 태운 적이 없었다(check_skill_key_input.gd가
## 2차 전직 4종에 대해 이미 잡은 것과 같은 미검증 지대, ⑥ 규칙).
## 이 검사는 같은 패턴(main._unhandled_input()에 진짜 InputEventKey)으로
## 1차 전직 9개 특수 효과(전사 3/마법사 2/도적 4)를 실제 입력 경로로 재확인한다.

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


func _new_main() -> Node:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999
	var player: Node = main.get_node("Player")
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT
	return main


func _new_enemy(main: Node, player: Node) -> Node:
	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 9999
	enemy.health = 9999
	enemy.defense = 0
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(20, 0)
	return enemy


func _ready() -> void:
	var ok := true
	ok = (await _check_shield_charge()) and ok
	ok = (await _check_warcry()) and ok
	ok = (await _check_ice_spear()) and ok
	ok = (await _check_swift_step()) and ok
	ok = (await _check_stealth()) and ok
	ok = (await _check_double_strike()) and ok
	ok = (await _check_shuriken()) and ok
	ok = (await _check_undying()) and ok
	ok = (await _check_mana_circulation()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_shield_charge() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("warrior")
	var player: Node = main.get_node("Player")
	var enemy: Node = _new_enemy(main, player)
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "shield_charge")
	var ok := _check("shield_charge 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 방패 돌진에 맞은 적이 기절함", enemy.stun_time > 0.0) and ok

	main.queue_free()
	return ok


func _check_warcry() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("warrior")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "warcry")
	var ok := _check("warcry 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var atk_before: int = player._attack_power()
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 전투 함성 버프가 걸림", player.active_buffs.has("atk_mult")) and ok
	ok = _check("버프 적용 후 공격력이 오름", player._attack_power() > atk_before) and ok

	main.queue_free()
	return ok


func _check_ice_spear() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("mage")
	var player: Node = main.get_node("Player")
	var enemy: Node = _new_enemy(main, player)
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "ice_spear")
	var ok := _check("ice_spear 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 얼음창에 맞은 적 이동속도 감소",
		enemy.slow_mult < 1.0 and enemy.slow_time > 0.0) and ok

	main.queue_free()
	return ok


func _check_swift_step() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("rogue")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "swift_step")
	var ok := _check("swift_step 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var speed_before: float = player._current_move_speed()
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 회피 강화 이동속도 버프가 걸림", player.active_buffs.has("speed_mult")) and ok
	ok = _check("버프 적용 후 이동속도가 오름", player._current_move_speed() > speed_before) and ok

	main.queue_free()
	return ok


func _check_stealth() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("rogue")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "stealth")
	var ok := _check("stealth 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력 후 확정 치명타 플래그가 켜짐", player.stealth_crit_pending) and ok
	var was_crit: bool = player._roll_critical()
	ok = _check("첫 판정은 확정 치명타", was_crit) and ok
	ok = _check("한 번 쓰면 플래그가 소모됨", not player.stealth_crit_pending) and ok

	main.queue_free()
	return ok


func _check_double_strike() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("rogue")
	var player: Node = main.get_node("Player")
	var enemy: Node = _new_enemy(main, player)
	enemy.max_health = 999999
	enemy.health = 999999
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "double_strike")
	var ok := _check("double_strike 슬롯 존재", idx >= 0)
	var single_power: int = int(player._attack_power() * float(GameState.active_skills()[idx]["damage"]))
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var hp_before: int = enemy.health
	_send_key(main, _slot_key(idx))
	var dmg: int = hp_before - enemy.health
	ok = _check("숫자키 입력만으로 연속베기가 1타 분량을 넘는 피해를 줌(피해 %d)" % dmg,
		dmg >= single_power * 2) and ok

	main.queue_free()
	return ok


func _check_shuriken() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("rogue")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "shuriken")
	var ok := _check("shuriken 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var arrows_before: int = get_tree().get_nodes_in_group("arrows").size()
	_send_key(main, _slot_key(idx))
	var arrows_after: int = get_tree().get_nodes_in_group("arrows").size()
	ok = _check("숫자키 입력만으로 표창 투사체 노드가 생성됨", arrows_after > arrows_before) and ok

	main.queue_free()
	return ok


func _check_undying() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("warrior")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "undying")
	var ok := _check("undying 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.health = int(player.max_health * 0.5)
	player.invulnerability_time = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 불굴 무적 시간이 걸림", player.invulnerability_time >= 3.0) and ok
	ok = _check("숫자키 입력만으로 불굴 HP가 회복됨", player.health > int(player.max_health * 0.5)) and ok

	main.queue_free()
	return ok


func _check_mana_circulation() -> bool:
	var main: Node = await _new_main()
	GameState.change_job("mage")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "heal")
	var ok := _check("heal(마나 순환) 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 0
	player.health = player.max_health
	var hp_before: int = player.health
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 마나 순환 HP가 소모됨", player.health < hp_before) and ok
	ok = _check("숫자키 입력만으로 마나 순환 마력이 회복됨", player.mana > 0) and ok

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
