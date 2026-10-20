extends Node
## 몬스터 여러 마리를 같은 자리에서 처치하면 드랍 아이템(pickup)이 겹쳐
## 쌓인다. 그 더미를 전부 주웠을 때 노드가 남지 않고(누수 없음), 개수만큼
## 정확히 반영되는지 검증. check_combat_fx_leak.gd와 같은 패턴.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.gold = 0
	await get_tree().process_frame

	var baseline := get_tree().get_node_count()
	var spot: Vector2 = player.global_position

	var stack_size := 15
	for i in stack_size:
		main._on_enemy_dropped({"kind": "gold", "amount": 3 + i}, spot)

	var mid := get_tree().get_node_count()
	var spawned_ok: bool = mid > baseline
	print("드랍 직후 노드 증가: base=%d mid=%d %s" % [baseline, mid, "OK" if spawned_ok else "FAIL"])

	var stacked: Array = get_tree().get_nodes_in_group("pickups")
	var stack_ok: bool = stacked.size() == stack_size
	print("겹쳐 쌓인 개수: %d/%d %s" % [stacked.size(), stack_size, "OK" if stack_ok else "FAIL"])

	for p in stacked:
		p._on_body_entered(player)
	await get_tree().process_frame

	var after := get_tree().get_node_count()
	var cleared_ok: bool = after <= baseline
	print("주운 후 노드 복귀: base=%d after=%d %s" % [baseline, after, "OK" if cleared_ok else "FAIL"])

	var groups_ok: bool = get_tree().get_nodes_in_group("pickups").is_empty()
	print("pickups 그룹 잔존 없음: %s" % ("OK" if groups_ok else "FAIL"))

	var expected_gold := 0
	for i in stack_size:
		expected_gold += 3 + i
	var gold_ok: bool = GameState.gold == expected_gold
	print("골드 합산 정확: 기대=%d 실제=%d %s" % [expected_gold, GameState.gold, "OK" if gold_ok else "FAIL"])

	var ok := spawned_ok and stack_ok and cleared_ok and groups_ok and gold_ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
