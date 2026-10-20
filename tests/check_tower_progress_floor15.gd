extends Node
## 실제 플레이 흐름과 최대한 비슷하게: 탑에 입장해서 층을 하나씩 클리어하며
## 15층까지 진행한다. 각 층에서 스폰 직후 상태(개수·좌표·겹침)를 확인한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.game_cleared = true
	GameState.tower_difficulty = "easy"
	main._change_map("tower", false)
	await get_tree().process_frame
	await get_tree().process_frame

	var ok := true
	while GameState.tower_floor <= 15:
		var f: int = GameState.tower_floor
		var enemies := get_tree().get_nodes_in_group("enemies")
		var positions := []
		for e in enemies:
			positions.append(Vector2i(e.position / 16.0))
		var dupes := 0
		for i in positions.size():
			for j in range(i+1, positions.size()):
				if positions[i] == positions[j]:
					dupes += 1
		var count_ok: bool = enemies.size() == main.tower_enemies_remaining and enemies.size() > 0
		ok = count_ok and ok
		ok = (dupes == 0) and ok
		print("floor=%d count=%d remaining=%d dupes=%d %s" % [
			f, enemies.size(), main.tower_enemies_remaining, dupes,
			"OK" if (count_ok and dupes == 0) else "FAIL"])
		# 이 층의 몬스터를 전부 "처치"해서 자연스럽게 다음 층으로 넘어간다.
		for e in enemies.duplicate():
			if is_instance_valid(e):
				e.take_damage(999999, Vector2.ONE)
		await get_tree().process_frame
		await get_tree().process_frame

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
