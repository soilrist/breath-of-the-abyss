extends Node
## (감독 2026-09-09) "퀘스트모드도 예전 오토모드처럼 아이템을 안 먹는다".
## 줍기는 `_auto_hunt_tick()`에만 있고, 퀘스트모드는 목표를 채운 뒤나 적이
## 사거리 밖일 때 `_quest_set_auto_walk()`(A*)로 걸어 드랍을 두고 떠났다.
## 적이 없는 hill(목표 달성, 동쪽 출구로 나가는 상태)에서 동쪽 근접(40px)
## 드랍을 줍고 서쪽 원거리(120px, A* 경로) 드랍까지 되돌아가 줍는지 본다 -
## 예전 코드는 동쪽 출구로만 걸어 서쪽 드랍을 영영 두고 갔다.
const PHYS_PER_TICK := 36
const MAX_TICKS := 100 ## 60초.


func _ready() -> void:
	seed(20260909)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	while main.dialogue_open: main._advance_dialogue()
	GameState.unlock_map("hill")
	GameState.quest_stage = 1
	GameState.kills = 6
	GameState.potions = 5
	GameState.gold = 0
	main.quest_mode = true
	var player: Node = main.get_node("Player")
	var start := Vector2(200.0, main.get_node("World").path_row_at("hill", 12) * World.TILE + 8.0)
	main._change_map("hill", false, start)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	await get_tree().process_frame
	player.global_position = start
	player.health = player.max_health
	main._on_enemy_dropped({"kind": "gold", "amount": 7}, start + Vector2(40.0, 0.0))
	main._on_enemy_dropped({"kind": "gold", "amount": 11}, start + Vector2(-120.0, 0.0))
	await get_tree().process_frame
	var golds := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.kind == "gold": golds += 1
	var ok := _check("준비: 골드 드랍 2개, 적 0", golds == 2 and get_tree().get_nodes_in_group("enemies").is_empty())
	var collected_tick := -1
	var left_early := false
	for t in MAX_TICKS:
		main._quest_mode_tick()
		for i in PHYS_PER_TICK:
			await get_tree().physics_frame
		while main.dialogue_open: main._advance_dialogue()
		if GameState.current_map != "hill" and GameState.gold < 18:
			left_early = true
			break
		if GameState.gold >= 18 and collected_tick < 0:
			collected_tick = t
			break
	ok = _check("드랍을 두고 지역을 떠나지 않음", not left_early) and ok
	ok = _check("근접+원거리 드랍 둘 다 주움(gold=%d, tick=%d)" % [GameState.gold, collected_tick], GameState.gold == 18) and ok
	if not ok:
		print("pos=%s walk=%s hunt=%s tgt=%s" % [player.global_position, player.auto_walk_active, player.auto_hunt, player.auto_walk_target])
	player.auto_walk_active = false
	player.auto_hunt = false
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
