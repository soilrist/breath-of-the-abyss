extends Node
## 원거리/마법형 몬스터가 실제 투사체(화살/마법구)를 발사하고, 그
## 투사체가 플레이어에게 닿아야 피해가 들어가는지 확인한다.
## - 사거리 안에 들어와도 즉시 데미지가 아니라 투사체가 먼저 생성되는지
## - 투사체가 실제로 플레이어 쪽으로 이동하는지
## - 투사체가 플레이어에게 닿으면 피해가 들어가고 사라지는지
## - 지역을 옮기면 남은 투사체가 정리되는지

func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	while main.dialogue_open: main._advance_dialogue()
	var ok := true

	var player: CharacterBody2D = main.get_node("Player")
	player.global_position = Vector2(160, 120)
	player.health = player.max_health

	# 원거리형(ranged) 몬스터 하나를 플레이어 근처에 배치.
	var ranged_enemy: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	ranged_enemy.position = Vector2(160, 178)
	ranged_enemy.damage = 10
	ranged_enemy.archetype = "spirit"
	ranged_enemy.area_id = GameState.current_map
	main.add_child(ranged_enemy)

	# 몹의 물리 처리가 한 프레임 돌면서 사거리 판정 -> 투사체 발사까지
	# 이어지도록 몇 프레임 기다린다.
	var fired := false
	for i in 30:
		await get_tree().physics_frame
		var projectiles := get_tree().get_nodes_in_group("enemy_projectiles")
		if not projectiles.is_empty():
			fired = true
			break
	ok = _check("원거리 몬스터가 즉시 때리지 않고 투사체를 실제로 생성함", fired) and ok

	if fired:
		var proj: Area2D = get_tree().get_nodes_in_group("enemy_projectiles")[0]
		var before_pos: Vector2 = proj.global_position
		var before_hp: int = player.health
		await get_tree().physics_frame
		await get_tree().physics_frame
		ok = _check("발사된 투사체가 실제로 이동함(위치 변화)",
			is_instance_valid(proj) and proj.global_position != before_pos or player.health < before_hp) and ok

		# 플레이어 체력이 아직 안 깎였다면(투사체가 아직 안 닿았다면) 강제로
		# 투사체를 플레이어 위치로 옮겨 충돌 판정을 재현한다.
		if is_instance_valid(proj) and player.health == before_hp:
			proj.global_position = player.global_position
			await get_tree().physics_frame
		ok = _check("투사체가 플레이어에게 닿으면 피해가 들어감", player.health < before_hp) and ok

	# 마법형(magic) 몬스터도 같은 방식으로 확인.
	var magic_enemy: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
	## (감독 결함 수정, 2026-09-08) 적도 지역 경계에 갇히므로(enemy.gd
	## clamp) 마을(320x240) 밖 y=260에 두면 y=230으로 밀려 시전 거리
	## (attack_range-24 이상)가 안 나온다 - 지역 안에서 거리를 확보한다.
	magic_enemy.position = Vector2(160, 170)
	magic_enemy.damage = 10
	magic_enemy.archetype = "flam"
	magic_enemy.area_id = GameState.current_map
	main.add_child(magic_enemy)
	player.global_position = Vector2(160, 40)

	var magic_fired := false
	for i in 120:
		await get_tree().physics_frame
		var projectiles := get_tree().get_nodes_in_group("enemy_projectiles")
		for p in projectiles:
			if p.kind == "magic":
				magic_fired = true
				break
		if magic_fired:
			break
	print("debug magic_enemy pos=", magic_enemy.global_position,
		" player pos=", player.global_position,
		" cast_time=", magic_enemy.cast_time, " attack_time=", magic_enemy.attack_time,
		" behavior=", magic_enemy.kind.get("behavior"))
	ok = _check("마법형 몬스터도 시전 후 실제 투사체(화염구)를 생성함", magic_fired) and ok

	# 지역 이동 시 잔여 투사체가 정리되는지. 이동 직전에 몬스터를 먼저
	# 치워야 이동 직후 프레임에 새 투사체가 다시 생기지 않는다.
	ranged_enemy.queue_free()
	magic_enemy.queue_free()
	await get_tree().process_frame
	main._change_map(GameState.current_map, false)
	await get_tree().process_frame
	ok = _check("지역 이동 후 몬스터 투사체가 전부 정리됨",
		get_tree().get_nodes_in_group("enemy_projectiles").is_empty()) and ok

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
