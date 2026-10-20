extends Node
## 씬 전환(맵 이동)을 반복해도 몬스터/줍기템 노드가 새지 않는지 검증.
## 지금까지 저장/불러오기 왕복, 프레임 성능은 검사가 있었지만 "여러 맵을
## 왔다갔다 반복해도 이전 맵의 노드가 안 남는지"는 검사가 없었다(STATUS 확인).
## 경로에 던전 2곳(glacier/abyss, 문 스폰 포함)과 5~9장 마을(remnant_village
## ~rift_camp, NPC 배치 포함)도 넣어 1~2장/탑 외 지역도 새지 않는지 넓혔다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.game_cleared = true
	var route := [
		"forest_w", "ruins_w", "village", "tower", "village",
		"glacier", "abyss", "remnant_village", "driftwood_pier",
		"lantern_village", "waystation_camp", "rift_camp", "village",
	]
	var enemy_counts := []
	var tree_node_counts := []
	var ok := true
	for cycle in 6:
		for map_name in route:
			if map_name == "tower":
				GameState.tower_difficulty = "easy"
				GameState.tower_progress["easy"] = 50
				GameState.tower_floor = 20
			main._change_map(map_name, false)
			await get_tree().process_frame
			await get_tree().process_frame
			enemy_counts.append(get_tree().get_nodes_in_group("enemies").size())
			tree_node_counts.append(get_tree().get_node_count())

	# 이전 맵의 몬스터/전체 노드가 queue_free 안 되고 쌓이면 같은 지역을 도는
	# 뒷바퀴일수록 수가 계속 늘어난다. 6바퀴 돈 뒤 마지막 바퀴 값이 첫 바퀴
	# 값보다 크면 새는 것이다.
	var first_enemies: int = enemy_counts[route.size() - 1]
	var last_enemies: int = enemy_counts[enemy_counts.size() - 1]
	var enemies_ok: bool = last_enemies <= first_enemies
	ok = enemies_ok and ok
	print("enemy count per lap (last map of lap): first=%d last=%d %s" % [
		first_enemies, last_enemies, "OK" if enemies_ok else "FAIL"])

	var first_nodes: int = tree_node_counts[route.size() - 1]
	var last_nodes: int = tree_node_counts[tree_node_counts.size() - 1]
	var nodes_ok: bool = last_nodes <= first_nodes
	ok = nodes_ok and ok
	print("scene tree node count per lap (last map of lap): first=%d last=%d %s" % [
		first_nodes, last_nodes, "OK" if nodes_ok else "FAIL"])

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
