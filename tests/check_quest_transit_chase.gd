extends Node
## AUTOHUNT_DESIGN.md §10.7(INBOX 답, 2026-09-07 00:12 ①④) 검증.
## 통과 중(goal_reached, 스토리 목표를 채우고 동쪽 출구로 걸어 나가는 중)
## 응전을 "붙은 적 추격"으로 넓힌 고침 - forest_w 같은 밀집 지역에서 몹이
## 계속 따라붙어 맞다가 물약이 바닥나 조기 귀환하는 순환(§10.7 실측)의
## 원인이었다. near_dist(=attack_range*2.5, _quest_should_retreat()와 같은
## 반경, 새 숫자 없음) 안에 살아있는 적이 있으면 auto_hunt=true, 없으면
## 기존처럼 auto_walk 동쪽 + _quest_transit_engage().
## (1) near_dist 안 적 1마리 -> auto_hunt=true, auto_walk_active=false.
## (2) near_dist 밖 적만 -> auto_walk_active=true, auto_hunt=false.
## (3) 적 0 -> 동쪽 출구 목표로 auto_walk.

func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")
	var ok := true

	GameState.reset()
	GameState.chapter = 1
	GameState.unlock_map("hill")
	GameState.unlock_map("hill_ridge")
	main.quest_mode = true
	main._quest_grind_zone = ""
	main._quest_resume_zone = ""
	GameState.current_map = "hill_ridge"
	## (INBOX 결함, 2026-09-07 09:20 대조 확인) `_build_walk_grid()`(world.gd)는
	## "이미 paint()된 지역 전용" 전제를 쓴다 - 여기서 `current_map`만 바꾸고
	## world는 그대로 두면(초기 village 그대로) 격자 크기가 hill_ridge 크기로
	## 커져 `walkable()`이 실제 `_grid`(village 크기) 밖 칸을 읽어 SCRIPT
	## ERROR(out of bounds)가 난다 - `_change_map()`은 몹을 스폰해 (3) 적 0
	## 시나리오를 깨므로 그 대신 `paint()`만 맞춰 전제를 지킨다.
	main.get_node("World").paint("hill_ridge")
	GameState.quest_stage = 1
	GameState.kills = 6 ## §10.7 1장 hill_ridge 목표를 이미 채운 상태(goal_reached=true)
	player.health = player.max_health
	player.potions = 5
	GameState.potions = 5
	GameState.gold = 100
	player.cooldown_time = 0.0

	# (1) near_dist 안 적 1마리 -> 추격(auto_hunt)
	var near_enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	near_enemy.max_health = 100
	near_enemy.health = 100
	main.get_node("World").add_child(near_enemy)
	near_enemy.global_position = player.global_position + Vector2(player.attack_range * 2.0, 0)
	await get_tree().process_frame
	main._quest_mode_tick()
	ok = _check("(1) near_dist 안 적 1마리 -> auto_hunt=true", player.auto_hunt == true) and ok
	ok = _check("(1) near_dist 안 적 1마리 -> auto_walk_active=false", player.auto_walk_active == false) and ok
	near_enemy.queue_free()
	await get_tree().process_frame

	# (2) near_dist 밖 적만 -> 추격 안 하고 경로(auto_walk) 유지
	player.auto_hunt = false
	player.auto_walk_active = false
	var far_enemy: Node = preload("res://scenes/enemy.tscn").instantiate()
	far_enemy.max_health = 100
	far_enemy.health = 100
	main.get_node("World").add_child(far_enemy)
	far_enemy.global_position = player.global_position + Vector2(player.attack_range * 3.5, 0)
	await get_tree().process_frame
	main._quest_mode_tick()
	ok = _check("(2) near_dist 밖 적만 -> auto_walk_active=true", player.auto_walk_active == true) and ok
	ok = _check("(2) near_dist 밖 적만 -> auto_hunt=false", player.auto_hunt == false) and ok
	far_enemy.queue_free()
	await get_tree().process_frame

	# (3) 적 0 -> 동쪽 출구 목표로 auto_walk
	player.auto_hunt = true
	player.auto_walk_active = false
	main._quest_mode_tick()
	var expect_target: Vector2 = main._quest_east_exit_target(GameState.current_map)
	ok = _check("(3) 적 0 -> auto_hunt=false", player.auto_hunt == false) and ok
	ok = _check("(3) 적 0 -> auto_walk_active=true", player.auto_walk_active == true) and ok
	ok = _check("(3) 적 0 -> auto_walk_target=동쪽 출구", player.auto_walk_target == expect_target) and ok

	main.queue_free()
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
