extends Node
## 직업별 신규 스킬 효과가 실제로 적용되는지 확인한다.
## - 전사 방패돌진: 맞은 적이 기절(멈춤)한다
## - 마법사 얼음창: 맞은 적 이동 속도가 줄어든다
## - 전사 전투함성 / 도적 회피강화: 자신에게 버프가 걸리고 시간이 지나면 사라진다
## - 도적 은신: 다음 공격이 확정 치명타가 되고 한 번 쓰면 소모된다
## - 전사 불굴: 무적 시간이 걸리고 HP가 회복된다
## - 마법사 마나 순환: HP를 소모해 마력을 회복한다
## - 도적 연속베기: 한 번 시전에 적이 2회 맞는다(multi_hit)
## - 도적 표창 던지기: 화살(투사체) 노드가 실제로 생성된다(projectile)

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.level = 15
	GameState.gold = 999999
	player.max_mana = 999
	player.mana = 999

	var enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	enemy.max_health = 9999
	enemy.health = 9999
	main.get_node("World").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(20, 0)
	player.facing = Vector2.RIGHT
	await get_tree().process_frame

	# --- 전사: 방패 돌진(기절) ---
	GameState.change_job("warrior")
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	var r_charge: String = player.cast_skill(1)  # shield_charge
	ok = _check("방패 돌진 시전 성공", not r_charge.contains("배우지") and not r_charge.contains("마력")) and ok
	ok = _check("방패 돌진에 맞은 적이 기절함", enemy.stun_time > 0.0) and ok

	# --- 전사: 전투 함성(버프) ---
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	var atk_before: int = player._attack_power()
	player.cast_skill(2)  # warcry
	ok = _check("전투 함성으로 공격력 버프가 걸림", player.active_buffs.has("atk_mult")) and ok
	ok = _check("버프 적용 후 공격력이 오름", player._attack_power() > atk_before) and ok
	player._tick_buffs(10.0)
	ok = _check("10초 지나면 버프가 사라짐", not player.active_buffs.has("atk_mult")) and ok

	# --- 마법사: 얼음창(슬로우) ---
	GameState.change_job("mage")
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	enemy.global_position = player.global_position + Vector2(20, 0)
	var r_ice: String = player.cast_skill(1)  # ice_spear
	ok = _check("얼음창 시전 성공", not r_ice.contains("배우지") and not r_ice.contains("마력")) and ok
	ok = _check("얼음창에 맞은 적 이동속도 감소", enemy.slow_mult < 1.0 and enemy.slow_time > 0.0) and ok

	# --- 도적: 회피 강화(이동속도 버프) ---
	GameState.change_job("rogue")
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	var speed_before: float = player._current_move_speed()
	player.cast_skill(3)  # swift_step
	ok = _check("회피 강화로 이동속도 버프가 걸림", player.active_buffs.has("speed_mult")) and ok
	ok = _check("버프 적용 후 이동속도가 오름", player._current_move_speed() > speed_before) and ok

	# --- 도적: 은신(확정 치명타 소모) ---
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	player.cast_skill(2)  # stealth
	ok = _check("은신 사용 후 확정 치명타 플래그가 켜짐", player.stealth_crit_pending) and ok
	var was_crit: bool = player._roll_critical()
	ok = _check("첫 판정은 확정 치명타", was_crit) and ok
	ok = _check("한 번 쓰면 플래그가 소모됨", not player.stealth_crit_pending) and ok

	# --- 도적: 연속베기(multi_hit=2, 같은 적이 2회 맞아야 한다) ---
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	enemy.max_health = 999999
	enemy.health = 999999
	enemy.global_position = player.global_position + Vector2(20, 0)
	var single_power: int = int(player._attack_power() * float(GameState.active_skills()[0]["damage"]))
	var hp_before_ds: int = enemy.health
	player.cast_skill(0)  # double_strike
	var dmg_ds: int = hp_before_ds - enemy.health
	ok = _check("연속베기가 1타 분량을 넘는 피해를 줌(multi_hit=2 적용, 피해 %d)" % dmg_ds,
		dmg_ds >= single_power * 2) and ok

	# --- 도적: 표창 던지기(투사체 노드 생성) ---
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	var arrows_before: int = get_tree().get_nodes_in_group("arrows").size()
	player.cast_skill(1)  # shuriken
	var arrows_after: int = get_tree().get_nodes_in_group("arrows").size()
	ok = _check("표창 던지기로 화살(투사체) 노드가 생성됨", arrows_after > arrows_before) and ok

	# --- 전사: 불굴(무적 + HP 회복) ---
	GameState.change_job("warrior")
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 999
	player.health = int(player.max_health * 0.5)
	player.invulnerability_time = 0.0
	player.cast_skill(3)  # undying
	ok = _check("불굴 사용 시 무적 시간이 걸림", player.invulnerability_time >= 3.0) and ok
	ok = _check("불굴 사용 시 HP가 회복됨", player.health > int(player.max_health * 0.5)) and ok

	# --- 마법사: 마나 순환(HP 소모 + 마력 회복) ---
	GameState.change_job("mage")
	for i in player.skill_cooldowns.size(): player.skill_cooldowns[i] = 0.0
	player.mana = 0
	player.health = player.max_health
	var hp_before_heal: int = player.health
	player.cast_skill(3)  # heal (마나 순환)
	ok = _check("마나 순환 사용 시 HP가 소모됨", player.health < hp_before_heal) and ok
	ok = _check("마나 순환 사용 시 마력이 회복됨", player.mana > 0) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
