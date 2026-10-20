extends Node

## (감독 결함 조사, 2026-09-09) `check_quest_mode_all_chapters` 9장 echo_of_forest
## game_min 967 FREEZE 실측 좌표 재현: 지도 맨 아래 테두리 줄(y=227, A*에선
## 못 걷는 칸이지만 충돌체가 없어 몸은 들어감) 안에서 바로 위 큰나무 충돌체
## (y 200~224) 너머의 적(57px)을 쫓다가 옆걸음↔복귀만 반복했다.
## 고침: 플레이어 세로 클램프를 적과 같은 24px로 → 테두리 줄엔 못 들어간다.
## 검사: ① 첫 물리 프레임 뒤 y ≤ 높이-24 ② 30초 안에 나무를 돌아 적 30px 안까지 간다.
const PLAYER_POS := Vector2(220.1753, 227.0748)
const ENEMY_POS := Vector2(181.2437, 184.5224)
const RUN_TICKS := 1800
const REACH := 30.0


func _ready() -> void:
	seed(20260907)
	GameState.reset()
	GameState.unlock_map("echo_of_forest")
	GameState.chapter = 9
	GameState.quest_stage = 51
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	main.quest_mode = true
	main._change_map("echo_of_forest", false, PLAYER_POS)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var keep: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if keep == null:
			keep = e
			continue
		e.remove_from_group("enemies")
		e.queue_free()
	await get_tree().process_frame
	keep.global_position = ENEMY_POS
	keep.speed = 0.0
	player.global_position = PLAYER_POS
	player.invulnerability_time = 999.0
	player.potions = 99
	player.health = player.max_health
	player.auto_hunt = true
	player.auto_walk_active = false
	var max_y: float = player.bounds.y - 24.0
	print("== enemy=", keep.archetype, " hp=", keep.health, " max_y=", max_y)
	var ok := true
	var reached := false
	var worst_y := 0.0
	for i in RUN_TICKS:
		if i % 36 == 0:
			main._quest_mode_tick()
		await get_tree().physics_frame
		if i >= 2: # physics_frame 신호는 그 프레임 물리 처리 '앞'에 온다 → 첫 프레임은 아직 클램프 전
			worst_y = maxf(worst_y, player.global_position.y)
		if i % 120 == 0:
			print("t=%.2f p=%s v=%s d=%.1f" % [i / 60.0, player.global_position, player.velocity,
				player.global_position.distance_to(keep.global_position)])
		if player.global_position.distance_to(keep.global_position) <= REACH:
			reached = true
			print("REACHED at t=%.2f p=%s" % [i / 60.0, player.global_position])
			break
	print("worst_y=%.2f" % worst_y)
	if worst_y > max_y + 0.01:
		ok = false
		print("테두리 줄 진입(y=%.2f > %.2f) FAIL" % [worst_y, max_y])
	else:
		print("테두리 줄 밖 유지(y ≤ %.0f) OK" % max_y)
	if not reached:
		ok = false
		print("나무 돌아 적 %.0fpx 안 도달 %d초 안에 FAIL" % [REACH, RUN_TICKS / 60])
	else:
		print("나무 돌아 적 %.0fpx 안 도달 OK" % REACH)
	print("RESULT ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
