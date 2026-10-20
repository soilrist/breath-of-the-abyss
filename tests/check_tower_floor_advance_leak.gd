extends Node
## 탑에서 맵 재진입 없이 같은 화면 안에서 계속 몬스터를 스폰(_spawn_tower_floor)해도
## 노드가 새지 않는지 검증. 기존 check_map_transition_leak은 맵을 왔다갔다
## 전환하는 경로만 봤고, 같은 맵 안에서 층만 넘어가는 경로(실제 플레이의
## 주된 탑 공략 방식)는 아직 검사가 없었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.game_cleared = true
	GameState.tower_difficulty = "easy"
	GameState.tower_progress["easy"] = 50
	GameState.tower_active = true
	main._change_map("tower", false)
	await get_tree().process_frame

	# floor_num을 고정해 매번 같은 수의 몬스터를 스폰한다 - _advance_tower_floor는
	# 층이 오를수록 몬스터 수도 늘어(count = 5 + floor_num/10) 노드 수가 자연히
	# 늘어나므로, 그 증가와 진짜 누수를 구분하려면 스폰 수를 고정해야 한다.
	GameState.tower_floor = 50
	var node_counts := []
	for i in 30:
		main._spawn_tower_floor()
		await get_tree().process_frame
		await get_tree().process_frame
		node_counts.append(get_tree().get_node_count())

	# 처음 몇 번은 아직 안 정리된 이전 프레임 잔여가 섞일 수 있어 워밍업으로
	# 건너뛰고, 그 뒤로도 노드 수가 계속 늘면 새는 것이다.
	var early: int = node_counts[4]
	var late: int = node_counts[node_counts.size() - 1]
	var ok: bool = late <= early
	print("tower same-floor respawn node count: lap5=%d lap30=%d %s" % [
		early, late, "OK" if ok else "FAIL"])

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
