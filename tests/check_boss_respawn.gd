extends Node
## 보스는 처치해도 재입장 시 다시 등장해야 한다(보상·진행 기록만
## boss_defeated에 남고, 보스 자체를 영구히 막지 않는다는 설계 규칙).
## - 보스 지역 최초 입장 시 보스가 스폰되는지
## - 보스를 처치하면 사라지는지, boss_defeated가 기록되는지
## - 같은 보스 지역을 나갔다가 다시 들어오면 보스가 다시 스폰되는지

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	var player: CharacterBody2D = main.get_node("Player")

	# 1장 보스 지역(cave_deep)으로 이동.
	main._change_map("cave_deep", false)
	await get_tree().process_frame
	var boss := find_boss()
	ok = _check("보스 지역 최초 입장 시 보스가 스폰됨", boss != null) and ok

	if boss != null:
		player.global_position = boss.global_position + Vector2(boss.body_radius() + 5.0, 0.0)
		player.attack_damage = 400
		player.facing = Vector2.LEFT
		for i in 40:
			if not is_instance_valid(boss):
				break
			player.cooldown_time = 0.0
			player.attack()
			await get_tree().physics_frame
		ok = _check("보스를 처치하면 사라짐", not is_instance_valid(boss)) and ok
		ok = _check("처치 기록(boss_defeated)이 남음", GameState.boss_defeated) and ok

	# 다른 지역으로 나갔다가 같은 보스 지역으로 재입장.
	main._change_map("dungeon", false)
	await get_tree().process_frame
	main._change_map("cave_deep", false)
	await get_tree().process_frame
	var boss2 := find_boss()
	ok = _check("재입장 시 보스가 다시 스폰됨", boss2 != null) and ok
	ok = _check("처치 기록은 유지된 채로 재스폰됨", GameState.boss_defeated) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func find_boss() -> Node:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss:
			return enemy
	return null


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
