extends Node
## (감독 2026-09-09) 2장 4단계 정체 회귀 검사. 퀘스트모드가 가장자리 적을
## 쫓다(auto_hunt) 지역 끝에 닿아도 옆 지역으로 넘어가지 않고, 동쪽 출구로
## 걷는 중(auto_walk, `_quest_east_exit_target`)일 때만 넘어가는지 본다.
## 퀘스트모드가 아니면 예전대로 위치만으로 넘어간다.
const FRAMES := 90


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open: main._advance_dialogue()
	for m in ["harbor", "shore", "marsh", "marsh_deep"]: GameState.unlock_map(m)
	GameState.chapter = 2; GameState.quest_stage = 4; GameState.level = 22
	var player: Node = main.get_node("Player")
	var bounds: Vector2 = World.pixel_size_of("marsh")
	var row: float = World.path_row("marsh") * World.TILE + 8.0
	var ok := true
	var cases := [
		["추격 중 서쪽 끝 -> 안 넘어감", true, true, false, Vector2(main.EDGE_MARGIN - 2.0, row), "marsh"],
		["추격 중 동쪽 끝 -> 안 넘어감", true, true, false, Vector2(bounds.x - main.EDGE_MARGIN + 2.0, row), "marsh"],
		["줍기 걷기 중 서쪽 끝 -> 안 넘어감", true, false, true, Vector2(main.EDGE_MARGIN - 2.0, row), "marsh"],
		["동쪽 출구 걷기 -> 넘어감", true, false, true, Vector2(bounds.x - main.EDGE_MARGIN + 2.0, row), "marsh_deep"],
		["퀘스트모드 OFF 서쪽 끝 -> 넘어감", false, false, false, Vector2(main.EDGE_MARGIN - 2.0, row), "shore"],
	]
	for c in cases:
		main.quest_mode = c[1]
		main._change_map("marsh", false, Vector2(160.0, row))
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		for e in get_tree().get_nodes_in_group("enemies"):
			e.remove_from_group("enemies")
			e.queue_free()
		await get_tree().process_frame
		main.transition_lock = 0.0
		player.auto_hunt = c[2]
		player.auto_walk_active = c[3]
		player.auto_walk_waypoints.clear()
		player.auto_walk_target = Vector2(100.0, row)
		if c[5] == "marsh_deep":
			player.auto_walk_target = main._quest_east_exit_target("marsh")
		player.global_position = c[4]
		for i in FRAMES:
			await get_tree().process_frame
			if not player.auto_hunt and not player.auto_walk_active:
				player.global_position = c[4]
			if GameState.current_map != "marsh":
				break
		var pass_case: bool = GameState.current_map == c[5]
		print("%s: map=%s %s" % [c[0], GameState.current_map, "PASS" if pass_case else "FAIL"])
		ok = ok and pass_case
		player.auto_hunt = false
		player.auto_walk_active = false
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
