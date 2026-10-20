extends Node
## 탑 Phase 3 - 나머지 4개 난이도(보통/어려움/헬/심연)가 실제로 돌아가는지
## 확인한다. 몬스터 풀을 안 채우면 층에 몬스터가 하나도 안 뜨고 진행이
## 막히는 게 진짜 위험한 버그라, 5개 난이도 전부 실제로 스폰까지 해본다.

func _ready() -> void:
	var ok := true
	var tiers: Array = GameState.TOWER_TIERS.keys()

	ok = _check("5개 난이도 전부 있음", tiers.size() == 5) and ok

	var probe: Node = preload("res://scenes/enemy.tscn").instantiate()
	add_child(probe)
	for tier in tiers:
		var pool: Array = GameState.TOWER_MONSTER_POOLS.get(tier, [])
		ok = _check("%s 난이도 몬스터 풀이 채워짐" % tier, not pool.is_empty()) and ok
		for kind_id in pool:
			ok = _check("%s 풀의 '%s'는 실제 KINDS에 있음" % [tier, kind_id],
				probe.KINDS.has(kind_id)) and ok
	probe.queue_free()

	# 실제 씬으로 5개 난이도를 다 입장시켜, 몬스터가 실제로 스폰되고
	# 그 풀에 속한 종류만 나오는지 확인한다.
	GameState.reset()
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	for tier in tiers:
		GameState.tower_active = false
		GameState.tower_difficulty = tier
		GameState.tower_progress[tier] = 0
		main._change_map("tower", false)
		var tower_enemies: Array = []
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.area_id == "tower":
				tower_enemies.append(enemy)
		ok = _check("%s 난이도 1층에 몬스터가 실제로 스폰됨" % tier,
			not tower_enemies.is_empty() and tower_enemies.size() == main.tower_enemies_remaining) and ok
		var pool: Array = GameState.TOWER_MONSTER_POOLS.get(tier, [])
		var all_from_pool := true
		for enemy in tower_enemies:
			if not pool.has(enemy.archetype):
				all_from_pool = false
		ok = _check("%s 난이도 스폰 몬스터가 전부 그 난이도 풀 소속" % tier, all_from_pool) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
