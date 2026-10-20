extends Node
## 심연의 탑 15층 진입 시 "남은 몬스터 2"인데 화면에 몬스터가 안 보인다는
## 버그 재현: 스폰된 몬스터들의 실제 좌표와 landmark(조형물) 겹침 여부,
## 그리고 서로 겹쳐 스폰됐는지를 검사한다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()

	GameState.game_cleared = true
	GameState.tower_difficulty = "easy"
	GameState.tower_progress["easy"] = 14
	GameState.tower_active = false
	main._change_map("tower", false)
	await get_tree().process_frame
	# 15층까지 강제 진행
	GameState.tower_active = true
	GameState.tower_floor = 15
	main._spawn_tower_floor()
	await get_tree().process_frame

	var enemies := get_tree().get_nodes_in_group("enemies")
	print("스폰된 몬스터 수: ", enemies.size(), " / tower_enemies_remaining=", main.tower_enemies_remaining)
	var positions := []
	for e in enemies:
		var cell := Vector2i(e.position / 16.0)
		positions.append(cell)
		print("  - ", e.kind.get("id", "?"), " cell=", cell, " pos=", e.position, " visible=", e.visible)

	# landmark 좌표(2x2): tower_a(3,3) tower_b(14,3) tower_c(8,10)
	var landmark_cells := []
	for lm in [[3,3],[14,3],[8,10]]:
		for dy in 2:
			for dx in 2:
				landmark_cells.append(Vector2i(lm[0]+dx, lm[1]+dy))

	var overlap_landmark := 0
	for c in positions:
		if landmark_cells.has(c):
			overlap_landmark += 1
	print("landmark와 겹치는 스폰: ", overlap_landmark)

	var dupes := 0
	for i in positions.size():
		for j in range(i+1, positions.size()):
			if positions[i] == positions[j]:
				dupes += 1
	print("서로 같은 칸에 겹쳐 스폰된 쌍: ", dupes)

	get_tree().quit()
