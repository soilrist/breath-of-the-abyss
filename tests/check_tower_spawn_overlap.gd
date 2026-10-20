extends Node
## 여러 층·난이도에서 몬스터 스폰이 서로 겹치지 않는지 광범위 검증.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.game_cleared = true
	# 실제 입장 경로(_confirm_tower_select -> _change_map("tower"))처럼 탑
	# 맵을 실제로 칠해 둬야 World._grid/랜드마크 충돌체가 탑 것으로 맞는다.
	# 이걸 안 하면 이전 맵(마을)의 그리드를 대신 검사해 결과가 무의미해진다.
	main._change_map("tower", false)
	var ok := true
	for tier in ["easy", "normal", "hard"]:
		GameState.tower_difficulty = tier
		GameState.tower_progress[tier] = 99
		for floor_num in [1, 10, 15, 25, 50, 99, 100]:
			GameState.tower_active = true
			GameState.tower_floor = floor_num
			print("  [before spawn] existing enemies=", get_tree().get_nodes_in_group("enemies").size())
			main._spawn_tower_floor()
			var enemies_immediate := get_tree().get_nodes_in_group("enemies")
			print("  [immediate right after call] count=", enemies_immediate.size())
			for e in enemies_immediate:
				print("    hp=", e.health, "/", e.max_health, " dmg=", e.damage, " def=", e.defense, " valid=", is_instance_valid(e), " pos=", e.position, " archetype=", e.archetype)
				e.tree_exiting.connect(func(): print("    !! tree_exiting for ", e.archetype, " at frame ", Engine.get_process_frames()))
			await get_tree().process_frame
			print("  [after frame 1] count=", get_tree().get_nodes_in_group("enemies").size())
			await get_tree().process_frame
			print("  [after frame 2] count=", get_tree().get_nodes_in_group("enemies").size())
			var enemies := get_tree().get_nodes_in_group("enemies")
			var positions := []
			for e in enemies:
				positions.append(Vector2i(e.position / 16.0))
			var dupes := 0
			for i in positions.size():
				for j in range(i+1, positions.size()):
					if positions[i] == positions[j]:
						dupes += 1
			var count_ok: bool = enemies.size() == main.tower_enemies_remaining
			var no_dupe: bool = dupes == 0
			ok = count_ok and ok
			ok = no_dupe and ok
			print("tier=%s floor=%d count=%d remaining=%d dupes=%d %s" % [
				tier, floor_num, enemies.size(), main.tower_enemies_remaining, dupes,
				"OK" if (count_ok and no_dupe) else "FAIL"])

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
