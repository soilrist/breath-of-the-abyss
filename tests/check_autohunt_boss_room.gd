extends Node
## INBOX 답(2026-09-07 02:50 ①③) 검증: 막다른 보스방(cave_deep, 동쪽 출구
## 없음)에서 잡몹을 다 잡은 뒤에도 `goal_reached`(몹 킬 목표)만 보고
## 통과 취급해 `_quest_east_exit_target()`이 없는 동쪽 출구로 걷다 지역 끝
## (316,120=bounds.x-4)에서 영원히 멈췄던 결함. 통과 여부와 무관하게 살아있는
## 보스(`is_boss`)가 있으면 거리 제한 없이 쫓도록 고쳤다(`_quest_mode_tick()`).
## (i) 잡몹 전멸·보스만 생존 -> auto_hunt=true, 실제로 보스 쪽으로 전진.
## (ii) 보스 처치 -> RETURN 단계로 전환, 다음 틱에 홈 마을(village)로 귀환.
## (iii) boss_chapter_of==0인 일반 지역(hill_ridge)에서는 이 조건이 안 걸림(회귀).

const RUN_TICKS := 1200 ## 게임 20초(60fps) 상한.
const REPRO_POS := Vector2(316, 120) ## cave_deep 서쪽 출구뿐인 지역 끝(bounds.x-4).


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _clear_non_boss_enemies(main: Node) -> void:
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss:
			continue
		enemy.remove_from_group("enemies")
		enemy.queue_free()


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	# (i) 잡몹 전멸, 보스만 살아있는 cave_deep.
	GameState.reset()
	GameState.unlock_map("dungeon")
	GameState.unlock_map("cave_deep")
	GameState.chapter = 1
	GameState.quest_stage = 1
	main.quest_mode = true
	main._change_map("cave_deep", false, REPRO_POS)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	_clear_non_boss_enemies(main)
	await get_tree().process_frame
	player.global_position = REPRO_POS
	player.invulnerability_time = 999.0
	player.potions = 99
	player.health = player.max_health

	var boss: Node = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss:
			boss = enemy
	ok = _check("(i) cave_deep 진입 시 보스가 스폰됨", boss != null) and ok

	var start_dist: float = player.global_position.distance_to(boss.global_position)
	var reached_boss := false
	var boss_died := false
	for i in RUN_TICKS:
		await get_tree().physics_frame
		main._quest_mode_tick()
		if not is_instance_valid(boss) or boss.health <= 0:
			boss_died = true
			break
		if player.global_position.distance_to(boss.global_position) <= player.attack_range + boss.body_radius():
			reached_boss = true
			break
	ok = _check("(i) 통과 판정과 무관하게 auto_hunt=true로 전환됨",
		player.auto_hunt == true) and ok
	ok = _check("(i) %d틱 안에 보스 쪽으로 실제 전진 또는 보스 사망(start_dist=%.1f)"
			% [RUN_TICKS, start_dist],
		reached_boss or boss_died) and ok

	# (ii) 보스를 처치하면 RETURN 단계로 바뀌고, 다음 틱에 홈 마을로 귀환한다.
	if is_instance_valid(boss) and boss.health > 0:
		boss.take_damage(boss.health + 9999, Vector2.ZERO)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	ok = _check("(ii) 보스 처치 -> quest_stage RETURN 단계로 전환",
		GameState.QUEST_STAGE_KIND.get(GameState.quest_stage) == "RETURN") and ok
	main._quest_mode_tick()
	await get_tree().process_frame
	ok = _check("(ii) 보스 처치 후 다음 틱에 홈 마을(village)로 귀환",
		GameState.current_map == "village") and ok

	# (iii) 회귀: boss_chapter_of==0인 일반 지역에서는 이 조건이 안 걸린다.
	GameState.reset()
	GameState.unlock_map("hill_ridge")
	GameState.chapter = 1
	GameState.quest_stage = 1
	main.quest_mode = true
	main._change_map("hill_ridge", false, Vector2(316, 120))
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.queue_free()
	await get_tree().process_frame
	player.auto_hunt = false
	player.auto_walk_active = false
	main._quest_mode_tick()
	ok = _check("(iii) boss_chapter_of==0 지역에서는 보스 추격 분기가 안 걸림(auto_walk 유지)",
		player.auto_hunt == false and player.auto_walk_active == true) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
