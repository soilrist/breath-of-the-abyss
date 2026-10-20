extends Node
## (감독 2026-09-08) 10장 탐침 STALL 회귀 검사. 적을 다 잡은 사냥터에서
## 퀘스트틱이 동쪽 출구로 걸어 나가는지 본다 - marsh_deep (230.96,543.08)은
## `path_row_at` 평균 행 목표와 길 복귀 목표 사이를 영원히 왕복하던 자리,
## citadel_gate (232,248)은 길 복귀 목표가 소품 충돌체 안이던 자리다.
const CASES := [["marsh_deep", Vector2(230.96, 200.0), "ruins_w"], ["citadel_gate", Vector2(232.0, 200.0), "citadel"]]
const PHYS_PER_TICK := 36
const MAX_TICKS := 300 ## 180초. 640px 지역을 72px/s로 곧장 가면 9초.


func _ready() -> void:
	seed(20260907)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open: main._advance_dialogue()
	for m in ["shore", "marsh", "marsh_deep", "ruins_w", "citadel_gate", "citadel"]: GameState.unlock_map(m)
	GameState.chapter = 2; GameState.quest_stage = 4; GameState.level = 22
	GameState.potions = 5; GameState.gold = 500
	main.quest_mode = true
	var player: Node = main.get_node("Player")
	var ok := true
	for c in CASES:
		main._change_map(c[0], false, c[1])
		await get_tree().process_frame
		while main.dialogue_open: main._advance_dialogue()
		for e in get_tree().get_nodes_in_group("enemies"):
			e.remove_from_group("enemies")
			e.queue_free()
		await get_tree().process_frame
		player.global_position = c[1]
		player.health = player.max_health
		var reached := false
		for t in MAX_TICKS:
			main._quest_mode_tick()
			for i in PHYS_PER_TICK:
				await get_tree().physics_frame
			while main.dialogue_open: main._advance_dialogue()
			if GameState.current_map == c[2]:
				reached = true
				print("%s -> %s tick=%d" % [c[0], c[2], t])
				break
		if not reached:
			print("%s STALL pos=%s tgt=%s" % [c[0], player.global_position, player.auto_walk_target])
		ok = reached and ok
		player.auto_walk_active = false
		player.auto_hunt = false
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
