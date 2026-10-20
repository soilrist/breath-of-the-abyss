extends Node
## 전투 중 반복 스폰되는 이펙트(베기 궤적/스킬 이펙트/화살)가 자기 수명이
## 끝나면 스스로 사라지는지, 연속으로 여러 번 써도 노드가 안 쌓이는지 검증.
## 지금까지 맵 전환 반복 누수(check_map_transition_leak)는 검사가 있었지만
## 같은 맵 안에서 전투 FX를 반복 스폰할 때의 누수는 검사가 없었다.

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var player: Node = main.get_node("Player")

	GameState.reset()
	GameState.level = 15
	player.mana = 999
	player.max_mana = 999
	player.facing = Vector2.RIGHT
	await get_tree().process_frame

	var baseline := get_tree().get_node_count()

	for i in 20:
		player._spawn_slash(Vector2.RIGHT, Color.WHITE, 1.0)
	for i in 20:
		player._spawn_skill_fx("res://assets/fx/burst.png", 4, 0.06, Color.WHITE, 1.0)
	for i in 20:
		player._shoot_arrow()

	var mid := get_tree().get_node_count()
	var spawned_ok: bool = mid > baseline
	print("spawn 직후 노드 증가: base=%d mid=%d %s" % [baseline, mid, "OK" if spawned_ok else "FAIL"])

	# 화살 LIFE(0.9초)가 가장 오래 사니 넉넉히 기다린다. 헤드리스 모드의
	# 프레임 간 delta가 예상보다 짧아(실측 약 0.006초/프레임 ~166Hz) 90프레임
	# (0.9초 가정)으로는 실제 0.9초가 안 채워져 화살이 안 사라진 채로
	# 검사가 끝나는 오탐이 있었다(90프레임 후 _life가 0.36까지만 줆,
	# 실측 확인 완료) - 300프레임으로 넉넉히 늘렸다.
	for i in 300:
		await get_tree().process_frame

	var after := get_tree().get_node_count()
	var cleared_ok: bool = after <= baseline
	print("소멸 후 노드 복귀: base=%d after=%d %s" % [baseline, after, "OK" if cleared_ok else "FAIL"])

	var groups_ok: bool = get_tree().get_nodes_in_group("arrows").size() == 0
	print("arrows 그룹 잔존 없음: %s" % ("OK" if groups_ok else "FAIL"))

	var ok := spawned_ok and cleared_ok and groups_ok
	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()
