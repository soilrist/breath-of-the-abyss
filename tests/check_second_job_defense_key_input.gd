extends Node
## check_skill_key_input.gd는 2차 전직 6분기 중 암살자/원소술사/강령술사 4스킬만
## 실제 입력 경로로 검증했다 - 수호자/광전사/그림자무희(전사·도적의 나머지 분기)
## 6스킬(guardian_ward/guardian_taunt/berserker_rage/berserker_final_strike/
## shadow_dancer_leap/shadow_dancer_clone)은 어떤 테스트에도(직접 호출조차) 걸린 적이
## 없었다. 이 검사가 guardian_ward를 실제 키 입력으로 태우다가 damage_reduction
## 버프가 player.gd의 take_damage()에서 전혀 읽히지 않는 버그(스킬을 써도 받는
## 피해가 그대로)를 찾아 함께 고쳤다.

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


func _new_main(job: String, second_job: String) -> Node:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	GameState.reset()
	GameState.level = 40
	GameState.chapter = 4
	GameState.change_job(job)
	GameState.second_job = second_job
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
	ok = (await _check_guardian_ward()) and ok
	ok = (await _check_guardian_taunt()) and ok
	ok = (await _check_berserker_rage()) and ok
	ok = (await _check_berserker_final_strike()) and ok
	ok = (await _check_shadow_dancer_leap()) and ok
	ok = (await _check_shadow_dancer_clone()) and ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check_guardian_ward() -> bool:
	var main: Node = await _new_main("warrior", "guardian")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "guardian_ward")
	var ok := _check("guardian_ward 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 damage_reduction 버프가 걸림", player.active_buffs.has("damage_reduction")) and ok

	player.invulnerability_time = 0.0
	var hp_before: int = player.health
	player.take_damage(100, Vector2.RIGHT)
	var taken: int = hp_before - player.health
	ok = _check("버프 적용 후 받는 피해가 절반 가까이 줄어듦(피해 %d)" % taken, taken < 60) and ok

	main.queue_free()
	return ok


func _check_guardian_taunt() -> bool:
	var main: Node = await _new_main("warrior", "guardian")
	var player: Node = main.get_node("Player")
	var enemy: Node = _new_enemy(main, player)
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "guardian_taunt")
	var ok := _check("guardian_taunt 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var hp_before: int = enemy.health
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 도발 충격파가 적을 맞춤", enemy.health < hp_before) and ok

	main.queue_free()
	return ok


func _check_berserker_rage() -> bool:
	var main: Node = await _new_main("warrior", "berserker")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "berserker_rage")
	var ok := _check("berserker_rage 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var atk_before: int = player._attack_power()
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 광기 버프가 걸림", player.active_buffs.has("atk_mult")) and ok
	ok = _check("버프 적용 후 공격력이 오름", player._attack_power() > atk_before) and ok

	main.queue_free()
	return ok


func _check_berserker_final_strike() -> bool:
	var main: Node = await _new_main("warrior", "berserker")
	var player: Node = main.get_node("Player")
	var enemy: Node = _new_enemy(main, player)
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "berserker_final_strike")
	var ok := _check("berserker_final_strike 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var hp_before: int = enemy.health
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 최후의 일격이 적을 맞춤", enemy.health < hp_before) and ok

	# low_hp_mult_max HP 배율 검증(가배치: 1.0 + (1.0 - HP비율) * 2.0).
	# 치명타(기본 8%) 잡음을 없애려 매 시나리오 5회 중 최소 피해(비크리티컬)를 쓴다.
	var dmg_full := _min_final_strike_damage(main, player, enemy, idx, 1.0)
	var dmg_half := _min_final_strike_damage(main, player, enemy, idx, 0.5)
	var dmg_low := _min_final_strike_damage(main, player, enemy, idx, 0.0)
	ok = _check("HP 100%%에서 배율 1.0배(피해 %d)" % dmg_full, dmg_full > 0) and ok
	ok = _check("HP 50%%에서 배율 2.0배(피해 %d, 기대 %d, 오차 %d)" % [dmg_half, dmg_full * 2, absi(dmg_half - dmg_full * 2)], absi(dmg_half - dmg_full * 2) <= 1) and ok
	# HP=1은 비율이 정확히 0이 아니라(1/max_health) 배율이 2.997배 정도라
	# 3.0배 기준과 int() 절삭이 두 번(기준 피해 계산 + 배율 곱) 겹쳐 오차가
	# ±1보다 한 칸 더 벌어질 수 있다 - 결정론적 절삭이지 잡음이 아니다.
	ok = _check("HP 1에서 배율 ~3.0배(피해 %d, 기대 %d, 오차 %d)" % [dmg_low, dmg_full * 3, absi(dmg_low - dmg_full * 3)], absi(dmg_low - dmg_full * 3) <= 2) and ok

	main.queue_free()
	return ok


## 최후의 일격을 5번 다시 쏴서(쿨타임 즉시 초기화) 가장 작은 피해를 돌려준다.
## 크리티컬은 항상 피해를 키우기만 하므로 최소값이 곧 비크리티컬 피해다.
func _min_final_strike_damage(main: Node, player: Node, enemy: Node, idx: int, hp_ratio: float) -> int:
	player.health = maxi(int(player.max_health * hp_ratio), 1)
	player.mana = 999
	var spawn_pos: Vector2 = player.global_position + Vector2(20, 0)
	var best := 999999
	for i in 5:
		player.skill_cooldowns[idx] = 0.0
		enemy.health = enemy.max_health
		# 매 타격이 넉백을 주므로 반경(radius) 밖으로 밀려나 다음 타격이
		# 빗나가지 않도록 위치도 매번 되돌린다.
		enemy.global_position = spawn_pos
		var before: int = enemy.health
		_send_key(main, _slot_key(idx))
		best = mini(best, before - enemy.health)
	return best


func _check_shadow_dancer_leap() -> bool:
	var main: Node = await _new_main("rogue", "shadow_dancer")
	var player: Node = main.get_node("Player")
	var enemy: Node = _new_enemy(main, player)
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "shadow_dancer_leap")
	var ok := _check("shadow_dancer_leap 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var pos_before: Vector2 = player.global_position
	var hp_before: int = enemy.health
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 그림자 도약이 이동함", player.global_position != pos_before) and ok
	ok = _check("숫자키 입력만으로 그림자 도약이 지나간 적을 맞춤", enemy.health < hp_before) and ok

	main.queue_free()
	return ok


func _check_shadow_dancer_clone() -> bool:
	var main: Node = await _new_main("rogue", "shadow_dancer")
	var player: Node = main.get_node("Player")
	await get_tree().process_frame

	var idx := _skill_idx(GameState.active_skills(), "shadow_dancer_clone")
	var ok := _check("shadow_dancer_clone 슬롯 존재", idx >= 0)
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.invulnerability_time = 0.0
	_send_key(main, _slot_key(idx))
	ok = _check("숫자키 입력만으로 분신술 무적 시간이 걸림", player.invulnerability_time > 0.0) and ok
	ok = _check("숫자키 입력만으로 분신술 이동속도 버프가 걸림", player.active_buffs.has("speed_mult")) and ok

	main.queue_free()
	return ok


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
